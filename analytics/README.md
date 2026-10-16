# Project 2: Advanced SQL Analytics

Scenario (from Project 1): I am a developer relations analyst at a company that makes AI and agentic developer tools. These queries ask which AI/agent-related Hacker News stories get attention in 2024, who keeps showing up in those discussions, and when.

"AI/agent-related" means the story title matches a word-boundary regex for terms like ai, llm, gpt, agent(s), agentic, openai, anthropic, claude, copilot, rag, gemini, llama and mistral. The same filter is used in every AI query. Months are bucketed in UTC.

Run everything: `uv run --env-file .env analytics/run_queries.py`

## a01: Running total of AI stories

- Question: How many AI/agent-related stories have accumulated month by month through 2024?
- Purpose: The DevRel lead wants to know whether AI discussion on HN is still growing, to decide how much launch content to schedule for H2.
- Technique: Window aggregate `sum() OVER` with an explicit `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` frame.
- Sample result:

| month | ai_stories | running_stories |
|---|---|---|
| 2024-01 | 2545 | 2545 |
| 2024-02 | 2578 | 5123 |
| 2024-03 | 2757 | 7880 |
| 2024-04 | 2848 | 10728 |
| 2024-05 | 3316 | 14044 |

- Interesting result: Around 2,500 to 3,300 AI stories were posted monthly, with May having the most at 3,316 stories. By the end of the year, there were 32,629 AI-related stories in total. This suggests that interest in AI remained steady throughout 2024 rather than declining, making it a worthwhile topic for the team to continue creating content about. 

## a02: Top 3 AI stories per month

- Question: What were the top 3 AI/agent-related stories by points in each month of 2024?
- Purpose: Shows which kinds of AI posts win attention each month, so the team can model its own Show HN launches on them.
- Technique: `row_number() OVER (PARTITION BY month ORDER BY points DESC)`.
- Sample result:

| month | rk | title | author | points | num_comments |
|---|---|---|---|---|---|
| 2024-01 | 1 | I'm sorry but I cannot fulfill this request it goes against OpenAI use policy | edward | 1325 | 736 |
| 2024-01 | 2 | The Internet Is Full of AI Dogshit | thinkingemote | 805 | 587 |
| 2024-01 | 3 | Implementing a ChatGPT-like LLM from scratch, step by step | rasbt | 739 | 98 |
| 2024-02 | 1 | Our next-generation model: Gemini 1.5 | todsacerdoti | 1244 | 588 |
| 2024-02 | 2 | FCC rules AI-generated voices in robocalls illegal | ortusdux | 1156 | 674 |

- Interesting result: The winners are almost always big-company model launches or drama (Gemini 1.5 in February, Meta Llama 3 in April with 2199 points, GPT-4o in May with 3138 points and 2,366 comments, etc.). Opinion pieces like "The Internet Is Full of AI Dogshit" and "I Am Tired of AI" also reach the top 3, so skepticism gets as much attention as launches.

## a03: Month-over-month change in AI stories

- Question: How did the number of AI/agent-related stories change month over month in 2024?
- Purpose: Shows whether interest in AI topics is speeding up or slowing down, which helps time the team's own posts.
- Technique: `lag()` over a monthly aggregate.
- Sample result:

| month | ai_stories | prev_month | change |
|---|---|---|---|
| 2024-01 | 2545 | NULL | NULL |
| 2024-02 | 2578 | 2545 | 33 |
| 2024-03 | 2757 | 2578 | 179 |
| 2024-04 | 2848 | 2757 | 91 |
| 2024-05 | 3316 | 2848 | 468 |

- Interesting result: Growth was slow and steady from January to April (+33 to +179 a month), then May jumped by 468 stories (+16%), the biggest monthly change of the year, lining up with the GPT-4o launch. The rest of the year swung up and down by 84 to 263 stories a month with no clear trend. January has no previous month, so its change is NULL.

## a04: Top 1% by comments (cumulative distribution)

- Question: Which stories sit in the top 1% of all 2024 stories by comment count?
- Purpose: Finds stories that sparked unusually large discussions, which are the threads worth joining.
- Technique: `cume_dist()`.
- Sample result:

