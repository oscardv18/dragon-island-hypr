"""Exercise the real check, plan adapter and Bash installation functions with fake pacman."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

from test_preflight import record

ROOT = Path(__file__).resolve().parents[2]


class ProviderCommands(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.registry = {
            'nodejs': record('nodejs'), 'rust': record('rust'),
            'nodejs-lts-krypton': record('nodejs-lts-krypton', Provides='nodejs=24',
                                        **{'Conflicts With': 'nodejs'}),
            'rustup': record('rustup', Provides='rust', **{'Conflicts With': 'rust'}),
        }
        bindir = self.base/'bin'; bindir.mkdir()
        fake = bindir/'fixture'
        fake.write_bytes((ROOT/'tests/preflight/fake-command.py').read_bytes())
        fake.chmod(0o755)
        for name in ('pacman', 'curl', 'busctl', 'systemctl', 'uname', 'timedatectl',
                     'lspci', 'getent', 'id', 'sudo', 'paru', 'yay', 'gum'):
            (bindir/name).symlink_to(fake)
        home = self.base/'home'; home.mkdir()
        system = self.base/'system'
        (system/'etc').mkdir(parents=True)
        (system/'etc/os-release').write_text('ID=cachyos\n')
        kernel = system/'usr/lib/modules/6.test'; kernel.mkdir(parents=True)
        (kernel/'pkgbase').write_text('linux-cachyos\n')
        self.env = dict(os.environ, PATH=str(bindir)+':/usr/bin:/bin', HOME=str(home),
                        DRAGON_PREFLIGHT_ROOT=str(system), PYTHONDONTWRITEBYTECODE='1',
                        PREFLIGHT_FAKE_PACKAGES=json.dumps(self.registry),
                        PREFLIGHT_FAKE_LOG=str(self.base/'commands.jsonl'),
                        TARGET_LOG=str(self.base/'targets.json'), LC_ALL='C')
        self.env.pop('DRAGON_EXTRAS', None)

    def installed(self, *names):
        self.env['PREFLIGHT_FAKE_INSTALLED'] = ','.join(names)

    def execute(self, *args):
        return subprocess.run(args, cwd=ROOT, env=self.env, text=True,
                              capture_output=True, timeout=90)

    def check(self, profiles='editor'):
        result = self.execute(str(ROOT/'install.sh'), '--check', '--profiles', profiles, '--json')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return json.loads(result.stdout)

    def plan(self, report):
        path = self.base/'plan.json'; path.write_text(json.dumps(report))
        result = self.execute('python3', str(ROOT/'lib/installer_plan.py'), str(path),
                              '--engine', 'base,keyring,taller,archivos,editor')
        self.assertEqual(result.returncode, 0, result.stderr)
        return [line.split('\t')[1:] for line in result.stdout.splitlines() if line.startswith('pkg\t')]

    def shell(self, function, *targets):
        # Capture the exact argv at the mutation boundary: never invoke sudo or an AUR helper.
        script = """
set -Eeuo pipefail
REPO_DIR="$PWD"; ASSUME_YES=true; AUR_HELPER=paru
. "$REPO_DIR/lib/common.sh"
log_info() { :; }
log_warn() { echo "$*" >&2; }
confirm() { return 0; }
capture() { python3 -c 'import json,os,sys; open(os.environ["TARGET_LOG"],"w").write(json.dumps(sys.argv[1:]))' "$@"; }
confirm_sudo() { shift; capture "$@"; }
run() { capture "$@"; }
"""
        if function in ('install_official', 'install_aur'):
            installer = (ROOT/'install.sh').read_text()
            definitions = installer[installer.index('# pkg_failure_cause <log-line-offset>'):installer.index('install_official || RESULT')]
            script += """
