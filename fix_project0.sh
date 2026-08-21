#!/usr/bin/env bash
# Run this from the root of cop5725fa26-project/
set -euo pipefail

cat > README.md << 'EOF'
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
EOF

cat > data/source.md << 'EOF'
# Data Source

**Dataset name:** Hacker News — 2024 story submissions

**URL / fetch instructions:**
Loadable with no signup or auth key via the Algolia HN Search API (mirrors the official Hacker News API):

```
https://hn.algolia.com/api/v1/search_by_date?tags=story&numericFilters=created_at_i>=1704067200,created_at_i<1735689600&hitsPerPage=1000
```

Sample regeneration (1000 most recent stories in the 2024 window):

```python
import requests, pandas as pd

resp = requests.get(
    "https://hn.algolia.com/api/v1/search_by_date",
    params={
        "tags": "story",
        "numericFilters": "created_at_i>=1704067200,created_at_i<1735689600",
        "hitsPerPage": 1000,
    },
)
pd.DataFrame(resp.json()["hits"]).to_csv("data/sample.csv", index=False)
```

**License:**
The Algolia HN Search API mirrors data served by the official Hacker News API (HackerNews/API), which is MIT-licensed and has no rate limit or auth requirement. See https://github.com/HackerNews/API.

**Approximate size:**
- Row count: ~400,000 story submissions in 2024 (annual submission volume has held near this level through the 2020s); comments run into the millions per year
- Table count: 2 conceptual tables (stories, comments) — comments nest under stories in a tree via each item's `parent`/`kids` field
- Columns (stories, via this API): objectID (story id), title, url, author, points, num_comments, created_at / created_at_i, story_text (if any)

**Update frequency:**
Continuous, near real-time; this project uses a fixed date range (2024-01-01 to 2025-01-01, UTC) for reproducibility.
EOF

cat > .env.example << 'EOF'
# Copy to .env and fill in real values. Never commit .env.
DATABASE_URL=postgresql://user:password@localhost:5432/cop5725fa26
EOF

cat > pyproject.toml << 'EOF'
[project]
name = "cop5725fa26-project"
version = "0.1.0"
description = "Add your description here"
readme = "README.md"
requires-python = ">=3.11"
dependencies = [
    "duckdb>=1.5.5",
    "pandas>=3.0.5",
]

[project.optional-dependencies]
postgres = ["psycopg[binary]"]

[build-system]
requires = ["uv_build>=0.12.5,<0.13.0"]
build-backend = "uv_build"
EOF

cat > setup/verify.py << 'EOF'
import sys
from pathlib import Path

def check_uv():
    """Confirm the uv package manager is installed and on PATH."""
    import shutil
    assert shutil.which("uv"), "uv not on PATH"
    print("uv: OK")

def check_python_packages():
    """Confirm the base dependencies from pyproject.toml import cleanly."""
    import duckdb, pandas
    print("duckdb, pandas: OK")

def check_sqlite():
    """Round-trip a small table through Python's built-in SQLite."""
    import sqlite3
    conn = sqlite3.connect(":memory:")
    conn.execute("CREATE TABLE t (x INTEGER)")
    conn.executemany("INSERT INTO t VALUES (?)", [(1,), (2,), (3,)])
    n = conn.execute("SELECT count(*) FROM t").fetchone()[0]
    conn.close()
    assert n == 3, n
    print(f"SQLite: OK (version {sqlite3.sqlite_version})")

def check_duckdb():
    """Query the committed sample file with DuckDB and count its rows."""
    import duckdb
    sample = next(
        (p for p in ("data/sample.csv", "data/sample.parquet") if Path(p).exists()),
        None,
    )
    assert sample, "data/sample.csv or data/sample.parquet not found"
    rows = duckdb.sql(f"SELECT count(*) FROM '{sample}'").fetchone()[0]
    assert rows >= 100, f"expected at least 100 rows in {sample}, found {rows}"
    print(f"DuckDB: OK ({rows} rows in {sample})")

def check_postgres_optional():
    """Test the PostgreSQL connection in DATABASE_URL; skip when unset."""
    import os
    url = os.environ.get("DATABASE_URL")
    if not url:
        print("PostgreSQL: skipped (optional; class resources come later)")
        return
    import psycopg
    with psycopg.connect(url) as conn:
        v = conn.execute("SELECT version()").fetchone()[0]
    print(f"PostgreSQL: OK ({v.split(',')[0]})")

if __name__ == "__main__":
    try:
        check_uv()
        check_python_packages()
        check_sqlite()
        check_duckdb()
        check_postgres_optional()
    except Exception as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
    print("All checks passed.")
EOF

# regenerate the sample CSV from Hacker News (replaces the taxi sample)
uv add requests
uv run python - << 'PYEOF'
import requests, pandas as pd
resp = requests.get(
    "https://hn.algolia.com/api/v1/search_by_date",
    params={
        "tags": "story",
        "numericFilters": "created_at_i>=1704067200,created_at_i<1735689600",
        "hitsPerPage": 1000,
    },
)
pd.DataFrame(resp.json()["hits"]).to_csv("data/sample.csv", index=False)
print("wrote", len(resp.json()["hits"]), "rows to data/sample.csv")
PYEOF

uv sync
uv run setup/verify.py

echo ""
echo "Done. Now check src/ for a project.scripts issue (see chat notes),"
echo "then git add -A && git commit and push."