| title | author | num_comments | points | comments_percentile |
|---|---|---|---|---|
| Trump wins presidency for second time | koolba | 9274 | 1796 | 100.00 |
| CrowdStrike Update: Windows Bluescreen and Boot Loops | BLKNSLVR | 3859 | 4489 | 100.00 |
| U.S. sues Apple, accusing it of maintaining an iPhone monopoly | jcfrei | 2569 | 2546 | 100.00 |
| Hezbollah pager explosions kill several people in Lebanon | logicchains | 2526 | 1076 | 100.00 |
| Apple announces changes to iOS, Safari, and the App Store in the European Union | colinhb | 2485 | 2108 | 100.00 |

- Interesting result: Politics and big-tech news dominate the most-discussed stories, but AI stories make up about a fifth of the top 50: GPT-4o (6th, 2366 comments), Sora, OpenAI O3, "Learning to Reason with LLMs", ChatGPT Search, Apple Intelligence, etc. Some stories get far more discussion than their points suggest: "Why America's economy is soaring ahead of its rivals" has 2,210 comments but only 481 points, and "Fewer people are buying electric cars in the US" has 2,127 comments on just 370 points. Lots of comments = lots of discussion, but not necessarily lots of agreement.

## a05: Deepest reply chains

- Question: Which stories have the deepest reply chains, and how long is the deepest chain in each?
- Purpose: Deep chains mean back-and-forth debate, which is where a DevRel person can add the most value.
- Technique: `WITH RECURSIVE` over `comments.parent_comment_id`, with a depth bound of 200.
- Sample result:

| title | author | points | max_depth | comments_in_tree |
|---|---|---|---|---|
| The Soviet Union's Monster Mi-6 Helicopter Airliner | Thevet | 106 | 52 | 175 |
| Daniel Dennett has died | mellosouls | 952 | 46 | 630 |
| What if I'm wrong? (2023) | jrlocke | 209 | 42 | 279 |
| State-space models can learn in-context by gradient descent | dsalaj | 86 | 41 | 58 |
| Israel shuts down local Al Jazeera offices | jjgreen | 783 | 36 | 1353 |

- Interesting result: Having more comments doesn't always mean having longer reply chains. This query finds which stories have the deepest reply chains. For example, the Soviet helicopter story had 175 comments, with its longest conversation reaching 52 levels deep, while the Daniel Dennett story had 630 comments but only reached 46 levels. This shows that having more comments doesn't necessarily mean having longer back-and-forth conversations. The query took about 103.5 seconds to run.

## a06: Most active commenters in AI threads

- Question: Who are the most active commenters on AI/agent-related stories?
- Purpose: Identifies the people to build relationships with.
- Technique: Two-step CTE pipeline: filter AI stories, then per-commenter stats.
- Sample result:

| author | comments | stories_touched |
|---|---|---|
| ben_w | 1116 | 307 |
| simonw | 822 | 292 |
| fragmede | 613 | 298 |
| ChrisArchitect | 563 | 518 |
| talldayo | 530 | 288 |

- Interesting result: Ben_w had the most comments with 1,116 across 307 stories, followed by simonw with 822 comments across 292 stories. Interestingly, ChrisArchitect left 563 comments across 518 stories, suggesting they usually comment only once per story, while ben_w and simonw tend to participate more in discussions. This shows that some users actively engage in conversations, while others mostly leave individual comments.

## a07a / a07b: Points vs month average (naive vs window)

- Question: For each AI/agent story, how many points above or below its month's average is it?
- Purpose: Normalizes points by month so stories can be compared fairly across the year.
- Technique: a07a uses a correlated subquery; a07b uses `avg() OVER (PARTITION BY month)`.
- Sample result (a07b):

| title | month | points | points_vs_month_avg |
|---|---|---|---|
| Stuff we figured out about AI in 2023 | 2024-01 | 210 | 195.7 |
| AI Trends for 2024 | 2024-01 | 1 | -13.3 |
| 2023 in Review: RARBG, Zoro, Z-Library, Flawless, IPTV and AI | 2024-01 | 7 | -7.3 |
| US Supreme Court's Roberts urges 'caution' as AI reshapes legal field | 2024-01 | 7 | -7.3 |
| AI's Predictable Path: Things to Expect from AI in 2024 | 2024-01 | 1 | -13.3 |

