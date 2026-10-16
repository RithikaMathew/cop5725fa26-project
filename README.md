# COP5725 Project — Rithika Mathew

## Program
MS in Computer Science, University of Florida

## Dataset
**Dataset:** Hacker News — 2024 story submissions (via the Algolia HN Search API)

**Why it interests me:** This dataset appeals to me because my research involves AI systems that work with chains of reasoning and pull in outside information, and this data has a similar shape: stories with comment threads branching off them, plus patterns of when people post and how others react over time. It's a nice way to practice the SQL joins and recursive queries this class focuses on, at the same time, connecting to the kind of tree like and time based data I deal with in my own work.

## Local Environment Setup

Installed and verified locally on macOS (Apple Silicon):

- uv (Python package/env manager): `curl -LsSf https://astral.sh/uv/install.sh | sh`
- Project + base dependencies: `uv init cop5725fa26-project && cd cop5725fa26-project && uv add duckdb pandas`
- Optional PostgreSQL extra (only needed to run the opt-in check): `uv add --optional postgres "psycopg[binary]"`

## Parquet vs. CSV

Parquet is a file format built for handling large amounts of data quickly, and it works very differently from something simple like a CSV file. CSV stores everything as plain text (row by row) so a program has to read through the whole file even if it only needs one column. Parquet instead stores data column by column and compresses it, so a tool can grab just the columns it actually needs, which makes it much faster and smaller for big datasets. CSV still wins when you want something easy to open, read, or share (like a small sample file in this repo) while Parquet is the better choice once you're working with the full/ much larger dataset.

## Semester Plan
I can explore if posts that ask a question tend to get more replies than ones that just share a link or look into the URLs and titles to figure out which websites or topics show up most often as sources people share.

## Project 1: Schema Design and SQL ETL

### Scenario

As a developer relations analyst for a company making AI and agentic developer tools, I want to see which related stories get attention on Hacker News, which discussions attract many different commenters, and which users contribute often.

### Schema

`schema.sql` creates seven tables for Hacker News stories from 2024. The `stories` table has each post, including links, Ask HN questions, Show HN posts, and polls. The `users` table stores usernames, and `domains` stores website names, so those values do not have to be repeated as separate records for every story. The `story_tags` table stores the multiple tags a story can have. The `comments` table links each comment to its story and, when applicable, to the comment it replies to. Finally, `polls` and `poll_options` store polls and their answer choices. The relationships are shown in `er-diagram.png`.

### Fetching and Loading the Data

1. Start the database and get a live connection string — the password rotates every server start, so `.env.example` is a template only, not a usable value:

```bash
   /blue/cop5725/share/pg-tools/pg-start.sh
   until squeue -u rmathew1 -n postgres-rmathew1 -h -o "%T" | grep -q RUNNING; do sleep 5; done
   /blue/cop5725/share/pg-tools/pg-info.sh | grep -m1 -o 'DATABASE_URL=.*' > .env
```

2. Check the environment with `uv run --env-file .env setup/verify.py`.
3. Fetch and load the data with:

```bash
   uv run --env-file .env load.py
```

The normal command fetches data for the full 2024 date range. For a quick test, `uv run --env-file .env load.py --demo` fetches a smaller sample. The loader saves the fetched records as JSON in `data/raw/`. It then runs `schema.sql` to recreate the tables and inserts the records with `psycopg`. Running the loader again rebuilds the database rather than adding duplicate rows.

### Running a Query

`psql` isn't on `$PATH` by default on the HiPerGator login node so load it first. `$DATABASE_URL` also needs to be exported into your shell; `.env` alone isn't enough outside `uv run --env-file .env`.

1. Start the database (if not already running) and get a live connection string — the password rotates every start, so pull it fresh each session:

```bash
   /blue/cop5725/share/pg-tools/pg-start.sh
   until squeue -u rmathew1 -n postgres-rmathew1 -h -o "%T" | grep -q RUNNING; do sleep 5; done
   /blue/cop5725/share/pg-tools/pg-info.sh | grep -m1 -o 'DATABASE_URL=.*' > .env
```

