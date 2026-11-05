"""rc2: sintaxis de hyprctl de Hyprland 0.57 (config Lua) sin regresiones · KWallet: aviso y desactivación con confirmación."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

from tests.installer_ux.test_rc1 import run_pty, script
from tests.tui.test_install_modes import ROOT

# Third-party references and historic design notes are not code of this repo.
# (docs/VIRTUALBOX.md and the rc2 handoff quote the old syntax on purpose, as the thing that no longer works)
SKIP = ('.agents/', 'quickshell/', 'docs/design/', 'tests/', 'dragon-core/prompts/', 'docs/VIRTUALBOX.md', 'docs/handoff-instalador-rc2.md')
STUBS = Path('/usr/share/hypr/stubs/hl.meta.lua')

# `hyprctl [flags] dispatch <arg>`: in 0.57 the arg is a Lua expression, e.g. 'hl.dsp.exec_cmd("kitty")'
SHELL_DISPATCH = re.compile(r'''hyprctl\b(?:\s+-[-\w]+(?:\s+\w+)?)*\s+dispatch\s+(?P<arg>\S.*)''')
QML_DISPATCH = re.compile(r'''Hyprland\.dispatch\(\s*(?P<arg>["'`].*)''')
PY_DISPATCH = re.compile(r'''\[\s*['"]dispatch['"]\s*,\s*(?P<arg>.*)''')


def old_syntax(line):
    """The offending argument if `line` calls a dispatcher with the pre-Lua syntax, else None."""
    m = SHELL_DISPATCH.search(line)
    if m and not re.match(r'''["']?hl\.''', m['arg']):
        return m['arg']
    m = QML_DISPATCH.search(line)
    if m and 'usingLua' not in line and not re.match(r'''["'`]hl\.''', m['arg']):
        return m['arg']
    m = PY_DISPATCH.search(line)
    if m and not re.match(r'''["']hl\.''', m['arg']):
        return m['arg']
    return None


def tracked():
    out = subprocess.check_output(['git', 'ls-files'], cwd=ROOT, text=True).splitlines()
    for rel in out:
        if rel.startswith(SKIP) or rel.endswith(('.png', '.jpg', '.svg', '.webp', '.ttf', '.otf', '.gif')):
            continue
        yield rel


class HyprctlSyntax(unittest.TestCase):
    def test_checker_catches_the_old_syntax(self):
        for line in ('hyprctl dispatch exec kitty', 'hyprctl dispatch killactive', 'hyprctl --instance 0 dispatch exec hyprlock',
                     'Hyprland.dispatch("workspace 3")', "Hyprland.dispatch(`closewindow address:${a}`)", "hypr(['dispatch','focuswindow x'])"):
            self.assertIsNotNone(old_syntax(line), line)
        for line in ("hyprctl dispatch 'hl.dsp.exec_cmd(\"kitty\")'", 'hyprctl dispatch "hl.dsp.focus({ window = 1 })"',
                     'Hyprland.dispatch(root.usingLua ? `hl.dsp.focus()` : "x")', 'Hyprland.dispatch(command)',
                     "hypr(['dispatch','hl.dsp.focus({})'])"):
            self.assertIsNone(old_syntax(line), line)

    def test_no_old_dispatch_syntax_in_the_repo(self):
        found = []
        for rel in tracked():
            path = ROOT/rel
            if not path.is_file():
                continue
            try:
                text = path.read_text()
            except UnicodeDecodeError:
                continue
            for number, line in enumerate(text.splitlines(), 1):
                bad = old_syntax(line)
                if bad:
                    found.append(f'{rel}:{number}: {bad[:80]}')
        self.assertEqual(found, [], 'sintaxis antigua de hyprctl dispatch (usa hl.dsp.*, Hyprland 0.57):\n' + '\n'.join(found))

    @unittest.skipUnless(STUBS.exists(), 'sin los stubs de la API Lua de Hyprland instalados')
    def test_every_dispatcher_used_exists_in_the_installed_api(self):
        stubs = STUBS.read_text()
        top = set(re.findall(r'---@field (\w+) fun', stubs[stubs.index('---@class HL.DspNamespace'):stubs.index('---@class HL.DspCursorNamespace')]))
        sections = {}
        for ns, name in (('window', 'DspWindowNamespace'), ('workspace', 'DspWorkspaceNamespace'), ('group', 'DspGroupNamespace'), ('cursor', 'DspCursorNamespace')):
            block = stubs[stubs.index(f'---@class HL.{name}'):]
            sections[ns] = set(re.findall(r'---@field (\w+) fun', block.split('\n\n')[0]))
        missing = []
        for rel in tracked():
            if not rel.startswith(('config/', 'bin/', 'dragon-core/', 'scripts/')):
                continue
            try:
                text = (ROOT/rel).read_text()
            except (UnicodeDecodeError, IsADirectoryError):
                continue
            for ns, fn in re.findall(r'hl\.dsp\.(?:(window|workspace|group|cursor)\.)?(\w+)', text):
                if (ns and fn not in sections[ns]) or (not ns and fn not in top):
                    missing.append(f'{rel}: hl.dsp.{ns + "." if ns else ""}{fn}')
        self.assertEqual(sorted(set(missing)), [])


class MainModifier(unittest.TestCase):
    def modifier(self, conf):
        d = Path(tempfile.mkdtemp()); self.addCleanup(shutil.rmtree, d, True)
        (d/'dragon-island').mkdir()
        if conf is not None:
            (d/'dragon-island/local.conf').write_text(conf)
        src = (ROOT/'config/hypr/binds.lua').read_text()
        block = src[src.index('local mainMod = "SUPER"'):src.index('\nend', src.index('local mainMod = "SUPER"')) + 4]
        code = f'local function getenv_stub() end\n{block}\nprint(mainMod)'
        r = subprocess.run(['lua', '-e', code], env=dict(os.environ, XDG_CONFIG_HOME=str(d)), capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        return r.stdout.strip()

    def test_default_and_overrides(self):
        self.assertEqual(self.modifier(None), 'SUPER')
        self.assertEqual(self.modifier('KB_LAYOUTS=us\nMAIN_MOD=ALT\n'), 'ALT')
        self.assertEqual(self.modifier('MAIN_MOD=CTRL\n'), 'CTRL')
        self.assertEqual(self.modifier('MAIN_MOD=SHIFT\n'), 'SUPER')          # anything else falls back


class KWallet(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp()); self.addCleanup(shutil.rmtree, self.tmp, True)
        self.bin = self.tmp/'bin'; self.bin.mkdir()
        self.log = self.tmp/'calls.log'
        script(self.bin/'pacman', '#!/bin/sh\n[ "$1" = -Qq ] && [ "$2" = "$FAKE_PKG" ] && exit 0\nexit 1\n')
        script(self.bin/'kreadconfig6', '#!/bin/sh\necho "$FAKE_API"\n')
        script(self.bin/'kwriteconfig6', f'#!/bin/sh\necho "kwriteconfig6 $*" >> "{self.log}"\n')
        self.cfg = self.tmp/'cfg'; self.cfg.mkdir()
        (self.cfg/'kwalletrc').write_text('[Wallet]\nEnabled=true\n')
        self.env = dict(os.environ, HOME=str(self.tmp), XDG_CONFIG_HOME=str(self.cfg), XDG_STATE_HOME=str(self.tmp/'state'),
                        PATH=f'{self.bin}:/usr/bin:/bin', FAKE_PKG='kwallet', FAKE_API='', TERM='xterm', DRAGON_NO_GUM='1')

    def code(self, dry='false', yes='false'):
        return f'''set -uo pipefail
REPO_DIR="{ROOT}"; STATE_DIR="$HOME/state"; BACKUP_DIR="$HOME/backups"; DRY_RUN={dry}; ASSUME_YES={yes}; NO_SUDO=false
. "$REPO_DIR/lib/common.sh"; . "$REPO_DIR/modules/keyring.sh"
keyring_kwallet_offer; echo "MANUAL=${{#MANUAL_ITEMS[@]}}"'''

    def test_absent_kwallet_is_silent(self):
        out, code = run_pty(self.code(), dict(self.env, FAKE_PKG='nada'), [])
        self.assertNotIn('KWallet', out)
        self.assertFalse(self.log.exists())

    def test_warns_and_changes_nothing_without_a_yes(self):
        out, code = run_pty(self.code(yes='true'), self.env, [])          # --yes never answers it
        self.assertIn('KWallet está presente', out)
        self.assertFalse(self.log.exists())
        self.assertIn('MANUAL=1', out)

    def test_confirmed_disables_only_the_secret_service_with_backup(self):
        out, code = run_pty(self.code(), self.env, [('[s/N]', 's\n')])
        self.assertIn('kwriteconfig6 --file kwalletrc --group org.freedesktop.secrets --key apiEnabled false', self.log.read_text())
        self.assertTrue(list((self.tmp/'backups').rglob('kwalletrc')), 'sin copia de seguridad')
        self.assertIn('MANUAL=0', out)

    def test_declined_keeps_it_and_lists_the_command(self):
        out, code = run_pty(self.code(), self.env, [('[s/N]', 'n\n')])
        self.assertFalse(self.log.exists())
        self.assertIn('MANUAL=1', out)

    def test_already_disabled_is_left_alone(self):
        out, code = run_pty(self.code(), dict(self.env, FAKE_API='false'), [])
        self.assertFalse(self.log.exists())
        self.assertIn('ya tiene desactivado', out)

    def test_dry_run_writes_nothing(self):
        out, code = run_pty(self.code(dry='true'), self.env, [])
        self.assertIn('[dry-run]', out)
        self.assertFalse(self.log.exists())
        self.assertFalse((self.tmp/'backups').exists())


if __name__ == '__main__':
    unittest.main()
