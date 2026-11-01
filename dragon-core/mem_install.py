"""Idempotent installer: consistent SQLite backup before opening an old schema."""
import os
import sqlite3
from dragon_mem import backup, connect, db_path, MIGRATIONS
os.umask(0o077)
p=db_path()
if p.exists():
    with sqlite3.connect(f'file:{p}?mode=ro', uri=True) as db:
        version=db.execute('PRAGMA user_version').fetchone()[0]
    if version < max(MIGRATIONS): backup(p)
with connect() as db:
    pass
