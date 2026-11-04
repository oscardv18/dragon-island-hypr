"""./install.sh lineal: pacman, paru, sudo y doctor FALSOS (tests/preflight/fake-command.py, estado en FAKE_STATE).

(a) todo ok · (b) paquete oficial inexistente · (c) paru termina con error · (d) paru ausente · (e) sudo que pide la clave por /dev/tty
(f) sin terminal · (g) segunda ejecución idempotente · (h) un módulo que falla no impide los demás · (i) el resumen nunca lleva «?» y solo
es verde si doctor pasa · (j) con y sin color a 60/80/120 columnas · (k) --dry-run no escribe, no pide sudo y no dice «terminada»."""
import os
from pathlib import Path
import re
import subprocess
import unittest

from tests.installer_ux.ptyutil import run_interactive
from tests.installer_ux.test_ux import ANSI, ROOT, UX

CLEAN_DOCTOR = '#!/bin/sh\necho "Todo en orden"\nexit 0\n'
BAD_DOCTOR = '#!/bin/sh\necho "✘ IPC shell no disponible"\necho "   ↳ qs -d"\necho "✘ llavero sin desbloquear"\necho "   ↳ dragon-keyring unlock"\nexit 2\n'
PREINSTALLED = {'git', 'base-devel', 'gum', 'curl', 'unzip', 'pciutils', 'sddm', 'linux-cachyos-headers'}
PROFILES = 'core,shell,editor,taller,archivos,theme,plugins,login,keyring,keyboard'


def manifest(source):
    out = subprocess.check_output(['python3', str(ROOT/'lib/manifest.py'), '--source', source, '--modules', PROFILES], text=True)
    return [n for n in out.split() if n]


class Simple(UX):
    """A bare machine: nothing of the manifests is installed (the base tools and sddm are, like on a real CachyOS)."""

    def setUp(self):
        super().setUp()
        (self.state/'installed').write_text('\n'.join(sorted(PREINSTALLED)) + '\n')
        self.env.update(DRAGON_SKIP_PREFLIGHT='1')
        self.doctor(CLEAN_DOCTOR)
        self.before = self.snapshot()

    def doctor(self, text):
        path = self.base/'doctor-fake.sh'
        path.write_text(text); path.chmod(0o755)
        self.env['DRAGON_DOCTOR'] = str(path)

    def go(self, *args, env=None, modules=PROFILES):
        run_env = dict(self.env, **(env or {}))
        return subprocess.run([str(ROOT/'install.sh'), '--modules', modules, *args], cwd=ROOT, env=run_env, text=True,
                              stdin=subprocess.DEVNULL, capture_output=True, timeout=300)

    def box(self, result):
        text = ANSI.sub('', result.stdout)
        return text[text.rindex('+- '):] if '+- ' in text else text

    def log(self):
        path = self.home/'dragon-install.log'
        return path.read_text() if path.exists() else ''

    def no_helper(self):
        for name in ('paru', 'yay'):
            link = self.base/'bin'/name
            if link.is_symlink():
                link.unlink()
        self.env['FAKE_NO_PARU_REPO'] = '1'


class FullRun(Simple):
    def test_a_everything_ok_with_all_profiles(self):
        result = self.go()
        self.assertEqual(result.returncode, 0, result.stdout[-3000:] + result.stderr)
        box = self.box(result)
        self.assertIn('Instalación completa', box)
        self.assertNotRegex(box, r'• \w+: \?')
        # the scan: faltan N paquetes + names, and ONE official pacman call with all of them
        self.assertRegex(result.stdout, r'faltan \d+ paquetes oficiales')
        installs = [c for c in self.calls('pacman') if c[1].startswith('-S') and c[1] not in ('-Si', '-Sp', '-Ss')]
        self.assertEqual(len(installs), 1, installs)
        self.assertEqual(installs[0][1], '-Syu')
        self.assertIn('--needed', installs[0]); self.assertIn('--noconfirm', installs[0])
        for name in manifest('pacman'):
            if name not in PREINSTALLED:
                self.assertIn(name, installs[0], name)
        # and the AUR ones through the helper
        self.assertTrue(self.calls('paru'), 'no se llamó a paru')
        self.assertTrue(set(manifest('aur')) <= self.installed(), 'AUR sin instalar')
        # all seven phases show up, in order
        positions = [result.stdout.index(f'[{n}/7]') for n in range(1, 8)]
        self.assertEqual(positions, sorted(positions))
        for title in ('Paquetes oficiales', 'Paquetes AUR', 'Despliegue', 'Servicios y SDDM', 'Llavero y grupos', 'Arranque', 'Verificación'):
            self.assertIn(title, result.stdout)
        self.assertIn('Reinicia y elige', box)
        self.assertTrue((self.home/'dragon-informe.txt').exists())
        self.assertIn('Salida:       0', (self.home/'dragon-informe.txt').read_text())
        self.assertIn('[1/7]', self.log())
        self.assertNotIn('\x1b[?1049', result.stdout)          # no alternate screen
        self.assertEqual(len(self.calls('sudo', '-v')) + len(self.calls('sudo', '-n', '-v')) > 0, True)

    def test_g_second_run_is_idempotent(self):
        first = self.go()
        self.assertEqual(first.returncode, 0, first.stdout[-2500:])
        before = self.snapshot()
        n_pacman = len([c for c in self.calls('pacman') if c[1] in ('-Syu', '-S')])
        n_paru = len([c for c in self.calls('paru') if '-S' in c])
        second = self.go()
        self.assertEqual(second.returncode, 0, second.stdout[-2500:])
        self.assertIn('Instalación completa', self.box(second))
        self.assertEqual(len([c for c in self.calls('pacman') if c[1] in ('-Syu', '-S')]), n_pacman, 'volvió a instalar')
        self.assertEqual(len([c for c in self.calls('paru') if '-S' in c]), n_paru, 'volvió a llamar a paru')
        self.assertIn('ya estaba todo instalado', second.stdout)
        after = self.snapshot()
        changed = {k for k in after if before.get(k) != after[k] and not k.startswith('home/dragon-') and 'backups' not in k and not k.endswith('.log')}
        self.assertEqual({k for k in changed if 'state' in k and 'install-progress' in k}, set())


