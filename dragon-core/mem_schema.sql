CREATE TABLE project(id INTEGER PRIMARY KEY, slug TEXT UNIQUE NOT NULL, name TEXT NOT NULL, path TEXT NOT NULL,
  key_prefix TEXT NOT NULL, next_num INTEGER NOT NULL DEFAULT 1, compose_file TEXT, test_cmd TEXT, build_cmd TEXT,
  wip_limit INTEGER NOT NULL DEFAULT 3, herdr_space TEXT, created_at INTEGER NOT NULL, archived INTEGER NOT NULL DEFAULT 0);
CREATE TABLE card(id INTEGER PRIMARY KEY, project_id INTEGER NOT NULL REFERENCES project(id) ON DELETE CASCADE,
  key TEXT NOT NULL, title TEXT NOT NULL, body TEXT NOT NULL DEFAULT '',
  kind TEXT NOT NULL DEFAULT 'feat' CHECK(kind IN('feat','fix','chore','docs')),
  col TEXT NOT NULL DEFAULT 'backlog' CHECK(col IN('backlog','ready','doing','review','done')),
  pos REAL NOT NULL DEFAULT 0, branch TEXT, worktree TEXT, agent_ref TEXT, session_ref TEXT,
  created_at INTEGER NOT NULL, started_at INTEGER, review_at INTEGER, done_at INTEGER, UNIQUE(project_id,key));
CREATE TABLE criterion(id INTEGER PRIMARY KEY, card_id INTEGER NOT NULL REFERENCES card(id) ON DELETE CASCADE,
  text TEXT NOT NULL, done INTEGER NOT NULL DEFAULT 0, pos INTEGER NOT NULL DEFAULT 0);
CREATE TABLE card_event(id INTEGER PRIMARY KEY, card_id INTEGER NOT NULL REFERENCES card(id) ON DELETE CASCADE,
  ts INTEGER NOT NULL, kind TEXT NOT NULL, data TEXT NOT NULL DEFAULT '{}');   -- moved, started, returned, gate, note
CREATE TABLE note(id INTEGER PRIMARY KEY, project_id INTEGER REFERENCES project(id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK(kind IN('decision','note','convention')), title TEXT NOT NULL, body TEXT NOT NULL,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL);
CREATE TABLE prompt_template(id INTEGER PRIMARY KEY, project_id INTEGER REFERENCES project(id) ON DELETE CASCADE,
  name TEXT NOT NULL, blocks TEXT NOT NULL, created_at INTEGER NOT NULL);       -- blocks = JSON
CREATE TABLE prompt_run(id INTEGER PRIMARY KEY, project_id INTEGER, card_id INTEGER, template TEXT, target TEXT,
  tokens_est INTEGER NOT NULL, sent_at INTEGER NOT NULL, body_hash TEXT NOT NULL, body TEXT);  -- body solo si el ajuste lo permite
CREATE TABLE review_seen(card_id INTEGER NOT NULL, path TEXT NOT NULL, blob_hash TEXT NOT NULL, seen_at INTEGER NOT NULL,
  PRIMARY KEY(card_id,path));
CREATE TABLE review_comment(id INTEGER PRIMARY KEY, card_id INTEGER NOT NULL, path TEXT NOT NULL, line INTEGER NOT NULL,
  text TEXT NOT NULL, created_at INTEGER NOT NULL, sent INTEGER NOT NULL DEFAULT 0);
CREATE TABLE agent_wait(id INTEGER PRIMARY KEY, agent_id TEXT NOT NULL, card_id INTEGER, blocked_at INTEGER NOT NULL, resumed_at INTEGER);
CREATE TABLE system_change(id INTEGER PRIMARY KEY, ts INTEGER NOT NULL, key TEXT NOT NULL, old TEXT, new TEXT, source TEXT NOT NULL);
CREATE VIRTUAL TABLE search_fts USING fts5(kind, ref, title, body, tokenize='unicode61 remove_diacritics 2');
