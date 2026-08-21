import sys

def check_postgres():
    import psycopg
    # NOTE: adjust user/db name if yours differ. Homebrew Postgres uses your
    # Mac username by default and (usually) no password for local connections.
    with psycopg.connect("postgresql://rithika@localhost:5432/mytestdb") as conn:
        v = conn.execute("SELECT version()").fetchone()
        assert "PostgreSQL 16" in v[0] or "PostgreSQL 17" in v[0], v
    print("PostgreSQL: OK")

def check_duckdb():
    import duckdb
    assert duckdb.sql("SELECT 42").fetchone()[0] == 42
    print("DuckDB: OK")

def check_uv():
    import shutil
    assert shutil.which("uv"), "uv not on PATH"
    print("uv: OK")

def check_python_packages():
    import psycopg, duckdb, pandas
    print("psycopg, duckdb, pandas: OK")

if __name__ == "__main__":
    try:
        check_uv()
        check_python_packages()
        check_postgres()
        check_duckdb()
    except Exception as e:
        print(f"FAIL: {e}", file=sys.stderr)
        sys.exit(1)
    print("All four checks passed.")
