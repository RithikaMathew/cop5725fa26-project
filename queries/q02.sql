-- q02.sql
-- Question: Who are the top 100 authors by total points earned across all their 2024 story submissions?
-- Difficulty: easy
SELECT
    u.username,
    COUNT(*)      AS stories_posted,
    SUM(s.points) AS total_points
FROM stories s
JOIN users u ON u.username = s.author
GROUP BY u.username
ORDER BY total_points DESC
LIMIT 100;
