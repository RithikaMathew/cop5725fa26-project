-- a03-period-over-period.sql
-- Question: How did the number of AI/agent-related stories change month over month in 2024?
-- Technique: lag() over a monthly aggregate
-- Project 2 requirement: period-over-period

SELECT
  to_char(date_trunc('month', created_at AT TIME ZONE 'UTC'), 'YYYY-MM') AS month,
  count(*) AS ai_stories,
  -- previous month's count (NULL for January)
  lag(count(*)) OVER (ORDER BY date_trunc('month', created_at AT TIME ZONE 'UTC')) AS prev_month,
  count(*) - lag(count(*)) OVER (ORDER BY date_trunc('month', created_at AT TIME ZONE 'UTC')) AS change
FROM   stories
WHERE  title ~* '\m(ai|llm|llms|gpt|chatgpt|agents?|agentic|openai|anthropic|claude|copilot|rag|gemini|llama|mistral)\M'
GROUP  BY date_trunc('month', created_at AT TIME ZONE 'UTC')
ORDER  BY month;
