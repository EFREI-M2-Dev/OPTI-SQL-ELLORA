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
    PRIMARY KEY (title_id, ordering)
);

CREATE TABLE title_episode
(
    tconst         VARCHAR(12) PRIMARY KEY,
    parent_tconst  VARCHAR(12),
    season_number  INTEGER,
    episode_number INTEGER
);

CREATE TABLE title_principals
(
    tconst     VARCHAR(12),
    ordering   INTEGER,
    nconst     VARCHAR(12),
    category   VARCHAR(50),
    job        VARCHAR(100),
    characters TEXT,
    PRIMARY KEY (tconst, ordering)
);

CREATE TABLE title_ratings
(
    tconst         VARCHAR(12) PRIMARY KEY,
    average_rating NUMERIC(3, 1),
    num_votes      INTEGER
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

CREATE TABLE title_crew (
                            tconst VARCHAR(12) PRIMARY KEY,
                            directors TEXT,  -- Chaîne CSV : ex. "nm0005690,nm0001234"
                            writers   TEXT  -- Chaîne CSV : ex. "nm0001234"
);


ALTER TABLE title_akas
    ALTER COLUMN types TYPE TEXT,
    ALTER COLUMN attributes TYPE TEXT;

ALTER TABLE name_basics
    ALTER COLUMN primary_profession TYPE TEXT;

ALTER TABLE name_basics
    ALTER COLUMN known_for_titles TYPE TEXT;

ALTER TABLE title_crew
    ALTER COLUMN directors TYPE TEXT;

ALTER TABLE title_crew
    ALTER COLUMN writers TYPE TEXT;

COPY name_basics FROM PROGRAM 'zcat /import/name.basics.tsv.gz | head -200'
    WITH (FORMAT csv, DELIMITER E'\t', HEADER, NULL '\N', QUOTE E'\001');

COPY title_basics FROM PROGRAM 'zcat /import/title.basics.tsv.gz | head -200'
    WITH (FORMAT csv, DELIMITER E'\t', HEADER, NULL '\N', QUOTE E'\001');

COPY title_akas FROM PROGRAM 'zcat /import/title.akas.tsv.gz | head -200'
    WITH (FORMAT csv, DELIMITER E'\t', HEADER, NULL '\N', QUOTE E'\001');

COPY title_crew FROM PROGRAM 'zcat /import/title.crew.tsv.gz | head -200'
    WITH (FORMAT csv, DELIMITER E'\t', HEADER, NULL '\N', QUOTE E'\001');

COPY title_episode FROM PROGRAM 'zcat /import/title.episode.tsv.gz | head -200'
    WITH (FORMAT csv, DELIMITER E'\t', HEADER, NULL '\N', QUOTE E'\001');

COPY title_principals FROM PROGRAM 'zcat /import/title.principals.tsv.gz | head -200'
    WITH (FORMAT csv, DELIMITER E'\t', HEADER, NULL '\N', QUOTE E'\001');

COPY title_ratings FROM PROGRAM 'zcat /import/title.ratings.tsv.gz | head -200'
    WITH (FORMAT csv, DELIMITER E'\t', HEADER, NULL '\N', QUOTE E'\001');