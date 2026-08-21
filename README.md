# COP5725 Project — Rithika Mathew

## Program
MS in Computer Science, University of Florida

## Dataset
**Dataset:** Hacker News — 2024 story submissions (via the Algolia HN Search API)

**Why it interests me:** I work on agentic AI, LLM pipelines, and RAG systems, so a dataset with a natural tree structure (stories → nested comment threads) and time-series submission/engagement patterns gives me a real-world analog for the graph- and sequence-heavy queries I care about, while staying squarely in COP5725's SQL/joins/recursion territory.

## Local Environment Setup

Installed and verified locally on macOS (Apple Silicon):

- uv (Python package/env manager): `curl -LsSf https://astral.sh/uv/install.sh | sh`
- Project + base dependencies: `uv init cop5725fa26-project && cd cop5725fa26-project && uv add duckdb pandas`
- Optional PostgreSQL extra (only needed to run the opt-in check): `uv add --optional postgres "psycopg[binary]"`

## Parquet vs. CSV

Parquet is a columnar, binary, compressed file format designed for analytical workloads, as opposed to CSV, which is row-oriented, plain-text, and uncompressed. Because Parquet stores each column contiguously, an engine like DuckDB can read only the columns a query touches instead of scanning every row, and Parquet's built-in compression and embedded schema (column types, no re-parsing needed) make files smaller and faster to load than an equivalent CSV. CSV wins on portability and human-readability — any tool can open it, and it's easy to diff or eyeball in a text editor — which is why this repo still ships `data/sample.csv`. For a small, shareable, git-friendly sample, CSV is the right call; for the full multi-hundred-thousand-row dataset used in later projects, Parquet is the better default.

## Semester Plan
Build out a schema and query pipeline around Hacker News stories and their comment trees, progressing from basic SQL through joins, aggregation, window functions, and recursive queries over the comment hierarchy across the semester.
