# Project 3 Tuning Report

For this project I picked nine queries a developer relations analyst would run
against my Hacker News data and timed them. Then I read the query plans, added
indexes, and timed them again. `bench/benchmark.py` runs each query 5 times.
"Cold" means the first run, and "warm" means the median of runs 2 to 5. I compare
warm times unless I say otherwise.

## 1. Test Environment

I ran PostgreSQL on my own laptop, and `benchmark.py` ran on the same laptop.
Later I repeated the whole thing on HiPerGator (section 5a).

| | |
|---|---|
| Machine | Apple M3 Pro laptop, 12 cores, 18 GB RAM, SSD |
| PostgreSQL | 17.11 (Homebrew) |
| Client | macOS, Python 3.13.2 |
| Memory settings | shared_buffers 128MB, work_mem 4MB, effective_cache_size 4GB |
| Planner settings | random_page_cost 4, seq_page_cost 1, up to 2 parallel workers, JIT on |
| Statistics | default_statistics_target 100, autovacuum on |
| Database collation | en_US.UTF-8 (this turned out to matter for b07) |

These all come from `bench/before/environment.txt`. The settings are the same
in `bench/after/environment.txt`. The only differences are the new indexes,
the bigger table sizes, and the "last analyze" times.

**How much data.** Loading the whole year took hours, so `load.py` now has a row
cap called `MAX_ROWS`. The default is 200,000. It loads the newest 200,000 comments from
2024 and every story posted during the same days, which works out to
December 4 to 31, 2024. Loading from scratch, including downloading from the
API, took **7.8 minutes** on my laptop and **5.5 minutes** on HiPerGator.

| Table | Rows | Size |
|---|---:|---:|
| comments | 188,712 | 148 MB |
| stories | 19,561 | 6.2 MB |
| users | 32,989 | 2.9 MB |
| links | 16,596 | 3.8 MB |
| story_tags | 21,951 | 2.2 MB |
| domains | 7,116 | 0.8 MB |
| polls / poll_options | 3 / 13 | tiny |
| whole database | | 172 MB before, 191 MB after |

About 11,000 downloaded comments were skipped because their story was posted
before December 4. `comments` is the only big table, so that is where indexes
matter most. `stories` is small enough to sit in memory the whole time.

Before the baseline run I ran `VACUUM ANALYZE`, so the planner had up-to-date
statistics in both runs.

## 2. Workload Summary

My scenario from earlier projects: I work in developer relations for a company
that makes AI and agent tools, and I want to know which AI stories get attention
on Hacker News, which threads get a lot of different people talking, and who the
active users are. These nine queries are things I would actually check
every day or week.

| Query | Type | What it answers |
|---|---|---|
| b01 | lookup | All comments on one big story (the OpenAI o3 announcement) |
| b02 | lookup | The 50 latest comments from one user (simonw) |
| b03 | lookup | All stories posted by one frequent poster |
| b04 | range | Comments per hour on December 20, the day o3 came out |
| b05 | range | Top 30 stories from one week |
| b06 | aggregation | Which websites post the most AI stories |
| b07 | aggregation | The most active commenters in one week |
| b08 | join | AI stories from one week, ranked by how many different people commented |
| b09 | join | Which stories one user commented on, and how many times |

I left out year-long reports like "comments per month". They have to read every
row anyway, so no index would help them, and I would only run them once.
To find AI stories I used PostgreSQL full-text search (`to_tsvector ... @@
to_tsquery`) instead of the regex from Project 2, because full-text search
can use an index.

## 3. Initial Measurements (before any changes)

| Query | What the plan did | Cold ms | Warm ms |
|---|---|---:|---:|
| b01 | Read the whole comments table (parallel Seq Scan), then sorted | 24.08 | 13.29 |
| b02 | Read the whole comments table, then sorted | 12.09 | 11.79 |
| b03 | Read the whole (small) stories table | 1.47 | 0.71 |
| b04 | Read the whole comments table, then grouped by hour | 12.81 | 12.27 |
| b05 | Read the whole (small) stories table, kept the top 30 | 2.03 | 1.76 |
| b06 | Read all stories and ran the text-search function on every title | 75.97 | 74.66 |
| b07 | Read the whole comments table, then sorted 51,000 rows by username | 106.06 | 107.26 |
| b08 | Read the whole comments table to find comments on 51 stories | 35.46 | 31.84 |
| b09 | Read the whole comments table to find one user's 174 comments | 13.07 | 12.93 |

