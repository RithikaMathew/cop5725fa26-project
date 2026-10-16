-- a10-revived-threads.sql
-- Question: Which AI/agent stories went quiet and were later revived, i.e. had the longest gap between consecutive comments?
-- Technique: lag() over comments partitioned by story, then max gap per story
-- Project 2 requirement: own choice

WITH gaps AS (
  SELECT
    s.story_id, s.title, s.points,
    -- time since the previous comment in the same story (NULL for the first comment)
    c.created_at - lag(c.created_at) OVER (PARTITION BY c.story_id ORDER BY c.created_at, c.comment_id) AS gap
  FROM   comments c
  JOIN   stories  s USING (story_id)
  WHERE  s.title ~* '\m(ai|llm|llms|gpt|chatgpt|agents?|agentic|openai|anthropic|claude|copilot|rag|gemini|llama|mistral)\M'
)
SELECT title, points, count(*) AS comments, max(gap) AS longest_gap
FROM   gaps
GROUP  BY story_id, title, points
HAVING count(*) >= 10          -- ignore tiny threads
ORDER  BY longest_gap DESC NULLS LAST
LIMIT  20;
