-- COP5725 Project 1 — schema for Hacker News stories from 2024
-- By: Rithika Mathew
--
-- Each table is in 3NF. domains is normalized out of stories because the
-- same domain repeats on many stories. domain_name has no functional
-- dependency on story attributes like title or points.

DROP TABLE IF EXISTS poll_options CASCADE;
DROP TABLE IF EXISTS polls CASCADE;
DROP TABLE IF EXISTS comments CASCADE;
DROP TABLE IF EXISTS story_tags CASCADE;
DROP TABLE IF EXISTS stories CASCADE;
DROP TABLE IF EXISTS domains CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- users: author entity. Role: store each person once so a username is not
-- repeated on every post, and so we can see who posts often.
CREATE TABLE users (
    username        TEXT PRIMARY KEY,
    first_seen_at   TIMESTAMPTZ NOT NULL   -- earliest created_at for this user 
);

-- domains: normalized entity for the link host. Role: store each host once
-- (ex: github.com) so the name is not copied onto every story.
CREATE TABLE domains (
    domain_id       SERIAL PRIMARY KEY,
    domain_name     TEXT NOT NULL UNIQUE
);

-- stories: main entity for this slice. Role: one row per 2024 HN submission
-- (link post, Ask HN, Show HN, or poll) and the facts about that post.
-- is NULL when the post has no url.

CREATE TABLE stories (
    story_id        BIGINT PRIMARY KEY,              
    author          TEXT REFERENCES users(username) ON DELETE SET NULL,
    domain_id       INTEGER REFERENCES domains(domain_id) ON DELETE SET NULL,  -- NULL for text-only posts
    title           TEXT NOT NULL,
    url             TEXT,
    story_text      TEXT,                             
    points          INTEGER NOT NULL CHECK (points >= 0), --he score a story gets from votes
    num_comments    INTEGER NOT NULL DEFAULT 0 CHECK (num_comments >= 0),
    is_ask_hn       BOOLEAN NOT NULL DEFAULT FALSE,
    is_show_hn      BOOLEAN NOT NULL DEFAULT FALSE, --Ask HN stories are questions posted to the community, usually without a link to another website.
    is_poll         BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL,
    updated_at      TIMESTAMPTZ NOT NULL
);

-- story_tags: side table for a multi-valued attribute. Role: hold every tag
-- on a story (ex: story, ask_hn, front_page). tag is not its own entity,
-- so this is not a junction table.
CREATE TABLE story_tags (
    story_id        BIGINT NOT NULL REFERENCES stories(story_id) ON DELETE CASCADE,
    tag             TEXT NOT NULL,
    PRIMARY KEY (story_id, tag)
);

-- comments: reply entity. Role: store the thread under a story, like
-- which comment a reply is under.
-- Self-referencing FK on parent_comment_id (ON DELETE CASCADE) is NULL for a top-level comment (direct reply to the story).
CREATE TABLE comments (
    comment_id          BIGINT PRIMARY KEY,             
    story_id            BIGINT NOT NULL REFERENCES stories(story_id) ON DELETE CASCADE,
    parent_comment_id   BIGINT REFERENCES comments(comment_id) ON DELETE CASCADE,
    author              TEXT REFERENCES users(username) ON DELETE SET NULL,
    comment_text        TEXT,
    created_at          TIMESTAMPTZ NOT NULL
);

-- polls: 1:1 subtype of stories. Role: only poll stories go here, so options
-- can FK to a poll instead of to every story. 
CREATE TABLE polls (
    poll_id         BIGINT PRIMARY KEY REFERENCES stories(story_id) ON DELETE CASCADE,
    created_at      TIMESTAMPTZ NOT NULL
);

-- poll_options: child entity of a poll (1:N). Role: one row per choice on a
-- poll, with that choice's points. 
CREATE TABLE poll_options (
    poll_option_id  BIGINT PRIMARY KEY,                
    poll_id         BIGINT NOT NULL REFERENCES polls(poll_id) ON DELETE CASCADE,
    option_text     TEXT,
    points          INTEGER NOT NULL DEFAULT 0 CHECK (points >= 0)
);
