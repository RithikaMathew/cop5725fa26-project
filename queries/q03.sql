-- q03.sql
-- Question: How many comments were posted each month in the loaded data?
-- Difficulty: easy

SELECT
    DATE_TRUNC('month', created_at) AS month,
    COUNT(*) AS comments_posted
FROM comments
GROUP BY DATE_TRUNC('month', created_at)
ORDER BY month;