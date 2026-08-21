# Data Source

**Dataset name:** Hacker News — 2024 story submissions

**URL / fetch instructions:**
Loadable with no signup or auth key via the Algolia HN Search API (mirrors the official Hacker News API):

```
https://hn.algolia.com/api/v1/search_by_date?tags=story&numericFilters=created_at_i>=1704067200,created_at_i<1735689600&hitsPerPage=1000
```

Sample regeneration (1000 most recent stories in the 2024 window):

```python
import requests, pandas as pd

resp = requests.get(
    "https://hn.algolia.com/api/v1/search_by_date",
    params={
        "tags": "story",
        "numericFilters": "created_at_i>=1704067200,created_at_i<1735689600",
        "hitsPerPage": 1000,
    },
)
pd.DataFrame(resp.json()["hits"]).to_csv("data/sample.csv", index=False)
```

**License:**
The Algolia HN Search API mirrors data served by the official Hacker News API (HackerNews/API), which is MIT-licensed and has no rate limit or auth requirement. See https://github.com/HackerNews/API.

**Approximate size:**
- Row count: 210,440 story submissions in 2024; 220,490 comments in the same window (both exact counts via nbHits from the search_by_date endpoint, run 2026-08-21)
- Table count: 2 conceptual tables (stories, comments) — comments nest under stories in a tree via each item's `parent`/`kids` field
- Columns (stories, via this API): objectID (story id), story_id, title, url, author, points, num_comments, created_at / created_at_i, updated_at, story_text (if any), children (child comment IDs), _tags

**Update frequency:**
Continuous, near real-time; this project uses a fixed date range (2024-01-01 to 2025-01-01, UTC) for reproducibility.
