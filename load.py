"""
Load 2024 Hacker News stories, comments, polls, and poll options into PostgreSQL.

Run:
    uv run --env-file .env load.py
    uv run --env-file .env load.py --demo

The full run saves downloads in data/raw/. Later full runs reuse those files.
Demo downloads have separate filenames, so they cannot replace the full data.
"""

from __future__ import annotations

from collections import Counter
import argparse
import json
import logging
import os
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

# January 1, 2024 through January 1, 2025 (end exclusive), in UTC.
SLICE_START = 1704067200
SLICE_END = 1735689600

RAW_DIR = Path("data/raw")


def get_with_retry(
    url: str, params: dict | None = None, timeout: int = 30
) -> requests.Response:
    """Retry temporary request failures, then report an error."""
    delay = 1.0
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            resp = requests.get(url, params=params, timeout=timeout)
            if resp.status_code == 429 or resp.status_code >= 500:
                raise requests.HTTPError(
                    f"status {resp.status_code}", response=resp
                )
            resp.raise_for_status()
            return resp
        except requests.RequestException as exc:
            if attempt == MAX_RETRIES:
                log.error(
                    "Giving up after %d attempts: %s %s", attempt, url, exc
                )
                raise
            log.warning(
                "Request failed (attempt %d/%d); retrying in %.0fs: %s",
                attempt,
                MAX_RETRIES,
                delay,
                exc,
            )
            time.sleep(delay)
            delay *= 2
    raise RuntimeError("Unreachable")


def fetch_all(tags: str, start: int, end: int, demo: bool = False) -> list[dict]:
    """Fetch pages for a tag. Demo mode stops after two pages."""
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
        payload = get_with_retry(ALGOLIA_BASE, params=params).json()
        batch = payload.get("hits", [])
        hits.extend(batch)
        log.info(
            "  %s page %d: +%d hits (total %d)",
            tags,
            page,
            len(batch),
            len(hits),
        )
        if page + 1 >= payload.get("nbPages", 0) or not batch:
            break
        page += 1
        time.sleep(REQUEST_PAUSE_SECONDS)

    return hits


def fetch_all_windowed(
    tags: str,
    start: int,
    end: int,
    _stats: dict | None = None,
) -> list[dict]:
    """Split large date ranges until Algolia can return all hits in each."""
    if _stats is None:
        _stats = {"leaves": 0, "hits": 0, "requests": 0}

    params = {
        "tags": tags,
        "numericFilters": f"created_at_i>={start},created_at_i<{end}",
        "hitsPerPage": HITS_PER_PAGE,
        "page": 0,
    }
    payload = get_with_retry(ALGOLIA_BASE, params=params).json()
    _stats["requests"] += 1
    n_hits = payload.get("nbHits", 0)
    time.sleep(REQUEST_PAUSE_SECONDS)

    if n_hits == 0:
        return []

    if n_hits <= HITS_PER_PAGE or end - start <= 1:
        if n_hits > HITS_PER_PAGE:
            log.warning(
                "%s window [%d, %d) has %d hits in one second; "
                "some hits may be missed",
                tags,
                start,
                end,
                n_hits,
            )
        hits = payload.get("hits", [])
        _stats["leaves"] += 1
        _stats["hits"] += len(hits)
        if _stats["leaves"] % 25 == 0:
            log.info(
                "  %s progress: %d windows, %d hits, %d requests",
                tags,
                _stats["leaves"],
                _stats["hits"],
                _stats["requests"],
            )
        return hits

    mid = start + (end - start) // 2
    left = fetch_all_windowed(tags, start, mid, _stats)
    right = fetch_all_windowed(tags, mid, end, _stats)
    return left + right


def to_ts(hit: dict) -> str | None:
    if hit.get("created_at"):
        return hit["created_at"]
    if hit.get("created_at_i"):
        return datetime.fromtimestamp(
            hit["created_at_i"], tz=timezone.utc
        ).isoformat()
    return None


