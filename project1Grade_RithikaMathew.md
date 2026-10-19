# Project 1 notes for Rithika Mathew

These notes list what worked, what cost points, tips that did not cost points, and what to do before Project 2 and 3.
Your loader is repeatable: the counts are identical after loading twice into an empty PostgreSQL database, and every query runs.

## Score

| Area | Points | Out of | How the points were assigned |
|---|---|---|---|
| Schema design | 23 | 25 | Tables and normalization, including table comments 6/8; primary keys 4/4; foreign keys 5/5; constraints 4/4; data types 4/4 |
| ETL | 15 | 15 |  |
| Queries | 30 | 30 | q01 3, q02 3, q03 3, q04 3, q05 3, q06 3, q07 3, q08 3 (3 each); required query features 6/6 |
| Documentation | 10 | 10 | README 7/7; ER diagram 3/3 |
| Schema reviews | 10 | 10 | Diagram on main 3/3; reconstruction 1 3/3; reconstruction 2 3/3; assumption comments 1/1 |
| Review response | 5 | 5 | Discussion of the differences 2/2; categories 2/2; closing paragraph 1/1 |
| Repo hygiene | 5 | 5 |  |
| Total | 98 | 100 | |

## What worked well

- Loader design. load.py reads DATABASE_URL, runs schema.sql first, and fetches stories, polls, comments, and poll options (Algolia for the items, the Firebase API for option text). The recursive date-window splitting in `fetch_all_windowed` keeps each request under Algolia's result cap, and `dump_raw` writes to a .tmp file before renaming, so an interrupted download never leaves a half-written cache. `get_with_retry` backs off on 429 and 5xx responses.
- Repeatability. A load from an empty data/raw takes about 2.9 hours, mostly in the comment fetch (2 hours 34 minutes). A load that reuses data/raw takes 331 seconds, and the counts are identical after loading twice (users 141,430, domains 60,195, stories 297,625, story_tags 330,573, comments 3,093,962, polls 41, poll_options 485).
- Schema. The 7 tables use a composite key on story_tags, a self-referencing `comments.parent_comment_id`, a poll subtype table, ON DELETE actions chosen per relationship, TIMESTAMPTZ for instants, `UNIQUE` on `domains.domain_name`, and `CHECK (points >= 0)`.
- README. It explains the HiPerGator start-up steps, why $DATABASE_URL must be exported for psql, and the data quirks (first_seen_at is not a signup date, comments on 2023 stories are skipped, Algolia result limits).
- Queries. q04 compares `num_comments` with the loaded rows through a LEFT JOIN, and the top story shows the effect (9,274 comments reported, 9,273 loaded). q07 joins two pre-aggregated subqueries to users, which avoids multiplying rows.
- Review exchange. Your reconstruction 13.sql lists six assumptions (reserved word "character", weak-entity keys, rating as 1:1, one job per person per media, deathYear, nullable per_id). That is the kind of comment block the exercise asks for.

## What cost points

### Schema design (schema.sql)

Normalization cost points.

- `stories.url` determines `stories.domain_id`, because `domain_of()` in load.py computes the domain from the url (lines 214-218, used at line 349). A non-key column that determines another non-key column is the transitive dependency from the normalization lecture (Textbook §3.5.1, p. 102), and the project asks for third normal form. Move the pair into a table where the url is the key:

```sql
CREATE TABLE links (
    url        TEXT PRIMARY KEY,
    domain_id  INTEGER REFERENCES domains(domain_id)   -- NULL when the url has no host
);
-- stories.url then references links(url), and stories.domain_id is dropped.
-- q01 joins stories to links to domains.
```

Change load.py to insert one `links` row per distinct url before the stories, and remove `domain_id` from the `rows` tuple and the INSERT column list in `load_stories`:

```python
link_rows = {}
for hit in story_hits:
    url = hit.get("url")
    if url:
        link_rows[url] = domain_id_by_name.get(domain_of(url))
cur.executemany(
    "INSERT INTO links (url, domain_id) VALUES (%s, %s) ON CONFLICT (url) DO NOTHING",
    list(link_rows.items()),
)
```

If you keep `domain_id` on stories, say in a comment above the column that it is derived from url and why you keep it.

- `polls(poll_id, created_at)` repeats `stories.created_at`, because both come from `to_ts(hit)` (lines 363 and 481), and `stories.is_poll` repeats the existence of a row in `polls`. Keeping both copies lets them disagree, and a CHECK cannot compare two tables. Drop `polls.created_at`, so `polls` contains only the key, and read the poll flag from `polls` instead of storing it in `stories.is_poll`. `users.first_seen_at` is also computed from stories and comments, which your README documents, and a view over those tables avoids storing it. The schema change is two statements, and the flag becomes a query:

```sql
ALTER TABLE polls DROP COLUMN created_at;
ALTER TABLE stories DROP COLUMN is_poll;
SELECT s.story_id, EXISTS (SELECT 1 FROM polls p WHERE p.poll_id = s.story_id) AS is_poll
FROM stories s;
```

