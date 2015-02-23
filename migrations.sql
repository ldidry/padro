-- 1 up
CREATE TABLE IF NOT EXISTS pads (
    name text PRIMARY KEY,
    text text,
    html text,
    revisions integer,
    last_edition timestamp,
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
-- 1 down
DROP TABLE pad_has_authors;
DROP TABLE authors;
DROP TABLE pads;
