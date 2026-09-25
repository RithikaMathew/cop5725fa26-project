"""
COP5725 Project 1 — ETL loader for the Hacker News 2024 story slice.

The loader gets stories, their comments, polls, and poll options from the
Algolia HN Search API and puts them into the tables defined in schema.sql.

Algolia's search_by_date endpoint only lets a query return about 1,000 hits,
even when nbHits reports many more. 
To cover the full year, the loader splits the date range in half until each
smaller window has no more than 1,000 hits. Lastly, it then combines those results.

How to run:
    uv run --env-file .env load.py                 # fetch the full 2024 slice in date windows
    uv run --env-file .env load.py --demo           # fetch a small sample to test the loader

The database connection comes from the DATABASE_URL environment variable.
No credentials or paths are hardcoded. Each run executes schema.sql first,
which drops and recreates the tables so old rows are not duplicated.

"""

from __future__ import annotations

import argparse
import json
import logging
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse

import psycopg
import requests

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("load")

ALGOLIA_BASE = "https://hn.algolia.com/api/v1/search_by_date"
HITS_PER_PAGE = 1000
REQUEST_PAUSE_SECONDS = 0.2  
MAX_RETRIES = 5

# Start and end of 2024 in UTC, stored as Unix timestamps. The end is exclusive.
SLICE_START = 1704067200
SLICE_END = 1735689600

RAW_DIR = Path("data/raw")


def get_with_retry(url: str, params: dict | None = None, timeout: int = 30) -> requests.Response:
    """Send a GET request. After a timeout, connection error, etc, retry with an exponentially longer wait. Raise the
    error if all retries fail or another HTTP 4xx response occurs."""
    delay = 1.0
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            resp = requests.get(url, params=params, timeout=timeout)
            if resp.status_code == 429 or resp.status_code >= 500:
                raise requests.HTTPError(f"status {resp.status_code}", response=resp)
            resp.raise_for_status()
            return resp
        except (requests.RequestException,) as e:
            if attempt == MAX_RETRIES:
                log.error("  giving up after %d attempts: %s %s", attempt, url, e)
                raise
            log.warning("  request failed (attempt %d/%d), retrying in %.0fs: %s",
                        attempt, MAX_RETRIES, delay, e)
            time.sleep(delay)
            delay *= 2
    raise RuntimeError("unreachable")  


def fetch_all(tags: str, start: int, end: int, demo: bool = False) -> list[dict]:
    """Get raw hits from Algolia's search_by_date endpoint, page by page,
    for the given tag and Unix-time range.
    """
    hits: list[dict] = []
    page = 0
    max_pages = 2 if demo else 10_000
    while page < max_pages:
        params = {
            "tags": tags,
            "numericFilters": f"created_at_i>={start},created_at_i<{end}",
            "hitsPerPage": HITS_PER_PAGE,
            "page": page,
        }
        resp = get_with_retry(ALGOLIA_BASE, params=params)
        payload = resp.json()
        batch = payload.get("hits", [])
        hits.extend(batch)
        log.info("  %s page %d: +%d hits (running total %d)", tags, page, len(batch), len(hits))
        if page + 1 >= payload.get("nbPages", 0) or not batch:
            break
        page += 1
        time.sleep(REQUEST_PAUSE_SECONDS)
    return hits


def fetch_all_windowed(tags: str, start: int, end: int, _stats: dict | None = None) -> list[dict]:
    """Split the [start, end) Unix-time range in half until each part has
    at most about 1,000 hits. The first query for a small enough part already
    contains all its hits, so there is no need to request that part again.

    _stats keeps the progress counts across recursive calls. Pass None on
    the first call so the function creates those counters.
    """
    if _stats is None:
        _stats = {"leaves": 0, "hits": 0, "requests": 0}

    params = {
        "tags": tags,
        "numericFilters": f"created_at_i>={start},created_at_i<{end}",
        "hitsPerPage": HITS_PER_PAGE,
        "page": 0,
    }
    resp = get_with_retry(ALGOLIA_BASE, params=params)
    _stats["requests"] += 1
    payload = resp.json()
    n_hits = payload.get("nbHits", 0)
    time.sleep(REQUEST_PAUSE_SECONDS)

    if n_hits == 0:
        return []

    if n_hits <= HITS_PER_PAGE or end - start <= 1:
        if n_hits > HITS_PER_PAGE:
            log.warning(
                "  %s window [%d, %d) has %d hits but is a single second; "
                "cannot split further, some hits will be missed",
                tags, start, end, n_hits,
            )
        hits = payload.get("hits", [])
        _stats["leaves"] += 1
        _stats["hits"] += len(hits)
        if _stats["leaves"] % 25 == 0:
            log.info(
                "  %s progress: %d windows fetched, %d hits so far, %d requests",
                tags, _stats["leaves"], _stats["hits"], _stats["requests"],
            )
        return hits

    mid = start + (end - start) // 2
    left = fetch_all_windowed(tags, start, mid, _stats)
    right = fetch_all_windowed(tags, mid, end, _stats)
    if _stats.get("_top") is None and start == SLICE_START and end == SLICE_END:
        pass  # top-level marker not needed; final totals logged by caller
    return left + right


