-- q03.sql
-- Question: How many comments were posted each month in the loaded data?
-- Difficulty: easy

SELECT
    DATE_TRUNC('month', created_at AT TIME ZONE 'UTC') AS month,
    COUNT(*) AS comments_posted
FROM comments
GROUP BY DATE_TRUNC('month', created_at AT TIME ZONE 'UTC')
ORDER BY month;
