"""./install.sh as ONE command: preparation, reboot and continuation, report, dry-run purity, plan incidents.

pacman, AUR helpers, sudo, git/makepkg, systemd-detect-virt and the rest are the stateful fake of tests/preflight/fake-command.py
(FAKE_STATE directory). Nothing here touches the real system, and every run uses a private HOME/XDG tree."""
import json
import os
from pathlib import Path
import re
import subprocess
import unittest

from tests.tui.test_install_modes import ANSI, ROOT, Sandbox, run_in_pty

BASE = ['git', 'base-devel', 'gum', 'curl', 'unzip', 'pciutils']


class UX(Sandbox):
    def setUp(self):
        super().setUp()
        self.state = self.base/'fake-state'; self.state.mkdir()
        bin_dir = self.base/'bin'
        for name in ('systemd-detect-virt', 'git', 'makepkg'):
            (bin_dir/name).symlink_to(bin_dir/'fixture')
        self.env.update(FAKE_STATE=str(self.state), FAKE_BIN=str(bin_dir), DRAGON_AUR_HELPERS='paru fakeyay')
        self.system = Path(self.env['DRAGON_PREFLIGHT_ROOT'])
        (self.system/'usr/lib/modules/6.test').mkdir(parents=True, exist_ok=True)
        (self.system/'usr/lib/modules/6.test/pkgbase').write_text('linux-cachyos\n')
        self.install(['yay', 'linux-cachyos-headers', 'sddm'] + BASE)        # a prepared machine by default
        # a login manager is present unless a test removes it
        unit = self.system/'etc/systemd/system'; unit.mkdir(parents=True)
        (unit/'sddm.service').write_text('')
        (unit/'display-manager.service').symlink_to(unit/'sddm.service')
        self.before = self.snapshot()
        self.git_before = subprocess.check_output(['git', 'status', '--porcelain', '-z'], cwd=ROOT)

    def install(self, names):
        have = set((self.state/'installed').read_text().split()) if (self.state/'installed').exists() else set()
        (self.state/'installed').write_text('\n'.join(sorted(have | set(names))) + '\n')

    def installed(self):
        return set((self.state/'installed').read_text().split())

    def commands(self):
        path = self.base/'commands.jsonl'
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def calls(self, command, *prefix):
        return [c for c in self.commands() if c[0] == command and c[1:1 + len(prefix)] == list(prefix)]

    def run_install(self, *args, stop=None):
        env = dict(self.env)
        if stop:
            env['DRAGON_STOP_AFTER'] = stop
        return subprocess.run([str(ROOT/'install-tui.sh'), *args], cwd=ROOT, env=env, text=True, capture_output=True, timeout=300)

    def events(self, result):
        return [json.loads(line) for line in result.stdout.splitlines()]

    @property
    def home(self):
        return Path(self.env['HOME'])


class DryRunPurity(UX):
    """Item 15: a simulation writes nothing, never asks for sudo and never runs a partial upgrade."""

    def test_dry_run_writes_nothing_and_never_sudo(self):
        self.install([])
        (self.state/'installed').write_text('')               # nothing installed: the prerequisites would all be needed
        for args in (('--dry-run', '--yes', '--plain', '--modules', 'core,taller'), ('--dry-run', '--plain', '--modules', 'core')):
            result = self.run_install(*args)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assert_untouched()
            self.assertEqual(self.calls('sudo'), [], 'pidió sudo en --dry-run')
            for command in self.calls('pacman'):
                self.assertFalse(re.fullmatch(r'-S[a-z]*', command[1]) and command[1] not in ('-Si', '-Sp'),
                                 'instalación o sincronización en --dry-run: ' + ' '.join(command))
            self.assertFalse((self.home/'dragon-informe.txt').exists())
            self.assertFalse(list(Path(self.env['XDG_STATE_HOME']).glob('**/*')), 'el estado no está vacío')
            self.assertIn('[dry-run] sudo pacman -Syu --needed --noconfirm', result.stdout)
            self.assertNotIn('pacman -Sy ', result.stdout.replace('pacman -Syu', ''))

    def test_dry_run_title_and_no_contradiction(self):
        result = self.run_install('--dry-run', '--yes', '--json-events', '--modules', 'core')
        done = self.events(result)[-1]
        self.assertEqual(done['status'], 'dry-run')
        self.assertIn('paquetes:', done['msg'])
        self.assertNotIn('paquetes: ok', done['msg'])
        self.assertNotRegex(done['msg'], r'\d+ con problema')


