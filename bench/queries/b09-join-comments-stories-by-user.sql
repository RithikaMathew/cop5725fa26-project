-- b09-join-comments-stories-by-user.sql
-- Question: Which stories did simonw comment on, and how many times on each?
-- Pattern: join comments (filtered by author) to stories on story_id

SELECT s.story_id, s.title, count(*) AS comments_by_user, max(c.created_at) AS last_comment_at
FROM   comments c
JOIN   stories  s ON s.story_id = c.story_id
WHERE  c.author = 'simonw'
GROUP BY s.story_id, s.title
ORDER BY comments_by_user DESC, last_comment_at DESC;
