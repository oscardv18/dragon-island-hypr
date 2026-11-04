"""UX2: a failing step never reaches the success summary; the terminal is yielded to interactive commands.

paru that asks for the sudo password on the terminal, paru that fails, paru that does not exist, paru that «succeeds» without
installing: every case ends with an honest summary (no «?», «incompleta» when something is missing) and a non-zero exit code."""
import os
from pathlib import Path
import re
import subprocess
import unittest

from tests.installer_ux.ptyutil import run_interactive
from tests.installer_ux.test_ux import ANSI, ROOT, UX

CLEAN_DOCTOR = '#!/bin/sh\necho "Todo en orden"\nexit 0\n'


class Flow(UX):
    def setUp(self):
        super().setUp()
        self.doctor(CLEAN_DOCTOR)

    def doctor(self, text):
        path = self.base/'doctor-fake.sh'
        path.write_text(text); path.chmod(0o755)
        self.env['DRAGON_DOCTOR'] = str(path)

    def no_helper(self):
        for name in ('paru', 'yay'):
            link = self.base/'bin'/name
            if link.is_symlink():
                link.unlink()
        self.env['FAKE_NO_PARU_REPO'] = '1'
        (self.state/'installed').write_text('\n'.join(BASE_INSTALLED) + '\n')
        

    def run_pty(self, *args, answers=(), modules='core'):
        out, code = run_interactive(['--modules', modules, *args], self.env, answers=answers, timeout=240)
        return out, ANSI.sub('', out).replace('\r', ''), code

    def box(self, plain):
        return plain[plain.rindex('╭'):] if '╭' in plain else plain


BASE_INSTALLED = ['git', 'base-devel', 'gum', 'curl', 'unzip', 'pciutils', 'linux-cachyos-headers', 'sddm']


class ParuCases(Flow):
    def test_paru_asks_the_password_on_the_terminal_and_the_tui_yields(self):
        self.env['FAKE_PARU_MODE'] = 'tty'
        raw, plain, code = self.run_pty(answers=[('contraseña', 'x\n')] * 4)
        self.assertEqual(code, 0, plain[-2500:])
        # the prompt appears while the alternate screen is OFF (the last toggle before it is «leave»)…
        at = raw.index('[sudo] contraseña')
        before = raw[:at]
        self.assertGreater(before.rfind('\x1b[?1049l'), before.rfind('\x1b[?1049h'), 'la TUI no cedió el terminal al pedir la contraseña')
        # …and the TUI comes back afterwards with its state (the phase bar still knows the finished phases)
        after = raw[at:]
        self.assertIn('\x1b[?1049h', after)
        self.assertIn('Instalación terminada', ANSI.sub('', after))
        self.assertNotRegex(self.box(plain), r'• \w+: \?')
        self.assertIn('• core: ok', plain)

    def test_paru_fails_modules_still_deploy_and_summary_is_incomplete(self):
        self.env['FAKE_PARU_MODE'] = 'fail'
        raw, plain, code = self.run_pty()
        self.assertEqual(code, 1, plain[-2500:])
        box = self.box(plain)
        self.assertIn('INCOMPLETA', box)
        self.assertIn('grimblast-git', box)
        self.assertIn('no se pudo compilar', box)
        self.assertIn('• core: ok', box)                       # the modules ran regardless
        self.assertNotIn('Instalación terminada', box)
        self.assertNotRegex(box, r'• \w+: \?')
        text = (self.home/'dragon-informe.txt').read_text()
        self.assertIn('grimblast-git — ', text)
        self.assertIn('Paquetes con problema', text)

    def test_paru_missing_and_unbuildable_stops_with_a_clear_error(self):
        self.no_helper()
        self.env['FAKE_MAKEPKG_NOHELPER'] = '1'            # the AUR build "works" but leaves no helper in the PATH
        result = self.run_install('--yes', '--json-events', '--modules', 'core')
        done = self.events(result)[-1]
        self.assertEqual(result.returncode, 1)
        self.assertEqual(done['status'], 'error')
        self.assertIn('Ayudante de AUR', done['msg'])
        self.assertIn('./install.sh', done['msg'])
        self.assertNotIn('Despliegue', [e.get('name') for e in self.events(result) if e['event'] == 'phase'])

    def test_paru_exit_zero_without_installing_is_not_counted_as_installed(self):
        self.env['FAKE_PARU_MODE'] = 'noop'
        raw, plain, code = self.run_pty()
        box = self.box(plain)
        self.assertEqual(code, 1)
        self.assertRegex(box, r'[1-9]\d* con problema')
        self.assertIn('grimblast-git', box)
        self.assertIn('INCOMPLETA', box)


