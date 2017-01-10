-- 1 up
CREATE TABLE IF NOT EXISTS pads (
    name text PRIMARY KEY,
    text text,
    html text,
    revisions integer,
    last_edition timestamp,
    authors_nb integer,
    fetched_at timestamp NOT NULL DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS authors (
    ep_id text PRIMARY KEY,
    name varchar(255) NOT NULL
);
CREATE TABLE IF NOT EXISTS pad_has_authors (
    pad_id text REFERENCES pads(name),
    author_id text REFERENCES authors(ep_id)
);
CREATE TABLE IF NOT EXISTS revisions (
    pad_id text REFERENCES pads(name),
    rev integer NOT NULL,
    text text,
    html text,
    UNIQUE(pad_id, rev)
);
-- 1 down
DROP TABLE revisions;
DROP TABLE pad_has_authors;
DROP TABLE authors;
DROP TABLE pads;
