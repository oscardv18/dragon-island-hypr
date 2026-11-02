"""Idle CPU (5e): Brightness follows backlight uevents from one idle `udevadm monitor` and only polls without it.
Real Quickshell with a fake udevadm / ddcutil; needs a real backlight (sysfs is read, never written)."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
HAS_BACKLIGHT = any(Path('/sys/class/backlight').glob('*')) if Path('/sys/class/backlight').exists() else False

UDEVADM = '''#!/bin/sh
# Fake monitor: header, three change events (one from another subsystem), then exit to test the poll fallback.
echo "$*" >> "$HOME/udevadm-calls"
echo "monitor will print the received events for:"
echo "KERNEL - the kernel uevent"
echo
for i in 1 2 3; do
  sleep 0.3
  echo "KERNEL[1.$i] change   /devices/fake/backlight/fake_bl (backlight)"
done
sleep "${FAKE_UDEV_LIFE:-1}"
'''

SHELL = '''import Quickshell
import QtQuick
import "services"
ShellRoot {
    property bool sawLive: false
    property bool sawFallback: false
    Connections {
        target: Brightness
        function onEventsLiveChanged() {
            if (Brightness.eventsLive) { sawLive = true; console.log("LIVE"); }
            else if (sawLive) { sawFallback = true; console.log("FALLBACK"); }
        }
    }
    Timer { interval: 100; running: true; repeat: true
        onTriggered: {
            if (!Brightness.available) return;
            if (EXPECT_MISSING && ++ticks > 15) { console.log("MISSING", Brightness.eventsLive); Qt.quit(); }
            if (sawLive && sawFallback) { console.log("EVENTS_OK"); Qt.quit(); }
        }
    }
    property int ticks: 0
    Timer { interval: 12000; running: true; onTriggered: { console.log("TIMEOUT", Brightness.available, Brightness.eventsLive); Qt.quit(); } }
}
'''


@unittest.skipUnless(shutil.which('qs') and HAS_BACKLIGHT, 'Quickshell and a backlight device required')
class BrightnessEvents(unittest.TestCase):
    def run_shell(self, with_udevadm):
        with tempfile.TemporaryDirectory(prefix='d5e-') as tmp:
            home = Path(tmp); runtime = home / 'runtime'; runtime.mkdir(mode=0o700)
            cfg = home / 'shell'; (cfg / 'services').mkdir(parents=True)
            shutil.copy(ROOT / 'config/quickshell/services/Brightness.qml', cfg / 'services')
            (cfg / 'services/qmldir').write_text('singleton Brightness 1.0 Brightness.qml\n')
            (cfg / 'shell.qml').write_text(SHELL.replace('EXPECT_MISSING', 'false' if with_udevadm else 'true'))
            fake = home / 'bin'; fake.mkdir()
            (fake / 'ddcutil').write_text('#!/bin/sh\nexit 1\n')
            if with_udevadm: (fake / 'udevadm').write_text(UDEVADM)
            for f in fake.iterdir(): f.chmod(0o755)
            # PATH without /usr/bin for udevadm: link only what the service needs besides the fakes.
            for tool in ('sh', 'ls', 'head', 'setpriv'):
                if shutil.which(tool):
                    (fake / tool).symlink_to(shutil.which(tool))
            env = dict(os.environ, HOME=tmp, XDG_RUNTIME_DIR=str(runtime), QT_QPA_PLATFORM='offscreen',
                       PATH=str(fake))
            p = subprocess.run([shutil.which('qs'), '-p', str(cfg)], env=env, capture_output=True, text=True, timeout=30)
            calls = (home / 'udevadm-calls').read_text() if (home / 'udevadm-calls').exists() else ''
            return p.stdout + p.stderr, calls

    def test_uevents_then_fallback(self):
        out, calls = self.run_shell(True)
        self.assertIn('EVENTS_OK', out, out)
        self.assertIn('monitor --kernel --subsystem-match=backlight', calls)
        self.assertEqual(calls.count('monitor'), 1, 'a dead monitor must not be respawned in a loop')

    @unittest.skipUnless(shutil.which('setpriv'), 'setpriv (util-linux) required')
    def test_monitor_dies_with_quickshell(self):
        """Killing Quickshell abruptly must not leave `udevadm monitor` orphaned (it only notices on its next write)."""
        import signal
        import time
        with tempfile.TemporaryDirectory(prefix='d5e-') as tmp:
            home = Path(tmp); runtime = home / 'runtime'; runtime.mkdir(mode=0o700)
            cfg = home / 'shell'; (cfg / 'services').mkdir(parents=True)
            shutil.copy(ROOT / 'config/quickshell/services/Brightness.qml', cfg / 'services')
            (cfg / 'services/qmldir').write_text('singleton Brightness 1.0 Brightness.qml\n')
            (cfg / 'shell.qml').write_text('import Quickshell\nimport QtQuick\nimport "services"\n'
                                           'ShellRoot { Component.onCompleted: console.log(Brightness.device) }\n')
            fake = home / 'bin'; fake.mkdir()
            pidfile = home / 'monitor.pid'
            (fake / 'udevadm').write_text(f'#!/bin/sh\necho $$ > "{pidfile}"\necho "monitor will print"\nexec sleep 300\n')
            (fake / 'ddcutil').write_text('#!/bin/sh\nexit 1\n')
            for f in fake.iterdir(): f.chmod(0o755)
            for tool in ('sh', 'ls', 'head', 'setpriv', 'sleep'):
                (fake / tool).symlink_to(shutil.which(tool))
            env = dict(os.environ, HOME=tmp, XDG_RUNTIME_DIR=str(runtime), QT_QPA_PLATFORM='offscreen', PATH=str(fake))
            qs = subprocess.Popen([shutil.which('qs'), '-p', str(cfg)], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            try:
                deadline = time.monotonic() + 15
                while not pidfile.exists() and time.monotonic() < deadline:
                    time.sleep(0.1)
                self.assertTrue(pidfile.exists(), 'the monitor never started')
                monitor = int(pidfile.read_text())
                os.kill(qs.pid, signal.SIGKILL)
                qs.wait(timeout=5)
                deadline = time.monotonic() + 5
                while time.monotonic() < deadline and Path(f'/proc/{monitor}').exists():
                    time.sleep(0.1)
                alive = Path(f'/proc/{monitor}').exists()
                if alive:
                    os.kill(monitor, signal.SIGTERM)
                self.assertFalse(alive, 'udevadm monitor outlived Quickshell')
            finally:
                if qs.poll() is None:
                    qs.kill()

    def test_without_udevadm_it_polls(self):
        out, _ = self.run_shell(False)
        self.assertIn('MISSING false', out, out)


if __name__ == '__main__':
    unittest.main()