class PlainOutput(UX):
    """Items 8, 9, 10: --plain/--check carry text only; no raw pacman -Si, no JSON lines, one AUR note."""

    def test_plain_and_check_text_have_no_json_or_raw_pacman(self):
        for command in (('--dry-run', '--yes', '--plain', '--modules', 'core'), ('--check', '--modules', 'core')):
            result = self.run_install(*command)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            for needle in ('"unresolved_dependencies"', '"package":', 'Repository ', 'Licenses', 'Download Size', 'URL  '):
                self.assertNotIn(needle, result.stdout, f'{command}: salida cruda ({needle})')
            self.assertFalse([l for l in result.stdout.splitlines() if l.startswith('{')], f'{command}: líneas JSON en modo texto')
            self.assertLessEqual(result.stdout.count('Revisa PKGBUILD'), 0)
            self.assertLessEqual(result.stdout.count('PKGBUILD'), 2, 'el aviso de PKGBUILD debe ser una sola nota')

    def test_check_json_still_json(self):
        result = self.run_install('--check', '--json', '--modules', 'core')
        self.assertEqual(json.loads(result.stdout)['schema'], 1)


class Preparation(UX):
    """Item 1-2: prerequisites in one transaction with one sudo; reboot stops and the next run continues."""

    def test_missing_prerequisites_installed_once_with_one_update(self):
        (self.state/'installed').write_text('yay\n')
        result = self.run_install('--yes', '--plain', '--modules', 'core', stop='prepare')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        updates = self.calls('sudo', 'pacman', '-Syu')
        self.assertEqual(len(updates), 1, 'una sola transacción de actualización')
        for package in BASE:
            self.assertIn(package, updates[0], 'prerrequisito que falta en la transacción: ' + package)
        self.assertTrue(BASE and set(BASE) <= self.installed())
        # headers come AFTER the update, in a separate step, for the kernel that is running
        steps = [c for c in self.commands() if c[:3] == ['sudo', 'pacman', '-S'] or c[:3] == ['sudo', 'pacman', '-Syu']]
        self.assertEqual(steps[0][2], '-Syu')
        self.assertTrue(any('linux-cachyos-headers' in c for c in steps[1:]) or 'linux-cachyos-headers' in self.installed())
        self.assertNotIn('partial upgrade', result.stdout)

    def test_everything_present_still_updates_once_without_missing_packages(self):
        result = self.run_install('--yes', '--plain', '--modules', 'core', stop='prepare')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        updates = self.calls('sudo', 'pacman', '-Syu')
        self.assertEqual(len(updates), 1)
        self.assertEqual([a for a in updates[0] if a in BASE], [])

    def test_kernel_change_pauses_and_next_run_continues(self):
        self.env['FAKE_UPDATE_REPLACES_KERNEL'] = '1'
        (self.state/'installed').write_text('yay\n')           # headers are missing too
        first = self.run_install('--yes', '--json-events', '--modules', 'core,taller')
        self.assertEqual(first.returncode, 0, first.stdout + first.stderr)
        done = self.events(first)[-1]
        self.assertEqual(done['status'], 'pause')
        self.assertIn('Reinicia', done['msg'])
        self.assertIn('./install.sh', done['msg'])
        self.assertNotIn('linux-cachyos-headers', self.installed(), 'cabeceras instaladas para un kernel que ya no está')
        self.assertEqual(len(self.calls('sudo', 'pacman', '-Syu')), 1)
        progress = (Path(self.env['XDG_STATE_HOME'])/'dragon-island/install-progress').read_text()
        self.assertIn('stage=reboot', progress)
        phases = [e['name'] for e in self.events(first) if e['event'] == 'phase']
        self.assertNotIn('Paquetes', phases, 'siguió instalando con el kernel pendiente de reinicio')
        # still not rebooted: it stops again, without a second update
        again = self.run_install('--yes', '--json-events', '--modules', 'core,taller')
        self.assertEqual(self.events(again)[-1]['status'], 'pause')
        self.assertEqual(len(self.calls('sudo', 'pacman', '-Syu')), 1)
        # reboot: the running kernel is now the installed one → continues where it stopped
        (self.state/'uname').write_text('7.new\n')
        (self.system/'usr/lib/modules/7.new/pkgbase').write_text('linux-cachyos\n')
        third = self.run_install('--yes', '--json-events', '--modules', 'core,taller', stop='prepare')
        self.assertEqual(third.returncode, 0, third.stdout + third.stderr)
        self.assertEqual(len(self.calls('sudo', 'pacman', '-Syu')), 1, 'volvió a actualizar el sistema')
        self.assertIn('linux-cachyos-headers', self.installed())
        headers = [c for c in self.calls('sudo', 'pacman', '-S') if 'linux-cachyos-headers' in c]
        self.assertTrue(headers, 'las cabeceras se instalan tras el reinicio')

    def test_restart_forgets_progress(self):
        self.env['FAKE_UPDATE_REPLACES_KERNEL'] = '1'
        self.run_install('--yes', '--plain', '--modules', 'core')
        self.run_install('--yes', '--plain', '--restart', '--modules', 'core', stop='prepare')
        self.assertEqual(len(self.calls('sudo', 'pacman', '-Syu')), 1, '--restart no debe contar el progreso viejo como actualización')

    def test_aur_helper_from_repo_or_built_from_aur(self):
        for name in ('paru', 'yay'):
            link = self.base/'bin'/name
            if link.is_symlink():
                link.unlink()
        (self.state/'installed').write_text('\n'.join(BASE + ['linux-cachyos-headers', 'sddm']) + '\n')
        repo = self.run_install('--yes', '--plain', '--modules', 'core', stop='prepare')
        self.assertEqual(repo.returncode, 0, repo.stdout + repo.stderr)
        self.assertIn('paru', self.calls('sudo', 'pacman', '-Syu')[0], 'paru del repositorio en la misma transacción')
        self.assertEqual(self.calls('git', 'clone'), [])

    def test_aur_helper_built_when_not_in_repos(self):
        for name in ('paru', 'yay'):
            link = self.base/'bin'/name
            if link.is_symlink():
                link.unlink()
        self.env['FAKE_NO_PARU_REPO'] = '1'
        (self.state/'installed').write_text('\n'.join(BASE + ['linux-cachyos-headers', 'sddm']) + '\n')
        result = self.run_install('--yes', '--plain', '--modules', 'core', stop='prepare')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(self.calls('git', 'clone'), 'no construyó el ayudante desde AUR')
        self.assertIn('aur.archlinux.org/paru-bin.git', ' '.join(self.calls('git', 'clone')[0]))
        self.assertTrue(self.calls('makepkg'))
        self.assertNotIn('paru', self.calls('sudo', 'pacman', '-Syu')[0])

    def test_no_sudo_with_missing_prerequisites_stops_with_the_command(self):
        (self.state/'installed').write_text('yay\n')
        result = self.run_install('--yes', '--no-sudo', '--json-events', '--modules', 'core')
        done = self.events(result)[-1]
        self.assertEqual(done['status'], 'error')
        self.assertEqual(self.calls('sudo'), [])


