"""Herdr 0.9.5/protocol 22 adapter. Event driven; never stores pane output.

Read docs/HERDR-API.md for verified protocol and honest capability limits.
Only prompt/start accept text from stdin; there is no permission-answer command.
"""
from contextlib import closing
import json
import os
from pathlib import Path
import re
import select
import signal
import socket
import sqlite3
import subprocess
import sys
import threading
import time
from taller_common import Parser, ToolError, emit, error, safe, git_branch
from secret_filter import redact
from dragon_mem import db_path

MAX_FRAME=16*1024*1024
STOP=threading.Event()


def socket_path():
    config=Path(os.environ.get('XDG_CONFIG_HOME') or Path.home()/'.config')
    return os.environ.get('HERDR_SOCKET_PATH') or str(config/'herdr/herdr.sock')


def channel():
    s=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM);s.settimeout(3)
    try:s.connect(socket_path());return s
    except BaseException:s.close();raise


def send(s,method,params):
    s.sendall((json.dumps(dict(id='dragon',method=method,params=params),ensure_ascii=False)+'\n').encode())


def response(stream):
    line=stream.readline(MAX_FRAME+1)
    if not line or len(line)>MAX_FRAME:raise OSError('Respuesta de herdr incompleta o demasiado grande.')
    r=json.loads(line)
    if 'error' in r:
        e=r['error'];raise ToolError(e.get('code','herdr_error'),'herdr: '+e.get('message','Operación rechazada.'))
    return r


def rpc(method,params=None,timeout=3):
    with channel() as s:
        s.settimeout(timeout)
        send(s,method,params or {})
        with s.makefile('rb') as f:return response(f).get('result',{})


def memory():
    path=db_path()
    if not path.is_file():return [],[]
    try:
        with closing(sqlite3.connect(f'file:{path}?mode=ro',uri=True,timeout=.2)) as db:
            db.row_factory=sqlite3.Row
            return ([dict(r) for r in db.execute('SELECT * FROM project WHERE archived=0')],
                    [dict(r) for r in db.execute('SELECT * FROM card WHERE worktree IS NOT NULL')])
    except sqlite3.Error:return [],[]


def normalize(snapshot,previous=None):
    previous=previous or {};projects,cards=memory();now=int(time.time())
    spaces=[dict(id=w['workspace_id'],name=w.get('label',w['workspace_id']),state=w.get('agent_status','unknown'),
                 number=w.get('number',0),focused=w.get('focused',False)) for w in snapshot.get('workspaces',[])]
    labels={w['id']:w['name'] for w in spaces};agents=[]
    for a in snapshot.get('agents',[]):
        identifier=a['pane_id'];state=a.get('agent_status','unknown');cwd=a.get('foreground_cwd') or a.get('cwd') or ''
        old=previous.get(identifier,{})
        p=next((p for p in sorted(projects,key=lambda x:-len(x['path'])) if cwd==p['path'] or cwd.startswith(p['path']+'/')),None)
        c=next((c for c in sorted(cards,key=lambda x:-len(x['worktree'])) if cwd==c['worktree'] or cwd.startswith(c['worktree']+'/')),None)
        agents.append(dict(id=identifier,pane=identifier,kind=a.get('agent') if a.get('agent') in ('claude','codex') else 'other',
                           state=state,since=old.get('since',now) if old.get('state')==state else now,
                           space=labels.get(a.get('workspace_id'),a.get('workspace_id','')),
                           space_id=a.get('workspace_id',''),tab=a.get('tab_id',''),cwd=cwd,branch=git_branch(cwd),helper_of=None,
                           card=c['key'] if c else None,project=p['slug'] if p else None,
                           card_id=c['id'] if c else None,name=a.get('name') or a.get('agent') or 'agente',
                           note=c['title'] if c else '',focused=bool(a.get('focused')),title=a.get('terminal_title_stripped') or ''))
    return safe(dict(ok=True,source='herdr',version=snapshot.get('version',''),agents=agents,spaces=spaces))