def to_ts(hit: dict) -> str | None:
    if hit.get("created_at"):
        return hit["created_at"]
    if hit.get("created_at_i"):
        return datetime.fromtimestamp(hit["created_at_i"], tz=timezone.utc).isoformat()
    return None


def fetch_poll_options(poll_story_ids: list[int]) -> list[dict]:
    """Get each poll's option IDs from Algolia's item endpoint, then get
    each option's text and score from the Firebase API. The Algolia pollopt
    search index does not consistently include option text."""
    hits: list[dict] = []
    for i, poll_id in enumerate(poll_story_ids, start=1):
        resp = get_with_retry(f"https://hn.algolia.com/api/v1/items/{poll_id}")
        option_ids = resp.json().get("options", [])
        for opt_id in option_ids:
            time.sleep(REQUEST_PAUSE_SECONDS)
            r2 = get_with_retry(f"https://hacker-news.firebaseio.com/v0/item/{opt_id}.json")
            opt = r2.json()
            if not opt:
                continue
            hits.append({
                "objectID": str(opt.get("id")),
                "story_id": opt.get("poll"),
                "comment_text": opt.get("text"),
                "points": opt.get("score"),
                "created_at_i": opt.get("time"),
            })
        time.sleep(REQUEST_PAUSE_SECONDS)
        if i % 25 == 0:
            log.info("  poll options progress: %d/%d polls processed", i, len(poll_story_ids))
    log.info("  fetched %d poll options across %d polls", len(hits), len(poll_story_ids))
    return hits


def domain_of(url: str | None) -> str | None:
    if not url:
        return None
    netloc = urlparse(url).netloc
    return netloc.lower().removeprefix("www.") or None


def dump_raw(name: str, hits: list[dict]) -> None:
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    path = RAW_DIR / f"{name}.json"
    path.write_text(json.dumps(hits))
    log.info("  wrote %d raw %s records to %s", len(hits), name, path)


def write_sample(name: str, hits: list[dict]) -> None:
    """Commit the first 1000 rows (or fewer) of a fetched relation to
    data/samples/, as required by the project spec."""
    samples_dir = Path("data/samples")
    samples_dir.mkdir(parents=True, exist_ok=True)
    path = samples_dir / f"{name}.json"
    path.write_text(json.dumps(hits[:1000]))
    log.info("  wrote %d sample %s records to %s", min(len(hits), 1000), name, path)


def run_schema(conn: psycopg.Connection) -> None:
    log.info("Running schema.sql (drop + create) ...")
    sql = Path("schema.sql").read_text()
    with conn.cursor() as cur:
        cur.execute(sql)
    conn.commit()
    log.info("Schema created.")


def load_users(conn: psycopg.Connection, story_hits: list[dict], comment_hits: list[dict]) -> None:
    seen: dict[str, str] = {}
    for hit in story_hits + comment_hits:
        author = hit.get("author")
        ts = to_ts(hit)
        if not author or not ts:
            continue
        if author not in seen or ts < seen[author]:
            seen[author] = ts
    rows = list(seen.items())
    with conn.cursor() as cur:
        cur.executemany(
            """
            INSERT INTO users (username, first_seen_at)
            VALUES (%s, %s)
            ON CONFLICT (username) DO UPDATE
                SET first_seen_at = LEAST(users.first_seen_at, EXCLUDED.first_seen_at)
            """,
            rows,
        )
    conn.commit()
    log.info("Loaded %d users.", len(rows))


