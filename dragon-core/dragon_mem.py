"""Project-local SQLite memory. Standard library, transactional writes, no daemon.

Schema versions live in MIGRATIONS. FTS is maintained by SQL triggers in the same
transaction as its source rows. All CLI text is redacted before persistence.
"""
from contextlib import closing
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import sqlite3
import statistics
import subprocess
import sys
import tempfile
import time
from taller_common import Parser, ToolError, emit, error, safe, git_branch

COLS = ('backlog', 'ready', 'doing', 'review', 'done')
KINDS = ('feat', 'fix', 'chore', 'docs')
MIGRATIONS = {1: 'mem_schema.sql'}


def db_path():
    return Path(os.environ.get('XDG_DATA_HOME') or Path.home() / '.local/share') / 'dragon-island/dragon.db'


def backup(path=None):
    path = path or db_path()
    if not path.exists():
        raise ToolError('no_database', 'La base todavía no existe.', 'Ejecuta dragon-mem init.')
    folder = path.parent / 'backups'
    folder.mkdir(mode=0o700, parents=True, exist_ok=True)
    dest = folder / (time.strftime('dragon-%Y%m%d-%H%M%S-') + str(time.time_ns()) + '.db')
    fd = os.open(dest, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    os.close(fd)
    try:
        with closing(sqlite3.connect(f'file:{path}?mode=ro', uri=True)) as src, closing(sqlite3.connect(dest)) as dst:
            src.backup(dst)
    except BaseException:
        dest.unlink(missing_ok=True)
        raise
    for old in sorted(folder.glob('dragon-*.db'), reverse=True)[7:]:
        old.unlink()
    return str(dest)


def connect():
    path = db_path()
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    # journal_mode changes do not reliably honor SQLite busy_timeout when two
    # processes create a new DB simultaneously. Serialize setup, not transactions.
    fd = os.open(str(path) + '.init.lock', os.O_CREAT | os.O_RDWR, 0o600)
    with os.fdopen(fd, 'a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        return _connect(path)


def _connect(path):
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    # Create privately BEFORE SQLite opens any files (including WAL and shm).
    fd = os.open(path, os.O_CREAT | os.O_RDWR, 0o600)
    os.close(fd)
    path.chmod(0o600)
    db = sqlite3.connect(path, timeout=10)
    try:
        db.row_factory = sqlite3.Row
        db.execute('PRAGMA foreign_keys=ON')
        db.execute('PRAGMA busy_timeout=10000')
        db.execute('PRAGMA journal_mode=WAL')
        version = db.execute('PRAGMA user_version').fetchone()[0]
        if version > max(MIGRATIONS):
            db.close()
            raise ToolError('newer_schema', 'La base usa un esquema más nuevo.', 'Actualiza dragon-mem.')
        if version < max(MIGRATIONS):
            # Serialise schema creation across first concurrent invocations.
            db.execute('BEGIN IMMEDIATE')
            try:
                version = db.execute('PRAGMA user_version').fetchone()[0]
                for number, filename in MIGRATIONS.items():
                    if number <= version:
                        continue
                    script = Path(__file__).with_name(filename).read_text()
                    for statement in script.split(';'):
                        # Remove SQL comments before splitting (comments can contain semicolons).
                        statement = re.sub(r'--[^\n]*', '', statement).strip()
                        if statement:
                            db.execute(statement)
                    for table, title, body in [('card', 'title', 'body'), ('note', 'title', 'body'),
                                                ('prompt_template', 'name', 'blocks')]:
                        for action in ('insert', 'update', 'delete'):
                            statements = []
                            if action != 'insert':
                                statements.append(f"DELETE FROM search_fts WHERE kind='{table}' AND ref=old.id;")
                            if action != 'delete':
                                statements.append(f"INSERT INTO search_fts(kind,ref,title,body) VALUES('{table}',new.id,new.{title},new.{body});")
                            db.execute(f'CREATE TRIGGER fts_{table}_{action} AFTER {action} ON {table} BEGIN ' + ''.join(statements) + ' END')
                    db.execute('CREATE UNIQUE INDEX one_open_wait ON agent_wait(agent_id) WHERE resumed_at IS NULL')
                    db.execute('CREATE INDEX card_project_col ON card(project_id,col)')
                    db.execute(f'PRAGMA user_version={number}')
                db.commit()
            except BaseException:
                db.rollback(); db.close(); raise
        return db
    except BaseException:
        db.close()
        raise


def rows(db, sql, args=()):
    return [dict(row) for row in db.execute(sql, args)]


def project(db, slug):
    row = db.execute('SELECT * FROM project WHERE slug=?', (slug,)).fetchone()
    if row is None:
        raise ToolError('project_not_found', 'No se encontró el proyecto.', 'Consulta project list.')
    result=dict(row)
    result['branch']=git_branch(result['path'])
    return result


def card(db, key, slug=None):
    query = 'SELECT card.* FROM card JOIN project ON project.id=card.project_id WHERE card.key=?'
    values = [key]
    if slug:
        query += ' AND project.slug=?'; values.append(slug)
    found = rows(db, query, values)
    if not found:
        raise ToolError('card_not_found', 'No se encontró la tarjeta.', 'Consulta card list.')
    if len(found) != 1:
        raise ToolError('ambiguous_card', 'La clave pertenece a varios proyectos.', 'Añade --project <slug>.')
    return found[0]


def update(db, table, identifier, values):
    if values:
        db.execute(f'UPDATE {table} SET ' + ','.join(k+'=?' for k in values) + ' WHERE id=?',
                   [*values.values(), identifier])


def event(db, identifier, kind, data=None):
    db.execute('INSERT INTO card_event(card_id,ts,kind,data) VALUES(?,?,?,?)',
               (identifier, int(time.time()), kind, json.dumps(safe(data or {}), ensure_ascii=False)))


def exclude_local(path):
    result = subprocess.run(['git', '-C', str(path), 'rev-parse', '--path-format=absolute', '--git-path', 'info/exclude'],
                            capture_output=True, text=True, timeout=3)
    if result.returncode:
        return False
    dest = Path(result.stdout.strip())
    dest.parent.mkdir(parents=True, exist_ok=True)
    # A separate advisory lock prevents duplicate lines from concurrent project adds.
    import fcntl
    with dest.open('a+', encoding='utf-8') as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        handle.seek(0); text = handle.read()
        if '.dragon/' not in text.splitlines():
            handle.write(('\n' if text and not text.endswith('\n') else '') + '.dragon/\n')
    return True


def blob_hash(path):
    try:
        data = os.fsencode(os.readlink(path)) if path.is_symlink() else path.read_bytes()
        return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
    except OSError:
        return None


def relative_file(base, value):
    path = Path(value)
    if path.is_absolute() or '..' in path.parts:
        raise ToolError('invalid_path', 'La ruta debe ser relativa al proyecto y no contener «..».')
    return Path(base) / path


def export_context(db, p, destination=None):
    conventions = rows(db, "SELECT title,body FROM note WHERE project_id=? AND kind='convention' ORDER BY updated_at DESC", (p['id'],))
    decisions = rows(db, "SELECT title,body FROM note WHERE project_id=? AND kind='decision' ORDER BY created_at DESC,id DESC LIMIT 10", (p['id'],))
    current = rows(db, "SELECT * FROM card WHERE project_id=? AND col IN ('doing','review') ORDER BY started_at DESC,id DESC LIMIT 1", (p['id'],))
    parts = ['<!-- generado por dragon-mem; no editar -->']
    # Per-section budgets keep the current card and its criteria present in a large project.
    def clipped(text, size):
        raw = safe(text).encode('utf-8')
        return raw[:size].decode('utf-8', 'ignore') + ('…' if len(raw) > size else '')
    parts.extend(['# '+clipped(p['name'], 180), '## Convenciones'])
    parts.append(clipped('\n'.join('- '+n['title']+': '+n['body'] for n in conventions), 900))
    parts.append('## Últimas decisiones')
    parts.extend('- '+clipped(n['title']+': '+n['body'], 100) for n in decisions)
    parts.append('## Tarjeta actual')
    if current:
        c = current[0]
        parts.extend([clipped(c['key']+' · '+c['title'], 240), clipped(c['body'], 500)])
        criteria = rows(db, 'SELECT * FROM criterion WHERE card_id=? ORDER BY pos,id', (c['id'],))
        parts.append(clipped('\n'.join('- ['+('x' if n['done'] else ' ')+'] '+n['text'] for n in criteria), 1000))
    else:
        parts.append('Ninguna tarjeta en curso.')
    text = clipped(safe('\n\n'.join(parts))+'\n', 3990)
    dest = Path(destination).expanduser() if destination else Path(p['path']) / '.dragon/CONTEXT.md'
    dest.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix='.context-', dir=dest.parent)
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as handle:
            handle.write(text)
        os.replace(temporary, dest)
    finally:
        if os.path.exists(temporary): os.unlink(temporary)
    return dict(path=str(dest), bytes=len(text.encode()))


def flow(db, p, days):
    if days < 1:
        raise ToolError('invalid_days', 'El período debe ser de al menos un día.')
    now = int(time.time()); since = now-days*86400
    done = rows(db, "SELECT * FROM card WHERE project_id=? AND col='done' AND done_at BETWEEN ? AND ?", (p['id'], since, now))
    def median(values):
        valid = [value for value in values if value >= 0]
        return statistics.median(valid)/3600 if valid else None
    waits = rows(db, 'SELECT w.* FROM agent_wait w JOIN card c ON c.id=w.card_id WHERE c.project_id=? AND w.resumed_at BETWEEN ? AND ?', (p['id'], since, now))
    returned = {r['card_id'] for r in rows(db, "SELECT DISTINCT e.card_id FROM card_event e JOIN card c ON c.id=e.card_id WHERE c.project_id=? AND e.kind='returned' AND e.ts<=?", (p['id'], now))}
    return dict(lead_time_median_h=median([c['done_at']-c['created_at'] for c in done]),
                cycle_time_median_h=median([c['done_at']-c['started_at'] for c in done if c['started_at'] is not None]),
                rework_pct=100*sum(c['id'] in returned for c in done)/len(done) if done else 0,
                throughput_7d=db.execute("SELECT COUNT(*) FROM card WHERE project_id=? AND col='done' AND done_at BETWEEN ? AND ?", (p['id'], now-7*86400, now)).fetchone()[0],
                approval_wait_median_h=median([w['resumed_at']-w['blocked_at'] for w in waits]))


def dispatch(db, a):
    now = int(time.time()); group=a.group; op=getattr(a,'op',None)
    if group == 'init': return dict(path=str(db_path()), schema=max(MIGRATIONS))
    if group == 'project':
        if op == 'add':
            path = Path(a.path).expanduser().resolve()
            if not path.is_dir(): raise ToolError('invalid_path', 'La carpeta del proyecto no existe.')
            slug = a.slug or re.sub(r'[^a-z0-9-]+','-',path.name.lower()).strip('-')
            if not re.fullmatch(r'[a-z0-9][a-z0-9-]{0,79}',slug): raise ToolError('invalid_slug','El identificador del proyecto no es válido.')
            prefix = a.prefix or ''.join(x[0] for x in slug.split('-')).upper()[:6]
            if not re.fullmatch('[A-Z][A-Z0-9]{0,11}', prefix): raise ToolError('invalid_prefix','El prefijo debe usar letras mayúsculas y números.')
            db.execute('INSERT INTO project(slug,name,path,key_prefix,test_cmd,compose_file,created_at) VALUES(?,?,?,?,?,?,?)',
                       (slug,safe(a.name or path.name),str(path),prefix,safe(a.test_cmd),a.compose,now))
            exclude_local(path)
            return dict(project=project(db,slug))
        if op == 'list':
            projects=rows(db,'SELECT * FROM project WHERE archived=0 ORDER BY name')
            for p in projects:p['branch']=git_branch(p['path'])
            return dict(projects=projects)
        p=project(db,a.slug)
        if op == 'show': return dict(project=p)
        if op == 'archive': update(db,'project',p['id'],{'archived':1})
        else:
            values={k:safe(getattr(a,k)) for k in ('name','test_cmd','build_cmd','wip_limit','herdr_space','compose_file') if getattr(a,k,None) is not None}
            if 'wip_limit' in values and values['wip_limit']<1: raise ToolError('invalid_wip','El límite WIP debe ser mayor que cero.')
            update(db,'project',p['id'],values)
        return dict(project=project(db,a.slug))
    if group == 'card':
        if op == 'add':
            p=project(db,a.project);key=f"{p['key_prefix']}-{p['next_num']}"
            db.execute('UPDATE project SET next_num=next_num+1 WHERE id=?',(p['id'],))
            db.execute('INSERT INTO card(project_id,key,title,body,kind,created_at) VALUES(?,?,?,?,?,?)',
                       (p['id'],key,safe(a.title),safe(a.body),a.kind,now))
            return dict(card=card(db,key,a.project))
        if op == 'list':
            sql='SELECT card.*,project.slug AS project FROM card JOIN project ON project.id=card.project_id WHERE 1=1'; values=[]
            if a.project: sql+=' AND project.slug=?';values.append(a.project)
            if a.col: sql+=' AND col=?';values.append(a.col)
            return dict(cards=rows(db,sql+' ORDER BY pos,card.id',values))
        c=card(db,a.key,a.project)
        if op == 'show':
            return dict(card=c,criteria=rows(db,'SELECT * FROM criterion WHERE card_id=? ORDER BY pos,id',(c['id'],)), events=rows(db,'SELECT * FROM card_event WHERE card_id=? ORDER BY ts,id',(c['id'],)))
        if op == 'criteria':
            if a.action == 'add':
                db.execute('INSERT INTO criterion(card_id,text,pos) VALUES(?,?,?)',(c['id'],safe(a.text),a.pos))
            else:
                where=(a.id,c['id'])
                if not db.execute('SELECT 1 FROM criterion WHERE id=? AND card_id=?',where).fetchone(): raise ToolError('criterion_not_found','No se encontró el criterio.')
                if a.action=='toggle': db.execute('UPDATE criterion SET done=1-done WHERE id=? AND card_id=?',where)
                else: db.execute('DELETE FROM criterion WHERE id=? AND card_id=?',where)
            return dict(criteria=rows(db,'SELECT * FROM criterion WHERE card_id=? ORDER BY pos,id',(c['id'],)))
        if op == 'set':
            update(db,'card',c['id'],{k:safe(getattr(a,k)) for k in ('title','body','kind','branch','worktree','agent_ref','session_ref') if getattr(a,k,None) is not None})
        if op == 'move' and c['col'] != a.to:
            p=dict(db.execute('SELECT * FROM project WHERE id=?',(c['project_id'],)).fetchone())
            if a.to=='doing' and not a.force:
                count=db.execute("SELECT COUNT(*) FROM card WHERE project_id=? AND col='doing'",(p['id'],)).fetchone()[0]
                if count >= p['wip_limit']: raise ToolError('wip_limit_reached','El proyecto alcanzó su límite de trabajo en curso.','Confirma el movimiento con --force o termina otra tarjeta.')
            changes={'col':a.to,'done_at': now if a.to=='done' else None}
            if a.to=='doing' and c['started_at'] is None: changes['started_at']=now;event(db,c['id'],'started')
            if a.to=='review': changes['review_at']=now
            if c['col']=='review' and a.to=='doing': event(db,c['id'],'returned')
            update(db,'card',c['id'],changes);event(db,c['id'],'moved',{'from':c['col'],'to':a.to})
        return dict(card=card(db,a.key,a.project))
    if group in ('note','template'):
        table='note' if group=='note' else 'prompt_template';label='notes' if group=='note' else 'templates'
        pid=project(db,a.project)['id'] if a.project else None
        if op=='list':
            query=f'SELECT * FROM {table}';values=()
            if pid is not None: query+=' WHERE project_id=? OR project_id IS NULL';values=(pid,)
            return {label:rows(db,query+' ORDER BY id',values)}
        if group=='note' and op=='add':
            cursor=db.execute('INSERT INTO note(project_id,kind,title,body,created_at,updated_at) VALUES(?,?,?,?,?,?)', (pid,a.kind,safe(a.title),safe(a.body),now,now));return dict(id=cursor.lastrowid)
        if group=='template' and op=='save':
            blocks=json.dumps(safe(json.loads(a.blocks)),ensure_ascii=False)
            old=db.execute('SELECT id FROM prompt_template WHERE project_id IS ? AND name=?',(pid,safe(a.name))).fetchone()
            if old: update(db,table,old['id'],{'blocks':blocks});return dict(id=old['id'])
            cursor=db.execute('INSERT INTO prompt_template(project_id,name,blocks,created_at) VALUES(?,?,?,?)',(pid,safe(a.name),blocks,now));return dict(id=cursor.lastrowid)
        found=db.execute(f'SELECT * FROM {table} WHERE id=?',(a.id,)).fetchone()
        if not found: raise ToolError('not_found','No se encontró la entrada.')
        if op=='show': return dict(note=dict(found))
        db.execute(f'DELETE FROM {table} WHERE id=?',(a.id,));return {}
    if group=='search':
        # Quote terms so punctuation cannot inject FTS operators or trigger syntax errors.
        query=' AND '.join('"'+s.replace('"','""')+'"' for s in a.query.split())
        if not query: return dict(results=[])
        condition='search_fts MATCH ?';params=[query]
        if a.project:
            pid=project(db,a.project)['id']
            condition += " AND ("+' OR '.join(f"(kind='{table}' AND ref IN (SELECT id FROM {table} WHERE project_id=?))" for table in ('card','note','prompt_template'))+")"
            params.extend([pid]*3)
        result=rows(db,"SELECT kind,ref,title,snippet(search_fts,3,'[',']','…',18) AS fragment FROM search_fts WHERE "+condition+" ORDER BY rank LIMIT 100",params)
        return dict(results=result)
    if group in ('seen','comment'):
        c=card(db,a.key,a.project);identifier=c['id']
        if group=='seen':
            base=c['worktree'] or db.execute('SELECT path FROM project WHERE id=?',(c['project_id'],)).fetchone()[0]
            if op=='set':
                relative_file(base,a.path)
                if not re.fullmatch(r'[a-f0-9]{40}|[a-f0-9]{64}',a.hash): raise ToolError('invalid_hash','El hash no es válido.')
                db.execute('INSERT OR REPLACE INTO review_seen VALUES(?,?,?,?)',(identifier,a.path,a.hash,now))
            result=rows(db,'SELECT * FROM review_seen WHERE card_id=?',(identifier,))
            for r in result:
                p=relative_file(base,r['path']);current=blob_hash(p)
                if len(r['blob_hash'])==64:
                    try: current=hashlib.sha256(p.read_bytes()).hexdigest()
                    except OSError: current=None
                r.update(current_hash=current,seen=current==r['blob_hash'],changed=current!=r['blob_hash'])
            return dict(seen=result)
        if op=='add':
            relative_file('.',a.path)
            if a.line<1: raise ToolError('invalid_line','La línea debe ser mayor que cero.')
            db.execute('INSERT INTO review_comment(card_id,path,line,text,created_at) VALUES(?,?,?,?,?)',(identifier,a.path,a.line,safe(a.text),now))
        if op=='clear': db.execute('DELETE FROM review_comment WHERE card_id=?',(identifier,))
        if op=='mark-sent': db.execute('UPDATE review_comment SET sent=1 WHERE card_id=?',(identifier,))
        return dict(comments=rows(db,'SELECT * FROM review_comment WHERE card_id=? ORDER BY path,line,id',(identifier,)))
    if group=='wait':
        cid=card(db,a.card,a.project)['id'] if a.card else None
        if op=='start': db.execute('INSERT OR IGNORE INTO agent_wait(agent_id,card_id,blocked_at) VALUES(?,?,?)',(a.agent_id,cid,now))
        else: db.execute('UPDATE agent_wait SET resumed_at=? WHERE agent_id=? AND resumed_at IS NULL',(now,a.agent_id))
        return {}
    if group=='stats': return flow(db,project(db,a.project),a.days)
    if group=='export': return export_context(db,project(db,a.project),a.out)
    if group=='system':
        if op=='add': db.execute('INSERT INTO system_change(ts,key,old,new,source) VALUES(?,?,?,?,?)',(now,safe(a.key),safe(a.old),safe(a.new),safe(a.source)))
        return dict(changes=rows(db,'SELECT * FROM system_change ORDER BY ts DESC,id DESC LIMIT 100'))
    raise ToolError('invalid_usage','Comando desconocido.')


def parser():
    root=Parser(description=__doc__);groups=root.add_subparsers(dest='group',required=True)
    for name in ('init','path','backup'): groups.add_parser(name)
    def commands(name,ops):
        g=groups.add_parser(name);sub=g.add_subparsers(dest='op',required=True)
        return {op:sub.add_parser(op) for op in ops.split()}
    def option(p,name,**kw): p.add_argument('--'+name,**kw)
    def scope(p): option(p,'project')
    def key(p): p.add_argument('key');scope(p)
    ps=commands('project','add list show set archive')
    p=ps['add'];option(p,'path',required=True)
    for n in ('slug','name','prefix','test-cmd','compose'): option(p,n)
    for op in ('show','set','archive'): ps[op].add_argument('slug')
    for n in ('name','test-cmd','build-cmd','herdr-space','compose-file'): option(ps['set'],n)
    option(ps['set'],'wip-limit',type=int)
    cs=commands('card','add list show set move criteria')
    p=cs['add'];option(p,'project',required=True);option(p,'title',required=True);option(p,'body',default='');option(p,'kind',choices=KINDS,default='feat')
    scope(cs['list']);option(cs['list'],'col',choices=COLS)
    for op in ('show','set','move'): key(cs[op])
    for n in ('title','body','branch','worktree','agent-ref','session-ref'): option(cs['set'],n)
    option(cs['set'],'kind',choices=KINDS)
    option(cs['move'],'to',required=True,choices=COLS);option(cs['move'],'force',action='store_true')
    sub=cs['criteria'].add_subparsers(dest='action',required=True)
    for op in ('add','toggle','rm'):
        p=sub.add_parser(op);key(p)
        if op=='add':option(p,'text',required=True);option(p,'pos',type=int,default=0)
        else:p.add_argument('id',type=int)
    ns=commands('note','add list show rm')
    for p in ns.values():scope(p)
    for op in ('show','rm'):ns[op].add_argument('id',type=int)
    for n in ('title','body'):option(ns['add'],n,required=True)
    option(ns['add'],'kind',choices=('note','decision','convention'),default='note')
    ts=commands('template','list save rm')
    for p in ts.values():scope(p)
    for n in ('name','blocks'):option(ts['save'],n,required=True)
    ts['rm'].add_argument('id',type=int)
    p=groups.add_parser('search');p.add_argument('query');scope(p)
    ss=commands('seen','set list')
    for p in ss.values():key(p)
    for n in ('path','hash'):option(ss['set'],n,required=True)
    co=commands('comment','add list clear mark-sent')
    for p in co.values():key(p)
    for n in ('path','text'):option(co['add'],n,required=True)
    option(co['add'],'line',type=int,required=True)
    ws=commands('wait','start end')
    for p in ws.values():
        p.add_argument('agent_id');option(p,'card');scope(p)
    st=commands('stats','flow');option(st['flow'],'project',required=True);option(st['flow'],'days',type=int,default=30)
    p=groups.add_parser('export');option(p,'project',required=True);option(p,'out')
    sy=groups.add_parser('system');sy.add_argument('log',choices=['log']);sub=sy.add_subparsers(dest='op',required=True)
    p=sub.add_parser('add')
    for n in ('key','old','new','source'):option(p,n,required=True)
    sub.add_parser('list')
    return root


def main(argv=None):
    os.umask(0o077)
    args=parser().parse_args([v for v in (sys.argv[1:] if argv is None else argv) if v!='--json'])
    db=None
    try:
        if args.group=='path': emit(dict(ok=True,path=str(db_path())));return 0
        if args.group=='backup': emit(dict(ok=True,path=backup()));return 0
        db=connect()
        db.execute('BEGIN IMMEDIATE')
        result=dispatch(db,args)
        db.commit()
        emit(dict(ok=True,**result));return 0
    except ToolError as e:
        emit(error(e.code,e.message,e.hint));return 1
    except sqlite3.IntegrityError:
        emit(error('conflict','La entrada ya existe o incumple una restricción.','Comprueba las claves y los valores permitidos.'));return 1
    except (sqlite3.Error,OSError,ValueError,subprocess.SubprocessError) as e:
        emit(error('storage_error','No se pudo completar la operación: '+str(e)));return 1
    finally:
        if db is not None: db.close()


if __name__=='__main__': raise SystemExit(main())
