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
    # Some older PostgreSQL servers (e.g. 9.x) don't negotiate encoding
    # the way psycopg3 expects, so this can come back as bytes instead
    # of str depending on the server.
    if isinstance(v, bytes):
        v = v.decode("utf-8", errors="replace")
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
    