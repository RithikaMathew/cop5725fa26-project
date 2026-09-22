-- Peer reconstruction of your ER diagram. Reviewer identity withheld.

DROP TABLE IF EXISTS writes;
DROP TABLE IF EXISTS directs;
DROP TABLE IF EXISTS principal_character;
DROP TABLE IF EXISTS principal;
DROP TABLE IF EXISTS alternate_attribute;
DROP TABLE IF EXISTS alternate_type;
DROP TABLE IF EXISTS alternate;
DROP TABLE IF EXISTS episode;
DROP TABLE IF EXISTS rating;
DROP TABLE IF EXISTS person_known_for_title;
DROP TABLE IF EXISTS person_primary_profession;
DROP TABLE IF EXISTS person;
DROP TABLE IF EXISTS title;

CREATE TABLE title (
    tconst TEXT PRIMARY KEY,
    title_type TEXT,
    primary_title TEXT,
    original_title TEXT,
    is_adult BOOLEAN,
    start_year INTEGER,
    end_year INTEGER,
    runtime_minutes INTEGER,
    genres TEXT
);

CREATE TABLE person (
    nconst TEXT PRIMARY KEY,
    primary_name TEXT,
    birth_year INTEGER,
    death_year INTEGER
);

CREATE TABLE person_primary_profession (
    nconst TEXT NOT NULL,
    profession TEXT NOT NULL,
    CONSTRAINT pk_person_profession PRIMARY KEY (nconst, profession),
    CONSTRAINT fk_person_profession_person FOREIGN KEY (nconst) REFERENCES person (nconst) ON DELETE CASCADE
);

CREATE TABLE person_known_for_title (
    nconst TEXT NOT NULL,
    tconst TEXT NOT NULL,
    CONSTRAINT pk_person_known_for PRIMARY KEY (nconst, tconst),
    CONSTRAINT fk_known_for_person FOREIGN KEY (nconst) REFERENCES person (nconst) ON DELETE CASCADE,
    CONSTRAINT fk_known_for_title FOREIGN KEY (tconst) REFERENCES title (tconst) ON DELETE CASCADE
);

CREATE TABLE rating (
    tconst TEXT PRIMARY KEY,
    average_rating NUMERIC(3,1),
    num_votes INTEGER,
    CONSTRAINT fk_rating_title FOREIGN KEY (tconst) REFERENCES title (tconst) ON DELETE CASCADE
);

CREATE TABLE episode (
    tconst TEXT PRIMARY KEY,
    parent_tconst TEXT,
    season_number INTEGER,
    episode_number INTEGER,
    CONSTRAINT fk_episode_title FOREIGN KEY (tconst) REFERENCES title (tconst) ON DELETE CASCADE,
    CONSTRAINT fk_episode_parent FOREIGN KEY (parent_tconst) REFERENCES title (tconst) ON DELETE SET NULL
);

CREATE TABLE alternate (
    tconst TEXT NOT NULL,
    ordering INTEGER NOT NULL,
    title TEXT,
    region TEXT,
    language TEXT,
    is_original_title BOOLEAN,
    CONSTRAINT pk_alternate PRIMARY KEY (tconst, ordering),
    CONSTRAINT fk_alternate_title FOREIGN KEY (tconst) REFERENCES title (tconst) ON DELETE CASCADE
);

CREATE TABLE alternate_type (
    tconst TEXT NOT NULL,
    ordering INTEGER NOT NULL,
    type TEXT NOT NULL,
    CONSTRAINT pk_alternate_type PRIMARY KEY (tconst, ordering, type),
    CONSTRAINT fk_alternate_type_alt FOREIGN KEY (tconst, ordering) REFERENCES alternate (tconst, ordering) ON DELETE CASCADE
);

CREATE TABLE alternate_attribute (
    tconst TEXT NOT NULL,
    ordering INTEGER NOT NULL,
    attribute TEXT NOT NULL,
    CONSTRAINT pk_alternate_attribute PRIMARY KEY (tconst, ordering, attribute),
    CONSTRAINT fk_alternate_attribute_alt FOREIGN KEY (tconst, ordering) REFERENCES alternate (tconst, ordering) ON DELETE CASCADE
);

CREATE TABLE principal (
    tconst TEXT NOT NULL,
    ordering INTEGER NOT NULL,
    nconst TEXT,
    category TEXT,
    job TEXT,
    CONSTRAINT pk_principal PRIMARY KEY (tconst, ordering),
    CONSTRAINT fk_principal_title FOREIGN KEY (tconst) REFERENCES title (tconst) ON DELETE CASCADE,
    CONSTRAINT fk_principal_person FOREIGN KEY (nconst) REFERENCES person (nconst) ON DELETE SET NULL
);

CREATE TABLE principal_character (
    tconst TEXT NOT NULL,
    ordering INTEGER NOT NULL,
    character_name TEXT NOT NULL,
    CONSTRAINT pk_principal_character PRIMARY KEY (tconst, ordering, character_name),
    CONSTRAINT fk_principal_character_principal FOREIGN KEY (tconst, ordering) REFERENCES principal (tconst, ordering) ON DELETE CASCADE
);

CREATE TABLE directs (
    tconst TEXT NOT NULL,
    nconst TEXT NOT NULL,
    CONSTRAINT pk_directs PRIMARY KEY (tconst, nconst),
    CONSTRAINT fk_directs_title FOREIGN KEY (tconst) REFERENCES title (tconst) ON DELETE CASCADE,
    CONSTRAINT fk_directs_person FOREIGN KEY (nconst) REFERENCES person (nconst) ON DELETE CASCADE
);

CREATE TABLE writes (
    tconst TEXT NOT NULL,
    nconst TEXT NOT NULL,
    CONSTRAINT pk_writes PRIMARY KEY (tconst, nconst),
    CONSTRAINT fk_writes_title FOREIGN KEY (tconst) REFERENCES title (tconst) ON DELETE CASCADE,
    CONSTRAINT fk_writes_person FOREIGN KEY (nconst) REFERENCES person (nconst) ON DELETE CASCADE
);