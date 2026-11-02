"""No real package manager, AUR, systemd or session bus is touched."""
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'lib'))
import installer_preflight as pf
import installer_prereq as prereq


def record(name, version='1.0', **fields):
    return '\n'.join(f'{k} : {v}' for k, v in {'Name': name, 'Version': version,
                      'Repository': 'cachyos-v4', 'Provides': 'None', 'Conflicts With': 'None',
                      'Replaces': 'None', 'Depends On': 'None', 'Required By': 'None', **fields}.items()) + '\n\n'


class Preflight(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root/'etc').mkdir()
        (self.root/'etc/os-release').write_text('ID=cachyos\nVERSION_ID=test\n')
        (self.root/'usr/lib/modules/6.test').mkdir(parents=True)
        (self.root/'usr/lib/modules/6.test/pkgbase').write_text('linux-cachyos\n')
        self.installed = record('linux-cachyos') + record('linux-cachyos-headers')
        self.repo = {'docker': record('docker')}
        self.aur = []
        self.bus = 'org.freedesktop.secrets 100 gnome-keyring user :1.2 session - -'
        self.enabled = set()
        self.calls = []
        self.transaction = (0, 'docker 1.0 cachyos-v4 100', '')
        self.requested = [{'name': 'docker', 'source': 'pacman', 'profiles': ['taller']}]
        for p in (patch.dict(os.environ, DRAGON_PREFLIGHT_ROOT=str(self.root)),
                  patch.object(pf, 'run', self.fake), patch.object(prereq, 'run', self.fake),
                  patch.object(pf.os, 'geteuid', return_value=1000),
                  patch.object(pf.shutil, 'which', side_effect=lambda n: '/fake/' + n if n == 'sudo' else None),
                  patch.object(pf.shutil, 'disk_usage', return_value=type('Disk', (), {'free': 20*1024**3})())):
            p.start(); self.addCleanup(p.stop)
        pf.compare.cache_clear()

    def fake(self, *args):
        self.calls.append(args)
        if args[:2] == ('pacman', '-Qi'):
            return 0, self.installed, ''
        if args[:2] == ('pacman', '-Si'):
            return (0, self.repo[args[2]], '') if args[2] in self.repo else (1, '', 'not found')
        if args[:2] == ('pacman', '-Ql'):
            return 0, 'linux-cachyos /usr/lib/modules/6.test/pkgbase', ''
        if args[:2] == ('pacman', '-Sp'):
            return self.transaction
        if args[:2] == ('pacman', '-Qqe'):
            return 0, 'linux-cachyos', ''
        if args == ('uname', '-r'):
            return 0, '6.test', ''
        if args[0] == 'curl':
            return 0, json.dumps({'results': self.aur}) if 'aur.archlinux' in args[-1] else '', ''
        if args[0] == 'busctl':
            return 0, self.bus, ''
        if args[0] == 'systemctl':
            if 'is-enabled' in args:
                return (0, 'enabled', '') if args[-1] in self.enabled else (1, 'disabled', '')
            if 'is-active' in args:
                return 3, 'inactive', ''
            return 0, 'Id=sddm.service\nActiveState=active', ''
        if args[0] == 'timedatectl':
            return 0, 'yes', ''
        if args[0] == 'getent':
            return 0, 'user:x:1000:1000::/home/user:/usr/bin/zsh', ''
        if args[0] == 'id':
            return 0, 'user wheel', ''
        if args[0] == 'lspci':
            return 0, 'VGA: AMD\n Kernel driver in use: amdgpu', ''
        if args[0] == 'vercmp':
            # Deterministic fixture versions only; integration exercises real vercmp.
            a, b = args[1:]
            return 0, str((a > b) - (a < b)), ''
        return 127, '', 'unexpected fake command: ' + repr(args)

    def inspect(self):
        return pf.Inspector(['taller'], self.requested).inspect()

    def check(self, result, code):
        return next(c for c in result['checks'] if c['id'] == code)

    def test_clean_custom_repository_and_json(self):
        data = self.inspect()
        self.assertFalse(data['blocked'])
        self.assertEqual(data['packages'][0]['repository'], 'cachyos-v4')
        self.assertTrue(json.loads(json.dumps(data))['read_only'])
        self.assertTrue(any(c[:2] == ('pacman', '-Sp') for c in self.calls))

    def test_missing_official_package_blocks(self):
        self.repo.clear()
        self.assertEqual(self.check(self.inspect(), 'package:docker')['level'], 'bloqueante')

    def test_installed_and_plan_conflict(self):
        self.installed += record('podman-docker', Provides='docker', **{'Conflicts With': 'docker'})
        self.assertTrue(self.inspect()['blocked'])
        self.installed = record('linux-cachyos-headers')
        self.repo['other'] = record('other', **{'Conflicts With': 'docker'})
        self.requested.append({'name': 'other', 'source': 'pacman', 'profiles': ['taller']})
        data = self.inspect()
        self.assertTrue(any(c['id'].startswith('conflicts:plan:') for c in data['checks']))

    def test_versioned_virtual_conflict_and_replaces(self):
        self.installed += record('old-archive', Provides='archive=2')
        self.repo['docker'] = record('docker', **{'Conflicts With': 'archive>=2', 'Replaces': 'old-archive'})
        data = self.inspect()
        self.assertTrue(data['blocked'])
        self.assertTrue(any(c['id'].startswith('replaces:') for c in data['checks']))
        self.repo['docker'] = record('docker', **{'Conflicts With': 'archive>2'})
        self.assertFalse(self.inspect()['blocked'])

    def test_aur_rpc_build_dependencies_and_failure(self):
        self.requested = [{'name': 'aur-tool', 'source': 'aur', 'profiles': ['base']}]
        self.aur = [{'Name': 'aur-tool', 'Version': '1', 'MakeDepends': ['huge-sdk']}]
        data = self.inspect()
        self.assertIn('huge-sdk', self.check(data, 'aur-build:aur-tool')['evidence'])
        self.assertEqual(data['packages'][0]['repository'], 'AUR')
        self.aur = []
        self.assertTrue(self.inspect()['blocked'])

    def test_solver_failure_is_blocking(self):
        self.transaction = (1, '', 'unresolvable dependency')
        self.assertEqual(self.check(self.inspect(), 'transaction')['level'], 'bloqueante')

    def test_wrapped_pacman_fields(self):
        data = pf.records('Name : p\nProvides : a=1\n    b=2\nConflicts With : c\n    d>=2\n\n')
        self.assertEqual(data[0]['Provides'], 'a=1 b=2')
        self.assertEqual(data[0]['Conflicts With'], 'c d>=2')

    def test_no_mutation_commands(self):
        self.inspect()
        self.assertFalse(any(c[0] == 'sudo' for c in self.calls))
        self.assertFalse(any(c[0] == 'pacman' and c[1] not in ('-Qi', '-Ql', '-Si', '-Sp', '-Qqe') for c in self.calls))
        self.assertFalse(any(c[0] == 'systemctl' and any(v in c for v in ('start', 'enable', 'disable')) for c in self.calls))

    def test_cachyos_hypr_noctalia_blocks(self):
        self.installed += record('cachyos-hypr-noctalia')
        self.assertEqual(self.check(self.inspect(), 'desktop:cachyos-hypr-noctalia')['level'], 'bloqueante')

    def test_obsolete_hyprland_settings_blocks(self):
        self.installed += record('cachyos-hyprland-settings')
        self.assertEqual(self.check(self.inspect(), 'desktop:cachyos-hyprland-settings')['level'], 'bloqueante')

    def test_noctalia_variants_block(self):
        for name in ('noctalia-shell', 'noctalia-git'):
            with self.subTest(name=name):
                self.installed = record(name)
                self.assertEqual(self.check(self.inspect(), 'desktop:' + name)['level'], 'bloqueante')

    def test_plasma_and_gnome_preserved(self):
        self.installed += record('plasma-desktop') + record('plasma-workspace') + record('gnome-shell')
        data = self.inspect()
        self.assertFalse(data['blocked'])
        for name in ('plasma-desktop', 'plasma-workspace', 'gnome-shell'):
            self.assertEqual(self.check(data, 'desktop:' + name)['level'], 'aviso')

    def test_kwallet_owner_blocks_gnome_keyring(self):
        self.installed += record('kwallet') + record('kwalletmanager')
        self.bus = 'org.freedesktop.secrets 123 kwalletd6 user :1.3 - - -'
        self.repo['gnome-keyring'] = record('gnome-keyring')
        self.requested.append({'name': 'gnome-keyring', 'source': 'pacman', 'profiles': ['keyring']})
        data = self.inspect()
        self.assertEqual(self.check(data, 'secrets-owner')['level'], 'bloqueante')
        self.assertEqual(self.check(data, 'kwallet')['level'], 'aviso')

    def test_kwallet_installed_with_gnome_owner_only_warns(self):
        self.installed += record('kwallet')
        data = self.inspect()
        self.assertFalse(data['blocked'])
        self.assertEqual(self.check(data, 'kwallet')['level'], 'aviso')
        self.assertEqual(self.check(data, 'secrets-owner')['level'], 'informacion')

    def test_bus_unavailable_or_activatable_warns_without_activation(self):
        self.bus = 'org.freedesktop.secrets - - - (activatable) - - -'
        data = self.inspect()
        self.assertEqual(self.check(data, 'secrets-owner')['level'], 'aviso')
        self.assertTrue(all('list' in c for c in self.calls if c[0] == 'busctl'))
        original = self.fake
        with patch.object(pf, 'run', lambda *a: (1, '', 'No session bus') if a[0] == 'busctl' else original(*a)):
            self.assertEqual(self.check(self.inspect(), 'secrets-owner')['level'], 'aviso')

    def test_fish_warns_without_chsh(self):
        original = self.fake
        with patch.object(pf, 'run', lambda *a: (0, 'u:x:1:1::/home/u:/usr/bin/fish', '') if a[0] == 'getent' else original(*a)):
            self.assertEqual(self.check(self.inspect(), 'login-shell')['level'], 'aviso')
        self.assertFalse(any(c[0] == 'chsh' for c in self.calls))

    def test_each_cachyos_leftover_is_only_a_warning(self):
        names = ('cachyos-hello', 'cachyos-kernel-manager', 'cachyos-packageinstaller',
                 'cachyos-wallpapers', 'firefox', 'firefox-i18n-es-es', 'vlc-plugins-all')
        self.installed += ''.join(record(n) for n in names)
        data = self.inspect()
        self.assertFalse(data['blocked'])
        for name in names:
            self.assertEqual(self.check(data, 'leftover:' + name)['level'], 'aviso')

    def test_deselected_dependency_explains_why_it_stays(self):
        self.installed += record('lazygit', **{'Required By': 'neovim-addon'})
        data = self.inspect()
        self.assertEqual(self.check(data, 'retained:lazygit')['level'], 'informacion')
        self.assertIn('neovim-addon', self.check(data, 'retained:lazygit')['evidence'])

    def test_dkms_requires_running_kernel_headers(self):
        self.installed = record('dkms') + record('nvidia-dkms')
        self.assertEqual(self.check(self.inspect(), 'headers')['level'], 'bloqueante')

    def test_running_kernel_reboot_blocks_with_dkms(self):
        self.installed += record('dkms')
        original = self.fake
        with patch.object(prereq, 'run', lambda *a: (0, 'linux-cachyos /usr/lib/modules/7.new/pkgbase', '') if a[:2] == ('pacman', '-Ql') else original(*a)):
            data = self.inspect()
        self.assertEqual(self.check(data, 'kernel')['level'], 'aviso')
        self.assertEqual(self.check(data, 'headers')['level'], 'bloqueante')

    def test_two_display_managers_block(self):
        self.enabled = {'sddm.service', 'gdm.service'}
        self.assertEqual(self.check(self.inspect(), 'display-managers')['level'], 'bloqueante')

    def test_podman_docker_compatibility_blocks(self):
        self.installed += record('podman-docker')
        self.assertEqual(self.check(self.inspect(), 'container-sockets')['level'], 'bloqueante')

    def test_shared_container_socket_blocks(self):
        self.enabled = {'docker.socket', 'podman.socket'}
        original = self.fake
        def fake(*args):
            if args[0] == 'systemctl' and 'show' in args and 'Listen' in args:
                return 0, '/run/docker.sock (Stream)', ''
            return original(*args)
        with patch.object(pf, 'run', fake):
            self.assertEqual(self.check(self.inspect(), 'container-sockets')['level'], 'bloqueante')

    def test_snapper_is_inspected_never_created(self):
        original = self.fake
        def fake(*args):
            return (0, 'root | btrfs\n1 | pre-existing', '') if args[0] == 'snapper' else original(*args)
        with patch.object(pf.shutil, 'which', side_effect=lambda n: '/fake/' + n if n in ('snapper', 'sudo') else None), patch.object(pf, 'run', fake):
            data = self.inspect()
        self.assertEqual(self.check(data, 'snapshot-plan')['level'], 'aviso')
        self.assertIn('pre-existing', self.check(data, 'snapshot-existing')['evidence'])
        self.assertTrue(all(c[1] in ('list-configs', 'list') for c in self.calls if c[0] == 'snapper'))

    def test_disk_network_clock_and_unsupported_distro(self):
        with patch.object(pf.shutil, 'disk_usage', return_value=type('Disk', (), {'free': 100})()):
            self.assertEqual(self.check(self.inspect(), 'disk:/')['level'], 'bloqueante')
        original = self.fake
        with patch.object(pf, 'run', lambda *a: (1, '', 'no network') if a[0] == 'curl' else original(*a)):
            self.assertEqual(self.check(self.inspect(), 'network')['level'], 'bloqueante')
        with patch.object(pf, 'run', lambda *a: (0, 'no', '') if a[0] == 'timedatectl' else original(*a)):
            self.assertEqual(self.check(self.inspect(), 'clock')['level'], 'aviso')
        (self.root/'etc/os-release').write_text('ID=debian\n')
        self.assertEqual(self.check(self.inspect(), 'distro')['level'], 'bloqueante')

    def test_solver_dependency_metadata_is_checked(self):
        self.transaction = (0, 'docker 1.0 cachyos-v4 100\nextra-dep 1.0 extra 200', '')
        self.repo['extra-dep'] = record('extra-dep', **{'Conflicts With': 'linux-cachyos'})
        data = self.inspect()
        self.assertTrue(data['blocked'])
        self.assertEqual(self.check(data, 'dependency:extra-dep')['level'], 'aviso')

    def test_provider_overlap_warns(self):
        self.repo['docker'] = record('docker', Provides='virtual-api=1')
        self.repo['tool'] = record('tool', Provides='virtual-api=1')
        self.requested.append({'name': 'tool', 'source': 'pacman', 'profiles': ['taller']})
        self.assertEqual(self.check(self.inspect(), 'provides:docker:tool')['level'], 'aviso')

    def test_old_installed_version_does_not_conflict_when_upgraded_in_plan(self):
        self.installed += record('tool', **{'Conflicts With': 'docker'})
        self.repo['tool'] = record('tool', version='2')
        self.requested.append({'name': 'tool', 'source': 'pacman', 'profiles': ['taller']})
        self.assertFalse(self.inspect()['blocked'])


