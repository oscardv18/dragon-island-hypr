"""Protocol-22 fake Unix server; event injection is explicit, never polls a file."""
import copy
import json
import socketserver
import threading


class FakeHerdr:
    def __init__(self,path,cwd):
        self.read_busy=False;self.path=path;self.calls=[];self.clients=[];self.lock=threading.Lock()
        self.data=dict(version='0.9.5',protocol=22,workspaces=[dict(workspace_id='w1',label='demo',agent_status='working')],
                       agents=[dict(pane_id='w1:p1',agent='claude',agent_status='working',cwd=cwd,workspace_id='w1',tab_id='w1:t1',focused=False)])
    def start(self):
        owner=self
        class Handler(socketserver.StreamRequestHandler):
            def handle(self):
                try:
                    r=json.loads(self.rfile.readline());m=r['method'];p=r['params']
                    with owner.lock:owner.calls.append((m,p));data=copy.deepcopy(owner.data)
                    if m=='session.snapshot':result=dict(type='session_snapshot',snapshot=data)
                    elif m=='events.subscribe':
                        self.wfile.write(b'{"id":"dragon","result":{"type":"subscription_started"}}\n');self.wfile.flush()
                        with owner.lock:owner.clients.append(self.request)
                        try:
                            while self.request.recv(1):pass
                        finally:
                            with owner.lock:
                                if self.request in owner.clients:owner.clients.remove(self.request)
                        return
                    elif m=='agent.read' and owner.read_busy and p['source']=='recent':
                        self.wfile.write(b'{"id":"dragon","error":{"code":"agent_not_idle","message":"cannot scroll"}}\n');return
                    elif m=='agent.read':result={'type':'pane_read','read':{'text':'normal\nAPI_TOKEN=neverexpose\nBearer private_value\nfin'}}
                    elif m=='workspace.create':result={'root_pane':{'pane_id':'w2:p1'},'workspace':{'workspace_id':'w2'},'tab':{'tab_id':'w2:t1'}}
                    elif m=='agent.start':result={'agent':{'pane_id':'w2:p1'}}
                    else:result={'type':'ok'}
                    self.wfile.write((json.dumps({'id':'dragon','result':result})+'\n').encode())
                except (OSError,ValueError):pass
        class Server(socketserver.ThreadingUnixStreamServer):
            daemon_threads=True
            allow_reuse_address=True
        self.server=Server(self.path,Handler);self.thread=threading.Thread(target=self.server.serve_forever,daemon=True);self.thread.start()
        return self
    def event(self,state=None,remove=False):
        with self.lock:
            if remove:self.data['agents']=[]
            elif state:self.data['agents'][0]['agent_status']=state
            clients=list(self.clients)
        for client in clients:
            try:client.sendall(b'{"event":"pane_agent_status_changed","data":{"pane_id":"w1:p1"}}\n')
            except OSError:pass
    def stop(self):
        with self.lock:clients=list(self.clients)
        for c in clients:
            try:c.shutdown(2)
            except OSError:pass
        self.server.shutdown();self.server.server_close();self.thread.join()
        import os
        if os.path.exists(self.path):os.unlink(self.path)


if __name__=='__main__':
    import argparse,signal
    p=argparse.ArgumentParser();p.add_argument('socket');p.add_argument('cwd');a=p.parse_args()
    server=FakeHerdr(a.socket,a.cwd).start();stop=threading.Event()
    signal.signal(signal.SIGTERM,lambda *_:stop.set());signal.signal(signal.SIGINT,lambda *_:stop.set())
    try:stop.wait()
    finally:server.stop()