Change `poll_rows.append((poll_id, to_ts(hit)))` in `load_polls` to `poll_rows.append((poll_id,))` and the INSERT to `INSERT INTO polls (poll_id) VALUES (%s)`. In `load_stories`, remove `"poll" in tags` from the `rows` tuple and `is_poll` from the INSERT column list.

## Tips that did not cost points

### Constraints

Constraints did not cost points, because schema.sql declares NOT NULL, UNIQUE and CHECK constraints beyond the keys.
A story that is both Ask HN and Show HN is probably invalid, and one more CHECK states that:

```sql
ALTER TABLE stories ADD CONSTRAINT one_kind CHECK (NOT (is_ask_hn AND is_show_hn));
```

### ETL

- Document the runtime. The README says the normal command fetches the full range but not that it takes about three hours, and the missing estimate cost nothing. A line such as "first run takes about 3 hours because of Algolia limits; later runs reuse data/raw and take about 6 minutes" tells a reader to submit it as a batch job. Add the sbatch command or the screen or tmux advice you used.
- Log what you skip. This cost nothing, because the README states the rule for comments (lines 85 and 91) and the final counts are printed. `load_comments` drops comments whose story is outside 2024 (line 418), and 3,117,537 comments are cached against 3,093,962 loaded. A count per reason in the log lets a reader see how many rows each check removed. This version tracks the three `continue` branches of `load_comments`:

```python
from collections import Counter

skipped = Counter()
...
        if comment_id is None or story_id is None:
            skipped["missing id"] += 1
            continue
        comment_id = int(comment_id)
        if comment_id in seen_ids:
            skipped["duplicate id"] += 1
            continue
        story_id = int(story_id)
        if story_id not in story_ids:
            skipped["story outside the slice"] += 1
            continue
...
for reason, count in skipped.items():
    log.warning("Skipped %d comments: %s", count, reason)
```

  `load_polls` skips one poll option without a log line (line 495, 486 fetched and 485 loaded). The condition `opt_id in seen_opts or poll_id not in poll_ids` covers two reasons, so two separate checks let the log name the one that applied:

```python
skipped = Counter()
...
        if opt_id in seen_opts:
            skipped["duplicate id"] += 1
            continue
        if poll_id not in poll_ids:
            skipped["poll not loaded"] += 1
            continue
...
for reason, count in skipped.items():
    log.warning("Skipped %d poll options: %s", count, reason)
```

- Source count. data/source.md says 297,634 stories and the load produced 297,625. Say where the 9 went or update the number.
- Comment parents. The per-row UPDATE through `executemany` (lines 448-459) is a second pass over 3 million rows, and the comment load takes 3 minutes 24 seconds. A reply always has a larger id than its parent, so insert the rows sorted by `comment_id` and set `parent_comment_id` in the INSERT, using NULL when the parent is not loaded:

```python
loaded_ids = {r[0] for r in rows}
ordered = sorted(rows, key=lambda r: r[0])
cur.executemany(
    """
    INSERT INTO comments
        (comment_id, story_id, parent_comment_id, author, comment_text, created_at)
    VALUES (%s,%s,%s,%s,%s,%s)
    ON CONFLICT (comment_id) DO NOTHING
    """,
    [(r[0], r[1], r[2] if r[2] in loaded_ids else None, r[3], r[4], r[5]) for r in ordered],
)
```

### Queries

All 8 queries ran and answer their questions, and none of the following cost points.

- q03. `DATE_TRUNC('month', created_at)` runs in the session time zone, so a 2023-12-01 bucket with 257 comments appears for data created in 2024 UTC. Fix it with:

```sql
SELECT date_trunc('month', created_at AT TIME ZONE 'UTC') AS month,
       count(*) AS comments_posted
FROM comments
GROUP BY 1
ORDER BY 1;
```

- q06. `ILIKE '%code%'` also matches decode, barcode, and codec. A word-boundary regex matches the words you asked about:

```sql
WHERE title ~* '\m(python|code)\M'
   OR story_text ~* '\m(python|code)\M'
```

- q04. The LEFT JOIN is the right choice, and `ORDER BY hn_reported_comments DESC` with `LIMIT 100` hides the stories with zero loaded comments. Sort by the difference between the two counts to surface the mismatches:

```sql
SELECT s.story_id, s.title,
       s.num_comments                       AS hn_reported_comments,
       count(c.comment_id)                  AS loaded_comments,
       s.num_comments - count(c.comment_id) AS missing_comments
FROM stories s
LEFT JOIN comments c ON c.story_id = s.story_id
GROUP BY s.story_id, s.title, s.num_comments
ORDER BY missing_comments DESC, s.story_id
LIMIT 100;
```

- Header comments. q05.sql has "-- Difficulty: medium" appended to the Question line (line 2), and q03, q07, and q08 end without a trailing newline.
- Scenario. Your stakeholder is a developer relations analyst for AI and agentic developer tools, but only q06 mentions a topic. A keyword filter in q01, q05 and q08 ties them to the scenario, for example `WHERE s.title ~* '\m(ai|llm|llms|gpt|agents?)\M'`.
- Most of the set joins tables and groups the result, which the project accepts. Add one query with a CTE and a window function before Project 3 so the planner has another operator to work with, for example the 3 most active commenters in each of the 20 most commented stories:

