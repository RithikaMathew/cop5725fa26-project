-- b04-range-comments-by-hour.sql
-- Question: How many comments were posted in each hour (UTC) of December 20, 2024, the day OpenAI announced o3?
-- Pattern: range scan on comments.created_at

SELECT date_trunc('hour', created_at AT TIME ZONE 'UTC') AS hour_utc, count(*) AS comments
FROM   comments
WHERE  created_at >= '2024-12-20 00:00:00+00'
  AND  created_at <  '2024-12-21 00:00:00+00'
GROUP BY hour_utc
ORDER BY hour_utc;