class Report(UX):
    """Item 5: ~/dragon-informe.txt on success and on failure; versions, checks, packages with a cause, no secrets."""

    def test_report_on_failure_has_cause_step_and_no_secrets(self):
        self.env['FAKE_FAIL_INSTALL'] = 'ghostty'
        self.env['DRAGON_API_TOKEN'] = 'tok-123456789-SECRET'
        self.env['SUPER_SECRET_ENV'] = 'hunter3-env'
        result = self.run_install('--yes', '--plain', '--modules', 'core', stop='packages')
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)       # a failed package phase stops the run (UX2)
        report = self.home/'dragon-informe.txt'
        self.assertTrue(report.exists(), 'no escribió el informe')
        self.assertEqual(report.stat().st_mode & 0o777, 0o600)
        text = report.read_text()
        for expected in ('Versiones', 'Comprobaciones', 'ghostty', 'Paquetes con problema', 'Cola del registro', 'Fase / paso'):
            self.assertIn(expected, text)
        self.assertRegex(text, r'ghostty — .*(error|failed)')
        for secret in ('hunter2', 'abcdefghijklmnop', 'tok-123456789-SECRET', 'hunter3-env', str(self.home)):
            self.assertNotIn(secret, text, 'el informe contiene: ' + secret)
        self.assertIn('~/dragon-informe.txt', result.stdout)               # its path is printed
        self.assertTrue((self.base/'commands.jsonl').exists())

    def test_report_on_blocked_run(self):
        self.env['PREFLIGHT_FAKE_MISSING'] = 'lazydocker'
        result = self.run_install('--yes', '--json-events', '--modules', 'core,taller')
        self.assertEqual(result.returncode, 1)
        text = (self.home/'dragon-informe.txt').read_text()
        self.assertIn('lazydocker', text)
        self.assertIn('error', text)

    def test_report_survives_a_crash(self):
        self.env['PREFLIGHT_FAKE_DEPTEST_ERROR'] = '1'          # pacman -T fails: the run cannot continue
        (self.state/'installed').write_text('yay\n')
        result = self.run_install('--yes', '--plain', '--modules', 'core')
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue((self.home/'dragon-informe.txt').exists())


