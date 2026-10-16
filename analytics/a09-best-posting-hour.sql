-- a09-best-posting-hour.sql
-- Question: Which UTC hour of the day gets AI/agent stories the most comments on average?
-- Technique: rank() over a per-hour aggregate
-- Project 2 requirement: own choice

SELECT
  extract(hour FROM created_at AT TIME ZONE 'UTC')::int AS hour_utc,
  count(*)                                              AS stories,
  round(avg(num_comments), 1)                           AS avg_comments,
  rank() OVER (ORDER BY round(avg(num_comments), 1) DESC) AS rank_by_avg
FROM   stories
WHERE  title ~* '\m(ai|llm|llms|gpt|chatgpt|agents?|agentic|openai|anthropic|claude|copilot|rag|gemini|llama|mistral)\M'
GROUP  BY 1
ORDER  BY rank_by_avg, hour_utc;
