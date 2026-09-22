-- Peer reconstruction of your ER diagram. Reviewer identity withheld.

DROP TABLE IF EXISTS POLL_OPTIONS;
DROP TABLE IF EXISTS POLLS;
DROP TABLE IF EXISTS STORY_TAGS;
DROP TABLE IF EXISTS COMMENTS;
DROP TABLE IF EXISTS STORIES;
DROP TABLE IF EXISTS DOMAINS;
DROP TABLE IF EXISTS USERS; 

CREATE TABLE IF NOT EXISTS USERS (
    username text PRIMARY KEY,
    first_seen_at timestamp
);

CREATE TABLE IF NOT EXISTS DOMAINS (
    domain_id int PRIMARY KEY,
    domain_name text
);

CREATE TABLE IF NOT EXISTS STORIES (
    story_id bigint PRIMARY KEY,
    author text,
    domain_id int,
    title text,
    url text,
    story_text text,
    points int,
    num_comments int,
    is_ask_hn boolean,
    is_show_hn boolean,
    is_poll boolean,
    created_at timestamp,
    updated_at timestamp,
    FOREIGN KEY (domain_id) REFERENCES DOMAINS(domain_id),
    FOREIGN KEY (author) REFERENCES USERS(username)
);

CREATE TABLE IF NOT EXISTS COMMENTS (
    comment_id bigint PRIMARY KEY,
    story_id bigint NOT NULL,
    parent_comment_id bigint,
    author text,
    comment_text text,
    created_at timestamp,
    FOREIGN KEY (story_id) REFERENCES STORIES(story_id),
    FOREIGN KEY (parent_comment_id) REFERENCES COMMENTS(comment_id),
    FOREIGN KEY (author) REFERENCES USERS(username)
);

CREATE TABLE IF NOT EXISTS STORY_TAGS (
    story_id bigint,
    tag text,
    PRIMARY KEY (story_id, tag),
    FOREIGN KEY (story_id) REFERENCES STORIES(story_id)
);

CREATE TABLE IF NOT EXISTS POLLS (
    poll_id bigint PRIMARY KEY,
    created_at timestamp,
    FOREIGN KEY (poll_id) REFERENCES STORIES(story_id)
);

CREATE TABLE IF NOT EXISTS POLL_OPTIONS (
    poll_option_id bigint,
    poll_id bigint NOT NULL,
    option_text text,
    points int,
    PRIMARY KEY (poll_option_id),
    FOREIGN KEY (poll_id) REFERENCES POLLS(poll_id)
);