-- a07b-window.sql
-- Question: For each AI/agent story, how many points above or below its month's average is it?
-- Technique: window function avg() OVER (PARTITION BY month), one pass instead of one subquery per row
-- Project 2 requirement: naive vs window comparison (window form)

WITH ai_stories AS (
  SELECT story_id, title, points, date_trunc('month', created_at AT TIME ZONE 'UTC') AS month
  FROM   stories
  WHERE  title ~* '\m(ai|llm|llms|gpt|chatgpt|agents?|agentic|openai|anthropic|claude|copilot|rag|gemini|llama|mistral)\M'
)
SELECT
  title,
  to_char(month, 'YYYY-MM') AS month,
  points,
  round(points - avg(points) OVER (PARTITION BY month), 1) AS points_vs_month_avg
FROM   ai_stories
ORDER  BY story_id;
