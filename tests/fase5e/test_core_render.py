"""Idle CPU (5e): the neural core paints with Canvas.Immediate (one window frame per tick instead of two) and looks
exactly as it did with Canvas.Cooperative. Both variants render the same state offscreen and are compared pixel by pixel."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
CORE = ROOT / 'shared/neural-core/NeuralCore.qml'

VIEW = '''import QtQuick
import QtQuick.Window
Window {
    id: win
    visible: true; width: 420; height: 220; color: "#101018"
    property string out: Qt.application.arguments[Qt.application.arguments.length - 1]
    Row {
        id: row
        CoreNow { id: a; width: 200; height: 200; mood: "thinking"; running: false; hud: true }
        CoreOld { id: b; width: 200; height: 200; mood: "thinking"; running: false; hud: true }
    }
    Timer {
        interval: 1500; running: true
        onTriggered: {
            a.grabToImage(r => { r.saveToFile(win.out + "/now.png");
                b.grabToImage(s => { s.saveToFile(win.out + "/old.png"); Qt.quit(); }); });
        }
    }
}
'''


QML6 = '/usr/lib/qt6/bin/qml' if Path('/usr/lib/qt6/bin/qml').exists() else shutil.which('qml6')


@unittest.skipUnless(QML6, 'Qt 6 qml runtime required')
class CoreRender(unittest.TestCase):
    def test_immediate_strategy(self):
        self.assertIn('renderStrategy: Canvas.Immediate', CORE.read_text())
        for copy in ('config/quickshell/components/NeuralCore.qml', 'sddm/dragon-core/components/NeuralCore.qml'):
            self.assertEqual((ROOT / copy).read_text(), CORE.read_text(), f'{copy} drifted: run scripts/sync-shared.sh')

    def test_same_pixels_as_cooperative(self):
        try:
            from PIL import Image, ImageChops  # noqa: F401
        except ImportError:
            self.skipTest('Pillow required to compare images')
        with tempfile.TemporaryDirectory(prefix='d5e-core-') as tmp:
            d = Path(tmp)
            # the synapse pulses start at random links: fix them so both copies draw the same state
            src = CORE.read_text().replace('Math.random()', '0.5')
            (d / 'CoreNow.qml').write_text(src)
            (d / 'CoreOld.qml').write_text(src.replace('renderStrategy: Canvas.Immediate', 'renderStrategy: Canvas.Cooperative'))
            (d / 'view.qml').write_text(VIEW)
            env = dict(os.environ, QT_QPA_PLATFORM='offscreen')
            p = subprocess.run([QML6, str(d / 'view.qml'), '--', str(d)], env=env, capture_output=True, text=True, timeout=30)
            self.assertTrue((d / 'now.png').exists() and (d / 'old.png').exists(), p.stdout + p.stderr)
            a, b = Image.open(d / 'now.png').convert('RGBA'), Image.open(d / 'old.png').convert('RGBA')
            self.assertEqual(a.size, b.size)
            self.assertIsNotNone(a.getbbox(), 'the core painted nothing')
            self.assertIsNone(ImageChops.difference(a, b).getbbox(), 'Immediate must paint the same pixels')


if __name__ == '__main__':
    unittest.main()
