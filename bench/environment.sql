-- environment.sql
-- Reports the server facts every tuning report must state.
-- benchmark.py runs this file and saves the output as environment.txt;
-- you can also run it by hand: psql "$DATABASE_URL" -f bench/environment.sql

SELECT name, value
FROM (
  SELECT 0 AS ord, 'postgresql_version'::text AS name, version()::text AS value
  UNION ALL
  SELECT 1, 'database', current_database()
  UNION ALL
  SELECT 2, 'database_size', pg_size_pretty(pg_database_size(current_database()))
  UNION ALL
  SELECT 3, 'server_started', pg_postmaster_start_time()::text
  UNION ALL
  SELECT 4, name::text, current_setting(name)
  FROM pg_settings
  WHERE name IN ('server_version', 'shared_buffers', 'work_mem',
                 'maintenance_work_mem', 'effective_cache_size',
                 'random_page_cost', 'seq_page_cost', 'effective_io_concurrency',
                 'max_parallel_workers_per_gather', 'max_worker_processes',
                 'jit', 'enable_seqscan', 'enable_indexscan', 'enable_bitmapscan',
                 'default_statistics_target', 'autovacuum', 'track_io_timing',
                 'max_connections', 'huge_pages')
  UNION ALL
  SELECT 5, 'table:' || relname,
         n_live_tup::text || ' rows, ' || pg_size_pretty(pg_total_relation_size(relid))
         || ', last analyze ' || coalesce(greatest(last_analyze, last_autoanalyze)::text, 'never')
  FROM pg_stat_user_tables
  UNION ALL
  SELECT 6, 'index:' || indexrelname,
         relname || ', ' || pg_size_pretty(pg_relation_size(indexrelid))
  FROM pg_stat_user_indexes
) facts
ORDER BY ord, name;
