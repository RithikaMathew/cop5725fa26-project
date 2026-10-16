-- a02-top-n-per-group.sql
-- Question: What were the top 3 AI/agent-related stories by points in each month of 2024?
-- Technique: row_number() OVER (PARTITION BY month ORDER BY points DESC)
-- Project 2 requirement: top-N per group

WITH ranked AS (
  SELECT
    date_trunc('month', created_at AT TIME ZONE 'UTC') AS month,
    story_id,
    title,
    author,
    points,
    num_comments,
    -- story_id breaks ties so each month has exactly 3 rows
    row_number() OVER (PARTITION BY date_trunc('month', created_at AT TIME ZONE 'UTC')
                       ORDER BY points DESC, story_id) AS rk
  FROM stories
  WHERE title ~* '\m(ai|llm|llms|gpt|chatgpt|agents?|agentic|openai|anthropic|claude|copilot|rag|gemini|llama|mistral)\M'
)
SELECT to_char(month, 'YYYY-MM') AS month, rk, title, author, points, num_comments
FROM   ranked
WHERE  rk <= 3          
ORDER  BY month, rk;
