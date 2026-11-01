"""Opt-in Wayland preview used by real_compose.py --visual. Isolates HOME/XDG.
Only its own test shell is closed, without keyboard injection or user-window operations.
"""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import threading
ROOT = Path(__file__).resolve().parents[2]

def preview(project, target):
    with tempfile.TemporaryDirectory(prefix='5b-preview-') as tmp:
        home = Path(tmp); (home/'runtime').mkdir(mode=0o700)
        cfg = home/'shell'; shutil.copytree(ROOT/'config/quickshell',cfg)
        (cfg/'services/qmldir').write_text('ToolRequest 1.0 ToolRequest.qml\nsingleton Docker 1.0 Docker.qml\nsingleton Git 1.0 Git.qml\n')
        bindir = home/'.local/bin'; bindir.mkdir(parents=True)
        for name in ('dragon-docker','dragon-git'): (bindir/name).symlink_to(ROOT/'bin'/name)
        display = os.environ.get('WAYLAND_DISPLAY','wayland-1')
        if not display.startswith('/'): display = str(Path(os.environ['XDG_RUNTIME_DIR'])/display)
        env = dict(os.environ,QT_QPA_PLATFORM="wayland",WAYLAND_DISPLAY=display,HOME=tmp,XDG_RUNTIME_DIR=str(home/'runtime'),TEST_PROJECT=project,
                   GIT_AUTHOR_NAME='Prueba',GIT_AUTHOR_EMAIL='test@example.org',GIT_COMMITTER_NAME='Prueba',GIT_COMMITTER_EMAIL='test@example.org')
        for key in ('CONFIG','DATA','STATE','CACHE'): env[f'XDG_{key}_HOME'] = str(home/key.lower())
        repo = home/'repo'; subprocess.run(['git','init','-b','main',str(repo)],env=env,capture_output=True,check=True)
        (repo/'sample.py').write_text('print("antes")\n')
        for args in (['add','.'],['commit','-m','feat(test): base']): subprocess.run(['git','-C',str(repo),*args],env=env,capture_output=True,check=True)
        (repo/'sample.py').write_text('print("después")\nprint("solo datos sintéticos")\n')
        (cfg/'shell.qml').write_text('''import Quickshell
import Quickshell.Wayland
import QtQuick
import "."
import "services"
import "modules/taller"
ShellRoot {
    id: root
    property int phase: 0
    property int ticks: 0
    Component.onCompleted: Docker.activate(true)
    QtObject { id: memory; property var project: ({name:"Compose de prueba",branch:"main"}); property var projects: [{}]; property string selectedSlug: "test"; property string status: "ok" }
    PanelWindow {
        implicitWidth: Theme.taller.width
        implicitHeight: Theme.taller.height
        color: Theme.transparent
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "dragon5b-preview"
        WlrLayershell.layer: WlrLayer.Overlay
        TallerPanel { id: panel; anchors.fill: parent; shown: true; tab: "contenedores"; dockerService: Docker; gitService: Git; memService: memory }
    }
    Timer { interval: 100; running: true; repeat: true
        onTriggered: {
            root.ticks++;
            if (root.phase === 0) {
                const worker = Docker.containers.find(c => c.project === Quickshell.env("TEST_PROJECT") && c.service === "worker");
                if (worker && Docker.selectedId !== worker.id) Docker.select(worker.id);
                const api = Docker.containers.find(c => c.project === Quickshell.env("TEST_PROJECT") && c.service === "api");
                if (worker && api && Docker.history[api.id]?.length >= 2 && Docker.issues.some(i => i.container === worker.id && i.kind === "restart_loop")) {
                    console.log("VISUAL_DOCKER_READY"); root.phase = 1; root.ticks = 0;
                }
            } else if (root.phase === 1 && root.ticks >= 15) {
                const api = Docker.containers.find(c => c.project === Quickshell.env("TEST_PROJECT") && c.service === "api");
                Docker.select(api.id); root.phase = 4; root.ticks = 0;
            } else if (root.phase === 4 && root.ticks >= 15) {
                console.log("VISUAL_METRICS_READY"); root.phase = 5; root.ticks = 0;
            } else if (root.phase === 5 && root.ticks >= 15) {
                Docker.activate(false); panel.tab = "git"; Git.activate(true,Quickshell.env("HOME")+"/repo"); root.phase = 2;
            } else if (root.phase === 2 && Git.diffData.hunks?.length && Git.history.length) {
                console.log("VISUAL_GIT_READY"); root.phase = 3; root.ticks = 0;
            } else if (root.phase === 3 && root.ticks >= 15) { Git.activate(false,""); Qt.quit(); }
        }
    }
    Timer { interval: 18000; running: true; onTriggered: { console.error("VISUAL_TIMEOUT",Docker.message,Git.message); Qt.quit(); } }
}
''')
        p = subprocess.Popen([shutil.which('qs'),'-p',str(cfg)],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
        guard = threading.Timer(25,p.terminate); guard.start()
        output = ''
        try:
            for line in p.stdout:
                output += line
                for state, name in [('VISUAL_DOCKER_READY','real-compose.png'),('VISUAL_GIT_READY','real-git-temporal.png'),('VISUAL_METRICS_READY','real-compose-metricas.png')]:
                    if state in line:
                        subprocess.run(['grim',str(Path(target)/name)],check=True,timeout=5)
            p.wait(timeout=5)
            for state in ('VISUAL_DOCKER_READY','VISUAL_GIT_READY','VISUAL_METRICS_READY'): assert state in output, output
            for bad in ('ReferenceError','TypeError','Failed to load configuration'): assert bad not in output,output
            print('REAL_VISUAL_OK',flush=True)
        finally:
            guard.cancel()
            if p.poll() is None: p.terminate(); p.communicate(timeout=5)
            p.stdout.close()
