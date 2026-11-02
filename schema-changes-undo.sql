-- schema-changes-undo.sql
-- Drops everything schema-changes.sql created.
-- Run: psql "$DATABASE_URL" -f schema-changes-undo.sql

DROP INDEX IF EXISTS idx_comments_story_author;
DROP INDEX IF EXISTS idx_comments_author_story_incl;
DROP INDEX IF EXISTS idx_comments_created_at;
DROP INDEX IF EXISTS idx_stories_title_fts;
