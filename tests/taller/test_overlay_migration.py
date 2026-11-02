"""Taller overlay update: copied installs, dry run, backup and repeat application."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]

class OverlayMigration(unittest.TestCase):
    def test_copy_dry_run_backup_and_idempotence(self):
        self.check_migration("093-taller-overlays", "093-taller-overlays-files.txt")

    def test_main_panel_glass_migration(self):
        self.check_migration("094-panel-glass", "094-panel-glass-files.txt")

    def check_migration(self, migration, manifest):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            cfg = home / "config/quickshell"
            cfg.mkdir(parents=True)
            (cfg / "Theme.qml").write_text("old theme")
            env = dict(os.environ, HOME=tmp, XDG_CONFIG_HOME=str(home / "config"),
                       XDG_STATE_HOME=str(home / "state"), BACKUP_DIR=str(home / "backup"),
                       REPO_DIR=str(ROOT), LINK_MODE="copy", ASSUME_YES="true")
            def snapshot():
                return {str(p.relative_to(home)): p.read_bytes()
                        for p in home.rglob("*") if p.is_file()}
            def run(dry):
                result = subprocess.run(["bash", str(ROOT / "migrations" / (migration + ".sh"))],
                                        env=dict(env, DRY_RUN=dry), capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            before = snapshot()
            run("true")
            self.assertEqual(before, snapshot())
            run("false")
            files = (ROOT / "migrations" / manifest).read_text().splitlines()
            for rel in files:
                self.assertEqual((cfg / rel).read_bytes(), (ROOT / "config/quickshell" / rel).read_bytes())
            self.assertTrue(any(p.read_bytes() == b"old theme" for p in (home / "backup").rglob("*") if p.is_file()))
            before = snapshot()
            run("false")
            self.assertEqual(before, snapshot())
