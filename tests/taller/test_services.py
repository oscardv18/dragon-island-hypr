"""Run the real services with fake herdr and isolated HOME; no desktop inputs."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('fake_herdr',ROOT/'tests/herdr/fake_herdr.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)

@unittest.skipUnless(shutil.which('qs'),'Quickshell required')
class Services(unittest.TestCase):
    def test_real_services_with_fake_socket(self):
        with tempfile.TemporaryDirectory(prefix='dt-') as tmp:
            home=Path(tmp);(home/'runtime').mkdir(mode=0o700);cfg=home/'shell';shutil.copytree(ROOT/'config/quickshell',cfg)
            (cfg/'services/qmldir').write_text('singleton Mem 1.0 Mem.qml\nsingleton Herdr 1.0 Herdr.qml\nsingleton Activity 1.0 Activity.qml\n')
            bindir=home/'.local/bin';bindir.mkdir(parents=True)
            for name in ('dragon-herdr','dragon-mem'):(bindir/name).symlink_to(ROOT/'bin'/name)
            env=dict(os.environ,HOME=tmp,XDG_RUNTIME_DIR=str(home/'runtime'),QT_QPA_PLATFORM='offscreen',HERDR_SOCKET_PATH=str(home/'h.sock'),PYTHONDONTWRITEBYTECODE='1')
            for n in ('CONFIG','DATA','STATE','CACHE'):env[f'XDG_{n}_HOME']=str(home/n.lower())
            server=module.FakeHerdr(env['HERDR_SOCKET_PATH'],tmp).start()
            try:
                (cfg/'shell.qml').write_text('''import Quickshell
import QtQuick
import "services"
ShellRoot {
    property bool created: false
    Component.onCompleted: {
        Mem.addProject(Quickshell.env("HOME"), "Proyecto de prueba", "TX", r => {
            if (!r.ok) throw new Error("project registration failed");
            Herdr.init(); created = true;
        });
    }
    Timer { interval: 100; running: true; repeat: true
        onTriggered: {
            if (!created || Mem.status !== "ok" || Herdr.agents.length !== 1) return;
            if (Mem.project?.name !== "Proyecto de prueba") throw new Error("project selection failed");
            const a = Herdr.agents[0];
            if (a.agent !== "claude" || a.workspace !== "demo" || a.since < 1000000000000) throw new Error("normalization failed");
            const since = Math.floor(Date.now()/1000);
            Herdr._event(JSON.stringify({t:"snapshot",source:"herdr",version:"0.9.5",spaces:[],agents:[
                {id:"blocked",kind:"claude",state:"blocked",since:since,space:"demo"},
                {id:"done",kind:"codex",state:"done",since:since-10,space:"demo"}]}));
            if (Herdr.attentionAgent.id !== "blocked") throw new Error("blocked priority failed");
            Herdr.snooze(Herdr.attentionAgent,10);
            if (Herdr.attentionAgent.id !== "done") throw new Error("snooze priority failed");
            Herdr.markSeen(Herdr.attentionAgent);
            if (Herdr.attentionAgent !== null) throw new Error("seen failed");
            Herdr._now = Date.now()+600001;
            if (Herdr.attentionAgent.id !== "blocked") throw new Error("snooze expiry failed");
            console.log("TALLER_SERVICES_OK"); Qt.quit();
        }
    }
    Timer { interval: 5000; running: true; onTriggered: { console.error("TALLER_SERVICES_TIMEOUT",Mem.status,Herdr.status); Qt.quit(); } }
}
''')
                r=subprocess.run(['qs','-p',str(cfg)],env=env,capture_output=True,text=True,timeout=10)
                out=r.stdout+r.stderr
                self.assertIn('TALLER_SERVICES_OK',out,out)
                self.assertNotIn('Error loading configuration',out,out)
                self.assertEqual(list((home/'data/dragon-island').glob('pane*')),[])
            finally:server.stop()
