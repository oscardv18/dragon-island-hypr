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
