# Project 2 notes for Rithika Mathew

These notes list what worked, what cost points, tips that did not cost points, and what to do before Project 3.

Graded commit: `v2` at `cc5f850028` (2026-10-21 12:38 EDT).

## Score

| Area | Points | Out of | How the points were assigned |
|---|---|---|---|
| Query coverage | 30 | 30 |  |
| Query craftsmanship | 20 | 20 |  |
| Naive vs window (a07a, a07b) | 15 | 15 |  |
| Analytics script and README | 15 | 15 |  |
| Documentation (root README) | 10 | 10 |  |
| Repo hygiene | 10 | 10 |  |
| Total | 100 | 100 | |

## What worked well

- All 11 queries in `analytics/` ran without an error and returned rows.
- These required patterns appear in separate files, one question per file: top-N per group in `a02-top-n-per-group` (a rank function with `PARTITION BY`); running total in `a01-running-totals` (a window aggregate with `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`); period-over-period in `a03-period-over-period` (`lag()` or `lead()`); cumulative distribution in `a04-cumulative-distribution` (`cume_dist()` or `percent_rank()`); multi-step transformation in `a06-cte-pipeline` (a chain of CTEs); deduplication in `a08-deduplication` (`row_number()` filtered on its rank).
- The naive and window forms are in separate files, `a07a-naive` and `a07b-window` with the same Question line, so each runs and times on its own.
- Your own-choice queries go beyond the required patterns: `a09` asks "Which UTC hour of the day gets AI/agent stories the most comments on average?"; `a10` asks "Which AI/agent stories went quiet and were later revived, i.e. had the longest gap between consecutive comments?".
- The root README has a Project 2 section with the run command and a pointer to `analytics/README.md`, which the page asks for.
- Repository: `run_queries.py` matches the file on the project page, no `.env` is committed, the `v2` tag points at the graded commit.

## Tips that did not cost points

- The page asks for comments past the header ("a `--` line above a CTE or a window clause costs one line"). `a07a`, `a07b`, and `a09` have no comment below the header. A line above each CTE and window clause saves you from re-deriving the logic when you return to the query.

## Before Project 3

- Project 3 repeats the a07a and a07b comparison at a larger scale. `bench/benchmark.py` runs each query 5 times under `EXPLAIN (ANALYZE, BUFFERS, VERBOSE)` and saves the plan, so keep your two a07 plans and the `Execution Time` values as your first before and after pair.
- Pick your candidates for `bench/queries/` from the Project 2 files. Project 3 asks for 5 to 10 `SELECT` queries, one statement per file, starting at `b01-...sql`, and the slowest of your analytics queries are the ones an index or a rewrite can change.
- Project 3 runs `uv sync` and then `uv run --env-file .env ...`, so every package your scripts import must be in `pyproject.toml`. Check that `psycopg[binary]` and `loguru` are listed.
- Project 3 asks for a loader that stops at a row cap you set in an environment variable (for example `MAX_ROWS`), sized so a fresh load takes about 10 minutes. State the default cap and the measured load time in README.md.

## Next steps, ordered by value

1. Add `--` comments above each CTE and window clause.
2. Follow the Before Project 3 list when you start `bench/`.
