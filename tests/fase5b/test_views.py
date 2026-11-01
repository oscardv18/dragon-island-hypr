"""Pure Taller views: render without Quickshell services, Docker, Git or network."""
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import unittest
ROOT = Path(__file__).resolve().parents[2]

def render(mock, target):
    with tempfile.TemporaryDirectory(prefix='5b-view-') as tmp:
        work = Path(tmp); (work/'runtime').mkdir(mode=0o700)
        cfg = work/'config/quickshell'; shutil.copytree(ROOT/'config/quickshell', cfg)
        qml = work/'tests/qml'; qml.mkdir(parents=True); shutil.copy(ROOT/'tests/qml'/mock, qml/mock)
        for name in ('Theme','Icons'):
            p = cfg/(name+'.qml'); p.write_text(p.read_text().replace('import Quickshell\n','').replace('Singleton {','QtObject {'))
        (cfg/'qmldir').write_text('singleton Theme 1.0 Theme.qml\nsingleton Icons 1.0 Icons.qml\n')
        env = dict(os.environ, HOME=tmp, XDG_RUNTIME_DIR=str(work/'runtime'), QT_QPA_PLATFORM='offscreen')
        for key in ('CONFIG','DATA','STATE','CACHE'): env[f'XDG_{key}_HOME'] = str(work/key.lower())
        return subprocess.run(['qml6',str(qml/mock),'--',str(target)],env=env,capture_output=True,text=True,timeout=10)

@unittest.skipUnless(shutil.which('qml6'), 'qml6 required')
class Views(unittest.TestCase):
    def test_compose_with_oom_and_permission_denied(self):
        with tempfile.TemporaryDirectory() as tmp:
            r = render('taller_docker_mock.qml',tmp)
            self.assertEqual(r.returncode,0,r.stdout+r.stderr)
            for bad in ('Error:','ReferenceError','TypeError','Cannot assign','Unable to assign'): self.assertNotIn(bad,r.stderr,r.stderr)
            for name in ('taller-contenedores.png','taller-docker-sin-permiso.png'):
                self.assertEqual(struct.unpack('>II',(Path(tmp)/name).read_bytes()[16:24]),(1226,612))
