-- a06-cte-pipeline.sql
-- Question: Who are the most active commenters on AI/agent-related stories?
-- Technique: multi-step CTE pipeline (filter stories -> per-commenter stats)
-- Project 2 requirement: multi-step transformation

WITH ai_stories AS (
  -- step 1: AI/agent stories only
  SELECT story_id
  FROM   stories
  WHERE  title ~* '\m(ai|llm|llms|gpt|chatgpt|agents?|agentic|openai|anthropic|claude|copilot|rag|gemini|llama|mistral)\M'
),
commenter_stats AS (
  -- step 2: per commenter, how many comments and on how many of those stories
  SELECT c.author,
         count(*)                   AS comments,
         count(DISTINCT c.story_id) AS stories_touched
  FROM   comments c
  JOIN   ai_stories a USING (story_id)
  WHERE  c.author IS NOT NULL
  GROUP  BY c.author
)
SELECT author, comments, stories_touched
FROM   commenter_stats
ORDER  BY comments DESC, author
LIMIT  25;
