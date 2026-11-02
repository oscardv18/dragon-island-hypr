"""Runs a scenario through the real xdg-desktop-portal in a private session bus (dbus-run-session), HOME/XDG temporary."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
XDP = '/usr/lib/xdg-desktop-portal'
CAN_RUN = all([shutil.which('dbus-run-session'), os.path.exists(XDP)]) and subprocess.run(
    [sys.executable, '-c', 'import gi'], capture_output=True).returncode == 0
needs_session = unittest.skipUnless(CAN_RUN, 'needs dbus-run-session, xdg-desktop-portal and PyGObject')

SERVICE = '[D-BUS Service]\nName=%s\nExec=%s\n'
PORTAL = '[portal]\nDBusName=%s\nInterfaces=org.freedesktop.impl.portal.FileChooser;\nUseIn=Hyprland\n'


def b(text):
    """`ay` option: NUL-terminated bytes, as a list of ints (JSON friendly)."""
    return list(os.fsencode(text) + b'\0')


def u32(value):
    return value


class Scenario:
    """One private session: Dragon backend (the real dragon-portal) + fake GTK backend + simulated explorer."""

    def __init__(self, extra_env=None, plan=None):
        # short path: Unix sockets are limited to 108 bytes
        self.root = Path(tempfile.mkdtemp(prefix='dp', dir='/tmp'))
        self.home = self.root / 'home'
        self.fx = self.root / 'fx'
        self.tree = self.root / 'tree'
        for p in (self.home, self.fx, self.tree, self.root / 'rt', self.root / 'data/dbus-1/services', self.root / 'portals',
                  self.root / 'config/xdg-desktop-portal'):
            p.mkdir(parents=True, exist_ok=True)
        (self.root / 'rt').chmod(0o700)
        self.extra_env = dict(extra_env or {})
        self.plan = dict(plan or {})
        (self.root / 'portals/dragon.portal').write_text(PORTAL % 'org.freedesktop.impl.portal.desktop.dragon')
        (self.root / 'portals/gtk.portal').write_text(PORTAL % 'org.freedesktop.impl.portal.desktop.gtk')
        (self.root / 'config/xdg-desktop-portal/hyprland-portals.conf').write_text('[preferred]\ndefault=dragon;gtk\n')
        services = self.root / 'data/dbus-1/services'
        (services / 'org.freedesktop.impl.portal.desktop.dragon.service').write_text(
            SERVICE % ('org.freedesktop.impl.portal.desktop.dragon', '%s serve' % (ROOT / 'bin/dragon-portal')))
        (services / 'org.freedesktop.impl.portal.desktop.gtk.service').write_text(
            SERVICE % ('org.freedesktop.impl.portal.desktop.gtk', '%s %s' % (sys.executable, HERE / 'fake_gtk.py')))

    def cleanup(self):
        shutil.rmtree(self.root, ignore_errors=True)

    def env(self):
        env = {k: v for k, v in os.environ.items() if k in ('PATH', 'LANG', 'LC_ALL')}
        env.update(HOME=str(self.home), XDG_DATA_HOME=str(self.root / 'data'), XDG_CONFIG_HOME=str(self.root / 'config'),
                   XDG_STATE_HOME=str(self.root / 'state'), XDG_CACHE_HOME=str(self.root / 'cache'),
                   XDG_RUNTIME_DIR=str(self.root / 'rt'), XDG_CURRENT_DESKTOP='Hyprland',
                   XDG_DESKTOP_PORTAL_DIR=str(self.root / 'portals'), FAKE_EXPLORER_DIR=str(self.fx),
                   DRAGON_PORTAL_QS='%s %s' % (sys.executable, HERE / 'fake_explorer.py'),
                   DRAGON_PORTAL_ACK='2', DRAGON_PORTAL_PROBE='0.4', DRAGON_PORTAL_IDLE='30', PYTHONDONTWRITEBYTECODE='1')
        env.update(self.extra_env)
        return env

    def run(self, cases, timeout=20):
        """Returns {name: case result}; also `self.opens`, `self.seen`, `self.cancels`, `self.gtk` (logged by the fakes)."""
        (self.fx / 'plan.json').write_text(json.dumps(self.plan))
        (self.root / 'case.json').write_text(json.dumps(dict(cases=cases, timeout=timeout)))
        done = subprocess.run(['dbus-run-session', '--', sys.executable, str(HERE / 'harness.py'), str(self.root / 'case.json')],
                              env=self.env(), capture_output=True, text=True, timeout=timeout * 3 + 30)
        self.stderr = done.stderr
        try:
            out = json.loads(done.stdout.strip().splitlines()[-1])
        except (ValueError, IndexError):
            raise AssertionError('harness failed: rc=%s\nstdout=%s\nstderr=%s' % (done.returncode, done.stdout, done.stderr))
        if not out['ready']:
            raise AssertionError('xdg-desktop-portal did not start\n' + (self.fx / 'xdp.log').read_text())
        self.opens, self.seen, self.cancels, self.gtk = ([self._log(n) for n in ('opens.log', 'seen.log', 'cancels.log', 'gtk.log')])
        return {c['name']: c for c in out['cases']}

    def _log(self, name):
        path = self.fx / name
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def seen_for(self, title):
        found = [s for s in self.seen if s['title'] == title]
        return found[0] if found else None

    def make_tree(self):
        t = self.tree
        (t / 'd').mkdir()
        (t / 'a.txt').write_text('a')
        (t / 'b.txt').write_text('b')
        (t / 'c.png').write_bytes(b'\x89PNG')
        weird = t / '-x\n#?%é.txt'
        weird.write_text('w')
        return t
