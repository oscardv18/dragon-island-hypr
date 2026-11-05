"""Migration 194 / usb_audio_quirks_setup: /etc/modprobe.d/dragon-usb-audio.conf through a fake sudo into a temporary
folder. Installed once (idempotent), the old hand-made jieli-headset-mic.conf removed only when it carries our exact
options, and nothing written with DRY_RUN or NO_SUDO (both exit 10 so update.sh retries)."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / 'config/modprobe.d/dragon-usb-audio.conf'
OPTIONS = 'options snd-usb-audio quirk_alias=4c4a4155:12242a25 quirk_flags=1224:2a25:!mic_res_16'


class UsbAudioQuirks(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory(prefix='usb-audio-194-')
        self.addCleanup(tmp.cleanup)
        self.t = Path(tmp.name)
        self.home = self.t / 'home with spaces'
        self.home.mkdir()
        self.etc = self.t / 'etc/modprobe.d'
        shims = self.t / 'shims'
        shims.mkdir()
        self.sudo_log = self.t / 'sudo.log'
        (shims / 'sudo').write_text(f'#!/usr/bin/env bash\necho "$*" >> "{self.sudo_log}"\nexec "$@"\n')
        (shims / 'sudo').chmod(0o755)
        self.env = dict(os.environ, HOME=str(self.home), REPO_DIR=str(ROOT), XDG_STATE_HOME=str(self.home / '.local/state'),
                        DRAGON_MODPROBE_DIR=str(self.etc), ASSUME_YES='true', PATH=f'{shims}:{os.environ["PATH"]}')

    def migrate(self, code=0, **extra):
        r = subprocess.run(['bash', str(ROOT / 'migrations/194-usb-audio-quirks.sh')], env=dict(self.env, **extra),
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, code, r.stdout + r.stderr)
        return r

    def sudo_calls(self):
        return self.sudo_log.read_text().splitlines() if self.sudo_log.exists() else []

    def test_repo_file_has_the_options(self):
        self.assertIn(OPTIONS, SRC.read_text().splitlines())

    def test_installs_once(self):
        self.migrate()
        dest = self.etc / 'dragon-usb-audio.conf'
        self.assertEqual(dest.read_bytes(), SRC.read_bytes())
        self.assertEqual(oct(dest.stat().st_mode & 0o777), '0o644')
        self.assertEqual(len(self.sudo_calls()), 1)
        self.migrate()                              # already up to date: no sudo at all
        self.assertEqual(len(self.sudo_calls()), 1)

    def test_legacy_file_with_our_options_is_removed(self):
        self.etc.mkdir(parents=True)
        (self.etc / 'jieli-headset-mic.conf').write_text('# mine, by hand\n' + OPTIONS + '\n')
        self.migrate()
        self.assertFalse((self.etc / 'jieli-headset-mic.conf').exists())
        self.assertTrue((self.etc / 'dragon-usb-audio.conf').exists())

    def test_legacy_file_with_other_options_is_kept(self):
        self.etc.mkdir(parents=True)
        (self.etc / 'jieli-headset-mic.conf').write_text(OPTIONS + '\noptions snd-usb-audio implicit_fb=1\n')
        self.migrate()
        self.assertTrue((self.etc / 'jieli-headset-mic.conf').exists())

    def test_dry_run_and_no_sudo_write_nothing(self):
        r = self.migrate(code=0, DRY_RUN='true')
        self.assertIn('[dry-run] sudo install', r.stdout + r.stderr)
        self.migrate(code=10, NO_SUDO='true')
        self.assertFalse(self.etc.exists())
        self.assertEqual(self.sudo_calls(), [])


if __name__ == '__main__':
    unittest.main()
