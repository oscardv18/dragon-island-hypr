"""Explorer in selector mode: the real FilesPanel/PickerBar over a simulated Files service (tests/qml/files_picker_mock.qml), offscreen."""
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless(shutil.which('qml6'), 'qml6 required')
class PickerViews(unittest.TestCase):
    def test_every_kind_of_dialog(self):
        with tempfile.TemporaryDirectory(prefix='pk-ui-') as tmp:
            work = Path(tmp)
            cfg = work / 'config/quickshell'
            shutil.copytree(ROOT / 'config/quickshell', cfg)
            tests = work / 'tests/qml'
            tests.mkdir(parents=True)
            shutil.copy(ROOT / 'tests/qml/files_picker_mock.qml', tests)
            (work / 'sddm/dragon-core').mkdir(parents=True)
            shutil.copy(ROOT / 'sddm/dragon-core/background.jpg', work / 'sddm/dragon-core')
            for name in ('Theme', 'Icons'):
                p = cfg / (name + '.qml')
                p.write_text(p.read_text().replace('import Quickshell\n', '').replace('Singleton {', 'QtObject {'))
            (cfg / 'qmldir').write_text('singleton Theme 1.0 Theme.qml\nsingleton Icons 1.0 Icons.qml\n')
            (work / 'runtime').mkdir(mode=0o700)
            env = dict(os.environ, HOME=tmp, XDG_RUNTIME_DIR=str(work / 'runtime'), QT_QPA_PLATFORM='offscreen',
                       QT_FORCE_STDERR_LOGGING='1', TZ='UTC', PYTHONDONTWRITEBYTECODE='1')
            env.pop('QT_QPA_PLATFORMTHEME', None)
            for n in ('CONFIG', 'DATA', 'STATE', 'CACHE'):
                env[f'XDG_{n}_HOME'] = str(work / n.lower())
            out = work / 'out'
            out.mkdir()
            r = subprocess.run(['qml6', str(tests / 'files_picker_mock.qml'), '--', str(out)], env=env, capture_output=True, text=True, timeout=90)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            for bad in ('Error:', 'ReferenceError', 'TypeError', 'files_picker_mock:', 'is not a type', 'Unable to assign'):
                self.assertNotIn(bad, r.stderr, r.stderr)
            shots = sorted(p.name for p in out.glob('picker-*.png'))
            self.assertEqual(shots, ['picker-abrir.png', 'picker-carpeta.png', 'picker-guardar-varios.png', 'picker-guardar.png',
                                     'picker-reemplazar.png', 'picker-varios.png'])
            for name in shots:
                self.assertEqual(struct.unpack('>II', (out / name).read_bytes()[16:24]), (1226, 612), name)
            keep = os.environ.get('PORTAL_SHOTS')          # local inspection only; never commit these
            if keep:
                shutil.copytree(out, keep, dirs_exist_ok=True)


@unittest.skipUnless(shutil.which('node'), 'node required')
class PickerHelpers(unittest.TestCase):
    def test_glob_mime_and_rules(self):
        script = ROOT / 'tests/portal/picker_helpers.js'
        r = subprocess.run(['node', str(script), str(ROOT / 'config/quickshell/modules/files/files.js')], capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)


if __name__ == '__main__':
    unittest.main()