class BinaryReadOnly(unittest.TestCase):
    def setUp(self):
        import subprocess
        self.subprocess = subprocess
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.sandbox = self.base/'sandbox'
        self.sandbox.mkdir()
        self.home = self.sandbox/'home'; self.home.mkdir()
        self.env = dict(os.environ, HOME=str(self.home), PYTHONDONTWRITEBYTECODE='1',
                        PREFLIGHT_FAKE_LOG=str(self.base/'commands.jsonl'),
                        DRAGON_PREFLIGHT_ROOT=str(self.base/'system'))
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
        for name in ('pacman', 'curl', 'busctl', 'systemctl', 'timedatectl', 'lspci', 'getent',
                     'id', 'uname', 'sudo', 'paru', 'yay', 'gum', 'gsettings', 'chsh', 'hyprctl', 'hyprpm', 'qs'):
            (bin_dir/name).symlink_to(fixture)
        self.env['PATH'] = str(bin_dir) + ':/usr/bin:/bin'
        self.env.pop('HYPRLAND_INSTANCE_SIGNATURE', None)
        (self.home/'.zshrc').write_text('# usuario\n')
        self.repo_before = subprocess.check_output(['git', 'status', '--porcelain', '-z'], cwd=ROOT)

    def snapshot(self):
        return {str(p.relative_to(self.sandbox)): (p.lstat().st_mode, p.lstat().st_mtime_ns,
                os.readlink(p) if p.is_symlink() else p.read_bytes() if p.is_file() else None)
                for p in self.sandbox.rglob('*')}

    def execute(self, *args):
        return self.subprocess.run([str(ROOT/'install.sh'), *args], cwd=ROOT, env=self.env,
                                   text=True, capture_output=True, timeout=120)

    def assert_unchanged(self, before):
        self.assertEqual(before, self.snapshot())
        self.assertEqual(self.repo_before, self.subprocess.check_output(['git', 'status', '--porcelain', '-z'], cwd=ROOT))

    def test_check_json_and_text_repeat_without_writes(self):
        before = self.snapshot()
        reports = []
        for _ in range(2):
            result = self.execute('--check', '--json', '--profiles', 'base,taller')
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            report = json.loads(result.stdout)
            # Free space is live telemetry and can change because of unrelated processes.
            # Idempotence is asserted separately on every file, mode and mtime.
            for check in report['checks']:
                if check['id'].startswith('disk:'):
                    check['evidence'] = '<live free space>'
            reports.append(report)
            self.assert_unchanged(before)
        self.assertEqual(reports[0], reports[1])
        self.assertIn('AUR', {p['repository'] for p in reports[0]['packages']})
        text = self.execute('--check', '--profiles', 'taller')
        self.assertEqual(text.returncode, 0, text.stdout + text.stderr)
        self.assertIn('SOLO LECTURA', text.stdout)
        self.assert_unchanged(before)
        calls = [json.loads(line) for line in (self.base/'commands.jsonl').read_text().splitlines()]
        self.assertFalse(any(c[0] in ('sudo', 'paru', 'yay', 'chsh', 'qs', 'hyprctl', 'hyprpm') for c in calls))

    def test_dry_run_repeat_without_writes(self):
        before = self.snapshot()
        for _ in range(2):
            result = self.execute('--dry-run', '--yes', '--modules', 'core,shell,editor,theme,plugins,keyboard,extras,keyring,login',
                                  '--extras', 'brave,protonvpn,herdr')
            self.assertEqual(result.returncode, 0, result.stdout[-4000:] + result.stderr)
            self.assert_unchanged(before)
        calls = [json.loads(line) for line in (self.base/'commands.jsonl').read_text().splitlines()]
        self.assertFalse(any(c[0] in ('sudo', 'paru', 'yay', 'chsh', 'qs', 'hyprctl', 'hyprpm') for c in calls))

    def test_bad_selection_returns_two_without_writes(self):
        before = self.snapshot()
        for args in (('--check', '--json', '--profiles', 'typo'),
                     ('--check', '--modules', 'typo'), ('--profiles', 'taller'),
                     ('--check', '--profiles', 'taller', '--modules', 'core')):
            result = self.execute(*args)
            self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
            self.assert_unchanged(before)

    def test_blocking_text_and_json_exit_one_without_writes(self):
        (Path(self.env['DRAGON_PREFLIGHT_ROOT'])/'etc/os-release').write_text('ID=debian\n')
        before = self.snapshot()
        for extra in ((), ('--json',)):
            result = self.execute('--check', '--profiles', 'taller', *extra)
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            if extra:
                self.assertTrue(json.loads(result.stdout)['blocked'])
            else:
                self.assertIn('BLOQUEADO', result.stdout)
            self.assert_unchanged(before)