def load_domains(conn: psycopg.Connection, story_hits: list[dict]) -> dict[str, int]:
    domains = sorted({domain_of(h.get("url")) for h in story_hits if domain_of(h.get("url"))})
    with conn.cursor() as cur:
        cur.executemany(
            "INSERT INTO domains (domain_name) VALUES (%s) ON CONFLICT (domain_name) DO NOTHING",
            [(d,) for d in domains],
        )
        cur.execute("SELECT domain_id, domain_name FROM domains")
        domain_id_by_name = {name: did for did, name in cur.fetchall()}
    conn.commit()
    log.info("Loaded %d domains.", len(domains))
    return domain_id_by_name


def load_stories(conn: psycopg.Connection, story_hits: list[dict], domain_id_by_name: dict[str, int]) -> None:
    rows = []
    tag_rows = []
    seen_ids: set[int] = set()
    for hit in story_hits:
        story_id = hit.get("story_id") or hit.get("objectID")
        if story_id is None:
            continue
        story_id = int(story_id)
        if story_id in seen_ids:
            continue  # story and poll fetches can overlap at window boundaries
        seen_ids.add(story_id)
        tags = hit.get("_tags", [])
        d_name = domain_of(hit.get("url"))
        rows.append(
            (
                story_id,
                hit.get("author"),
                domain_id_by_name.get(d_name),
                hit.get("title") or "(untitled)",
                hit.get("url"),
                hit.get("story_text"),
                hit.get("points") or 0,
                hit.get("num_comments") or 0,
                "ask_hn" in tags,
                "show_hn" in tags,
                "poll" in tags,
                to_ts(hit),
                hit.get("updated_at") or to_ts(hit),
            )
        )
        for t in tags:
            if not t.startswith("author_") and not t.startswith("story_"):
                tag_rows.append((story_id, t))

    with conn.cursor() as cur:
        cur.executemany(
            """
            INSERT INTO stories
                (story_id, author, domain_id, title, url, story_text,
                 points, num_comments, is_ask_hn, is_show_hn, is_poll,
                 created_at, updated_at)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
            ON CONFLICT (story_id) DO NOTHING
            """,
            rows,
        )
        cur.executemany(
            "INSERT INTO story_tags (story_id, tag) VALUES (%s,%s) ON CONFLICT DO NOTHING",
            tag_rows,
        )
    conn.commit()
    log.info("Loaded %d stories, %d story_tags rows.", len(rows), len(tag_rows))


def load_comments(conn: psycopg.Connection, comment_hits: list[dict], story_ids: set[int]) -> None:
    rows = []
    seen_ids: set[int] = set()
    for hit in comment_hits:
        comment_id = hit.get("objectID")
        story_id = hit.get("story_id")
        if comment_id is None or story_id is None:
            continue
        comment_id = int(comment_id)
        if comment_id in seen_ids:
            continue  # A boundary may return the same comment twice; keep one copy.
        story_id = int(story_id)
        if story_id not in story_ids:
            # Skip comments whose story is outside the selected 2024 stories.
            continue
        seen_ids.add(comment_id)
        parent = hit.get("parent_id")
        rows.append(
            (
                comment_id,
                story_id,
                int(parent) if parent and int(parent) != story_id else None,
                hit.get("author"),
                hit.get("comment_text"),
                to_ts(hit),
            )
        )
    # Insert comments first, then connect each reply to its parent comment.
    # This lets the parent_comment_id foreign key work even if a reply came
    # before its parent in the raw results.
    with conn.cursor() as cur:
        cur.executemany(
            """
            INSERT INTO comments (comment_id, story_id, parent_comment_id, author, comment_text, created_at)
            VALUES (%s,%s,NULL,%s,%s,%s)
            ON CONFLICT (comment_id) DO NOTHING
            """,
            [(r[0], r[1], r[3], r[4], r[5]) for r in rows],
        )
        loaded_ids = {r[0] for r in rows}
        cur.executemany(
            "UPDATE comments SET parent_comment_id = %s WHERE comment_id = %s",
            [(r[2], r[0]) for r in rows if r[2] is not None and r[2] in loaded_ids],
        )
    conn.commit()
    log.info("Loaded %d comments.", len(rows))


