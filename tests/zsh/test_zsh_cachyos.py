"""zsh de Dragon sobre el ~/.zshrc de CachyOS (HOME temporal, sin red, sin sudo).

Simula lo que pasó en la instalación real: CachyOS carga Powerlevel10k y sus plugins antes del bloque de Dragon y su
oh-my-zsh (/usr/share/oh-my-zsh) es de root. Comprueba que, tras el módulo shell, el prompt activo es Starship, los tres
plugins cargan, una segunda ejecución no cambia nada, un clon fallido hace fallar el módulo (y dragon.zsh avisa una vez),
las respuestas «no» quedan en «Queda para ti», un starship.toml ajeno se respalda y la migración 191 repara lo instalado.
git, chsh, getent y sudo son comandos simulados; zsh, p10k y los plugins de /usr/share son los reales del sistema.
"""
import os
import shutil
import stat
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CACHYOS_CONFIG = Path('/usr/share/cachyos-zsh-config/cachyos-config.zsh')
P10K = Path('/usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme')
SYSTEM_PLUGINS = Path('/usr/share/zsh/plugins')
FZF_TAB_REPO = 'https://github.com/Aloxaf/fzf-tab.git'

# El ~/.zshrc que CachyOS deja al instalar (instant prompt + su configuración + ~/.p10k.zsh)
CACHYOS_ZSHRC = textwrap.dedent('''\
    # Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
    if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
      source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
    fi

    source /usr/share/cachyos-zsh-config/cachyos-config.zsh

    # To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
    [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
    ''')

# Un fzf-tab mínimo: define el widget y se adueña de Tab, como el de verdad
FZF_TAB_STUB = textwrap.dedent('''\
    fzf-tab-complete() { zle expand-or-complete }
    zle -N fzf-tab-complete
    bindkey '^I' fzf-tab-complete
    ''')

SHIMS = {
    'git': textwrap.dedent('''\
        #!/usr/bin/env bash
        echo "git $*" >> "$SHIM_LOG"
        if [[ "$1" == clone ]]; then
            dest="${@: -1}"
            if [[ -n "${FAKE_GIT_FAIL:-}" ]]; then
                echo "fatal: no se pudo crear un árbol de trabajo '$dest': Permiso denegado" >&2; exit 128
            fi
            mkdir -p "$dest" || exit 128
            cp "$FZF_TAB_STUB" "$dest/fzf-tab.plugin.zsh"; exit 0
        fi
        exec /usr/bin/git "$@"
        '''),
    'chsh': '#!/usr/bin/env bash\necho "chsh $*" >> "$SHIM_LOG"\n',
    'sudo': '#!/usr/bin/env bash\necho "sudo $*" >> "$SHIM_LOG"\nexit 1\n',
    'getent': textwrap.dedent('''\
        #!/usr/bin/env bash
        if [[ -n "${FAKE_LOGIN_SHELL:-}" && "$1" == passwd ]]; then echo "$2:x:1000:1000::$HOME:$FAKE_LOGIN_SHELL"; exit 0; fi
        exec /usr/bin/getent "$@"
        '''),
}

APPLY = textwrap.dedent('''\
    set -Eeuo pipefail
    PROJECT=dragon-island
    STATE_DIR="$HOME/.local/state/$PROJECT"; MANIFEST="$STATE_DIR/manifest"; BACKUP_DIR="$STATE_DIR/backups/test"
    LOG=/dev/null; DRY_RUN=false; ASSUME_YES=${ASSUME_YES:-true}; NO_SUDO=true; LINK_MODE=symlink
    mkdir -p "$STATE_DIR"
    . "$REPO_DIR/lib/common.sh"; . "$REPO_DIR/lib/detect.sh"; . "$REPO_DIR/modules/shell.sh"
    if [[ -n "${ANSWER_NO:-}" ]]; then confirm_explicit() { echo "PREGUNTA: $1"; return 1; }; fi
    rc=0; shell_apply || rc=$?
    for item in "${MANUAL_ITEMS[@]}"; do echo "MANUAL: $item"; done
    echo "RC=$rc"
    ''')


def need_system():
    missing = [str(p) for p in (CACHYOS_CONFIG, P10K, SYSTEM_PLUGINS / 'zsh-autosuggestions',
                                 SYSTEM_PLUGINS / 'zsh-syntax-highlighting') if not p.exists()]
    if missing or not shutil.which('zsh') or not shutil.which('starship'):
        raise unittest.SkipTest('sin CachyOS/zsh/starship/plugins en este sistema: ' + ', '.join(missing))