- Both queries returned the same results, but the window function was much faster. In January, the average story had about 14.3 points, even though most stories scored only 1 to 7 points, because a few very popular stories pulled the average up. EXPLAIN ANALYZE timings: the naive query took about 72.8 seconds, while the window query took only 1.06 seconds, making it roughly 69 times faster. This is because the naive query repeatedly calculates the monthly average for each story, while the window function calculates the averages more efficiently. Interestingly, when I added LIMIT 50, both queries ran in around 1.3 seconds because the naive query only needed to calculate averages for 50 returned rows.

## a08: Resubmitted URLs, canonical submission

- Question: Which URLs were submitted more than once in 2024, and which submission was the canonical (highest-scoring) one?
- Purpose: Shows how often the same links are resubmitted and which submissions received the most points, helping evaluate whether reposting a link is worthwhile.
- Technique: `row_number() = 1` per url plus `count(*) OVER` the same partition.
- Sample result:

| url | submissions | canonical_title | canonical_author | canonical_points |
|---|---|---|---|---|
| https://hacktoberfest.com | 27 | Hacktoberfest 2024 | ironinter | 11 |
| github.com/fzliu/radient/.../multimodal_rag.md | 19 | Multimodal RAG (With Meta Chameleon 7B) | fzliu | 6 |
| theverge.com/.../google-search-seo-algorithm-webpage-optimization | 15 | How Google perfected the web | pros | 20 |
| situational-awareness.ai/.../situationalawareness.pdf | 13 | Situational Awareness [pdf] | ingve | 17 |
| github.com/iterative/datachain | 12 | DataChain: DBT for Unstructured Data | shcheklein | 163 |

- Interesting result: This query shows that submitting the same URL multiple times doesn't necessarily lead to more points. For example, Hacktoberfest was submitted 27 times, but its highest-scoring post received only 11 points. Similarly, the Multimodal RAG GitHub link was submitted 19 times but only reached 6 points. However, DataChain was submitted 12 times and reached 163 points, showing that some reposted links can become popular. Overall, repeatedly submitting the same link doesn't guarantee a higher score.

## a09: Best posting hour for AI stories

- Question: Which UTC hour of the day gets AI/agent stories the most comments on average?
- Purpose: Picks a posting time for the team's own submissions.
- Technique: `rank()` over a per-hour aggregate.
- Sample result:

| hour_utc | stories | avg_comments | rank_by_avg |
|---|---|---|---|
| 17 | 2271 | 11.6 | 1 |
| 2 | 778 | 10.8 | 2 |
| 19 | 1849 | 9.8 | 3 |
| 15 | 2327 | 9.4 | 4 |
| 23 | 1017 | 9.4 | 4 |

- Interesting result: Stories posted at 17:00 UTC received the most comments on average (11.6), followed by 02:00 UTC (10.8). Although 17:00 UTC had more stories competing for attention, 02:00 UTC had nearly as many comments with far fewer posts, making it another promising time to try. Overall, these results suggest that 17:00 UTC and 02:00 UTC may be good posting times for getting more discussion, although they don't guarantee higher engagement.

## a10: Revived threads

- Question: Which AI/agent stories went quiet and were later revived, i.e. had the longest gap between consecutive comments?
- Purpose: Spots stories that were rediscovered later, e.g. via resubmission or a news event.
- Technique: `lag()` over comments partitioned by story.
- Sample result:

| title | points | comments | longest_gap |
|---|---|---|---|
| It's all unraveling at OpenAI (again) | 42 | 42 | 13 days, 21:59:01 |
| OpenAI CTO says AI should displace some creative jobs that shouldn't exist | 10 | 19 | 13 days, 16:43:36 |
| GLM-4-9B: open-source model with superior performance to Llama-3-8B | 66 | 17 | 13 days, 10:01:36 |
| Viking 7B: open LLM for the Nordic languages trained on AMD GPUs | 113 | 52 | 13 days, 5:51:21 |
| OpenAI Deal Lets Employees Sell Shares at $86B Valuation | 245 | 286 | 12 days, 23:12:31 |

- Interesting result: No gap in the whole dataset exceeds about 14 days (the longest is 13 days, 22 hours), which looks like Hacker News closing old threads to new comments after roughly two weeks, so a thread cannot be "revived" for longer than that. Many of these stories also had relatively low points, suggesting that even less popular discussions can receive comments days later.
