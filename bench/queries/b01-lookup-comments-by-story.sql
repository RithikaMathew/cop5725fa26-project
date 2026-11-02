-- b01-lookup-comments-by-story.sql
-- Question: What is the full discussion under the "OpenAI O3 breakthrough" story, oldest first?
-- Pattern: point lookup on comments.story_id (a foreign key with no automatic index)

SELECT comment_id, parent_comment_id, author, created_at
FROM   comments
WHERE  story_id = 42473321
ORDER BY created_at;
