-- q01.sql
-- Question: Which domains produced the most 2024 stories, and what was their average point total? (excludes text-only Ask HN / polls)
-- Difficulty: easy
SELECT
    d.domain_name,
    COUNT(*)              AS story_count,
    ROUND(AVG(s.points), 1) AS avg_points
FROM stories s
JOIN domains d ON d.domain_id = s.domain_id
GROUP BY d.domain_name
ORDER BY story_count DESC
LIMIT 20;