def fetch_poll_options(poll_story_ids: list[int]) -> list[dict]:
    """Fetch each poll's options from Algolia and their details from Firebase."""
    hits: list[dict] = []

    for i, poll_id in enumerate(poll_story_ids, start=1):
        resp = get_with_retry(f"https://hn.algolia.com/api/v1/items/{poll_id}")
        option_ids = resp.json().get("options", [])

        for opt_id in option_ids:
            time.sleep(REQUEST_PAUSE_SECONDS)
            resp = get_with_retry(
                f"https://hacker-news.firebaseio.com/v0/item/{opt_id}.json"
            )
            opt = resp.json()
            if not opt:
                continue
            hits.append(
                {
                    "objectID": str(opt.get("id")),
                    "story_id": opt.get("poll"),
                    "comment_text": opt.get("text"),
                    "points": opt.get("score"),
                    "created_at_i": opt.get("time"),
                }
            )

        time.sleep(REQUEST_PAUSE_SECONDS)
        if i % 25 == 0:
            log.info(
                "  Poll options progress: %d/%d polls",
                i,
                len(poll_story_ids),
            )

    log.info(
        "Fetched %d poll options across %d polls",
        len(hits),
        len(poll_story_ids),
    )
    return hits


def domain_of(url: str | None) -> str | None:
    if not url:
        return None
    netloc = urlparse(url).netloc
    return netloc.lower().removeprefix("www.") or None


def raw_path(name: str, demo: bool) -> Path:
    suffix = "_demo" if demo else ""
    return RAW_DIR / f"{name}{suffix}.json"


def read_raw(name: str, demo: bool) -> list[dict] | None:
    """Return cached records, or None if this relation has not been fetched."""
    path = raw_path(name, demo)
    if not path.exists():
        return None

    data = json.loads(path.read_text())
    if not isinstance(data, list):
        raise ValueError(f"Expected a list of records in {path}")

    log.info("Read %d cached %s records from %s", len(data), name, path)
    return data


def dump_raw(name: str, hits: list[dict], demo: bool) -> None:
    """Write a complete download before giving it its final filename."""
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    path = raw_path(name, demo)
    temporary = path.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(hits))
    temporary.replace(path)
    log.info("Wrote %d raw %s records to %s", len(hits), name, path)


def write_sample(name: str, hits: list[dict]) -> None:
    samples_dir = Path("data/samples")
    samples_dir.mkdir(parents=True, exist_ok=True)
    path = samples_dir / f"{name}.json"
    path.write_text(json.dumps(hits[:1000]))
    log.info(
        "Wrote %d sample %s records to %s",
        min(len(hits), 1000),
        name,
        path,
    )


def run_schema(conn: psycopg.Connection) -> None:
    log.info("Running schema.sql (drop + create) ...")
    with conn.cursor() as cur:
        cur.execute(Path("schema.sql").read_text())
    conn.commit()
    log.info("Schema created.")


def load_users(
    conn: psycopg.Connection,
    story_hits: list[dict],
    comment_hits: list[dict],
) -> None:
    authors = sorted({h["author"] for h in story_hits + comment_hits if h.get("author")})
    with conn.cursor() as cur:
        cur.executemany(
            "INSERT INTO users (username) VALUES (%s) ON CONFLICT DO NOTHING",
            [(author,) for author in authors],
        )
    conn.commit()
    log.info("Loaded %d users.", len(authors))


def load_domains(
    conn: psycopg.Connection,
    story_hits: list[dict],
) -> dict[str, int]:
    domains = sorted(
        {
            domain_of(h.get("url"))
            for h in story_hits
            if domain_of(h.get("url"))
        }
    )
    with conn.cursor() as cur:
        cur.executemany(
            """
            INSERT INTO domains (domain_name)
            VALUES (%s)
            ON CONFLICT (domain_name) DO NOTHING
            """,
            [(domain,) for domain in domains],
        )
        cur.execute("SELECT domain_id, domain_name FROM domains")
        domain_id_by_name = {
            name: domain_id for domain_id, name in cur.fetchall()
        }
    conn.commit()
    log.info("Loaded %d domains.", len(domains))
    return domain_id_by_name


