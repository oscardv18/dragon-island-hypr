"""Disposable SQLite index of activity.jsonl, always accessed under its flock.

The JSONL is authoritative. Inode/size/mtime invalidate stale indexes after a
crash, replacement or external edit. A broken index is rebuilt, never trusted.
"""
import json
import os
import sqlite3


def signature(path):
    stat = os.stat(path)
    return f'1:{stat.st_ino}:{stat.st_size}:{stat.st_mtime_ns}:{stat.st_ctime_ns}'


def connect(path):
    filename = path + '.index.sqlite'
    fd = os.open(filename, os.O_RDWR | os.O_CREAT, 0o600)
    os.close(fd)
    try:
        connection = sqlite3.connect(filename)
        connection.execute('CREATE TABLE IF NOT EXISTS metadata (signature TEXT)')
        connection.execute('CREATE TABLE IF NOT EXISTS items (id TEXT PRIMARY KEY, start REAL, end REAL, row TEXT)')
        connection.execute('CREATE INDEX IF NOT EXISTS items_start ON items(start)')
        return connection
    except sqlite3.DatabaseError:
        if 'connection' in locals():
            connection.close()
        os.unlink(filename)
        raise


def current(connection, expected):
    row = connection.execute('SELECT signature FROM metadata').fetchone()
    return row is not None and row[0] == expected


def replace(connection, items, stamp):
    with connection:
        connection.execute('DELETE FROM items')
        connection.executemany('INSERT INTO items VALUES (?, ?, ?, ?)',
                               ((item['id'], item['start'], item['end'], json.dumps(item, ensure_ascii=False,
                                 allow_nan=False, separators=(',', ':'))) for item in items.values()))
        connection.execute('DELETE FROM metadata')
        connection.execute('INSERT INTO metadata VALUES (?)', (stamp,))


def refresh(path, items, updates, previous, compacted):
    """Update a valid index incrementally, otherwise rebuild from authoritative rows."""
    connection = None
    try:
        connection = connect(path)
        stamp = signature(path)
        if compacted or not current(connection, previous):
            replace(connection, items, stamp)
        else:
            with connection:
                connection.executemany('INSERT OR REPLACE INTO items VALUES (?, ?, ?, ?)',
                                       ((item['id'], item['start'], item['end'], json.dumps(item, ensure_ascii=False,
                                         allow_nan=False, separators=(',', ':'))) for item in updates))
                connection.execute('UPDATE metadata SET signature = ?', (stamp,))
    except (OSError, sqlite3.DatabaseError):
        # Index failures must never turn a successful JSONL append into a lost event.
        pass
    finally:
        if connection is not None:
            connection.close()


def query(path, start, stop, now, timeout):
    """Return indexed matches or None if the source needs a rebuild/expiry pass."""
    connection = None
    try:
        if not os.path.exists(path + '.index.sqlite'):
            return None
        connection = connect(path)
        if not current(connection, signature(path)):
            return None
        if connection.execute('SELECT 1 FROM items WHERE end IS NULL AND start < ? LIMIT 1',
                              (now - timeout,)).fetchone():
            return None
        return [json.loads(row[0]) for row in connection.execute(
            'SELECT row FROM items WHERE start <= ? AND (end IS NULL OR end >= ?) ORDER BY start, id',
            (stop, start))]
    except (OSError, sqlite3.DatabaseError, ValueError):
        return None
    finally:
        if connection is not None:
            connection.close()