The main problem was clear: most queries read all 188,712 comments even when
they only needed a few hundred. Nothing spilled to disk; every sort fit in
memory. Two queries were slow for a different reason:

- **b06:** about 69 of its 75 ms went to running `to_tsvector` on all 19,561
  titles.
- **b07:** reading the rows took only about 23 ms, but sorting them by username
  took about 75 ms.

## 4. Hypotheses and Interventions

**1. Looking up comments by story (b01, b08).** `comments.story_id` is a
foreign key, but PostgreSQL doesn't index foreign keys automatically, so finding
"all comments on story X" means reading the whole table. I added a B-tree
index on `comments (story_id, author)`.
Now b01 jumps straight to the 1,754 comments it needs, and reads about 1,700
pages instead of about 17,800. b01 went from **13.29 to 0.50 ms**. I put `author` in the
index too, so that b08 can count commenters from the index alone without visiting
the table.

**2. Text search on titles (b06, b08).** b06 was spending most of its time
running the text-search function on every title. I added a GIN index on
`to_tsvector('english', title)`. The expression in the index has to match the
query exactly, or PostgreSQL won't use it. Now the plan uses a Bitmap Index Scan to
find the 2,199 AI stories directly. b06 went from **74.66 to 5.31 ms**. For b08
this index and index 1 work together. PostgreSQL first finds the AI stories from
that week, then looks up only their comments, instead of reading every comment.
b08 went from **31.84 to 5.97 ms**.

**3. The slow sort in b07.** The plan showed the sort was the slow part, not
reading the data. My guess was that the database's language-aware text
sorting (en_US.UTF-8) is slow. To test it, I ran the same query with plain byte-order
sorting (`COLLATE "C"`). The sort dropped from about 100 ms to about 10 ms, so the guess was
right. I didn't want to change how usernames sort, because that would change the
results people see. So instead I added an index that already stores the rows in
the order the query needs: `comments (author, story_id) INCLUDE (created_at)`.
PostgreSQL can now read everything it needs straight from the index, already in
order, and skip the sort entirely. b07 went from **107.26 to 14.11 ms**. The same index also
helps b02 (**11.79 to 0.12 ms**) and b09 (**12.93 to 0.12 ms**), since both look up
one author.

**4. One day of comments (b04).** I added a plain B-tree index on
`comments (created_at)`. Now PostgreSQL reads only that day's 7,378 entries
from the index. b04 went from **12.27 to 1.63 ms**.

**Things I tried that didn't work** (these are not in `schema-changes.sql`):

1. **BRIN index on `comments.created_at`.** A BRIN index is tiny but only works well
   when rows are stored in time order. My comments weren't, because the loader
   updates every comment a second time to fill in its parent, and that moves rows to
   the end of the table. PostgreSQL either ignored this index or got many false matches.
2. **Re-sorting the comments table by time (`CLUSTER`) and then using BRIN.** This
   put the rows in perfect time order, but PostgreSQL still preferred other
   indexes. It also made b09 slower (0.4 to 3.2 ms), because one person's comments
   ended up spread across the table. `CLUSTER` can't be undone with a simple DROP either,
   so I dropped the idea.
3. **BRIN index on `stories.created_at` for b05.** Stories *are* stored in time
   order, so this looked like a good fit, but b05 didn't get faster. Worse, in a
   full run PostgreSQL combined it with the text-search index for b08, and
   because BRIN only gives rough matches, it had to re-check about 5,300 rows.
   b08 slowed down to 26.6 ms, so I removed it.
4. **B-tree on `stories(created_at)` for b05.** The week covers about a quarter
   of the table, so using the index was slower (2.8 ms) than just reading the
   whole small table (1.7 ms).
5. **B-tree on `stories(author, created_at)` for b03.** It was also slower than
   reading the small table (1.4 vs 0.8 ms).
6. **Separate indexes for b01 and b02** that also matched their ORDER BY. They were
   a tiny bit faster, but the indexes I already had were fast enough, and
   every extra index makes inserts slower and takes space.

**b03 and b05 didn't change.** The stories table is only 638 pages and
always in memory, so reading all of it takes under 2 ms, and no index beat that. Their
before and after plans are exactly the same, so the small differences in timing
are just noise.

