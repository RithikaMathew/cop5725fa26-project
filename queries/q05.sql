-- q05.sql
-- Question: Which 2024 stories attracted the most different commenters, and who submitted those stories?
-- Difficulty: medium
SELECT
    s.story_id,
    s.title,
    u.username AS submitted_by,
    COUNT(DISTINCT c.author) AS distinct_commenters
FROM stories s
JOIN users u      ON u.username = s.author
JOIN comments c   ON c.story_id = s.story_id
GROUP BY s.story_id, s.title, u.username
ORDER BY distinct_commenters DESC
LIMIT 100;
