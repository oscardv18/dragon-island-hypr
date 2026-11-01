"""Real Quickshell services + fake Unix Docker + disposable Git, no desktop input."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'tests/docker'))
from fake_docker import FakeDocker, INSPECT

@unittest.skipUnless(shutil.which('qs'), 'Quickshell required')
class ServiceTests(unittest.TestCase):
    def test_reads_actions_and_lifetime(self):
        with tempfile.TemporaryDirectory(prefix='db-services-') as tmp:
            home = Path(tmp); runtime = home/'runtime'; runtime.mkdir(mode=0o700)
            cfg = home/'shell'; shutil.copytree(ROOT/'config/quickshell', cfg)
            (cfg/'services/qmldir').write_text('ToolRequest 1.0 ToolRequest.qml\nsingleton Docker 1.0 Docker.qml\nsingleton Git 1.0 Git.qml\n')
            bindir = home/'.local/bin'; bindir.mkdir(parents=True)
            for name in ('dragon-docker', 'dragon-git'): (bindir/name).symlink_to(ROOT/'bin'/name)
            commands = home/'commands'; commands.mkdir()
            for name in ('sh','bash','readlink','dirname','python3','git'):
                (commands/name).symlink_to(shutil.which(name))
            repo = home/'repo'; repo.mkdir()
            env = dict(os.environ, HOME=tmp, XDG_RUNTIME_DIR=str(runtime), QT_QPA_PLATFORM='offscreen',
                       DRAGON_DOCKER_SOCKET=str(home/'d.sock'), GIT_AUTHOR_NAME='Test', GIT_AUTHOR_EMAIL='test@example.org',
                       GIT_COMMITTER_NAME='Test', GIT_COMMITTER_EMAIL='test@example.org')
            env['PATH'] = str(commands)
            for key in ('CONFIG','DATA','CACHE','STATE'): env[f'XDG_{key}_HOME'] = str(home/key.lower())
            subprocess.run(['git','init','-b','main',str(repo)],env=env,capture_output=True,check=True)
            (repo/'.env').write_text('FOO=only-local-test\n')
            (repo/'safe.txt').write_text('safe\n')
            server = FakeDocker(str(home/'d.sock')).start()
            oldstate = INSPECT['State']['Status']; INSPECT['State']['Status'] = 'running'
            (cfg/'shell.qml').write_text('''import Quickshell
import QtQuick
import "services"
ShellRoot {
    property int phase: 0
    property int tick: 0
    property string path: Quickshell.env("HOME") + "/repo"
    Component.onCompleted: { Docker.activate(true); Git.activate(true,path); }
    Timer { interval: 100; running: true; repeat: true
        onTriggered: {
            tick++;
            if (phase === 0 && Docker.containers.length && Docker.logs.length && Object.keys(Docker.metrics).length && Git.snapshot.untracked?.length === 2) {
                if (Docker.logs[0].count !== 2) throw new Error("repeat count");
                Docker.inspect(); Git.stage(".env",true); phase = 1;
            } else if (phase === 1 && !Git.busy && Git.snapshot.staged?.length === 1 && Docker.inspectText.length) {
                if (Docker.inspectText.includes("ghp_")) throw new Error("inspect secret leak");
                Git.commit("feat(test): refused",false); phase = 2;
            } else if (phase === 2 && !Git.busy && Git.actionError.includes("secretos")) {
                Git.stage(".env",false); phase = 3;
            } else if (phase === 3 && !Git.busy && Git.snapshot.staged?.length === 0) {
                Git.stage("safe.txt",true); phase = 4;
            } else if (phase === 4 && !Git.busy && Git.snapshot.staged?.length === 1) {
                Git.commit("feat(test): safe",false); phase = 5;
            } else if (phase === 5 && !Git.busy && Git.history.length === 1) {
                Git.lazygit(); Docker.shell(); phase = 7;
            } else if (phase === 7 && Git.actionError.includes("lazygit no disponible") && Docker.actionError.includes("Shell requiere")) {
                Docker.activate(false); Git.activate(false,path); phase = 6; tick = 0;
                console.log("SERVICES_INACTIVE");
            } else if (phase === 6 && tick === 15) { console.log("FASE5B_SERVICES_OK"); Qt.quit(); }
        }
    }
    Timer { interval: 12000; running: true; onTriggered: { console.error("TIMEOUT",phase,Docker.status,Docker.message,Git.status,Git.actionError); Qt.quit(); } }
}
''')
            try:
                p = subprocess.Popen([shutil.which('qs'),'-p',str(cfg)],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
                output = ''
                for line in p.stdout:
                    output += line
                    if 'SERVICES_INACTIVE' in line:
                        import time
                        time.sleep(.5)
                        offenders = []
                        for f in Path('/proc').glob('[0-9]*/cmdline'):
                            try:
                                cmd = f.read_bytes().replace(b'\0',b' ').decode(errors='replace')
                                if str(bindir) in cmd and ('dragon-docker' in cmd or ('dragon-git' in cmd and ' watch ' in cmd)): offenders.append(cmd)
                            except (OSError,ProcessLookupError): pass
                        self.assertEqual(offenders, [])
                p.wait(timeout=5); p.stdout.close()
                self.assertIn('FASE5B_SERVICES_OK',output,output)
                for bad in ('ReferenceError','TypeError','Error loading configuration'): self.assertNotIn(bad,output,output)
            finally:
                if p.poll() is None: p.terminate(); p.communicate(timeout=5)
                server.stop(); INSPECT['State']['Status'] = oldstate
