-- a08-deduplication.sql
-- Question: Which URLs were submitted more than once in 2024, and which submission was the canonical (highest-scoring aka representative) one?
-- Technique: row_number() = 1 per url, with count(*) OVER the same partition
-- Project 2 requirement: deduplication by key

WITH ranked AS (
  SELECT
    story_id, url, title, author, points, created_at,
    row_number() OVER (PARTITION BY url ORDER BY points DESC, created_at, story_id) AS rn,
    count(*)     OVER (PARTITION BY url)                                            AS submissions
  FROM stories
  WHERE url IS NOT NULL
)
SELECT url, submissions, title AS canonical_title, author AS canonical_author, points AS canonical_points
FROM   ranked
WHERE  rn = 1            -- keep one row per url: the best-scoring submission
  AND  submissions > 1   -- only urls that were actually resubmitted
ORDER  BY submissions DESC, canonical_points DESC
LIMIT  25;
