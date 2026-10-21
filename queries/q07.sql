-- q07.sql
-- Question: How many stories and comments did each active user post?
-- Difficulty: medium

SELECT
    u.username,
    COALESCE(st.stories_posted, 0) AS stories_posted,
    COALESCE(cm.comments_posted, 0) AS comments_posted
FROM users u
LEFT JOIN (
    SELECT author, COUNT(*) AS stories_posted
    FROM stories
    GROUP BY author
) st ON st.author = u.username
LEFT JOIN (
    SELECT author, COUNT(*) AS comments_posted
    FROM comments
    GROUP BY author
) cm ON cm.author = u.username
ORDER BY comments_posted DESC, stories_posted DESC
LIMIT 100;
