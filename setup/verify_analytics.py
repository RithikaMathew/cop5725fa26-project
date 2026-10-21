"""Read-only full-data verification and server timings for the a07 pair.

Run after analytics/run_queries.py:
    uv run --env-file .env setup/verify_analytics.py
"""
import os
from pathlib import Path

import psycopg

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    with psycopg.connect(os.environ['DATABASE_URL'], client_encoding='UTF8') as conn:
        # One consistent snapshot for counts, outputs and timing comparisons.
        conn.execute('SET TRANSACTION ISOLATION LEVEL REPEATABLE READ, READ ONLY')
        for table in ('users', 'domains', 'links', 'stories', 'story_tags',
                      'comments', 'polls', 'poll_options'):
            count = conn.execute(f'SELECT count(*) FROM {table}').fetchone()[0]
            print(f'{table}: {count:,}')
            if table in ('stories', 'comments') and count == 0:
                raise RuntimeError(f'{table} is empty: load the full dataset first')
        outputs = []
        for name in ('a07a-naive.sql', 'a07b-window.sql'):
            sql = (ROOT / 'analytics' / name).read_text()
            rows = conn.execute(sql).fetchall()
            outputs.append(rows)
            print(f'\n{name}: {len(rows):,} rows')
            for line, in conn.execute('EXPLAIN (ANALYZE, BUFFERS) ' + sql):
                print(line)
        if outputs[0] != outputs[1]:
            raise AssertionError('a07 outputs differ')
        print('\nPASS: a07 outputs match exactly, including row order.')
        print('Compare the full-data samples and timings with analytics/README.md.')


if __name__ == '__main__':
    main()
