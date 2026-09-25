-- q08.sql
-- Question: Which Show HN posts received the most comments, and who submitted them?
-- Difficulty: medium

SELECT
    s.title,
    u.username AS submitted_by,
    s.points,
    COUNT(c.comment_id) AS comments_received
FROM stories s
JOIN users u ON u.username = s.author
LEFT JOIN comments c ON c.story_id = s.story_id
WHERE s.is_show_hn = TRUE
GROUP BY s.story_id, s.title, u.username, s.points
ORDER BY comments_received DESC
LIMIT 100;