def load_polls(conn: psycopg.Connection, poll_opt_hits: list[dict], story_ids: set[int]) -> None:
    poll_rows = []
    option_rows = []
    seen_polls: set[int] = set()
    seen_opts: set[int] = set()
    for hit in poll_opt_hits:
        opt_id = hit.get("objectID")
        poll_id = hit.get("story_id") or hit.get("parent_id")
        if opt_id is None or poll_id is None:
            continue
        opt_id = int(opt_id)
        if opt_id in seen_opts:
            continue
        seen_opts.add(opt_id)
        poll_id = int(poll_id)
        if poll_id not in story_ids:
            continue
        if poll_id not in seen_polls:
            poll_rows.append((poll_id, to_ts(hit)))
            seen_polls.add(poll_id)
        option_rows.append(
            (opt_id, poll_id, hit.get("comment_text") or hit.get("title"), hit.get("points") or 0)
        )
    with conn.cursor() as cur:
        cur.executemany(
            "INSERT INTO polls (poll_id, created_at) VALUES (%s,%s) ON CONFLICT (poll_id) DO NOTHING",
            poll_rows,
        )
        cur.executemany(
            """
            INSERT INTO poll_options (poll_option_id, poll_id, option_text, points)
            VALUES (%s,%s,%s,%s)
            ON CONFLICT (poll_option_id) DO NOTHING
            """,
            option_rows,
        )
    conn.commit()
    log.info("Loaded %d polls, %d poll_options.", len(poll_rows), len(option_rows))


def print_row_counts(conn: psycopg.Connection) -> None:
    tables = ["users", "domains", "stories", "story_tags", "comments", "polls", "poll_options"]
    with conn.cursor() as cur:
        log.info("Final row counts:")
        for t in tables:
            cur.execute(f"SELECT count(*) FROM {t}")
            log.info("  %-14s %d", t, cur.fetchone()[0])


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--demo",
        action="store_true",
        help="fetch only the first two pages per relation (fast smoke test, not the full slice)",
    )
    args = parser.parse_args()

    import os

    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        log.error("DATABASE_URL is not set. Copy .env.example to .env and fill it in.")
        sys.exit(1)

    if args.demo:
        log.info("Fetching stories for 2024 (tags=story, demo) ...")
        story_hits = fetch_all("story", SLICE_START, SLICE_END, demo=True)
        log.info("Fetching polls for 2024 (tags=poll, demo) ...")
        poll_hits = fetch_all("poll", SLICE_START, SLICE_END, demo=True)
        log.info("Fetching comments for 2024 (tags=comment, demo) ...")
        comment_hits = fetch_all("comment", SLICE_START, SLICE_END, demo=True)
    else:
        log.info("Fetching stories for 2024 (tags=story, windowed full slice) ...")
        story_hits = fetch_all_windowed("story", SLICE_START, SLICE_END)
        log.info("  total: %d story hits", len(story_hits))
        log.info("Fetching polls for 2024 (tags=poll, windowed full slice) ...")
        poll_hits = fetch_all_windowed("poll", SLICE_START, SLICE_END)
        log.info("  total: %d poll hits", len(poll_hits))
        log.info("Fetching comments for 2024 (tags=comment, windowed full slice) ...")
        comment_hits = fetch_all_windowed("comment", SLICE_START, SLICE_END)
        log.info("  total: %d comment hits", len(comment_hits))

    story_hits = story_hits + poll_hits
    dump_raw("stories", story_hits)
    write_sample("stories", story_hits)

    dump_raw("comments", comment_hits)
    write_sample("comments", comment_hits)

    poll_story_ids = [int(h["objectID"]) for h in poll_hits]
    if args.demo:
        poll_story_ids = poll_story_ids[:5]
    log.info("Fetching poll options for %d polls (item + Firebase) ...", len(poll_story_ids))
    poll_opt_hits = fetch_poll_options(poll_story_ids)
    dump_raw("poll_options", poll_opt_hits)
    write_sample("poll_options", poll_opt_hits)

    with psycopg.connect(database_url) as conn:
        run_schema(conn)
        load_users(conn, story_hits, comment_hits)
        domain_id_by_name = load_domains(conn, story_hits)
        load_stories(conn, story_hits, domain_id_by_name)
        story_ids = {int(h["story_id"] if h.get("story_id") else h["objectID"]) for h in story_hits}
        load_comments(conn, comment_hits, story_ids)
        load_polls(conn, poll_opt_hits, story_ids)
        print_row_counts(conn)

    log.info("Done.")


if __name__ == "__main__":
    main()
