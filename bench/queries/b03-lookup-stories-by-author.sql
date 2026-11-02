-- b03-lookup-stories-by-author.sql
-- Question: Which stories did the frequent submitter thunderbong post, newest first?
-- Pattern: point lookup on stories.author

SELECT story_id, title, points, num_comments, created_at
FROM   stories
WHERE  author = 'thunderbong'
ORDER BY created_at DESC;