class Failures(Simple):
    def test_b_unknown_official_package_isolated_and_reported(self):
        names = manifest('pacman')
        bad = 'lazygit'
        result = self.go(env={'FAKE_MISSING_PKG': bad})
        self.assertEqual(result.returncode, 1, result.stdout[-2500:])
        box = self.box(result)
        self.assertIn('Incompleta', box)
        self.assertIn(bad, box)
        self.assertIn('no existe en los repositorios', box)
        # the rest were installed anyway, in a second transaction, and the modules still ran
        have = self.installed()
        self.assertTrue(all(n in have for n in names if n != bad and n not in PREINSTALLED), 'faltan paquetes que sí existen')
        self.assertIn('• core:', box)
        self.assertIn('Repite ./install.sh', box)
        report = (self.home/'dragon-informe.txt').read_text()
        self.assertIn('Salida:       1', report)
        self.assertIn(bad, report)
        self.assertIn('Cola del registro', report)

    def test_c_aur_helper_fails(self):
        result = self.go(env={'FAKE_PARU_MODE': 'fail'})
        self.assertEqual(result.returncode, 1, result.stdout[-2500:])
        box = self.box(result)
        self.assertIn('Incompleta', box)
        aur = manifest('aur')
        self.assertIn(aur[0], box)
        self.assertRegex(box, r'\d+ con problema')
        # AUR failing does not stop the deployment
        for m in ('core', 'shell', 'keyring'):
            self.assertRegex(box, rf'• {m}: (ok|con avisos)')
        self.assertTrue(self.calls('paru'), 'sólo hubo un intento de paru')

    def test_c2_helper_that_exits_zero_without_installing_counts_as_problem(self):
        result = self.go(env={'FAKE_PARU_MODE': 'noop'})
        self.assertEqual(result.returncode, 1)
        self.assertIn('terminó con éxito pero el paquete no quedó instalado', self.box(result))

    def test_d_no_aur_helper_says_so_and_lists_the_command(self):
        self.no_helper()
        result = self.go()
        self.assertEqual(result.returncode, 1, result.stdout[-2500:])
        self.assertIn('No hay ayudante AUR', result.stdout)
        self.assertIn('paru -S --needed', result.stdout)
        self.assertIn(manifest('aur')[0], result.stdout)
        self.assertIn('Incompleta', self.box(result))

    def test_h_a_failing_module_does_not_stop_the_others(self):
        result = self.go(env={'DRAGON_TEST_FAIL': 'shell_apply'})
        self.assertEqual(result.returncode, 1, result.stdout[-2500:])
        box = self.box(result)
        self.assertIn('Incompleta', box)
        self.assertRegex(box, r'• shell: fallido')
        for m in ('core', 'editor', 'taller', 'keyring', 'keyboard'):
            self.assertRegex(box, rf'• {m}: (ok|con avisos)')
        self.assertIn('Verificación', result.stdout)           # the run reached the end

    def test_i_summary_is_green_only_if_doctor_passes(self):
        self.doctor(BAD_DOCTOR)
        result = self.go()
        self.assertEqual(result.returncode, 1, result.stdout[-2500:])
        box = self.box(result)
        self.assertIn('Incompleta', box)
        self.assertNotIn('Instalación completa', box)
        self.assertIn('IPC shell no disponible → qs -d', box)
        self.assertIn('llavero sin desbloquear → dragon-keyring unlock', box)
        self.assertNotRegex(box, r'• \w+: \?')
        self.assertNotIn('?', re.sub(r'¿[^?]*\?', '', box))


