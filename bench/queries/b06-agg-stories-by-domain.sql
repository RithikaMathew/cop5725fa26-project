-- b06-agg-stories-by-domain.sql
-- Question: Which websites supply the most AI/LLM/agent stories, and how well do those stories score?
-- Pattern: full-text match on stories.title, then GROUP BY domain

SELECT d.domain_name, count(*) AS stories, round(avg(s.points), 1) AS avg_points
FROM   stories s
JOIN   links   l ON l.url = s.url
JOIN   domains d ON d.domain_id = l.domain_id
WHERE  to_tsvector('english', s.title)
       @@ to_tsquery('english', 'ai | llm | llms | agent | agents | agentic | gpt | openai | anthropic | claude | gemini')
GROUP BY d.domain_name
ORDER BY stories DESC, d.domain_name
LIMIT 20;
