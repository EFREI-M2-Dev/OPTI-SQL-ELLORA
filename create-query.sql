CREATE TABLE title_basics
(
    tconst          VARCHAR(12) PRIMARY KEY,
    title_type      VARCHAR(20),
    primary_title   VARCHAR(500),
    original_title  VARCHAR(500),
    is_adult        BOOLEAN,
    start_year      INTEGER,
    end_year        INTEGER,
    runtime_minutes INTEGER,
    genres          VARCHAR(100)
);

CREATE TABLE title_akas
(
    title_id          VARCHAR(12), -- tconst
    ordering          INTEGER,
    title             VARCHAR(1000),
    region            VARCHAR(10),
    language          VARCHAR(20),
    types             TEXT[],      -- array of enumerated values
    attributes        TEXT[],      -- freeform additional descriptors
    is_original_title BOOLEAN,
    PRIMARY KEY (title_id, ordering),
    FOREIGN KEY (title_id) REFERENCES title_basics (tconst)
);

CREATE TABLE title_episode
(
    tconst         VARCHAR(12) PRIMARY KEY,
    parent_tconst  VARCHAR(12),
    season_number  INTEGER,
    episode_number INTEGER,
    FOREIGN KEY (tconst) REFERENCES title_basics (tconst),
    FOREIGN KEY (parent_tconst) REFERENCES title_basics (tconst)
);

CREATE TABLE title_principals
(
    tconst     VARCHAR(12),
    ordering   INTEGER,
    nconst     VARCHAR(12),
    category   VARCHAR(50),
    job        VARCHAR(100),
    characters TEXT,
    PRIMARY KEY (tconst, ordering),
    FOREIGN KEY (tconst) REFERENCES title_basics (tconst)
);

CREATE TABLE title_ratings
(
    tconst         VARCHAR(12) PRIMARY KEY,
    average_rating NUMERIC(3, 1),
    num_votes      INTEGER,
    FOREIGN KEY (tconst) REFERENCES title_basics (tconst)
);

CREATE TABLE name_basics
(
    nconst             VARCHAR(12) PRIMARY KEY,
    primary_name       VARCHAR(255),
    birth_year         INTEGER,
    death_year         INTEGER,
    primary_profession VARCHAR(255)[], -- top-3 professions
    known_for_titles   VARCHAR(12)[]   -- array of tconsts
);