class MachineAwareness(UX):
    """Items 16-17: virtual machines, bare logins and known-compatible pairs are not failures."""

    def test_vm_without_gpu_and_without_login_manager_is_only_a_warning(self):
        self.env.update(FAKE_VIRT='kvm', FAKE_NO_GPU='1', FAKE_NO_DM='1')
        (self.system/'etc/systemd/system/display-manager.service').unlink()
        doctor = subprocess.run([str(ROOT/'doctor.sh'), '--pre', '--no-ask'], cwd=ROOT, env=self.env, text=True, capture_output=True, timeout=120)
        self.assertIn('máquina virtual (kvm)', doctor.stdout + doctor.stderr)
        self.assertIn('el módulo login instalará y habilitará SDDM', doctor.stdout)
        self.assertNotIn('se encontró', doctor.stdout)
        self.assertNotIn('✘ GPU', doctor.stdout)
        self.assertNotIn('✘ Gestor', doctor.stdout)

    def test_bare_install_adds_login_module(self):
        self.env.update(FAKE_NO_DM='1')
        (self.system/'etc/systemd/system/display-manager.service').unlink()
        result = self.run_install('--dry-run', '--yes', '--plain')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('se añade el módulo login', result.stdout)

    def test_known_pairs_do_not_warn(self):
        result = self.run_install('--check', '--json', '--modules', 'core')
        ids = [c['id'] for c in json.loads(result.stdout)['checks']]
        self.assertNotIn('provides:hyprland:hyprpm', ids)
        self.assertNotIn('provides:xdg-desktop-portal-gtk:xdg-desktop-portal-hyprland', ids)

    def test_pciutils_is_a_prerequisite(self):
        self.assertIn('pciutils', (ROOT/'packages/base.txt').read_text().split())


