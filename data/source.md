# Data Source

**Dataset name:** Hacker News — 2024 story submissions

**URL / fetch instructions:**

Loadable with no signup or auth key via the Algolia HN Search API:

    https://hn.algolia.com/api/v1/search_by_date?tags=story&numericFilters=created_at_i>=1704067200,created_at_i<1735689600&hitsPerPage=1000

Sample regeneration:

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
MIT (official Hacker News API, Y Combinator). See https://github.com/HackerNews/API.

**Approximate size:**
- Row count: 297,634 distinct loaded stories verified in the October 21, 2026 full load (the earlier Project 1 grader snapshot contained 297,625; live API results can change)
- Table count: 3 raw item types pulled from the API (stories, comments, poll options); normalized in `schema.sql` into 8 relational tables plus a derived activity view

**Update frequency:**
Continuous, near real-time; this project uses a fixed 2024 date range for reproducibility.
