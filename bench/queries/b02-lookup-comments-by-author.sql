-- b02-lookup-comments-by-author.sql
-- Question: What are the 50 most recent comments by simonw, a prolific AI-tools commenter?
-- Pattern: point lookup on comments.author, newest first with LIMIT

SELECT comment_id, story_id, created_at, left(comment_text, 120) AS snippet
FROM   comments
WHERE  author = 'simonw'
ORDER BY created_at DESC
LIMIT 50;