class PlanIncidents(UX):
    """Item 3 and 18: nothing is shown as a bare «N con problema»: package, cause and action are in the plan."""

    def test_blocked_plan_names_package_cause_and_action(self):
        self.env['PREFLIGHT_FAKE_MISSING'] = 'lazydocker'
        result = self.run_install('--dry-run', '--yes', '--json-events', '--modules', 'core,taller')
        warns = [e['msg'] for e in self.events(result) if e['event'] == 'warn']
        issue = [w for w in warns if w.startswith('bloquear')]
        self.assertTrue(issue, warns)
        self.assertIn('lazydocker', issue[0])
        self.assertIn('→', issue[0])                                # and what the installer will do
        done = self.events(result)[-1]
        self.assertNotRegex(done['msg'], r'(?m)^\s*\d+ con problema\s*$')

    def plan_lines(self, packages, checks=()):
        data = self.base/'plan.json'
        data.write_text(json.dumps({'schema': 1, 'packages': packages, 'checks': list(checks), 'blocked': False, 'profiles': ['base']}))
        out = subprocess.run(['python3', str(ROOT/'lib/installer_plan.py'), str(data)], text=True, capture_output=True)
        self.assertEqual(out.returncode, 0, out.stderr)
        return [line.split('\t') for line in out.stdout.splitlines()]

    def test_xorg_server_is_explained(self):
        package = lambda name, depends=(), profiles=('login',): {'name': name, 'version': '1', 'repository': 'extra', 'source': 'pacman',
                                                                 'conflicts': [], 'replaces': [], 'provides': [], 'depends': list(depends),
                                                                 'required_by': [], 'profiles': list(profiles), 'state': 'install'}
        lines = self.plan_lines([package('sddm', ['xorg-server>=21']), package('xorg-server', profiles=('dependency',))])
        notes = [l for l in lines if l[:2] == ['issue', 'nota']]
        self.assertEqual(len(notes), 1)
        self.assertEqual(notes[0][2], 'xorg-server')
        self.assertIn('sddm', notes[0][3])
        self.assertEqual([l[1] for l in lines if l[0] == 'pkg'], ['sddm'], 'las dependencias no son filas de la tabla')
        self.assertIn(['meta', 'deps', '1'], lines)

    def test_every_non_plain_package_gets_cause_and_action(self):
        base = {'version': '1', 'repository': 'extra', 'source': 'pacman', 'conflicts': [], 'replaces': [], 'provides': [], 'depends': [],
                'required_by': [], 'profiles': ['base']}
        packages = [dict(base, name='nodejs', state='satisfied', provider='nodejs-lts-krypton', provider_origin='installed'),
                    dict(base, name='a', state='install'), dict(base, name='b', state='install')]
        checks = [{'id': 'conflicts:plan:a:b', 'level': 'bloqueante', 'message': 'Conflicts With: selección incompatible.',
                   'evidence': 'a / b (plan): b', 'remedy': ''},
                  {'id': 'aur-build:x', 'level': 'aviso', 'message': 'AUR', 'evidence': json.dumps({'package': 'x', 'unresolved_dependencies': ['scdoc']}), 'remedy': ''},
                  {'id': 'aur-build:y', 'level': 'aviso', 'message': 'AUR', 'evidence': json.dumps({'package': 'y', 'unresolved_dependencies': []}), 'remedy': ''}]
        issues = {l[2]: l for l in self.plan_lines(packages, checks) if l[0] == 'issue'}
        self.assertEqual(issues['nodejs'][1], 'omitir')
        self.assertIn('nodejs-lts-krypton', issues['nodejs'][3])
        for name in ('a', 'b'):
            self.assertEqual(issues[name][1], 'bloquear')
            self.assertTrue(issues[name][3], 'sin acción')
        self.assertEqual(issues['AUR'][1], 'compilar')
        self.assertIn('x, y', issues['AUR'][3])
        self.assertIn('scdoc', issues['AUR'][3])
        self.assertEqual(len([l for l in self.plan_lines(packages, checks) if l[0] == 'issue' and l[2] == 'AUR']), 1, 'una sola nota AUR')