def snapshot(previous=None):
    try:return normalize(rpc('session.snapshot')['snapshot'],previous)
    except (OSError,ValueError,KeyError,ToolError):
        return dict(ok=True,source='none',version='',agents=[],spaces=[])


def probe():
    s=snapshot();available=s['source']=='herdr'
    return dict(ok=True,version=s['version'],socket=socket_path(),features=dict(list=available,events=available,
                 focus=available,prompt=available,read=available,helpers=False))


def subscriptions(agents):
    subs=[{'type':t} for t in ('pane.created','pane.closed','pane.agent_detected','workspace.created',
                               'workspace.closed','workspace.renamed','workspace.updated')]
    subs.extend(dict(type='pane.agent_status_changed',pane_id=a['id']) for a in agents)
    return subs


def record_waits(agents):
    from dragon_mem import connect
    db=connect();now=int(time.time());blocked={a['id']:a for a in agents if a['state']=='blocked'}
    try:
        with db:
            for row in db.execute('SELECT agent_id FROM agent_wait WHERE resumed_at IS NULL').fetchall():
                if row[0] not in blocked:db.execute('UPDATE agent_wait SET resumed_at=? WHERE agent_id=? AND resumed_at IS NULL',(now,row[0]))
            for identifier,a in blocked.items():
                db.execute('INSERT OR IGNORE INTO agent_wait(agent_id,card_id,blocked_at) VALUES(?,?,?)',(identifier,a.get('card_id'),now))
    finally:db.close()


def watch(record=False):
    old={};delay=1;last_ping=time.monotonic();announced=False
    while not STOP.is_set():
        current=snapshot(old)
        if record and current['source']=='herdr':record_waits(current['agents'])
        emit(dict(t='snapshot',**current));announced=True
        old={a['id']:a for a in current['agents']}
        if current['source']=='none':
            STOP.wait(delay);delay=min(10,delay*2);continue
        delay=1
        try:
            with channel() as s:
                send(s,'events.subscribe',dict(subscriptions=subscriptions(current['agents'])))
                # Raw recv retains partial frames across idle timeouts (makefile timeouts do not).
                s.setblocking(False);buffer=b''
                # Re-read AFTER subscribing, closing the snapshot/subscription race.
                refreshed=snapshot(old)
                if refreshed['source']=='herdr':
                    if record:record_waits(refreshed['agents'])
                    for a in refreshed['agents']:
                        if old.get(a['id'])!=a:emit(dict(t='agent',op='update' if a['id'] in old else 'add',agent=a))
                    new={a['id']:a for a in refreshed['agents']}
                    for identifier in old.keys()-new.keys():emit(dict(t='agent',op='remove',id=identifier))
                    if set(old)!=set(new):old=new;continue
                    old=new
                while not STOP.is_set():
                    if time.monotonic()-last_ping>=30:
                        emit(dict(t='ping'));last_ping=time.monotonic()
                    ready,_,_=select.select([s],[],[],.5)
                    if not ready:continue
                    chunk=s.recv(65536)
                    if not chunk:raise OSError('Socket cerrado.')
                    buffer+=chunk
                    if len(buffer)>MAX_FRAME:raise OSError('Evento demasiado grande.')
                    dirty=False
                    while b'\n' in buffer:
                        line,buffer=buffer.split(b'\n',1);r=json.loads(line)
                        if 'error' in r:raise OSError('Suscripción perdida.')
                        dirty |= 'event' in r or 'events_lost' in str(r)
                    if not dirty:continue
                    next_snapshot=snapshot(old)
                    if next_snapshot['source']=='none':raise OSError('Servidor desconectado.')
                    next_agents={a['id']:a for a in next_snapshot['agents']}
                    if record and old!=next_agents:record_waits(next_snapshot['agents'])
                    if next_snapshot['spaces']!=current['spaces']:
                        emit(dict(t='snapshot',**next_snapshot));current=next_snapshot
                    else:
                        for identifier in old.keys()-next_agents.keys():emit(dict(t='agent',op='remove',id=identifier))
                        for identifier,a in next_agents.items():
                            if old.get(identifier)!=a:emit(dict(t='agent',op='update' if identifier in old else 'add',agent=a))
                    changed=set(old)!=set(next_agents);old=next_agents
                    if changed:break  # resubscribe for the new set of panes, no polling
        except (OSError,ValueError,KeyError,ToolError):
            if announced:emit(dict(t='snapshot',ok=True,source='none',version='',agents=[],spaces=[]))
            STOP.wait(delay);delay=min(10,delay*2)
        if time.monotonic()-last_ping>=30:
            emit(dict(t='ping'));last_ping=time.monotonic()


