"""install.sh --dry-run / bloqueos con pacman, AUR, sudo y gum simulados: eventos JSON, texto y TUI en un pty."""
import fcntl
import json
import os
import pty
import re
import select
import struct
import subprocess
import tempfile
import termios
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ANSI = re.compile(r'\x1b\[[0-9;?]*[A-Za-z]')


class Sandbox(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.sandbox = self.base/'sandbox'; self.sandbox.mkdir()
        home = self.sandbox/'home'; home.mkdir()
        self.env = dict(os.environ, HOME=str(home), PYTHONDONTWRITEBYTECODE='1', LC_ALL='C.UTF-8',
                        PREFLIGHT_FAKE_LOG=str(self.base/'commands.jsonl'), DRAGON_PREFLIGHT_ROOT=str(self.base/'system'))
        for kind in ('CONFIG', 'STATE', 'DATA', 'CACHE', 'RUNTIME'):
            path = self.sandbox/kind.lower(); path.mkdir(mode=0o700)
            self.env['XDG_'+kind+('_DIR' if kind == 'RUNTIME' else '_HOME')] = str(path)
        system = Path(self.env['DRAGON_PREFLIGHT_ROOT'])
        (system/'etc').mkdir(parents=True)
        (system/'etc/os-release').write_text('ID=cachyos\nVERSION_ID=fake\n')
        (system/'usr/lib/modules/6.test').mkdir(parents=True)
        (system/'usr/lib/modules/6.test/pkgbase').write_text('linux-cachyos\n')
        bin_dir = self.base/'bin'; bin_dir.mkdir()
        fixture = bin_dir/'fixture'
        fixture.write_bytes((ROOT/'tests/preflight/fake-command.py').read_bytes()); fixture.chmod(0o755)
        for name in ('pacman', 'curl', 'busctl', 'systemctl', 'timedatectl', 'lspci', 'getent', 'id', 'uname',
                     'sudo', 'paru', 'yay', 'gum', 'gsettings', 'chsh', 'hyprctl', 'hyprpm', 'qs', 'snapper', 'timeshift'):
            (bin_dir/name).symlink_to(fixture)
        self.env['PATH'] = str(bin_dir) + ':/usr/bin:/bin'
        self.env.pop('HYPRLAND_INSTANCE_SIGNATURE', None)
        self.env.pop('NO_COLOR', None)
        (home/'.zshrc').write_text('# usuario\n')
        self.git_before = subprocess.check_output(['git', 'status', '--porcelain', '-z'], cwd=ROOT)
        self.before = self.snapshot()

    def snapshot(self):
        return {str(p.relative_to(self.sandbox)): (p.lstat().st_mode, p.lstat().st_mtime_ns,
                os.readlink(p) if p.is_symlink() else p.read_bytes() if p.is_file() else None)
                for p in self.sandbox.rglob('*')}

    def assert_untouched(self):
        self.assertEqual(self.before, self.snapshot(), 'el instalador escribió en HOME/XDG')
        self.assertEqual(self.git_before, subprocess.check_output(['git', 'status', '--porcelain', '-z'], cwd=ROOT))
        commands = (self.base/'commands.jsonl').read_text().splitlines() if (self.base/'commands.jsonl').exists() else []
        for line in commands:
            command = json.loads(line)
            self.assertNotIn(command[0], ('sudo', 'paru', 'yay'), 'ejecutó ' + line)
            if command[0] in ('snapper', 'timeshift'):
                self.assertFalse({'create', '--create', 'delete', 'rollback', '--restore'} & set(command[1:]), 'ejecutó ' + line)

    def execute(self, *args, **kwargs):
        return subprocess.run([str(ROOT/'install.sh'), *args], cwd=ROOT, env=self.env, text=True,
                              capture_output=True, timeout=180, **kwargs)


class JsonAndPlain(Sandbox):
    def test_json_events_dry_run(self):
        result = self.execute('--dry-run', '--yes', '--json-events', '--modules', 'core,archivos')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        events = [json.loads(line) for line in result.stdout.splitlines()]   # every line is JSON, nothing else on stdout
        phases = [e['name'] for e in events if e['event'] == 'phase']
        self.assertEqual(phases, ['Preflight', 'Plan', 'Paquetes', 'Despliegue', 'Servicios', 'Verificación'])
        self.assertTrue(any(e['event'] == 'pkg' for e in events))
        self.assertEqual(events[-1]['event'], 'done')
        self.assertEqual(events[-1]['status'], 'dry-run')
        self.assertNotIn('\x1b', result.stdout)
        self.assert_untouched()

    def test_plain_dry_run_has_no_escape_sequences(self):
        result = self.execute('--dry-run', '--yes', '--plain', '--modules', 'core,taller')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn('\x1b', result.stdout)
        for title in ('== Preflight ==', '== Plan ==', '== Paquetes ==', '== Despliegue ==', '== Servicios ==', '== Verificación =='):
            self.assertIn(title, result.stdout)
        self.assertIn('Docker', result.stdout)
        self.assert_untouched()

    def test_docker_group_is_never_added_with_yes_alone(self):
        result = self.execute('--dry-run', '--yes', '--plain', '--modules', 'core,taller')
        self.assertIn('No se añade', result.stdout)
        self.assertNotIn('usermod -aG docker', result.stdout.split('No se añade')[0].rsplit('==', 1)[-1])
        flagged = self.execute('--dry-run', '--yes', '--plain', '--docker-group', '--modules', 'core,taller')
        self.assertIn('usermod -aG docker', flagged.stdout)
        self.assert_untouched()

    def test_blocking_preflight_stops_before_touching_anything(self):
        self.env['PREFLIGHT_FAKE_MISSING'] = 'lazydocker'
        result = self.execute('--yes', '--json-events', '--modules', 'core,taller')
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        events = [json.loads(line) for line in result.stdout.splitlines()]
        self.assertEqual(events[-1]['event'], 'done')
        self.assertEqual(events[-1]['status'], 'error')
        self.assertNotIn('Paquetes', [e.get('name') for e in events if e['event'] == 'phase'])
        self.assert_untouched()

    def test_json_requires_no_terminal(self):
        # sin terminal y sin banderas: texto lineal automáticamente
        result = self.execute('--dry-run', '--yes', '--modules', 'core')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('== Preflight ==', result.stdout)
        self.assertNotIn('\x1b', result.stdout)


def run_in_pty(args, env, cols, rows, timeout=180):
    pid, fd = pty.fork()
    if pid == 0:
        os.chdir(ROOT)
        env = dict(env, TERM='xterm-256color')
        os.execve(str(ROOT/'install.sh'), [str(ROOT/'install.sh'), *args], env)
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack('HHHH', rows, cols, 0, 0))
    chunks, deadline = [], time.time() + timeout
    while time.time() < deadline:
        ready, _, _ = select.select([fd], [], [], 1)
        if ready:
            try:
                data = os.read(fd, 65536)
            except OSError:
                break
            if not data:
                break
            chunks.append(data)
        else:
            done, status = os.waitpid(pid, os.WNOHANG)
            if done:
                break
    try:
        _, status = os.waitpid(pid, 0)
    except ChildProcessError:
        status = 0
    return b''.join(chunks).decode('utf-8', 'replace'), os.waitstatus_to_exitcode(status)