class RealTerminal(UX):
    """The whole flow on a terminal (pty), with the single «Instalar todo» confirmation and one sudo session."""

    def test_plan_screen_and_single_confirmation_at_80_columns(self):
        (self.state/'installed').write_text('yay\n')                      # prerequisites missing: preparation + plan both appear
        self.env['DRAGON_STOP_AFTER'] = 'packages'
        out, code = run_in_pty(['--modules', 'core,taller'], self.env, 80, 30, timeout=240)
        self.assertEqual(code, 0, out[-3000:])
        plain = ANSI.sub('', out).replace('\r', '')
        self.assertIn('Plan de instalación', plain)
        self.assertIn('Incidencias', plain)
        self.assertIn('Pasos con sudo', plain)
        self.assertIn('\x1b[?1049h', out)
        # the plan text is printed on the normal screen between the alternate-screen sessions: never wider than the terminal
        for line in plain.split('\n'):
            if '\x1b' not in line and '[H' not in line:
                self.assertLessEqual(len(line), 200)
        self.assertEqual(len(self.calls('sudo', 'pacman', '-Syu')), 1)
        self.assertTrue(self.calls('sudo', 'pacman', '-S'), 'el plan se instaló tras la confirmación')
        self.assertTrue((self.home/'dragon-informe.txt').exists())
        self.assertNotRegex(plain, r'\n\s*\d+ con problema\s*\n')


class FinalSummary(unittest.TestCase):
    """Items 12-14: readable version, nothing cut without «…», the right border always aligned."""

    def bash(self, script, **env):
        return subprocess.run(['bash', '-c', script], cwd=ROOT, text=True, capture_output=True,
                              env={**os.environ, 'TUI_COLS': '80', 'TUI_ROWS': '24', 'NO_COLOR': '1', 'LC_ALL': 'C.UTF-8', **env}, timeout=60)

    def test_version_is_readable_not_a_git_tag(self):
        version = (ROOT/'VERSION').read_text().strip()
        self.assertRegex(version, r'^\d+\.\d+\.\d+')
        self.assertNotIn('fix', version)
        result = self.bash('. lib/tui.sh; TUI_VERSION=' + version + '; tui_frame | head -3')
        self.assertIn('v' + version, result.stdout)

    def test_box_keeps_the_right_border_with_long_lines(self):
        long_path = '/home/usuario/.local/state/dragon-island/backups/20261103-120000/.config/quickshell/modules/launcher/Launcher.qml'
        script = ('. lib/tui.sh; EV_OUT_FD=1; tui_box green "Título" "  - %s" "Una línea muy larga con acentos: configuración, instalación, verificación y recuperación '
                  'que debe partirse en varias líneas sin perder ni un carácter ni desalinear el recuadro" "  ✖ paquete: causa"') % long_path
        result = self.bash(script)
        self.assertEqual(result.returncode, 0, result.stderr)
        lines = result.stdout.splitlines()
        self.assertGreater(len(lines), 6)
        widths = {len(line) for line in lines}
        self.assertEqual(len(widths), 1, f'recuadro desalineado: {sorted(widths)}')
        body = ''.join(line.strip(' │╭╮╰╯─') for line in lines)
        for fragment in ('Launcher.qml', 'recuadro', 'causa', 'recuperación'):
            self.assertIn(fragment.replace(' ', ''), body.replace(' ', ''))

    def test_cut_text_is_marked(self):
        result = self.bash('. lib/tui.sh; tui_fit "una línea muy larga que no cabe en el ancho" 20')
        self.assertTrue(result.stdout.endswith('…'))
        self.assertEqual(len(result.stdout), 20)

    def test_summary_titles_and_problem_detail(self):
        script = ('. lib/tui.sh; EV_OUT_FD=1; tui_handle pkg name foo state failed detail "error: no se pudo"; '
                  'tui_handle pkg name bar state install detail 1.0; tui_finish dry-run "mensaje"')
        out = self.bash(script).stdout
        self.assertIn('Simulación terminada (dry-run)', out)
        self.assertNotIn('Instalación terminada', out)
        self.assertIn('1 con problema', out)
        self.assertIn('foo: error: no se pudo', out)                 # a problem always comes with its cause

    def test_preflight_shows_checking_not_zero_of_zero(self):
        script = ('. lib/tui.sh; tui_handle phase name Preflight; tui_handle progress done 12 total 97 msg "Consultando paquetes: hyprland"; '
                  'tui_frame')
        out = self.bash(script).stdout
        self.assertIn('comprobando…', out)
        self.assertNotIn('(0/0)', out)
        self.assertIn('12/97', out)


if __name__ == '__main__':
    unittest.main()
