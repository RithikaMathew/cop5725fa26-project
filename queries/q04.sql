-- q04.sql
-- Question: For each 2024 story, how many comments did it actually receive in the comments table versus HN's reported num_comments count in stories table?
-- Difficulty: medium
SELECT
    s.story_id,
    s.title,
    s.num_comments        AS hn_reported_comments,
    COUNT(c.comment_id)   AS loaded_comments,
    s.num_comments - COUNT(c.comment_id) AS missing_comments
FROM stories s
LEFT JOIN comments c ON c.story_id = s.story_id -- use a LEFT JOIN so stories with zero loaded comments still appear with 0, instead of being dropped
GROUP BY s.story_id, s.title, s.num_comments
ORDER BY missing_comments DESC, s.story_id
LIMIT 100;
