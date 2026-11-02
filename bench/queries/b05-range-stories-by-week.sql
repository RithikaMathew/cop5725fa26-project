-- b05-range-stories-by-week.sql
-- Question: What were the 30 highest-scoring stories posted in the week of December 16, 2024?
-- Pattern: range scan on stories.created_at, top-N by points

SELECT story_id, title, author, points, num_comments, created_at
FROM   stories
WHERE  created_at >= '2024-12-16 00:00:00+00'
  AND  created_at <  '2024-12-23 00:00:00+00'
ORDER BY points DESC
LIMIT 30;
