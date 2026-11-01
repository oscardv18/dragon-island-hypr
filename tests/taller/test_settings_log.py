"""Actual Settings setters -> actual Mem -> temporary SQLite. Never touches the live desktop."""
import os
from pathlib import Path
import shutil
import sqlite3
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[2]

@unittest.skipUnless(shutil.which('qs'),'Quickshell required')
class SettingsLog(unittest.TestCase):
    def test_appearance_only_changes_logged(self):
        with tempfile.TemporaryDirectory(prefix='settings-log-') as tmp:
            home=Path(tmp);(home/'runtime').mkdir(mode=0o700);cfg=home/'shell';shutil.copytree(ROOT/'config/quickshell',cfg)
            (cfg/'services/qmldir').write_text('singleton Mem 1.0 Mem.qml\nsingleton Settings 1.0 Settings.qml\n')
            bindir=home/'.local/bin';bindir.mkdir(parents=True);(bindir/'dragon-mem').symlink_to(ROOT/'bin/dragon-mem')
            env=dict(os.environ,HOME=tmp,XDG_RUNTIME_DIR=str(home/'runtime'),QT_QPA_PLATFORM='offscreen',PYTHONDONTWRITEBYTECODE='1')
            for n in ('CONFIG','DATA','STATE','CACHE'):env[f'XDG_{n}_HOME']=str(home/n.lower())
            folder=home/'config/dragon-island';folder.mkdir(parents=True);(folder/'settings.json').write_text('{"barStyle":"B","glassStyle":"ahumado","wallpaperPalette":true}')
            (cfg/'shell.qml').write_text('''import Quickshell
import QtQuick
import "services"
ShellRoot {
    Timer {
        interval: 350; running: true; repeat: true; property int step: 0
        onTriggered: {
            if (step === 0) Settings.setBarStyle("C");
            if (step === 1) Settings.setBarStyle("C");
            if (step === 2) Settings.setGlassStyle("clasico");
            if (step === 3) Settings.setWallpaperPalette(false);
            if (step === 4) Settings.setSeconds("idleWarnSeconds",123);
            if (step === 6) Qt.quit();
            step++;
        }
    }
}
''')
            r=subprocess.run(['qs','-p',str(cfg)],env=env,capture_output=True,text=True,timeout=8)
            self.assertEqual(r.returncode,0,r.stdout+r.stderr)
            self.assertNotIn('Failed to load configuration',r.stdout+r.stderr)
            db=sqlite3.connect(home/'data/dragon-island/dragon.db')
            try:
                rows=db.execute('select key,old,new,source from system_change order by id').fetchall()
                self.assertEqual(rows,[('barStyle','"B"','"C"','settings'),('glassStyle','"ahumado"','"clasico"','settings'),('wallpaperPalette','true','false','settings')])
            finally:db.close()
