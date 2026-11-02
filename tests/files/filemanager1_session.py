"""Runs only inside a private dbus-run-session, with a fake qs."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time

root=Path(sys.argv[1])
server=subprocess.Popen([str(root/'bin/dragon-files'),'--filemanager1'],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
try:
    deadline=time.monotonic()+5
    ready=False
    while time.monotonic()<deadline:
        check=subprocess.run(['gdbus','call','--session','--dest','org.freedesktop.DBus',
                              '--object-path','/org/freedesktop/DBus','--method','org.freedesktop.DBus.NameHasOwner',
                              'org.freedesktop.FileManager1'],capture_output=True,text=True,check=True)
        if 'true' in check.stdout:
            ready=True;break
        if server.poll() is not None: break
        time.sleep(.05)
    assert ready, server.stderr.read() if server.poll() is not None else 'D-Bus timeout'
    folder=Path(os.environ['HOME'])/'folder';folder.mkdir()
    item=folder/'file';item.write_text('x')
    for method,path in (('ShowFolders',folder),('ShowItems',item),('ShowItemProperties',item)):
        call=subprocess.run(['gdbus','call','--session','--dest','org.freedesktop.FileManager1',
                             '--object-path','/org/freedesktop/FileManager1',
                             '--method','org.freedesktop.FileManager1.'+method,
                             json.dumps([path.as_uri()]),''],capture_output=True,text=True)
        assert call.returncode==0,call.stderr
    another=subprocess.run([str(root/'bin/dragon-files'),'--filemanager1'],capture_output=True,text=True,timeout=5)
    assert another.returncode==10,another.stderr
    assert server.poll() is None,'The current owner was replaced'
    calls=[json.loads(s) for s in (Path(os.environ['HOME'])/'ipc').read_text().splitlines()]
    assert len(calls)==3,calls
    assert all(c[-1]==str(folder) for c in calls),calls
finally:
    if server.poll() is None:
        server.terminate()
        try: server.wait(timeout=3)
        except subprocess.TimeoutExpired: server.kill();server.wait()
    server.stdout.close();server.stderr.close()
