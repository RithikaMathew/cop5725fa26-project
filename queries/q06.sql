-- q06.sql
-- Question: How many 2024 stories mention "python" or "code" in their title or body, and what is their average point total?

-- Difficulty: easy
SELECT
    COUNT(*) AS story_count,
    ROUND(AVG(points), 1) AS avg_points
FROM stories
WHERE title ILIKE '%python%'
   OR title ILIKE '%code%'
   OR story_text ILIKE '%python%'
   OR story_text ILIKE '%code%';