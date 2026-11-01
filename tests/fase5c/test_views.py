"""Pure 5c Taller views rendered offscreen with synthetic data (no Quickshell services, tools or network)."""
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import unittest
ROOT = Path(__file__).resolve().parents[2]
BAD = ('Error:', 'ReferenceError', 'TypeError', 'Cannot assign', 'Unable to assign', 'is not a function', 'is not defined')


def render(mock, target):
    with tempfile.TemporaryDirectory(prefix='5c-view-') as tmp:
        work = Path(tmp); (work / 'runtime').mkdir(mode=0o700)
        cfg = work / 'config/quickshell'; shutil.copytree(ROOT / 'config/quickshell', cfg)
        qml = work / 'tests/qml'; qml.mkdir(parents=True)
        for f in (ROOT / 'tests/qml').glob('*.qml'): shutil.copy(f, qml / f.name)
        shutil.copytree(ROOT / 'tests/qml/fixtures', qml / 'fixtures')
        for name in ('Theme', 'Icons'):
            p = cfg / (name + '.qml'); p.write_text(p.read_text().replace('import Quickshell\n', '').replace('Singleton {', 'QtObject {'))
        (cfg / 'qmldir').write_text('singleton Theme 1.0 Theme.qml\nsingleton Icons 1.0 Icons.qml\n')
        env = dict(os.environ, HOME=tmp, XDG_RUNTIME_DIR=str(work / 'runtime'), QT_QPA_PLATFORM='offscreen', QT_FORCE_STDERR_LOGGING='1')
        for key in ('CONFIG', 'DATA', 'STATE', 'CACHE'): env[f'XDG_{key}_HOME'] = str(work / key.lower())
        return subprocess.run(['qml6', str(qml / mock), '--', str(target)], env=env, capture_output=True, text=True, timeout=30)


def size(path):
    return struct.unpack('>II', Path(path).read_bytes()[16:24])


@unittest.skipUnless(shutil.which('qml6'), 'qml6 required')
class Views(unittest.TestCase):
    def check(self, mock, names):
        with tempfile.TemporaryDirectory() as tmp:
            r = render(mock, tmp)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            for bad in BAD: self.assertNotIn(bad, r.stderr, r.stderr)
            for name in names: self.assertEqual(size(Path(tmp) / name), (1226, 612), name)
            return r.stdout + r.stderr

    def test_composer(self):
        out = self.check('taller_prompt_mock.qml', ('taller-compositor.png', 'taller-compositor-pesado.png'))
        self.assertIn('"template":"revisar-cambios"', out)


    def test_kanban(self):
        out = self.check('taller_kanban_mock.qml', ('taller-kanban.png', 'taller-kanban-wip.png', 'taller-kanban-compositor.png'))
        self.assertIn('PENDING {"key":"AX-150","col":"doing","reason":"wip"', out)
        self.assertIn('["move","AX-148","doing",false]', out)
        self.assertNotIn('["move","AX-150","doing",true]', out)  # never forced without the confirmation
        self.assertIn('NOTICE Para pasar a', out)  # AX-137 has no green gates in the fixture


    def test_review(self):
        out = self.check('taller_review_mock.qml', ('taller-revision.png', 'taller-revision-marcado.png', 'taller-revision-vacio.png'))
        self.assertIn('SEEN 4 COMMENTS 3 BADGE 1', out)


if __name__ == '__main__':
    unittest.main()