## 5. Final Measurements (laptop)

| Query | Before cold | Before warm | After cold | After warm | Change (warm) |
|---|---:|---:|---:|---:|---|
| b01-lookup-comments-by-story | 24.08 | 13.29 | 2.28 | 0.50 | 27x faster |
| b02-lookup-comments-by-author | 12.09 | 11.79 | 0.30 | 0.12 | 98x faster |
| b03-lookup-stories-by-author | 1.47 | 0.71 | 1.89 | 0.85 | no change |
| b04-range-comments-by-hour | 12.81 | 12.27 | 1.85 | 1.63 | 7.5x faster |
| b05-range-stories-by-week | 2.03 | 1.76 | 2.10 | 2.83 | no change |
| b06-agg-stories-by-domain | 75.97 | 74.66 | 6.60 | 5.31 | 14x faster |
| b07-agg-comments-by-author | 106.06 | 107.26 | 22.07 | 14.11 | 7.6x faster |
| b08-join-stories-comments | 35.46 | 31.84 | 7.87 | 5.97 | 5.3x faster |
| b09-join-comments-stories-by-user | 13.07 | 12.93 | 0.16 | 0.12 | 108x faster |

The four new indexes take about 19 MB together, roughly 11% of the database.
Both runs were on the same server with the same settings, a couple of minutes
apart. On a laptop, small timings jump around a bit, so I only count a change as
real when the plan changed too.

### 5a. Repeating it on HiPerGator

To make sure the steps in the README work for graders, I pulled the code into my
HiPerGator folder and ran everything from scratch. These results are not the
committed `bench/` files; the laptop run is the official one.

HiPerGator ran PostgreSQL 18.6 in the course SLURM job (2 CPUs, 8 GB), and the
benchmark ran from the login node, which is a different machine. The settings matched the
laptop except `effective_io_concurrency` (16 instead of 0). The capped load took
5 minutes 28 seconds and gave the same row counts. Both SQL files ran cleanly, and running
`schema-changes.sql` a second time just skipped the existing indexes.

| Query | Before warm ms | After warm ms | Change |
|---|---:|---:|---|
| b01 | 47.08 | 2.35 | 20x faster |
| b02 | 48.33 | 0.43 | 112x faster |
| b03 | 1.77 | 4.95 | slower (see below) |
| b04 | 49.17 | 3.75 | 13x faster |
| b05 | 4.10 | 4.07 | no change |
| b06 | 252.78 | 14.11 | 18x faster |
| b07 | 188.28 | 41.15 | 4.6x faster |
| b08 | 130.22 | 13.41 | 9.7x faster |
| b09 | 43.62 | 10.31 | 4.2x faster |

Everything is 3 to 4 times slower than on my laptop because the server is smaller,
but the same seven queries improved. Two results needed a closer look:

- **b03 got slower,** but its plan didn't change at all. It's the same full read of
  `stories`, touching the same 638 pages. None of my indexes are on
  `stories.author`, so this is just the shared HiPerGator machine being slower
  during that run, not something the indexes caused.
- **b09 improved less than on the laptop.** On HiPerGator, PostgreSQL guessed that
  simonw had 195 comments (the real number is 174), while on my laptop it guessed 12.
  With the bigger guess it chose to build a hash table of all stories (about 8 ms)
  instead of looking up each story one at a time. The new index is still used, and it
  takes only 0.06 ms; the hash table is now the slow part. The guesses differ because
  ANALYZE looks at a random sample of rows. Giving the `author` column more
  statistics would probably fix it, but both plans cost about the same here, so I
  left it.

## 6. What I Would Do Differently With 10x the Data

With the full year (about 3 million comments), every query that still reads a
whole table would get about 16 times slower. The indexed queries would
barely change. For weekly reports like b07, I'd build a materialized view
with comment counts per user per week and refresh it once a night. I'd split
the comments table into one partition per month, so date-range queries
only look at the months they need. I'd also fix the loader so it doesn't update every
comment twice, which keeps rows in time order. I'd set `random_page_cost` to about 1.1,
since the data is on an SSD, and turn on `track_io_timing` to see where disk time goes.
If several analysts used this, I'd run their reports on a read replica so they
don't slow down loading. And at 300,000 stories, the `stories` indexes I
rejected here would probably start to pay off.