def find_agent(identifier):
    result=snapshot()
    a=next((a for a in result['agents'] if a['id']==identifier),None)
    if a is None:raise ToolError('agent_not_found','El agente ya no está disponible.','Actualiza la lista de agentes.')
    return a


def hypr(command):
    # Recover a stale terminal signature by matching this Wayland display, just as update.sh does.
    env=dict(os.environ)
    result=subprocess.run(['hyprctl',*command],capture_output=True,text=True,timeout=3,env=env)
    if result.returncode and env.get('WAYLAND_DISPLAY'):
        r=subprocess.run(['hyprctl','-j','instances'],capture_output=True,text=True,timeout=3)
        instances=json.loads(r.stdout or '[]')
        candidates=[x for x in instances if x.get('wl_socket')==os.path.basename(env['WAYLAND_DISPLAY'])]
        if len(candidates)==1:
            env['HYPRLAND_INSTANCE_SIGNATURE']=candidates[0]['instance']
            result=subprocess.run(['hyprctl',*command],capture_output=True,text=True,timeout=3,env=env)
    if result.returncode:raise ToolError('hyprland_unavailable','No se pudo conectar con Hyprland.','Comprueba la sesión gráfica.')
    return result.stdout


def client_ancestors():
    # Herdr can be launched inside an ordinary terminal, rather than our dedicated class.
    # Resolve real local process ancestry without reading command-line arguments or terminal output.
    parents={};clients=[]
    for path in Path('/proc').iterdir():
        if not path.name.isdecimal():continue
        try:
            if path.stat().st_uid != os.getuid():continue
            fields=(path/'stat').read_text().rsplit(') ',1)[1].split()
            pid=int(path.name);parents[pid]=int(fields[1])
            if (path/'comm').read_text().strip()=='herdr' and parents[pid]!=1:clients.append(pid)
        except (OSError,ValueError,IndexError):continue
    found=set()
    for pid in clients:
        for _ in range(64):
            pid=parents.get(pid,1)
            if pid<=1:break
            found.add(pid)
    return found


def focus(identifier):
    a=find_agent(identifier)
    clients=json.loads(hypr(['clients','-j']))
    ancestors=client_ancestors()
    candidates=[c for c in clients if c.get('class','').lower() in ('org.dragonisland.herdr','herdr','dev.herdr.app','com.herdr.app')
                or (c.get('pid') in ancestors and c.get('title','').casefold().startswith('herdr'))]
    if len(candidates)>1:
        candidates=[c for c in candidates if a['space'] and a['space'].casefold() in c.get('title','').casefold()]
    if len(candidates)!=1:raise ToolError('client_not_found','No se encontró una ventana inequívoca de herdr para ese espacio.','Abre el cliente de herdr y vuelve a intentarlo.')
    address=candidates[0].get('address','')
    if not re.fullmatch(r'0x[0-9a-fA-F]+',address):raise ToolError('invalid_window','La dirección de la ventana no es válida.')
    rpc('agent.focus',dict(target=identifier))
    output=hypr(['dispatch','hl.dsp.focus({ window = '+json.dumps('address:'+address)+' })'])
    if not output.strip().startswith('ok'):raise ToolError('focus_failed','Hyprland no pudo enfocar la ventana.')
    return dict(ok=True,id=identifier)


