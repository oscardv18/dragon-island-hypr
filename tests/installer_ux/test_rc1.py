"""rc1: plugins.lua sin claves plugin.* si el plugin no está cargado · primer arranque con notificaciones · doctor (bluetooth sin adaptador,
llavero solo en sesión gráfica, plugins y configerrors) · módulo boot con vista previa y confirmación mínima. hyprctl, hyprpm, notify-send y /sys FALSOS."""
import os
from pathlib import Path
import pty
import select
import shutil
import subprocess
import tempfile
import time
import unittest

from tests.boot.test_boot import Module
from tests.tui.test_install_modes import ROOT


def script(path, text):
    path.write_text(text); path.chmod(0o755)


class PluginsLua(unittest.TestCase):
    def run_lua(self, plugin_table):
        code = f'''
local calls = {{}}
hl = {{ config = function(t) calls[#calls + 1] = t end, animation = function() end, window_rule = function() end, plugin = {plugin_table} }}
dofile("{ROOT}/config/hypr/plugins.lua")
local n = 0
for _, t in ipairs(calls) do if t.plugin then n = n + 1 end end
print(n)
'''
        r = subprocess.run(['lua', '-e', code], capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        return int(r.stdout.strip())

    def test_no_plugin_keys_without_the_plugin(self):
        self.assertEqual(self.run_lua('nil'), 0)
        self.assertEqual(self.run_lua('{}'), 0)

    def test_keys_when_hyprfocus_is_loaded(self):
        self.assertEqual(self.run_lua('{ hyprfocus = {} }'), 1)


class FirstRun(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp()); self.addCleanup(shutil.rmtree, self.tmp, True)
        self.bin = self.tmp/'bin'; self.bin.mkdir()
        self.log = self.tmp/'calls.log'
        for name in ('hyprctl', 'hyprpm', 'notify-send'):
            script(self.bin/name, f'#!/bin/sh\necho "{name} $*" >> "{self.log}"\n'
                   + {'hyprctl': 'case "$1 $2" in "plugin list") cat "$FAKE_LOADED" 2>/dev/null;; "version -j") echo "{\\"tag\\":\\"$FAKE_TAG\\"}";; esac\n',
                      'hyprpm': '[ "$1" = update ] && [ -n "$FAKE_UPDATE_FAILS" ] && exit 1\n[ "$1" = list ] && echo "hyprland-plugins HyprGlass"\n',
                      'notify-send': ''}[name] + 'exit 0\n')
        self.loaded = self.tmp/'loaded'
        self.loaded.write_text('plugin hyprfocus\nplugin hyprglass\n  Version: 0.9.1\n')
        self.state = self.tmp/'state'
        self.env = dict(os.environ, PATH=f'{self.bin}:{os.environ["PATH"]}', XDG_STATE_HOME=str(self.state), HOME=str(self.tmp),
                        HYPRLAND_INSTANCE_SIGNATURE='fake', FAKE_LOADED=str(self.loaded), FAKE_UPDATE_FAILS='', FAKE_TAG='v0.57.0')
        (self.state/'dragon-island').mkdir(parents=True)
        (self.state/'dragon-island/plugins.pending').touch()

    def run_script(self, **extra):
        return subprocess.run([str(ROOT/'scripts/plugins-foreground.sh')], env=dict(self.env, **extra), stdin=subprocess.DEVNULL,
                              capture_output=True, text=True, timeout=60)

    def notifications(self):
        return [l for l in self.log.read_text().splitlines() if l.startswith('notify-send')]

    def test_success_notifies_start_and_end_and_clears_the_marker(self):
        r = self.run_script()
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        text = ' | '.join(self.notifications())
        self.assertIn('Compilando plugins…', text)
        self.assertIn('Plugins listos', text)
        self.assertNotIn('Plugins con error', text)
        calls = self.log.read_text()
        for needle in ('hyprpm update', 'hyprpm enable hyprfocus', 'hyprpm enable hyprglass', 'hyprpm reload -n', 'hyprctl reload'):
            self.assertIn(needle, calls)
        self.assertFalse((self.state/'dragon-island/plugins.pending').exists())
        self.assertTrue((self.state/'dragon-island/firstrun.done').exists())

    def test_failure_notifies_the_error_and_keeps_it_pending(self):
        r = self.run_script(FAKE_UPDATE_FAILS='1')
        self.assertNotEqual(r.returncode, 0)
        text = ' | '.join(self.notifications())
        self.assertIn('Compilando plugins…', text)
        self.assertIn('Plugins con error', text)
        self.assertNotIn('Plugins listos', text)
        self.assertTrue((self.state/'dragon-island/plugins.pending').exists())

    def test_other_hyprland_series_stops_before_compiling(self):
        r = self.run_script(FAKE_TAG='v0.56.2')
        self.assertNotEqual(r.returncode, 0)
        self.assertIn('no es la fijada', r.stdout + r.stderr)
        self.assertIn('git pull', r.stdout + r.stderr)
        self.assertNotIn('hyprpm update', self.log.read_text())
        self.assertIn('Plugins con error', ' | '.join(self.notifications()))
        self.assertTrue((self.state/'dragon-island/plugins.pending').exists())

    def test_pinned_series_compiles(self):
        r = self.run_script(FAKE_TAG='v0.57.3')
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn('hyprpm update', self.log.read_text())

    def test_plugin_not_loaded_is_an_error(self):
        self.loaded.write_text('plugin hyprfocus\n')
        r = self.run_script()
        self.assertNotEqual(r.returncode, 0)
        self.assertIn('Plugins con error', ' | '.join(self.notifications()))


class Doctor(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp()); self.addCleanup(shutil.rmtree, self.tmp, True)
        self.sys = self.tmp/'sys'; (self.sys/'class/bluetooth').mkdir(parents=True)
        (self.tmp/'state/dragon-island').mkdir(parents=True); (self.tmp/'state/dragon-island/modules').write_text('core\n')
        self.bin = self.tmp/'bin'; self.bin.mkdir()
        script(self.bin/'hyprctl', '#!/bin/sh\ncase "$1" in configerrors) [ -n "$FAKE_CFGERR" ] && echo "$FAKE_CFGERR";; plugin) cat "$FAKE_LOADED";; version) echo "{\\"tag\\":\\"$FAKE_TAG\\"}";; esac\nexit 0\n')
        script(self.bin/'systemctl', '#!/bin/sh\nexit 1\n')
        self.loaded = self.tmp/'loaded'; self.loaded.write_text('plugin hyprfocus\nplugin hyprglass\n')
        self.env = dict(os.environ, HOME=str(self.tmp), XDG_STATE_HOME=str(self.tmp/'state'), XDG_CONFIG_HOME=str(self.tmp/'cfg'),
                        DRAGON_SYSFS=str(self.sys), PATH=f'{self.bin}:{os.environ["PATH"]}', FAKE_LOADED=str(self.loaded), FAKE_CFGERR='', FAKE_TAG='v0.57.0')
        for k in ('WAYLAND_DISPLAY', 'DISPLAY', 'HYPRLAND_INSTANCE_SIGNATURE'):
            self.env.pop(k, None)

    def doctor(self, **extra):
        r = subprocess.run([str(ROOT/'doctor.sh'), '--no-ask'], env=dict(self.env, **extra), stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=120)
        return r.stdout

    def test_bluetooth_not_applicable_without_adapter(self):
        out = self.doctor()
        self.assertIn('bluetooth activo: no aplica', out)
        self.assertNotIn('Servicio bluetooth activo', out)
        (self.sys/'class/bluetooth/hci0').mkdir()
        self.assertIn('Servicio bluetooth activo', self.doctor())

    def test_keyring_only_in_a_graphic_session(self):
        self.assertIn('sin sesión gráfica', self.doctor())
        self.assertNotIn('Llavero «login»', self.doctor())
        graphic = self.doctor(WAYLAND_DISPLAY='wayland-9')
        self.assertNotIn('sin sesión gráfica', graphic)
        self.assertTrue('Llavero «login»' in graphic or 'org.freedesktop.secrets' in graphic)

    def test_inside_hyprland_checks_configerrors_and_plugins(self):
        env = dict(HYPRLAND_INSTANCE_SIGNATURE='fake')
        out = self.doctor(**env)
        self.assertIn('✔', out.split('hyprctl configerrors vacío')[0].rsplit('\n', 1)[-1])
        self.assertIn('Plugin hyprfocus cargado', out)
        bad = self.doctor(FAKE_CFGERR='unknown config key plugin.hyprfocus.shrink_percentage', **env)
        self.assertIn('✘', bad.split('hyprctl configerrors vacío')[0].rsplit('\n', 1)[-1])
        self.loaded.write_text('')
        gone = self.doctor(**env)
        self.assertIn('✘', gone.split('Plugin hyprfocus cargado')[0].rsplit('\n', 1)[-1])

    def test_pinned_hyprland_version_is_compared(self):
        self.assertIn('Versión de Hyprland = fijada', self.doctor())
        bad = self.doctor(FAKE_TAG='v0.56.2')
        self.assertIn('Versión de Hyprland distinta de la fijada', bad)
        self.assertIn('git pull && ./update.sh', bad)

    def test_hyprpm_prerequisites_are_checked(self):
        out = self.doctor()
        for p in ('hyprpm', 'cmake', 'meson', 'ninja', 'cpio', 'pkgconf', 'git', 'gcc'):
            self.assertIn(f'Paquete {p} (prerrequisito de hyprpm)', out)


def run_pty(args_script, env, answers):
    pid, fd = pty.fork()
    if pid == 0:
        os.execve('/bin/bash', ['bash', '-c', args_script], env)
    seen, out, deadline = b'', b'', time.time() + 90
    pending = list(answers)
    while time.time() < deadline:
        ready, _, _ = select.select([fd], [], [], 1)
        if ready:
            try:
                data = os.read(fd, 65536)
            except OSError:
                break
            if not data:
                break
            out += data; seen += data
            while pending and pending[0][0].encode() in seen:
                needle, typed = pending.pop(0)
                seen = seen.split(needle.encode(), 1)[1]
                os.write(fd, typed.encode())
    _, status = os.waitpid(pid, 0)
    return out.decode('utf-8', 'replace'), os.waitstatus_to_exitcode(status)


class BootMinimalUI(Module):
    def pty(self, code, answers):
        env = dict(os.environ, HOME=str(self.home), REPO_DIR=str(ROOT), BOOT_SUDO='', BOOT_ESP=str(self.esp), BOOT_SYSTEM_DIR=str(self.system),
                   BOOT_HOOK_DIR=str(self.hooks), BOOT_ROOT=str(self.tmp/'noroot'), PYTHONDONTWRITEBYTECODE='1', PATH=self.env['PATH'], TERM='xterm', DRAGON_NO_GUM='1')
        env.pop('DRAGON_BOOT_ASSUME_YES', None)
        text = f'''set -Eeuo pipefail
REPO_DIR="{ROOT}"; DRY_RUN=false; ASSUME_YES=true; NO_SUDO=false; LINK_MODE=symlink
. "$REPO_DIR/lib/common.sh"; . "$REPO_DIR/modules/boot.sh"
{code}'''
        return run_pty(text, env, answers)

    def test_preview_then_confirmation_in_the_linear_flow(self):
        from tests.boot.test_boot import sha
        before = sha(self.conf)
        out, code = self.pty('boot_apply', [('[s/N]', 's\n'), ('[s/N]', 's\n')])
        self.assertEqual(code, 0, out[-2000:])
        preview = self.home/'.local/state/dragon-island/boot-preview.png'
        self.assertTrue(preview.is_file(), out[-1500:])
        self.assertIn('Vista previa', out)
        self.assertNotEqual(sha(self.conf), before)
        self.assertEqual(len(self.backups()), 1, 'sin copia de seguridad')

    def test_answering_no_changes_nothing(self):
        from tests.boot.test_boot import sha
        before = sha(self.conf)
        out, code = self.pty('boot_apply', [('[s/N]', '\n')])
        self.assertEqual(code, 0, out[-1500:])
        self.assertEqual(sha(self.conf), before)
        self.assertFalse(self.system.exists())

    def test_revert_asks_and_undoes(self):
        original = self.conf.read_text()
        self.sh('boot_apply', DRAGON_BOOT_ASSUME_YES='1')
        self.assertNotEqual(self.conf.read_text(), original)
        out, code = self.pty('boot_revert_all', [('[s/N]', 's\n')])
        self.assertEqual(code, 0, out[-1500:])
        self.assertEqual(self.conf.read_text(), original)


if __name__ == '__main__':
    unittest.main()