class RealTerminal(Sandbox):
    def check_size(self, cols, rows):
        out, code = run_in_pty(['--dry-run', '--yes', '--modules', 'core,archivos'], self.env, cols, rows)
        self.assertEqual(code, 0, out[-2000:])
        self.assertIn('\x1b[?1049h', out)           # pantalla alternativa
        self.assertIn('\x1b[?1049l', out)           # y se devuelve al terminar
        self.assertIn('Instalación simulada', out)  # resumen final enmarcado
        frames = out.split('\x1b[H')
        self.assertGreater(len(frames), 3, 'no hubo redibujados')
        for frame in frames:
            frame = frame.split('\x1b[J')[0] if '\x1b[J' in frame else frame    # the summary comes after the last frame
            for line in ANSI.sub('', frame).replace('\r', '').split('\n'):
                self.assertLessEqual(len(line), cols, 'desborda: ' + line)
            self.assertLessEqual(ANSI.sub('', frame).replace('\r', '').count('\n'), rows, 'cuadro más alto que la terminal')
        self.assert_untouched()
        return out

    def test_tui_80_columns(self):
        out = self.check_size(80, 24)
        self.assertIn('Verificación', out)

    def test_tui_wide_terminal(self):
        self.check_size(200, 50)

    def test_plain_flag_in_a_terminal_draws_no_screen(self):
        out, code = run_in_pty(['--dry-run', '--yes', '--plain', '--modules', 'core'], self.env, 80, 24)
        self.assertEqual(code, 0)
        self.assertNotIn('\x1b[?1049h', out)
        self.assert_untouched()


if __name__ == '__main__':
    unittest.main()
