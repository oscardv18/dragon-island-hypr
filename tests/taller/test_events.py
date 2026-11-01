"""Fake Unix event -> real watch --record -> real QML service and visible AgentsTab."""
import importlib.util
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import threading
import time
import unittest
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('fake_herdr',ROOT/'tests/herdr/fake_herdr.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)

@unittest.skipUnless(shutil.which('qs'),'Quickshell required')
class Events(unittest.TestCase):
    def test_blocked_event_reaches_view_within_two_seconds(self):
        with tempfile.TemporaryDirectory(prefix='te-') as tmp:
            home=Path(tmp);(home/'runtime').mkdir(mode=0o700);cfg=home/'shell';shutil.copytree(ROOT/'config/quickshell',cfg)
            (cfg/'services/qmldir').write_text('singleton Mem 1.0 Mem.qml\nsingleton Herdr 1.0 Herdr.qml\nsingleton Activity 1.0 Activity.qml\n')
            bindir=home/'.local/bin';bindir.mkdir(parents=True)
            for name in ('dragon-mem','dragon-herdr'):(bindir/name).symlink_to(ROOT/'bin'/name)
            env=dict(os.environ,HOME=tmp,XDG_RUNTIME_DIR=str(home/'runtime'),HERDR_SOCKET_PATH=str(home/'h.sock'),QT_QPA_PLATFORM='offscreen',PYTHONDONTWRITEBYTECODE='1')
            for n in ('CONFIG','DATA','STATE','CACHE'):env[f'XDG_{n}_HOME']=str(home/n.lower())
            server=module.FakeHerdr(env['HERDR_SOCKET_PATH'],tmp).start()
            (cfg/'shell.qml').write_text('''import Quickshell
import QtQuick
import "services"
import "modules/taller"
ShellRoot {
    Component.onCompleted: Herdr.init()
    FloatingWindow {
        implicitWidth: 1226; implicitHeight: 612; visible: true
        TallerPanel { id: panel; anchors.fill: parent; shown: true; agentService: Herdr; memService: Mem }
    }
    Timer { interval: 25; running: true; repeat: true
        onTriggered: {
            const a=Herdr.agents[0];
            if (a?.state !== "blocked") return;
            const elapsed=Date.now()-Number(a.title);
            if (panel.agentService.counts.blocked !== 1 || Herdr.attentionAgent?.pane !== a.pane) throw new Error("view/attention missing");
            if (Herdr.readText.indexOf("neverexpose") >= 0) throw new Error("unmasked read");
            console.log("E2E_MS="+elapsed);Qt.quit();
        }
    }
    Timer { interval: 6000; running: true; onTriggered: { console.error("EVENT_TIMEOUT");Qt.quit(); } }
}
''')
            def update():
                deadline=time.monotonic()+4
                while time.monotonic()<deadline:
                    if server.clients:
                        with server.lock:server.data['agents'][0]['terminal_title_stripped']=str(int(time.time()*1000))
                        server.event('blocked');return
                    time.sleep(.02)
            thread=threading.Thread(target=update,daemon=True);thread.start()
            try:
                r=subprocess.run(['qs','-p',str(cfg)],env=env,capture_output=True,text=True,timeout=9)
                match=re.search(r'E2E_MS=(\d+)',r.stdout+r.stderr)
                self.assertIsNotNone(match,r.stdout+r.stderr);self.assertLess(int(match[1]),2000)
                self.assertNotIn('ReferenceError',r.stdout+r.stderr)
            finally:thread.join(timeout=5);server.stop()