2. Load `psql` and export the connection string into your shell:

```bash
   module load ubuntu
   set -a; source .env; set +a
```

3. Run a query, saving its header and first 100 result rows:

```bash
   mkdir -p queries/results
   psql "$DATABASE_URL" --csv -f queries/q01.sql | head -n 101 > queries/results/q01.csv
```

   Repeat for `q02.sql` through `q08.sql`, saving each result under the matching filename in `queries/results/`.

### Data Included

The loader requests stories, polls, and comments created from January 1, 2024, up to but not including January 1, 2025. It also retrieves answer choices for the polls it finds. Comments are loaded only when their parent story is also in the selected stories.

### Data Quirks

* Algolia search results do not include a user's karma, signup date, or profile description. The date stored for a user is the earliest story or comment by that username found in this dataset; it is **not** the user's signup date.
* Story and comment text can contain HTML tags and escaped characters rather than plain text.
* The loader selects stories posted in 2024 and comments posted in 2024. A comment posted in 2024 might be a reply to a story posted in 2023. Since that 2023 story is not in the stories table, the loader skips the comment; otherwise, its story_id would point to a story that is missing from the database.
* Poll option IDs are found through Algolia, while the option text and scores are retrieved from the Hacker News Firebase API.
* Algolia limits how many search results can be retrieved from one request. The loader splits the year into smaller date ranges to collect the full period.


## Project 2: Advanced SQL Analytics

Eleven query files in `analytics/` answer ten analytics questions about AI/agent-related Hacker News stories for the DevRel scenario above: running totals, top-N per group, month-over-month change, cumulative distribution, a recursive reply-chain traversal, a CTE pipeline, a naive-vs-window comparison (a07a/a07b, with EXPLAIN ANALYZE timings), URL deduplication, and two of my own (best posting hour, revived threads).

Each query's question, purpose, sample result and interesting finding is in [`analytics/README.md`](analytics/README.md).

### Starting from scratch (new session or fresh database)

Everything below runs on the HiPerGator login node from the repo directory (`/blue/cop5725/rmathew1/cop5725fa26-project`). The Postgres server is a 4-hour SLURM job and the password changes on every start, so redo steps 1 and 2 each session.

1. Start the database and write a live connection string (same as Project 1):

```bash
   /blue/cop5725/share/pg-tools/pg-start.sh
   until squeue -u rmathew1 -n postgres-rmathew1 -h -o "%T" | grep -q RUNNING; do sleep 5; done
   /blue/cop5725/share/pg-tools/pg-info.sh | grep -m1 -o 'DATABASE_URL=.*' > .env
```

2. Export the connection string and load `psql`:

```bash
   module load ubuntu
   set -a; source .env; set +a
```

3. Check that the tables are filled (roughly 297,634 stories and 3,094,184 comments):

```bash
   psql "$DATABASE_URL" -c "SELECT count(*) FROM stories;" -c "SELECT count(*) FROM comments;"
```

4. If the counts are 0 (a fresh Postgres data directory), reload from the cached files in `data/raw/`. Run only one load at a time, because `load.py` drops and recreates the tables. The cached files make this much faster than the original download:

```bash
   uv run --env-file .env load.py            # same command as Project 1
```

   If `data/raw/` is empty too, `load.py` re-downloads everything from the Algolia API, which took about 2h45m the first time.

5. Run all the analytics queries (about 2 minutes, mostly the recursive query a05):

```bash
   uv run --env-file .env analytics/run_queries.py
```

To run one file by itself, or to capture the a07a/a07b timings:

```bash
   psql "$DATABASE_URL" -f analytics/a05-recursive-hierarchy.sql
   (echo "EXPLAIN ANALYZE"; cat analytics/a07a-naive.sql) | psql "$DATABASE_URL"
```

### Notes

- "AI/agent-related" is a word-boundary regex on story titles (ai, llm, gpt, agent(s), openai, claude, and so on), so a few non-AI titles may match.
- Months are bucketed in UTC, so stories from early January 1 do not fall into December 2023.
- `loguru` was added as a dependency for `run_queries.py` (`uv add loguru`).
