-- a01-running-totals.sql
-- Question: How many AI/agent-related stories have accumulated month by month through 2024?
-- Technique: sum() OVER (ORDER BY ... ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
-- Project 2 requirement: running total

SELECT
  to_char(date_trunc('month', created_at AT TIME ZONE 'UTC'), 'YYYY-MM') AS month,
  count(*) AS ai_stories,
  -- running total of the monthly counts, January through the current month
  sum(count(*)) OVER (ORDER BY date_trunc('month', created_at AT TIME ZONE 'UTC')
                      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_stories
FROM   stories
WHERE  title ~* '\m(ai|llm|llms|gpt|chatgpt|agents?|agentic|openai|anthropic|claude|copilot|rag|gemini|llama|mistral)\M'
GROUP  BY date_trunc('month', created_at AT TIME ZONE 'UTC')
ORDER  BY month;
