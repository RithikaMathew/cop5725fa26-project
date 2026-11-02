-- schema-changes.sql
-- Project 3 tuning: every object here is reversed by schema-changes-undo.sql.
-- Run: psql "$DATABASE_URL" -f schema-changes.sql   (safe to run twice)
-- Experiments that did not help are described in tuning.md, not kept here.

-- Speeds up b01-lookup-comments-by-story and b08-join-stories-comments.
-- comments.story_id is a foreign key, and PostgreSQL does not index those
-- automatically. Adding author lets b08 read commenters from the index alone.
CREATE INDEX IF NOT EXISTS idx_comments_story_author
  ON comments (story_id, author);

-- Speeds up b07-agg-comments-by-author, b02-lookup-comments-by-author and
-- b09-join-comments-stories-by-user. Covering index: rows come out already
-- grouped by (author, story_id), so b07 skips its slow text sort, and the
-- INCLUDE column lets the created_at filter run on an index-only scan.
CREATE INDEX IF NOT EXISTS idx_comments_author_story_incl
  ON comments (author, story_id) INCLUDE (created_at);

-- Speeds up b04-range-comments-by-hour (one-day range on created_at).
-- A B-tree, not BRIN: comments are not stored in time order (tuning.md).
CREATE INDEX IF NOT EXISTS idx_comments_created_at
  ON comments (created_at);

-- Speeds up b06-agg-stories-by-domain and b08-join-stories-comments.
-- GIN expression index; the expression must match the queries exactly.
CREATE INDEX IF NOT EXISTS idx_stories_title_fts
  ON stories USING GIN (to_tsvector('english', title));

ANALYZE;
