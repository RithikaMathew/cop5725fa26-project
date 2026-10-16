"""Run every SQL file in this folder and print its results.

Usage:
    uv run --env-file .env analytics/run_queries.py
"""

import os
from pathlib import Path
import sys
import time

from loguru import logger
import psycopg


def run_query(cursor: psycopg.Cursor, path: Path) -> None:
    """Run one .sql file and print its result set.

    Args:
        cursor: An open psycopg cursor.
        path: Path to the .sql file to run.
    """
    sql = path.read_text()
    question = next(
        (line.split("Question:", 1)[1].strip() for line in sql.splitlines() if "Question:" in line),
        None,
    )

    start = time.perf_counter()
    cursor.execute(sql)
    elapsed_ms = (time.perf_counter() - start) * 1000

    print(f"\n=== {path.name} ({elapsed_ms:.1f} ms) ===")
    if question:
        print(question)
    if cursor.description is None:
        print("(statement produced no result set)")
        return

    columns = [col.name for col in cursor.description]
    rows = cursor.fetchall()
    widths = [len(name) for name in columns]
    for row in rows:
        for i, value in enumerate(row):
            widths[i] = max(widths[i], len(str(value)))

    print("  ".join(name.ljust(w) for name, w in zip(columns, widths)))
    for row in rows:
        print("  ".join(str(v).ljust(w) for v, w in zip(row, widths)))
    print(f"({len(rows)} row{'s' if len(rows) != 1 else ''})")


def main() -> None:
    """Run every *.sql file next to this script, in filename order."""
    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        logger.error("DATABASE_URL is not set. Run with: uv run --env-file .env analytics/run_queries.py")
        sys.exit(1)

    sql_files = sorted(Path(__file__).parent.glob("*.sql"))
    if not sql_files:
        logger.warning("No .sql files found next to run_queries.py")
        return

    logger.info(f"Running {len(sql_files)} quer{'y' if len(sql_files) == 1 else 'ies'} in {Path(__file__).parent}")
    with psycopg.connect(database_url) as conn:
        with conn.cursor() as cursor:
            for path in sql_files:
                run_query(cursor, path)


if __name__ == "__main__":
    main()
