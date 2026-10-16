-- a05-recursive-hierarchy.sql
-- Question: Which stories have the deepest reply chains, and how long is the deepest chain in each?
-- Technique: WITH RECURSIVE walking comments.parent_comment_id from top-level comments down, with a depth bound of 200
-- Project 2 requirement: hierarchical traversal

WITH RECURSIVE thread AS (
  -- anchor: top-level comments (direct replies to the story) are depth 1
  SELECT comment_id, story_id, 1 AS depth
  FROM   comments
  WHERE  parent_comment_id IS NULL

  UNION ALL

  -- recursive step: children of the comments found so far, one level deeper
  SELECT c.comment_id, c.story_id, t.depth + 1
  FROM   comments c
  JOIN   thread   t ON c.parent_comment_id = t.comment_id
  WHERE  t.depth < 200         -- termination guard so a bad cycle can never loop forever
)
SELECT s.title, s.author, s.points, max(t.depth) AS max_depth, count(*) AS comments_in_tree
FROM   thread  t
JOIN   stories s USING (story_id)
GROUP  BY s.story_id, s.title, s.author, s.points
ORDER  BY max_depth DESC, comments_in_tree DESC
LIMIT  25;