class Summary(Flow):
    def test_official_failure_stops_before_any_module(self):
        self.env['FAKE_FAIL_INSTALL'] = 'ghostty'
        result = self.run_install('--yes', '--json-events', '--modules', 'core')
        self.assertEqual(result.returncode, 1, result.stdout[-1500:])
        events = self.events(result)
        done = events[-1]
        self.assertEqual(done['status'], 'error')
        self.assertIn('La fase de paquetes falló', done['msg'])
        self.assertIn('./install.sh', done['msg'])
        self.assertIn('continúa donde lo dejó', done['msg'])
        phases = [e['name'] for e in events if e['event'] == 'phase']
        self.assertNotIn('Despliegue', phases)
        self.assertIn('stage=prepared', (Path(self.env['XDG_STATE_HOME'])/'dragon-island/install-progress').read_text())
        self.assertNotIn('?', re.findall(r'• \w+: (.)', done['msg']))

    def test_doctor_failure_makes_the_box_incomplete_with_exact_commands(self):
        self.doctor('#!/bin/sh\nprintf "  \\033[31m✘\\033[0m Servicio bluetooth activo\\n      ↳ sudo systemctl enable --now bluetooth\\n'
                    '  \\033[31m✘\\033[0m Iconos WhiteSur-dark\\n      ↳ paru -S whitesur-icon-theme\\n"\nexit 2\n')
        result = self.run_install('--yes', '--json-events', '--modules', 'core')
        done = self.events(result)[-1]
        self.assertEqual(done['status'], 'incomplete')
        self.assertEqual(result.returncode, 1)
        self.assertIn('Servicio bluetooth activo → sudo systemctl enable --now bluetooth', done['msg'])
        self.assertIn('Iconos WhiteSur-dark → paru -S whitesur-icon-theme', done['msg'])
        self.assertIn('stage=prepared', (Path(self.env['XDG_STATE_HOME'])/'dragon-island/install-progress').read_text())
        self.assertIn('bluetooth', (self.home/'dragon-informe.txt').read_text())

    def test_clean_run_is_terminada_and_exit_zero(self):
        result = self.run_install('--yes', '--json-events', '--modules', 'core')
        done = self.events(result)[-1]
        self.assertEqual(result.returncode, 0, result.stdout[-1500:])
        self.assertEqual(done['status'], 'ok')
        self.assertNotIn('?', re.findall(r'• \w+: (.)', done['msg']))
        self.assertFalse((Path(self.env['XDG_STATE_HOME'])/'dragon-island/install-progress').exists())

    def test_module_result_is_never_blank(self):
        # every module line ends in ok · con avisos · fallido · omitido (reason): checked in the source as well as in the output
        source = (ROOT/'install.sh').read_text()
        self.assertNotIn('${RESULT[$m]:-?}', source)
        self.assertIn('omitido (no se ejecutó', source)

    def test_unexpected_exit_says_where_and_how_to_retry(self):
        # a module that kills the installer with `exit`: no success box, a clear message and the report
        env = dict(self.env, DRAGON_TEST_CRASH_IN='core_apply')
        crash = self.base/'crash.sh'
        crash.write_text('core_apply() { exit 7; }\n')
        result = subprocess.run(['bash', '-c', f'cd {ROOT}; . {crash} 2>/dev/null; true'], env=env, capture_output=True)
        self.assertEqual(result.returncode, 0)
        source = (ROOT/'install.sh').read_text()
        self.assertIn('se detuvo de forma inesperada', source)


class DoctorHints(UX):
    def test_hints_use_the_detected_helper_not_yay(self):
        source = (ROOT/'doctor.sh').read_text()
        self.assertNotIn('"yay -S', source)
        out = subprocess.run(['bash', '-c', '. lib/common.sh; . lib/detect.sh; DRAGON_AUR_HELPERS="paru yay" aur_helper'],
                             cwd=ROOT, env=self.env, text=True, capture_output=True).stdout.strip()
        self.assertEqual(out, 'paru')

    def test_outside_hyprland_quickshell_and_ipc_are_not_failures(self):
        self.env.pop('HYPRLAND_INSTANCE_SIGNATURE', None)
        out = subprocess.run([str(ROOT/'doctor.sh'), '--no-ask'], cwd=ROOT, env=self.env, text=True, capture_output=True, timeout=120).stdout
        plain = ANSI.sub('', out)
        self.assertIn('fuera de Hyprland', plain)
        self.assertNotIn('Quickshell no está en marcha', plain)
        self.assertNotIn('IPC «shell»', plain)
        self.assertNotIn('IPC «lock»', plain)


class QuickshellReload(UX):
    def reload(self, inside, running):
        env = dict(self.env, FAKE_QS_RUNNING='1' if running else '')
        if inside:
            env['HYPRLAND_INSTANCE_SIGNATURE'] = 'test'
        else:
            env.pop('HYPRLAND_INSTANCE_SIGNATURE', None)
        script = ('REPO_DIR=%s; DRY_RUN=false; ASSUME_YES=true; LINK_MODE=symlink; . lib/common.sh; . lib/detect.sh; '
                  'log_info() { echo "$*"; }; log_warn() { echo "$*"; }; '
                  'sed -n "/^core_quickshell_reload()/,/^}/p" modules/core.sh > "$TMPF"; . "$TMPF"; core_quickshell_reload') % ROOT
        env['TMPF'] = str(self.base/'reload.sh')
        subprocess.run(['bash', '-c', script], cwd=ROOT, env=env, text=True, capture_output=True, timeout=60)
        return [c for c in self.commands() if c[0] == 'qs']

    def test_never_started_outside_hyprland(self):
        self.assertEqual(self.reload(inside=False, running=True), [])

    def test_running_shell_is_restarted_inside_hyprland(self):
        calls = self.reload(inside=True, running=True)
        self.assertIn(['qs', 'kill'], calls)
        self.assertIn(['qs', '-d'], calls)

    def test_not_running_is_left_to_hyprland(self):
        calls = self.reload(inside=True, running=False)
        self.assertNotIn(['qs', 'kill'], calls)
        self.assertNotIn(['qs', '-d'], calls)


if __name__ == '__main__':
    unittest.main()