def load_stories(
    conn: psycopg.Connection,
    story_hits: list[dict],
    domain_id_by_name: dict[str, int],
) -> None:
    rows = []
    tag_rows = []
    seen_ids: set[int] = set()

    for hit in story_hits:
        story_id = hit.get("story_id") or hit.get("objectID")
        if story_id is None:
            continue
        story_id = int(story_id)
        if story_id in seen_ids:
            continue
        seen_ids.add(story_id)

        tags = hit.get("_tags", [])
        rows.append(
            (
                story_id,
                hit.get("author"),
                hit.get("title") or "(untitled)",
                hit.get("url") or None,
                hit.get("story_text"),
                hit.get("points") or 0,
                hit.get("num_comments") or 0,
                "ask_hn" in tags,
                "show_hn" in tags,
                to_ts(hit),
                hit.get("updated_at") or to_ts(hit),
            )
        )
        for tag in tags:
            if not tag.startswith("author_") and not tag.startswith("story_"):
                tag_rows.append((story_id, tag))

    link_rows = {h["url"]: domain_id_by_name.get(domain_of(h["url"]))
                 for h in story_hits if h.get("url")}
    with conn.cursor() as cur:
        cur.executemany(
            "INSERT INTO links (url, domain_id) VALUES (%s, %s) ON CONFLICT DO NOTHING",
            list(link_rows.items()),
        )
        cur.executemany(
            """
            INSERT INTO stories
                (story_id, author, title, url, story_text,
                 points, num_comments, is_ask_hn, is_show_hn,
                 created_at, updated_at)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
            ON CONFLICT (story_id) DO NOTHING
            """,
            rows,
        )
        cur.executemany(
            """
            INSERT INTO story_tags (story_id, tag)
            VALUES (%s,%s)
            ON CONFLICT DO NOTHING
            """,
            tag_rows,
        )
    conn.commit()
    log.info(
        "Loaded %d stories, %d story_tags rows.",
        len(rows),
        len(tag_rows),
    )


def load_comments(
    conn: psycopg.Connection,
    comment_hits: list[dict],
    story_ids: set[int],
) -> None:
    rows = []
    seen_ids: set[int] = set()
    skipped = Counter()

    for hit in comment_hits:
        comment_id = hit.get("objectID")
        story_id = hit.get("story_id")
        if comment_id is None or story_id is None:
            skipped["missing id"] += 1
            continue

        comment_id = int(comment_id)
        if comment_id in seen_ids:
            skipped["duplicate id"] += 1
            continue

        story_id = int(story_id)
        if story_id not in story_ids:
            # A 2024 comment can belong to a story outside this story slice.
            skipped["story outside the slice"] += 1
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

    # Insert all comments before linking parents: real data can have a parent
    # whose ID is larger than its reply's ID.
    loaded_ids = {r[0] for r in rows}
    with conn.cursor() as cur:
        cur.executemany(
            """INSERT INTO comments
               (comment_id, story_id, parent_comment_id, author, comment_text, created_at)
               VALUES (%s,%s,NULL,%s,%s,%s) ON CONFLICT DO NOTHING""",
            [(r[0], r[1], r[3], r[4], r[5]) for r in rows],
        )
        cur.executemany(
            "UPDATE comments SET parent_comment_id = %s WHERE comment_id = %s",
            [(r[2], r[0]) for r in rows if r[2] in loaded_ids],
        )
    conn.commit()
    log.info("Loaded %d comments.", len(rows))
    for reason, count in skipped.items():
        log.warning("Skipped %d comments: %s", count, reason)


