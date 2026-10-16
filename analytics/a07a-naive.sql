-- a07a-naive.sql
-- Question: For each AI/agent story, how many points above or below its month's average is it?
-- Technique: correlated subquery (re-computes the month average for every story)
-- Project 2 requirement: naive vs window comparison (naive form)

WITH ai_stories AS MATERIALIZED (
  SELECT story_id, title, points, date_trunc('month', created_at AT TIME ZONE 'UTC') AS month
  FROM   stories
  WHERE  title ~* '\m(ai|llm|llms|gpt|chatgpt|agents?|agentic|openai|anthropic|claude|copilot|rag|gemini|llama|mistral)\M'
)
SELECT
  a.title,
  to_char(a.month, 'YYYY-MM') AS month,
  a.points,
  round(a.points - (SELECT avg(b.points)
                    FROM   ai_stories b
                    WHERE  b.month = a.month), 1) AS points_vs_month_avg
FROM   ai_stories a
ORDER  BY a.story_id;
