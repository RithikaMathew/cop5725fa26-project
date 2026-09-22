-- Peer reconstruction of your ER diagram. Reviewer identity withheld.

DROP TABLE IF EXISTS poll_options;
DROP TABLE IF EXISTS polls;
DROP TABLE IF EXISTS story_tags;
DROP TABLE IF EXISTS comments;
DROP TABLE IF EXISTS stories;
DROP TABLE IF EXISTS domains;
DROP TABLE IF EXISTS users;

CREATE TABLE users (
    username TEXT PRIMARY KEY,
    first_seen_at TIMESTAMP
);

CREATE TABLE domains (
    domain_id INTEGER PRIMARY KEY,
    domain_name TEXT NOT NULL
);

CREATE TABLE stories (
    story_id BIGINT PRIMARY KEY,
    author TEXT,
    domain_id INTEGER,
    title TEXT NOT NULL,
    url TEXT,
    story_text TEXT,
    points INTEGER DEFAULT 0,
    num_comments INTEGER DEFAULT 0,
    is_ask_hn BOOLEAN DEFAULT FALSE,
    is_show_hn BOOLEAN DEFAULT FALSE,
    is_poll BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP,
    CONSTRAINT fk_stories_author FOREIGN KEY (author) REFERENCES users(username) ON DELETE SET NULL,
    CONSTRAINT fk_stories_domain FOREIGN KEY (domain_id) REFERENCES domains(domain_id) ON DELETE SET NULL
);

CREATE TABLE comments (
    comment_id          BIGINT      PRIMARY KEY,
    story_id            BIGINT      NOT NULL,
    parent_comment_id   BIGINT,
    author              TEXT,
    comment_text        TEXT,
    created_at          TIMESTAMP   NOT NULL,
    CONSTRAINT fk_comments_story FOREIGN KEY (story_id) REFERENCES stories (story_id) ON DELETE CASCADE,
    CONSTRAINT fk_comments_parent FOREIGN KEY (parent_comment_id) REFERENCES comments (comment_id) ON DELETE CASCADE,
    CONSTRAINT fk_comments_author FOREIGN KEY (author) REFERENCES users (username) ON DELETE SET NULL
);

CREATE TABLE story_tags (
    story_id        BIGINT      NOT NULL,
    tag             TEXT        NOT NULL,
    CONSTRAINT pk_story_tags PRIMARY KEY (story_id, tag),
    CONSTRAINT fk_story_tags_story FOREIGN KEY (story_id) REFERENCES stories (story_id) ON DELETE CASCADE
);

CREATE TABLE polls (
    poll_id         BIGINT      PRIMARY KEY,
    created_at      TIMESTAMP   NOT NULL,
    CONSTRAINT fk_polls_story FOREIGN KEY (poll_id) REFERENCES stories (story_id) ON DELETE CASCADE
);

CREATE TABLE poll_options (
    poll_option_id  BIGINT      PRIMARY KEY,
    poll_id         BIGINT      NOT NULL,
    option_text     TEXT        NOT NULL,
    points          INTEGER     DEFAULT 0,
    CONSTRAINT fk_poll_options_poll FOREIGN KEY (poll_id) REFERENCES polls (poll_id) ON DELETE CASCADE
);