-- =============================================================================
-- Peer-review reconstruction = hand-drawn IMDb ER diagram

-- Ambiguities / assumptions made while reconstructing:
--   1. "character" is a reserved word/ built-in data type in PostgreSQL, so the table is declared as "character" with quotes
--   2. alternate_title and character tables depend on the media table, so each uses med_id + its own partial key as a composite primary key and is automatically deleted (CASCADE) when the media table is deleted.
--   3. rating is also a weak entity that is attached to media by "rated" with no cardinality label, so we can assume a 1:1 (mandatory relationship), where each media has exactly one rating, so rating's primary key is simply media's med_id rather than a separate partial key.
--   4. worked_on (media M --- N person) has a "job" attribute on the relationship itself so assumed one job per person per media.
--   5. Assuming that attribute right underneath birthYear in ER diagram is deathYear (can't read handwritten text properly).
--   6. Because total participation is not shown for character in played_by, per_id is assumed nullable and is set to NULL if the referenced person is deleted.
-- =============================================================================

DROP TABLE IF EXISTS worked_on;
DROP TABLE IF EXISTS "character";
DROP TABLE IF EXISTS rating;
DROP TABLE IF EXISTS alternate_title;
DROP TABLE IF EXISTS person;
DROP TABLE IF EXISTS media;

CREATE TABLE media (
    med_id      SERIAL PRIMARY KEY,
    title       VARCHAR(255) NOT NULL,
    year        INT,
    duration    INT,
    genre       VARCHAR(100),
    is_adult    BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE person (
    per_id      SERIAL PRIMARY KEY,
    name        VARCHAR(255) NOT NULL,
    birth_year  INT,
    death_year  INT
);

-- Weak entity
CREATE TABLE alternate_title (
    med_id      INT NOT NULL REFERENCES media(med_id) ON DELETE CASCADE,
    alt_id      INT NOT NULL,
    title       VARCHAR(255) NOT NULL,
    is_original BOOLEAN NOT NULL DEFAULT FALSE,
    region      VARCHAR(100),
    language    VARCHAR(100),
    PRIMARY KEY (med_id, alt_id)
);

-- Weak entity
CREATE TABLE rating (
    med_id      INT PRIMARY KEY REFERENCES media(med_id) ON DELETE CASCADE,
    value       DECIMAL(3, 1) NOT NULL,
    num_votes   INT NOT NULL DEFAULT 0
);

-- Weak entity
CREATE TABLE "character" (
    med_id      INT NOT NULL REFERENCES media(med_id) ON DELETE CASCADE,
    char_id     INT NOT NULL,
    name        VARCHAR(255) NOT NULL,
    per_id      INT REFERENCES person(per_id) ON DELETE SET NULL,
    PRIMARY KEY (med_id, char_id)
);

-- Junction table
CREATE TABLE worked_on (
    med_id      INT NOT NULL REFERENCES media(med_id) ON DELETE CASCADE,
    per_id      INT NOT NULL REFERENCES person(per_id) ON DELETE CASCADE,
    job         VARCHAR(100) NOT NULL,
    PRIMARY KEY (med_id, per_id)
);
