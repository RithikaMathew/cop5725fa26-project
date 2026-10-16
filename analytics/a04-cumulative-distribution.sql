-- a04-cumulative-distribution.sql
-- Question: Which stories sit in the top 1% of all 2024 stories by comment count?
-- Technique: cume_dist() over the whole table
-- Project 2 requirement: cumulative distribution

SELECT title, author, num_comments, points,
       round((100 * comments_cume)::numeric, 2) AS comments_percentile
FROM (
  SELECT story_id, title, author, num_comments, points,
         -- share of stories with num_comments <= this story's
         cume_dist() OVER (ORDER BY num_comments) AS comments_cume
  FROM   stories
) dist
WHERE  comments_cume >= 0.99   
ORDER  BY num_comments DESC, story_id
LIMIT  50;