NO_SUDO=false; DRY_RUN=false; LOG=/dev/null
ev_step() { :; }; ev_warn() { :; }; ev_pkg() { :; }; ev_log() { :; }
sudo() { capture "$@"; }
run_streamed() { capture "$@"; }
pkg_installed() { return 0; }
OFFICIAL=("$@"); AURPKGS=("$@")
"""
            result = self.execute('bash', '-c', script + definitions + '\n' + function, 'provider-test', *targets)
        else:
            result = self.execute('bash', '-c', script + '\n"$@"', 'provider-test', function, *targets)
        path = Path(self.env['TARGET_LOG'])
        argv = json.loads(path.read_text()) if path.exists() else []
        path.unlink(missing_ok=True)
        return result, argv

    def test_installed_providers_are_informational_and_never_install_targets(self):
        for target, provider in (('nodejs', 'nodejs-lts-krypton'), ('rust', 'rustup')):
            with self.subTest(target=target):
                self.installed(provider)
                report = self.check()
                package = next(p for p in report['packages'] if p['name'] == target)
                self.assertEqual(package['state'], 'satisfied')
                self.assertEqual(package['provider'], provider)
                finding = next(c for c in report['checks'] if c['id'] == 'satisfied:'+target)
                self.assertEqual(finding['level'], 'informacion')
                self.assertIn('ya satisfecho (lo provee '+provider+')', finding['message'])
                row = next(row for row in self.plan(report) if row[0] == target)
                self.assertEqual(row[1], 'installed')
                for function, binary in (('ensure_pacman', 'pacman'), ('ensure_aur', 'paru'),
                                         ('install_official', 'pacman'), ('install_aur', 'paru')):
                    result, argv = self.shell(function, target, 'new-tool')
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(argv, [binary, '-S', '--needed', '--noconfirm', 'new-tool'])

    def test_all_satisfied_and_deptest_failure_never_invoke_installer(self):
        self.installed('nodejs-lts-krypton', 'rustup')
        for function in ('ensure_pacman', 'ensure_aur', 'install_official', 'install_aur'):
            result, argv = self.shell(function, 'nodejs', 'rust')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(argv, [])
            self.env['PREFLIGHT_FAKE_DEPTEST_ERROR'] = '1'
            result, argv = self.shell(function, 'nodejs', 'rust')
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(argv, [])
            self.env.pop('PREFLIGHT_FAKE_DEPTEST_ERROR')

    def test_both_real_profiles_in_either_order_install_only_explicit_providers(self):
        self.installed()
        reports = [self.check(profiles) for profiles in ('editor,mis-apps', 'mis-apps,editor')]
        for report in reports:
            packages = {p['name']: p for p in report['packages']}
            self.assertEqual(packages['nodejs']['provider'], 'nodejs-lts-krypton')
            self.assertEqual(packages['rust']['provider'], 'rustup')
            rows = self.plan(report)
            engine_targets = {r[0] for r in rows if r[1] in ('install', 'aur') and r[4] == '1'}
            self.assertFalse({'nodejs', 'rust'} & engine_targets)
            self.assertTrue({'nodejs-lts-krypton', 'rustup'} <= engine_targets)

    def test_installed_aur_provider_uses_the_same_deptest_policy(self):
        self.registry['custom-runtime'] = record('custom-runtime', Provides='grimblast-git',
                                                  **{'Conflicts With': 'grimblast-git'})
        self.env['PREFLIGHT_FAKE_PACKAGES'] = json.dumps(self.registry)
        self.installed('custom-runtime')
        report = self.check('base')
        target = next(p for p in report['packages'] if p['name'] == 'grimblast-git')
        self.assertEqual(target['source'], 'aur')
        self.assertEqual(target['provider'], 'custom-runtime')
        self.assertEqual(target['state'], 'satisfied')
        result, argv = self.shell('ensure_aur', 'grimblast-git')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(argv, [])

    def test_real_conflict_still_blocks_in_json_and_text(self):
        self.installed('nodejs-lts-krypton', 'rustup', 'cachyos-hypr-noctalia')
        for extra in ((), ('--json',)):
            result = self.execute(str(ROOT/'install.sh'), '--check', '--profiles', 'editor', *extra)
            self.assertEqual(result.returncode, 1, result.stderr)
            if extra:
                data = json.loads(result.stdout)
                self.assertTrue(data['blocked'])
                self.assertTrue(any(c['id'] == 'desktop:cachyos-hypr-noctalia' and
                                    c['level'] == 'bloqueante' for c in data['checks']))
            else:
                self.assertIn('BLOQUEADO', result.stdout)


if __name__ == '__main__':
    unittest.main()