```sql
WITH top_stories AS (
    SELECT story_id
    FROM comments
    GROUP BY story_id
    ORDER BY count(*) DESC
    LIMIT 20
),
ranked AS (
    SELECT c.story_id,
           c.author,
           count(*) AS comments_by_author,
           row_number() OVER (
               PARTITION BY c.story_id
               ORDER BY count(*) DESC, c.author
           ) AS rank_in_story
    FROM comments AS c
    JOIN top_stories AS t ON t.story_id = c.story_id
    WHERE c.author IS NOT NULL
    GROUP BY c.story_id, c.author
)
SELECT s.title, r.author, r.comments_by_author, r.rank_in_story
FROM ranked AS r
JOIN stories AS s ON s.story_id = r.story_id
WHERE r.rank_in_story <= 3
ORDER BY s.num_comments DESC, s.story_id, r.rank_in_story;
```

The window functions lectures cover the top-N per group template.

### Documentation and diagram

The README and diagram met the requirements, and the diagram matches schema.sql, including the optional author and domain relationships.

- List the expected runtime and the row counts a successful load prints, so a reader can check the result.
- The setup steps begin at the `.env` step. Add `uv sync` before `setup/verify.py`, and mention Python 3.11 or newer. This cost nothing, because `uv run --env-file .env load.py` syncs the environment by itself.
- The diagram labels the timestamps `timestamp` (er-diagram.png and er-diagram.md), and schema.sql has `TIMESTAMPTZ`. Both reconstructions typed `TIMESTAMP`, which followed the diagram. Label the columns `timestamptz` in the diagram.

### Schema reviews

29.sql has one assumption comment, and it says the crow's foot shows 1:N between trip and trip_payment.
The diagram draws one-to-one at both ends of "has" (the 1:N line is "uses" from payment_type), and your SQL already enforces 1:1 with `trip_id` as primary key and foreign key.
Say that the diagram draws 1:1 and the SQL follows it, and list the other open choices (nullability, the types) as you did in 13.sql.

### Review response

Both reconstructions of your diagram recovered the same 7 tables, keys, and foreign key directions, which shows the diagram was clear.
schema.md lists the nullability and SQL detail differences (SERIAL against plain int, TIMESTAMP against TIMESTAMPTZ, ON DELETE, CHECK) accurately, but they sit under "Category 2: A reviewer misread a marked element" while the text says no reviewer misread anything.
They belong under Category 1, because the diagram does not show NOT NULL, UNIQUE, or delete rules, and the group you chose cost no points.
Neither reconstruction put UNIQUE on `domain_name`, which schema.md does not mention.
The Revision section says the diagram and schema were unchanged, and marking required attributes in the diagram (for example with an "NN" note) would be a concrete revision.

## Before Project 2 and 3

- Indexes. Project 2 tunes this database. Foreign keys do not create indexes in PostgreSQL, so `comments.story_id` (used by q04, q05, q08 and by the ON DELETE CASCADE) has no index today. Likely candidates are `comments (story_id)`, `comments (parent_comment_id)`, `comments (author)`, `stories (author)` and `stories (domain_id)`. Check each of your eight queries with `EXPLAIN (ANALYZE, BUFFERS)` before and after. An index is a separate, sorted structure that the database keeps up to date on every write (Textbook Ch. 14.1), and the B+ tree lectures cover the structure behind it (Textbook §14.2, p. 633).

```sql
CREATE INDEX comments_story_id_idx ON comments (story_id);
CREATE INDEX comments_parent_idx ON comments (parent_comment_id);
CREATE INDEX comments_author_idx ON comments (author);
CREATE INDEX stories_author_idx ON stories (author);
CREATE INDEX stories_domain_idx ON stories (domain_id);
```

- Data volume. At 3 million comments, q05's `COUNT(DISTINCT c.author)` is a good tuning target. The optimizer lectures cover statistics and join ordering (left-deep plans in Textbook §16.6.3, p. 816).
- Normalization. Revisit the points above with the normalization lecture (Textbook §3.5.1, p. 102).
- Time zones. The relational model lecture covers `timestamptz` against `timestamp`, and a query that groups by month needs `AT TIME ZONE` to follow the zone you intend.

## Next steps, ordered by value

1. Move the url and domain pair into a `links` table, so `stories.url` no longer determines `stories.domain_id`.
2. Drop the repeated `polls.created_at` and read the poll flag from `polls`.
3. Fix q03 with `AT TIME ZONE 'UTC'` and tighten q06.
4. Add the runtime note, the row counts and the skip counts to the README and the load.py log.
5. Create the indexes above and record EXPLAIN plans for each query before Project 2.
6. Move the schema.md differences to Category 1 and mark required attributes in the diagram.
7. Set `parent_comment_id` in the comment INSERT, and add the window-function query.