class Terminals(Simple):
    def test_f_no_terminal_at_all(self):
        result = self.go()
        self.assertEqual(result.returncode, 0, result.stdout[-2500:])
        self.assertNotIn('\x1b', result.stdout)
        self.assertIn('+- Instalación completa', result.stdout)           # ASCII box
        self.assertNotIn('╭', result.stdout)

    def test_e_sudo_asks_the_password_on_the_terminal_only_once(self):
        self.env['FAKE_SUDO_TTY'] = '1'
        out, code = run_interactive(['--modules', 'core,shell', '--yes'], self.env, answers=[('contraseña', 'x\n')] * 6, timeout=240, script='install.sh')
        plain = ANSI.sub('', out).replace('\r', '')
        self.assertEqual(code, 0, plain[-2500:])
        prompts = (self.state/'sudo-prompts').read_text().split() if (self.state/'sudo-prompts').exists() else []
        self.assertEqual(len(prompts), 1, f'la clave se pidió {len(prompts)} veces')
        self.assertEqual(plain.count('[sudo] contraseña'), 1)
        self.assertIn('Instalación completa', plain)

    def test_j_width_and_color_keep_the_same_content(self):
        texts = {}
        for cols in (60, 80, 120):
            for color in (True, False):
                env = dict(self.env)
                if not color:
                    env['NO_COLOR'] = '1'
                out, code = run_interactive(['--dry-run', '--modules', 'core,taller'], env, cols=cols, timeout=120, script='install.sh')
                plain = ANSI.sub('', out).replace('\r', '')
                self.assertEqual(code, 0, plain[-1500:])
                for line in plain.split('\n'):
                    if line.startswith(('[dry-run]', 'INFO', 'WARN')):
                        continue          # the raw output of a command is the terminal's to wrap, not ours
                    self.assertLessEqual(len(line), cols, f'desborda a {cols}: {line!r}')
                if not color:
                    self.assertNotIn('\x1b[', out)
                    self.assertNotIn('╭', plain)
                else:
                    self.assertIn('\x1b[38;2;', out)
                texts[(cols, color)] = re.sub(r'[\s╭╮╰╯│─+|-]', '', plain)
            self.assertEqual(texts[(cols, True)], texts[(cols, False)], f'el contenido cambia con el color a {cols} columnas')
        wide = ANSI.sub('', run_interactive(['--dry-run', '--modules', 'core'], self.env, cols=80, script='install.sh')[0])
        narrow = ANSI.sub('', run_interactive(['--dry-run', '--modules', 'core'], self.env, cols=60, script='install.sh')[0])
        self.assertIn('██████╗', wide)
        self.assertNotIn('██████╗', narrow)
        self.assertIn('DRAGON OS', narrow)


class DryRun(Simple):
    def test_k_dry_run_writes_nothing_asks_nothing_and_never_says_done(self):
        (self.state/'installed').write_text('')
        result = self.go('--dry-run')
        self.assertEqual(result.returncode, 0, result.stdout[-2500:])
        self.assert_untouched()
        self.assertEqual(self.calls('sudo'), [], 'pidió sudo en --dry-run')
        for command in self.calls('pacman'):
            self.assertFalse(re.fullmatch(r'-S[a-z]*', command[1]) and command[1] not in ('-Si', '-Sp'), ' '.join(command))
        self.assertFalse((self.home/'dragon-informe.txt').exists())
        self.assertFalse((self.home/'dragon-install.log').exists())
        self.assertFalse(list(Path(self.env['XDG_STATE_HOME']).glob('**/*')))
        out = result.stdout
        self.assertIn('Simulación (dry-run)', out)
        self.assertIn('[dry-run] sudo pacman -Syu --needed --noconfirm', out)
        self.assertNotRegex(out, r'Instalación completa|terminada|Incompleta')


class Preflight(Simple):
    def test_preflight_only_warns(self):
        env = {'DRAGON_SKIP_PREFLIGHT': ''}
        broken = self.base/'broken'; broken.mkdir()
        (broken/'python3').write_text('#!/bin/sh\nexit 1\n'); (broken/'python3').chmod(0o755)
        # the preflight engine is Python; a failing one must only warn (the manifest reader needs the real python, so wrap by argument)
        shim = broken/'python3'
        shim.write_text('#!/bin/sh\ncase "$*" in *installer_preflight*) echo boom >&2; exit 3;; esac\nexec /usr/bin/python3 "$@"\n')
        result = self.go(env=dict(env, PATH=f'{broken}:{self.env["PATH"]}'))
        self.assertEqual(result.returncode, 0, result.stdout[-2500:])
        self.assertIn('El preflight no pudo ejecutarse', result.stdout)
        self.assertIn('Instalación completa', self.box(result))


if __name__ == '__main__':
    unittest.main()
