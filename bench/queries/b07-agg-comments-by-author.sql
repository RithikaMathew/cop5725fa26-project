-- b07-agg-comments-by-author.sql
-- Question: Who were the 20 most active commenters in the week of December 16, 2024, and across how many threads?
-- Pattern: range on comments.created_at, then GROUP BY author

SELECT author, count(*) AS comments, count(DISTINCT story_id) AS threads
FROM   comments
WHERE  created_at >= '2024-12-16 00:00:00+00'
  AND  created_at <  '2024-12-23 00:00:00+00'
  AND  author IS NOT NULL
GROUP BY author
ORDER BY comments DESC, author
LIMIT 20;
