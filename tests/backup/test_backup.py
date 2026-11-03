"""backup-dragon.sh / restore-dragon.sh en un HOME temporal: base SQLite viva, dry-run, listas sin copiar, restauración."""
import os
import sqlite3
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BACKUP = ROOT/'scripts/backup-dragon.sh'
RESTORE = ROOT/'scripts/restore-dragon.sh'


class Backup(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.home = self.base/'home'; self.home.mkdir()
        self.env = dict(os.environ, HOME=str(self.home), LC_ALL='C.UTF-8', DRAGON_REPOS=str(self.home/'Devs'),
                        XDG_DATA_HOME=str(self.home/'.local/share'), XDG_CONFIG_HOME=str(self.home/'.config'),
                        PATH='/usr/bin:/bin')
        data = self.home/'.local/share/dragon-island'; data.mkdir(parents=True)
        # live WAL database: the newest rows exist only in dragon.db-wal, so cp of dragon.db alone would lose them
        self.live = sqlite3.connect(data/'dragon.db')
        self.live.execute('PRAGMA journal_mode=WAL'); self.live.execute('PRAGMA wal_autocheckpoint=0')
        self.live.execute('CREATE TABLE notas (id INTEGER PRIMARY KEY, texto TEXT)')
        self.live.executemany('INSERT INTO notas (texto) VALUES (?)', [('nota %d' % i,) for i in range(50)])
        self.live.commit()
        self.addCleanup(self.live.close)
        config = self.home/'.config/dragon-island'; config.mkdir(parents=True)
        (config/'settings.json').write_text('{"wallpaperDir": "~/Pictures/Wallpapers"}\n')
        keyrings = self.home/'.local/share/keyrings'; keyrings.mkdir(parents=True)
        (keyrings/'login.keyring').write_bytes(b'GnomeKeyring\n\r\0\n' + b'SECRETO-CIFRADO-NO-DEBE-IMPRIMIRSE')
        ssh = self.home/'.ssh'; ssh.mkdir(); (ssh/'id_ed25519').write_text('CLAVE PRIVADA DE PRUEBA')
        (self.home/'.config/BraveSoftware').mkdir(parents=True)
        # a repository with a branch that was never pushed
        repo = self.home/'Devs/proyecto'; repo.mkdir(parents=True)
        git = lambda *a: subprocess.run(['git', '-C', str(repo), '-c', 'user.name=t', '-c', 'user.email=t@t', *a],
                                        check=True, capture_output=True)
        git('init', '-q', '-b', 'main'); (repo/'a').write_text('x'); git('add', 'a'); git('commit', '-qm', 'uno')
        git('checkout', '-q', '-b', 'sin-subir')
        self.dest = self.base/'respaldo'

    def run_script(self, script, *args, check=True):
        result = subprocess.run([str(script), *args], env=self.env, text=True, capture_output=True, timeout=60)
        if check:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def tree(self, root):
        return sorted(str(p.relative_to(root)) for p in root.rglob('*'))

    def test_dry_run_writes_nothing(self):
        before = self.tree(self.home)
        result = self.run_script(BACKUP, '--dest', str(self.dest), '--dry-run')
        self.assertFalse(self.dest.exists())
        self.assertEqual(before, self.tree(self.home))
        self.assertIn('[dry-run]', result.stdout)

    def test_database_copy_is_consistent_even_with_unflushed_wal(self):
        self.run_script(BACKUP, '--dest', str(self.dest))
        copy = sqlite3.connect(self.dest/'dragon.db')
        self.addCleanup(copy.close)
        self.assertEqual(copy.execute('SELECT count(*) FROM notas').fetchone()[0], 50)
        self.assertEqual(copy.execute('PRAGMA integrity_check').fetchone()[0], 'ok')

    def test_copies_config_and_keyrings_with_private_modes(self):
        self.run_script(BACKUP, '--dest', str(self.dest))
        self.assertTrue((self.dest/'config-dragon-island/settings.json').is_file())
        self.assertTrue((self.dest/'keyrings/login.keyring').is_file())
        self.assertEqual(self.dest.stat().st_mode & 0o077, 0)
        self.assertEqual((self.dest/'keyrings/login.keyring').stat().st_mode & 0o077, 0)
        self.assertTrue((self.dest/'MANIFEST.sha256').is_file())

    def test_no_keyrings_flag(self):
        self.run_script(BACKUP, '--dest', str(self.dest), '--no-keyrings')
        self.assertFalse((self.dest/'keyrings').exists())

    def test_sensitive_list_is_printed_but_never_copied_or_revealed(self):
        result = self.run_script(BACKUP, '--dest', str(self.dest))
        out = result.stdout
        self.assertIn('claves SSH', out)
        self.assertIn('perfil de navegador', out)
        self.assertIn('sin-subir', out)
        self.assertNotIn('CLAVE PRIVADA', out + result.stderr)
        self.assertNotIn('SECRETO-CIFRADO', out + result.stderr)
        self.assertEqual([p for p in self.tree(self.dest) if 'ssh' in p or 'id_ed25519' in p or 'Brave' in p], [])

    def test_refuses_a_non_empty_destination(self):
        self.dest.mkdir(); (self.dest/'algo').write_text('x')
        result = self.run_script(BACKUP, '--dest', str(self.dest), check=False)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.tree(self.dest), ['algo'])

    def test_restore_round_trip_keeps_what_it_replaces(self):
        self.run_script(BACKUP, '--dest', str(self.dest))
        self.live.execute("DELETE FROM notas"); self.live.commit()
        (self.home/'.config/dragon-island/settings.json').write_text('{"roto": true}\n')
        self.live.close()
        self.run_script(RESTORE, str(self.dest), '--yes')
        restored = sqlite3.connect(self.home/'.local/share/dragon-island/dragon.db')
        self.addCleanup(restored.close)
        self.assertEqual(restored.execute('SELECT count(*) FROM notas').fetchone()[0], 50)
        self.assertIn('wallpaperDir', (self.home/'.config/dragon-island/settings.json').read_text())
        asides = [p.name for p in (self.home/'.config').iterdir() if '.pre-restore-' in p.name]
        self.assertEqual(len(asides), 1)
        self.assertIn('roto', (self.home/'.config'/asides[0]/'settings.json').read_text())
        self.assertTrue(list((self.home/'.local/share/dragon-island').glob('dragon.db.pre-restore-*')))

    def test_restore_does_not_touch_keyrings_without_the_flag(self):
        self.run_script(BACKUP, '--dest', str(self.dest))
        keyring = self.home/'.local/share/keyrings/login.keyring'
        keyring.write_bytes(b'otro llavero')
        result = self.run_script(RESTORE, str(self.dest), '--yes')
        self.assertEqual(keyring.read_bytes(), b'otro llavero')
        self.assertIn('--with-keyrings', result.stdout)

    def test_restore_dry_run_writes_nothing(self):
        self.run_script(BACKUP, '--dest', str(self.dest))
        self.live.close()
        before = [(p, p.stat().st_mtime_ns) for p in sorted(self.home.rglob('*'))]
        self.run_script(RESTORE, str(self.dest), '--yes', '--dry-run')
        self.assertEqual(before, [(p, p.stat().st_mtime_ns) for p in sorted(self.home.rglob('*'))])

    def test_restore_refuses_a_corrupted_backup(self):
        self.run_script(BACKUP, '--dest', str(self.dest))
        (self.dest/'config-dragon-island/settings.json').write_text('manipulado')
        result = self.run_script(RESTORE, str(self.dest), '--yes', check=False)
        self.assertEqual(result.returncode, 1)
        self.assertNotIn('manipulado', (self.home/'.config/dragon-island/settings.json').read_text())


if __name__ == '__main__':
    unittest.main()