def read(identifier,lines):
    if lines<1 or lines>200:raise ToolError('invalid_lines','El número de líneas debe estar entre 1 y 200.')
    try:
        r=rpc('agent.read',dict(target=identifier,source='recent',lines=200,strip_ansi=True))
    except ToolError as e:
        if e.code != 'agent_not_idle':raise
        # Active alternate-screen agents cannot scroll their history; read the viewport instead.
        r=rpc('agent.read',dict(target=identifier,source='visible',lines=200,strip_ansi=True))
    text=r.get('read',{}).get('text','')
    text=redact(text)[0]  # BEFORE line/character truncation
    return dict(ok=True,id=identifier,text='\n'.join(text.splitlines()[-lines:])[-8192:])


def validate_prompt(text):
    if len(text.encode())>65536:raise ToolError('prompt_too_large','El prompt supera los 64 KB.')
    text=redact(text)[0]
    if not text.strip():raise ToolError('empty_prompt','El prompt está vacío.')
    if len(text.encode())>65536:raise ToolError('prompt_too_large','El prompt supera los 64 KB.')
    return text


def prompt(identifier,text,no_enter=False):
    a=find_agent(identifier)
    if a['state']=='blocked':raise ToolError('agent_blocked','El agente espera una decisión en su panel.','Usa Ir al panel para responder allí.')
    text=validate_prompt(text)
    rpc('pane.send_text' if no_enter else 'agent.prompt',dict(pane_id=identifier,text=text) if no_enter else dict(target=identifier,text=text),timeout=10)
    return dict(ok=True,id=identifier)


def start(cwd,kind,name,text=None):
    path=Path(cwd).expanduser().resolve()
    if not path.is_dir():raise ToolError('invalid_path','La carpeta de trabajo no existe.')
    if text is not None:text=validate_prompt(text)
    created=rpc('workspace.create',dict(cwd=str(path),label=safe(name),focus=False))
    pane=created['root_pane']['pane_id']
    started=rpc('agent.start',dict(pane_id=pane,kind=kind,name=safe(name),args=[],timeout_ms=30000),timeout=35)
    identifier=started.get('agent',{}).get('pane_id',pane)
    if text is not None:prompt(identifier,text)
    return dict(ok=True,id=identifier,space=created['workspace']['workspace_id'],tab=created['tab']['tab_id'],pane=pane)


def main(argv=None):
    os.umask(0o077)
    p=Parser(description=__doc__);sub=p.add_subparsers(dest='command',required=True)
    for n in ('probe','snapshot'):sub.add_parser(n)
    w=sub.add_parser('watch');w.add_argument('--record',action='store_true')
    for n in ('focus','read','prompt'):
        c=sub.add_parser(n);c.add_argument('id')
        if n=='read':c.add_argument('--lines',type=int,default=8)
        if n=='prompt':c.add_argument('--stdin',action='store_true',required=True);c.add_argument('--no-enter',action='store_true')
    c=sub.add_parser('start');c.add_argument('--cwd',required=True);c.add_argument('--kind',choices=('claude','codex'),required=True);c.add_argument('--name',required=True);c.add_argument('--prompt-stdin',action='store_true')
    args=p.parse_args([v for v in (sys.argv[1:] if argv is None else argv) if v!='--json'])
    try:
        if args.command=='probe':r=probe()
        elif args.command=='snapshot':r=snapshot()
        elif args.command=='watch':
            signal.signal(signal.SIGTERM,lambda *_:STOP.set());signal.signal(signal.SIGINT,lambda *_:STOP.set())
            watch(args.record);return 0
        elif args.command=='focus':r=focus(args.id)
        elif args.command=='read':r=read(args.id,args.lines)
        elif args.command=='prompt':r=prompt(args.id,sys.stdin.read(65537),args.no_enter)
        else:r=start(args.cwd,args.kind,args.name,sys.stdin.read(65537) if args.prompt_stdin else None)
        emit(r);return 0
    except ToolError as e:emit(error(e.code,e.message,e.hint));return 1
    except (OSError,ValueError,KeyError,sqlite3.Error,subprocess.SubprocessError) as e:
        emit(error('herdr_unavailable','No se pudo completar la operación con herdr: '+str(e),'Comprueba que herdr está en marcha.'));return 1
    except BrokenPipeError:return 0


if __name__=='__main__':raise SystemExit(main())
