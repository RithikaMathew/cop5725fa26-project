-- q06.sql
-- Question: How many 2024 stories mention "python" or "code" in their title or body, and what is their average point total?

-- Difficulty: easy
SELECT
    COUNT(*) AS story_count,
    ROUND(AVG(points), 1) AS avg_points
FROM stories
WHERE title ~* '\m(python|code)\M'
   OR story_text ~* '\m(python|code)\M';
