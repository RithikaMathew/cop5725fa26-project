# COP5725 Project — Rithika Mathew

## Program
MS in Computer Science, University of Florida

## Dataset
**Claimed dataset:** NYC Yellow Taxi — 2024-01 slice (tentative, pending roster PR)

**Why it interests me:** I work on transportation and micromobility research, so a large real-world trip dataset with time-series and spatial structure fits well with my background and lets me apply database concepts to a domain I already know.

## Local Environment Setup

Installed and verified locally on macOS (Apple Silicon):

- uv (Python package/env manager): curl -LsSf https://astral.sh/uv/install.sh | sh
- PostgreSQL 17 via Homebrew: brew install postgresql@17 && brew services start postgresql@17
- Project + dependencies: uv init cop5725fa26-project && cd cop5725fa26-project && uv add psycopg duckdb pandas

## Semester Plan
Build out a normalized schema and query pipeline around NYC Yellow Taxi trip data, progressing from basic SQL through joins, aggregation, window functions, and performance tuning across the semester.