class ZshCachyOS(unittest.TestCase):
    @staticmethod
    def repo_state():
        return {p: (ROOT / p).read_bytes() for p in ('config/starship/starship.toml', 'config/zsh/dragon.zsh')}

    def setUp(self):
        need_system()
        self.repo_files = self.repo_state()
        self.tmp = Path(tempfile.mkdtemp(prefix='dragon-zsh-'))
        self.home = self.tmp / 'home'
        self.shims = self.tmp / 'shims'
        self.home.mkdir()
        self.shims.mkdir()
        self.log = self.tmp / 'shim.log'
        stub = self.tmp / 'fzf-tab.plugin.zsh'
        stub.write_text(FZF_TAB_STUB)
        for name, body in SHIMS.items():
            path = self.shims / name
            path.write_text(body)
            path.chmod(0o755)
        # oh-my-zsh de solo lectura, como el de CachyOS (de root)
        self.omz = self.tmp / 'oh-my-zsh'
        (self.omz / 'custom/plugins/example').mkdir(parents=True)
        for d in (self.omz / 'custom/plugins', self.omz / 'custom', self.omz):
            d.chmod(stat.S_IRUSR | stat.S_IXUSR)
        (self.home / '.zshrc').write_text(CACHYOS_ZSHRC)
        (self.home / '.p10k.zsh').write_text(
            'typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(dir)\ntypeset -g POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true\n')
        self.env = {
            'HOME': str(self.home), 'USER': os.environ.get('USER', 'tester'), 'LANG': 'C.UTF-8',
            'TERM': 'xterm-256color', 'PATH': f'{self.shims}:/usr/local/bin:/usr/bin:/bin',
            'REPO_DIR': str(ROOT), 'ZSH': str(self.omz), 'SHIM_LOG': str(self.log), 'FZF_TAB_STUB': str(stub),
            'DRAGON_NO_GUM': '1',
        }

    def tearDown(self):
        self.assertEqual(self.repo_files, self.repo_state(), 'las pruebas no escriben en el repo (enlaces simbólicos)')
        for d in (self.omz, self.omz / 'custom', self.omz / 'custom/plugins'):
            if d.exists():
                d.chmod(0o755)
        shutil.rmtree(self.tmp, ignore_errors=True)

    # --- helpers -------------------------------------------------------------------------------------------------
    def bash(self, script, **env):
        merged = dict(self.env, **env)
        return subprocess.run(['bash', '-c', script], env=merged, capture_output=True, text=True, timeout=120)

    def apply(self, **env):
        r = self.bash(APPLY, **env)
        self.assertIn('RC=', r.stdout, r.stderr[-2000:])
        return r, int(r.stdout.rsplit('RC=', 1)[1].split()[0])

    def probe(self, **env):
        r = self.bash('. "$REPO_DIR/lib/common.sh" >/dev/null 2>&1; . "$REPO_DIR/lib/zsh-setup.sh"; zsh_probe', **env)
        values = dict(line.split('=', 1) for line in r.stdout.splitlines() if '=' in line)
        return values

    def zsh_stderr(self, **env):
        """stderr of a new terminal: zsh -i on a pseudo-terminal (script), stderr to a file."""
        merged = dict(self.env, **env)
        merged.pop('ZSH')          # in a real terminal ZSH comes from cachyos-config.zsh
        err = self.tmp / 'zsh.err'
        subprocess.run(['script', '-qec', f'zsh -i -c true 2>{err}', '/dev/null'], env=merged, capture_output=True,
                       timeout=60, cwd=self.home, stdin=subprocess.DEVNULL)
        return err.read_text()

    def snapshot(self):
        out = []
        for path in sorted(self.home.rglob('*')):
            rel = path.relative_to(self.home)
            if rel.parts[:4] == ('.local', 'state', 'dragon-island', 'backups') or rel.name == 'manifest':
                continue
            if rel.parts[:1] == ('.cache',) or rel.name.startswith('.zcompdump') or rel.name.endswith('.zwc'):
                continue
            kind = 'l' if path.is_symlink() else 'd' if path.is_dir() else 'f'
            extra = os.readlink(path) if kind == 'l' else path.read_bytes() if kind == 'f' else b''
            out.append((str(rel), kind, extra))
        return out

    def plugins_dir(self):
        return self.home / '.local/share/dragon-island/zsh-plugins'

    # --- tests ---------------------------------------------------------------------------------------------------
    def test_before_dragon_the_prompt_is_p10k(self):
        """Comprobación de la prueba: sin el bloque de Dragon, CachyOS dibuja p10k (el fallo que se corrige)."""
        self.assertEqual(self.probe()['prompt'], 'p10k')

    def test_module_starship_wins_and_plugins_load(self):
        r, rc = self.apply()
        self.assertEqual(rc, 0, r.stdout[-3000:])
        p = self.probe()
        self.assertEqual(p['prompt'], 'starship', p)
        for key in ('autosuggestions', 'syntax', 'fzftab', 'zoxide'):
            self.assertEqual(p[key], '1', (key, p))
        self.assertEqual(p['stderr'], '0', p)
        zshrc = (self.home / '.zshrc').read_text()
        self.assertEqual(zshrc.count('>>> dragon-island:zsh'), 1)
        self.assertTrue(zshrc.startswith(CACHYOS_ZSHRC), 'las líneas de CachyOS siguen intactas y antes del bloque')
        self.assertTrue(list((self.home / '.local/state/dragon-island/backups').rglob('.zshrc')), 'copia del .zshrc')
        # el clon va a la carpeta propia: el oh-my-zsh de solo lectura queda intacto
        self.assertTrue((self.plugins_dir() / 'fzf-tab/fzf-tab.plugin.zsh').is_file())
        self.assertEqual(sorted(p.name for p in (self.omz / 'custom/plugins').iterdir()), ['example'])
        self.assertIn('# dragon-island — starship prompt', (self.home / '.config/starship.toml').read_text())
        self.assertTrue((self.home / '.config/dragon-island/zsh').is_symlink(), 'enlace al repo (modo por defecto)')
        # los dos plugins con paquete no se clonan
        self.assertEqual(self.log.read_text().count('git clone'), 1)

    def test_second_run_changes_nothing(self):
        self.apply()
        first = self.snapshot()
        r, rc = self.apply()
        self.assertEqual(rc, 0, r.stdout[-3000:])
        self.assertEqual(first, self.snapshot())
        self.assertEqual(self.log.read_text().count('git clone'), 1, 'la segunda vez no se clona nada')

    def test_failed_clone_fails_the_module_and_dragon_warns_once(self):
        r, rc = self.apply(FAKE_GIT_FAIL='1')
        self.assertEqual(rc, 1, r.stdout[-3000:])
        self.assertIn(f'git clone --depth 1 {FZF_TAB_REPO}', r.stdout + r.stderr)
        self.assertEqual(sorted(p.name for p in (self.omz / 'custom/plugins').iterdir()), ['example'])
        p = self.probe()
        self.assertEqual(p['prompt'], 'starship', p)   # sin fzf-tab, el resto sigue funcionando
        err = self.zsh_stderr()
        self.assertEqual(err.count('faltan plugins de zsh (fzf-tab)'), 1, err)
        self.assertIn('install.sh --modules shell', err)
        self.assertEqual(self.zsh_stderr(DRAGON_ZSH_WARNED='1'), '', 'una sola vez por sesión')

    def test_answering_no_leaves_it_for_the_user(self):
        r, rc = self.apply(ASSUME_YES='false', ANSWER_NO='1', FAKE_LOGIN_SHELL='/bin/bash')
        self.assertEqual(rc, 0, r.stdout[-3000:])
        self.assertIn('PREGUNTA: ¿Añadir UNA línea a ~/.zshrc para cargar la configuración de Dragon OS?', r.stdout)
        self.assertIn('no se borra nada de lo tuyo', r.stdout)
        self.assertNotIn('dragon-island:zsh', (self.home / '.zshrc').read_text())
        manual = [line for line in r.stdout.splitlines() if line.startswith('MANUAL: ')]
        self.assertTrue(any('dragon-island/zsh/dragon.zsh' in m and '~/.zshrc' in m for m in manual), manual)
        self.assertTrue(any('chsh -s ' in m for m in manual), manual)
        self.assertNotIn('chsh', self.log.read_text() if self.log.exists() else '')

    def test_chsh_yes_runs_it(self):
        r, rc = self.apply(FAKE_LOGIN_SHELL='/bin/bash')
        self.assertEqual(rc, 0, r.stdout[-3000:])
        self.assertIn('chsh -s ', self.log.read_text())

    def test_foreign_starship_is_backed_up_and_replaced(self):
        cfg = self.home / '.config'
        cfg.mkdir()
        (cfg / 'starship.toml').write_text('format = "$all"\n')
        r, rc = self.apply()
        self.assertEqual(rc, 0, r.stdout[-3000:])
        self.assertIn('# dragon-island — starship prompt', (cfg / 'starship.toml').read_text())
        backups = list((self.home / '.local/state/dragon-island/backups').glob('*/starship-antes-de-dragon/starship.toml'))
        self.assertEqual([b.read_text() for b in backups], ['format = "$all"\n'], 'la copia del tuyo no se pisa')
        manifest = (self.home / '.local/state/dragon-island/manifest').read_text()
        self.assertIn(f'backup\t{cfg / "starship.toml"}\t{backups[0]}', manifest)

    def test_writable_omz_is_used(self):
        for d in (self.omz, self.omz / 'custom', self.omz / 'custom/plugins'):
            d.chmod(0o755)
        r, rc = self.apply()
        self.assertEqual(rc, 0, r.stdout[-3000:])
        self.assertTrue((self.omz / 'custom/plugins/fzf-tab/fzf-tab.plugin.zsh').is_file())

    def test_migration_191_repairs_an_installed_system(self):
        # lo que dejó la instalación real: zsh enlazado, bloque puesto, sin fzf-tab y un starship.toml ajeno
        r, rc = self.apply(FAKE_GIT_FAIL='1')
        starship = self.home / '.config/starship.toml'
        starship.unlink()           # may still be a link to the repo: never write through it
        starship.write_text('format = "$all"\n')
        mig = ROOT / 'migrations/191-zsh-cachyos.sh'
        env = {'ASSUME_YES': 'true'}
        r = self.bash(f'bash "{mig}"', DRY_RUN='1', **env)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertFalse((self.plugins_dir() / 'fzf-tab').exists(), 'DRY_RUN no escribe')
        r = self.bash(f'bash "{mig}"', **env)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertTrue((self.plugins_dir() / 'fzf-tab/fzf-tab.plugin.zsh').is_file())
        self.assertIn('# dragon-island — starship prompt', (self.home / '.config/starship.toml').read_text())
        p = self.probe()
        self.assertEqual((p['prompt'], p['fzftab'], p['stderr']), ('starship', '1', '0'), p)
        before = self.snapshot()
        r = self.bash(f'bash "{mig}"', **env)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(before, self.snapshot(), 'idempotente')

    def test_migration_191_skips_without_the_shell_module(self):
        r = self.bash(f'bash "{ROOT}/migrations/191-zsh-cachyos.sh"', ASSUME_YES='true')
        self.assertEqual(r.returncode, 10, r.stdout + r.stderr)

    def test_doctor_reports_the_terminal(self):
        self.apply()
        state = self.home / '.local/state/dragon-island'
        (state / 'modules').write_text('core\nshell\n')
        r = self.bash(f'bash "{ROOT}/doctor.sh" --no-ask </dev/null')
        out = r.stdout
        section = out.split('Terminal (zsh)', 1)[1].split('\nLogin', 1)[0]
        for label in ('~/.zshrc carga Dragon', 'starship.toml de Dragon', 'Prompt activo: Starship de Dragon',
                      'Plugin zsh-autosuggestions cargado', 'Plugin zsh-syntax-highlighting cargado',
                      'Plugin fzf-tab cargado', 'zsh -i arranca sin errores'):
            self.assertIn('✔\x1b[0m ' + label, section, section)
        # sin fzf-tab: ✘ con el comando exacto
        shutil.rmtree(self.plugins_dir() / 'fzf-tab')
        section = self.bash(f'bash "{ROOT}/doctor.sh" --no-ask </dev/null').stdout.split('Terminal (zsh)', 1)[1]
        self.assertIn('Plugin fzf-tab: no está instalado', section)
        self.assertIn(f'git clone --depth 1 {FZF_TAB_REPO}', section)


if __name__ == '__main__':
    unittest.main()
