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