def load_polls(
    conn: psycopg.Connection,
    story_hits: list[dict],
    poll_opt_hits: list[dict],
) -> None:
    poll_rows = []
    poll_ids: set[int] = set()

    for hit in story_hits:
        if "poll" not in hit.get("_tags", []):
            continue

        poll_id = int(hit["objectID"])
        if poll_id in poll_ids:
            continue

        poll_ids.add(poll_id)
        poll_rows.append((poll_id,))

    option_rows = []
    seen_opts: set[int] = set()
    skipped = Counter()

    for hit in poll_opt_hits:
        opt_id = hit.get("objectID")
        poll_id = hit.get("story_id") or hit.get("parent_id")
        if opt_id is None or poll_id is None:
            skipped["missing id"] += 1
            continue

        opt_id = int(opt_id)
        poll_id = int(poll_id)

        if opt_id in seen_opts:
            skipped["duplicate id"] += 1
            continue
        if poll_id not in poll_ids:
            skipped["poll not loaded"] += 1
            continue

        seen_opts.add(opt_id)
        option_rows.append(
            (
                opt_id,
                poll_id,
                hit.get("comment_text") or hit.get("title"),
                hit.get("points") or 0,
            )
        )

    with conn.cursor() as cur:
        cur.executemany(
            """
            INSERT INTO polls (poll_id)
            VALUES (%s)
            ON CONFLICT (poll_id) DO NOTHING
            """,
            poll_rows,
        )
        cur.executemany(
            """
            INSERT INTO poll_options
                (poll_option_id, poll_id, option_text, points)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (poll_option_id) DO NOTHING
            """,
            option_rows,
        )

    conn.commit()
    for reason, count in skipped.items():
        log.warning("Skipped %d poll options: %s", count, reason)
    log.info(
        "Loaded %d polls, %d poll_options.",
        len(poll_rows),
        len(option_rows),
    )

def print_row_counts(conn: psycopg.Connection) -> None:
    tables = [
        "users",
        "domains",
        "links",
        "stories",
        "story_tags",
        "comments",
        "polls",
        "poll_options",
    ]
    with conn.cursor() as cur:
        log.info("Final row counts:")
        for table in tables:
            cur.execute(f"SELECT count(*) FROM {table}")
            log.info("  %-14s %d", table, cur.fetchone()[0])


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--demo",
        action="store_true",
        help="Fetch a small sample instead of the full 2024 slice",
    )
    args = parser.parse_args()

    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        log.error("DATABASE_URL is not set. Set it in .env first.")
        sys.exit(1)

    # Recreate the database before loading, including when using cached data.
    with psycopg.connect(database_url, client_encoding="UTF8") as conn:
        run_schema(conn)

    story_hits = read_raw("stories", args.demo)
    if story_hits is None:
        log.info("Fetching 2024 stories and polls ...")
        fetch = fetch_all if args.demo else fetch_all_windowed
        kwargs = {"demo": True} if args.demo else {}
        story_hits = fetch("story", SLICE_START, SLICE_END, **kwargs)
        poll_hits = fetch("poll", SLICE_START, SLICE_END, **kwargs)
        story_hits += poll_hits
        dump_raw("stories", story_hits, args.demo)

    poll_hits = [
        hit for hit in story_hits
        if "poll" in hit.get("_tags", [])
    ]
    write_sample("stories", story_hits)
    write_sample("polls", poll_hits)
        

    comment_hits = read_raw("comments", args.demo)
    if comment_hits is None:
        log.info("Fetching 2024 comments ...")
        fetch = fetch_all if args.demo else fetch_all_windowed
        kwargs = {"demo": True} if args.demo else {}
        comment_hits = fetch("comment", SLICE_START, SLICE_END, **kwargs)
        dump_raw("comments", comment_hits, args.demo)
    write_sample("comments", comment_hits)

    poll_opt_hits = read_raw("poll_options", args.demo)
    if poll_opt_hits is None:
        poll_story_ids = sorted(
            {
                int(hit["objectID"])
                for hit in story_hits
                if "poll" in hit.get("_tags", [])
            }
        )
        if args.demo:
            poll_story_ids = poll_story_ids[:5]

        log.info("Fetching poll options for %d polls ...", len(poll_story_ids))
        poll_opt_hits = fetch_poll_options(poll_story_ids)
        dump_raw("poll_options", poll_opt_hits, args.demo)
    write_sample("poll_options", poll_opt_hits)

    with psycopg.connect(database_url, client_encoding="UTF8") as conn:
        load_users(conn, story_hits, comment_hits)
        domain_id_by_name = load_domains(conn, story_hits)
        load_stories(conn, story_hits, domain_id_by_name)
        story_ids = {
            int(hit["story_id"] if hit.get("story_id") else hit["objectID"])
            for hit in story_hits
        }
        load_comments(conn, comment_hits, story_ids)
        load_polls(conn, story_hits, poll_opt_hits)
        print_row_counts(conn)

    log.info("Done.")


if __name__ == "__main__":
    main()