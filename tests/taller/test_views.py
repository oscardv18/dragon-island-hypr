"""Render actual Taller views with injected state, no runtime services or desktop inputs."""
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[2]

@unittest.skipUnless(shutil.which('qml6'),'qml6 required')
class Views(unittest.TestCase):
    def test_empty_and_grouped_agents(self):
        with tempfile.TemporaryDirectory(prefix='taller-view-') as tmp:
            work=Path(tmp);cfg=work/'config/quickshell';shutil.copytree(ROOT/'config/quickshell',cfg)
            tests=work/'tests/qml';tests.mkdir(parents=True)
            shutil.copy(ROOT/'tests/qml/taller_mock.qml',tests/'taller_mock.qml')
            for name in ('Theme','Icons'):
                p=cfg/(name+'.qml');p.write_text(p.read_text().replace('import Quickshell\n','').replace('Singleton {','QtObject {'))
            (cfg/'qmldir').write_text('singleton Theme 1.0 Theme.qml\nsingleton Icons 1.0 Icons.qml\n')
            env=dict(os.environ,HOME=tmp,QT_QPA_PLATFORM='offscreen')
            for n in ('CONFIG','DATA','STATE','CACHE'):env[f'XDG_{n}_HOME']=str(work/n.lower())
            r=subprocess.run(['qml6',str(tests/'taller_mock.qml'),'--',tmp],env=env,capture_output=True,text=True,timeout=10)
            self.assertEqual(r.returncode,0,r.stdout+r.stderr)
            self.assertNotIn('Error:',r.stderr,r.stderr)
            self.assertNotIn('ReferenceError',r.stderr,r.stderr)
            raw=(work/'taller-atencion.png').read_bytes();self.assertEqual(struct.unpack('>II',raw[16:24]),(440,30))
            for name in ('taller-vacio.png','taller-agentes.png'):
                raw=(work/name).read_bytes();self.assertEqual(struct.unpack('>II',raw[16:24]),(1226,612))
