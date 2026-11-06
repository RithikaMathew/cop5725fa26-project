# Project 2 notes for Rithika Mathew

These notes list what worked, what cost points, tips that did not cost points, and what to do before Project 3. Scores below are provisional from automated static checks and a single execution pass; the TA may adjust after review.

Graded commit: **`v2`** → `cc5f850028` (2026-10-21 12:38 EDT).

Project 1 feedback (local): `/blue/cop5725/czzqunbe/project1/student-notes/RithikaMathew.md`

## Score

| Area | Points | Out of | How the points were assigned |
|---|---|---|---|
| Query coverage | 30 | 30 |  |
| Query craftsmanship | 20 | 20 |  |
| Naive vs window (a07a, a07b) | 15 | 15 |  |
| Analytics script and README | 15 | 15 |  |
| Documentation (root README) | 10 | 10 |  |
| Repo hygiene | 10 | 10 |  |
| **Total** | **100** | **100** | |

## What worked well

- Loader and analytics runner both completed on the HiPerGator grading database (capped slice / polite API limits—not necessarily identical to your full local run).
- Static review found most required SQL pattern groups in `analytics/*.sql`: top-N per group, running total, period-over-period, cumulative distribution, CTE pipeline, deduplication, naive half of a07, window half of a07.
- SQL files generally include Question / Technique headers as required.

## What cost points

### Execution notes

- _No automated rubric deductions recorded; TA may still adjust after reading SQL and README._

## Before Project 3

- Before Project 3, pick your slowest Project 2 query and be ready to add indexes and capture EXPLAIN plans.
