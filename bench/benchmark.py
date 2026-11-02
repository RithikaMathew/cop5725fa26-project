"""Run every query in bench/queries/ and save plans, timings, and server facts.

Usage:
    uv run --env-file .env bench/benchmark.py before
    uv run --env-file .env bench/benchmark.py after

Each run writes into bench/<phase>/:
    environment.txt      the server facts from environment.sql, plus the client OS
    <query stem>.txt     EXPLAIN (ANALYZE, BUFFERS, VERBOSE) output, one file per query
    timings.csv          planning and execution time for every run of every query
    summary.csv          cold time and warm median per query
"""

import argparse
import csv
import os
from pathlib import Path
import platform
import re
import statistics
import sys

from loguru import logger
import psycopg

BENCH_DIR = Path(__file__).parent
QUERY_DIR = BENCH_DIR / "queries"
ENVIRONMENT_SQL = BENCH_DIR / "environment.sql"
RUNS = 5
TIME_PATTERN = re.compile(r"^(Planning|Execution) time: ([0-9.]+) ms$", re.IGNORECASE)


def read_query(path: Path) -> str:
    """Return the single SELECT statement in a query file, without its trailing semicolon.

    Args:
        path: Path to the .sql file.
    """
    return path.read_text().strip().rstrip(";")


def explain_analyze(cursor: psycopg.Cursor, sql: str) -> tuple[str, float, float]:
    """Run one query under EXPLAIN ANALYZE and return the plan and its two timings.

    Args:
        cursor: An open psycopg cursor.
        sql: The query text, one statement, no trailing semicolon.

    Returns:
        The plan text, the planning time in ms, and the execution time in ms.
    """
    cursor.execute(f"EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT TEXT) {sql}")
    lines = [row[0] for row in cursor.fetchall()]
    times = {}
    for line in lines:
        match = TIME_PATTERN.match(line)
        if match:
            times[match.group(1).capitalize()] = float(match.group(2))
    return "\n".join(lines), times.get("Planning", 0.0), times.get("Execution", 0.0)


def write_environment(cursor: psycopg.Cursor, out_dir: Path) -> None:
    """Save the server facts from environment.sql and the client platform.

    Args:
        cursor: An open psycopg cursor.
        out_dir: The phase directory to write environment.txt into.
    """
    cursor.execute(ENVIRONMENT_SQL.read_text())
    rows = cursor.fetchall()
    width = max(len(name) for name, _ in rows)
    lines = [f"{'client_os':<{width}}  {platform.platform()}",
             f"{'client_python':<{width}}  {platform.python_version()}"]
    lines += [f"{name:<{width}}  {value}" for name, value in rows]
    (out_dir / "environment.txt").write_text("\n".join(lines) + "\n")


def benchmark_query(cursor: psycopg.Cursor, path: Path, out_dir: Path, runs: int) -> list[dict]:
    """Run one query several times, save its warm plan, and return one row per run.

    Args:
        cursor: An open psycopg cursor.
        path: Path to the .sql file.
        out_dir: The phase directory to write the plan into.
        runs: How many times to run the query.
    """
    sql = read_query(path)
    rows = []
    plan = ""
    for run in range(1, runs + 1):
        plan, planning_ms, execution_ms = explain_analyze(cursor, sql)
        rows.append({"query": path.stem, "run": run,
                     "planning_ms": planning_ms, "execution_ms": execution_ms})
        logger.info(f"{path.stem} run {run}: {execution_ms:.2f} ms")
    (out_dir / f"{path.stem}.txt").write_text(plan + "\n")
    return rows


def main() -> None:
    """Benchmark every query file and write the phase directory."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("phase", choices=["before", "after"],
                        help="before or after applying schema-changes.sql")
    parser.add_argument("--runs", type=int, default=RUNS,
                        help=f"runs per query (default {RUNS})")
    args = parser.parse_args()

    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        logger.error("DATABASE_URL is not set. Run with: uv run --env-file .env bench/benchmark.py before")
        sys.exit(1)

    query_files = sorted(QUERY_DIR.glob("b*.sql"))
    if not query_files:
        logger.error(f"No b*.sql files found in {QUERY_DIR}")
        sys.exit(1)

    out_dir = BENCH_DIR / args.phase
    out_dir.mkdir(exist_ok=True)
    logger.info(f"Phase '{args.phase}': {len(query_files)} queries, {args.runs} runs each, output in {out_dir}")

    timings = []
    with psycopg.connect(database_url, autocommit=True, client_encoding="utf8") as conn:
        with conn.cursor() as cursor:
            write_environment(cursor, out_dir)
            for path in query_files:
                timings += benchmark_query(cursor, path, out_dir, args.runs)

    with (out_dir / "timings.csv").open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["query", "run", "planning_ms", "execution_ms"])
        writer.writeheader()
        writer.writerows(timings)

    with (out_dir / "summary.csv").open("w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["query", "runs", "cold_execution_ms", "warm_median_execution_ms"])
        for path in query_files:
            runs = [r["execution_ms"] for r in timings if r["query"] == path.stem]
            warm = runs[1:] or runs
            writer.writerow([path.stem, len(runs), f"{runs[0]:.2f}", f"{statistics.median(warm):.2f}"])
            logger.info(f"{path.stem}: cold {runs[0]:.2f} ms, warm median {statistics.median(warm):.2f} ms")

    logger.info(f"Wrote {out_dir / 'environment.txt'}, {len(query_files)} plan files, timings.csv, summary.csv")


if __name__ == "__main__":
    main()
