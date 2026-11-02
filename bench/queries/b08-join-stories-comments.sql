-- b08-join-stories-comments.sql
-- Question: Which AI/LLM/agent stories from the week of December 16, 2024 drew the most distinct commenters?
-- Pattern: join stories to comments on story_id (unindexed foreign key)

SELECT s.story_id, s.title, s.points,
       count(DISTINCT c.author) AS distinct_commenters
FROM   stories  s
JOIN   comments c ON c.story_id = s.story_id
WHERE  s.created_at >= '2024-12-16 00:00:00+00'
  AND  s.created_at <  '2024-12-23 00:00:00+00'
  AND  to_tsvector('english', s.title)
       @@ to_tsquery('english', 'ai | llm | llms | agent | agents | agentic | gpt | openai | anthropic | claude | gemini')
GROUP BY s.story_id, s.title, s.points
ORDER BY distinct_commenters DESC, s.story_id
LIMIT 20;
