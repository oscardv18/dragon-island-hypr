import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('prereq', ROOT/'lib/installer_prereq.py')
p = importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)


class Prereq(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        module = self.root/'usr/lib/modules/6.test'
        module.mkdir(parents=True)
        (module/'pkgbase').write_text('linux-cachyos\n')
        (self.root/'etc').mkdir()
        (self.root/'etc/os-release').write_text('ID=cachyos\n')
        env = patch.dict(os.environ, DRAGON_PREFLIGHT_ROOT=str(self.root))
        env.start(); self.addCleanup(env.stop)

    def fake(self, *args):
        if args == ('uname', '-r'):
            return 0, '6.test', ''
        if args == ('pacman', '-Ql', 'linux-cachyos'):
            return 0, 'linux-cachyos /usr/lib/modules/6.test/pkgbase', ''
        return 0, '', ''

    def test_exact_command_and_preserve_helper(self):
        with patch.object(p, 'run', self.fake), patch.object(p.shutil, 'which', lambda n: n == 'yay'):
            data = p.prerequisites()
        self.assertEqual(data['packages'], ['git', 'base-devel', 'gum', 'curl', 'unzip', 'linux-cachyos-headers'])
        self.assertEqual(data['helper'], 'yay')

    def test_cachyos_prefers_paru_when_missing(self):
        with patch.object(p, 'run', self.fake), patch.object(p.shutil, 'which', return_value=None):
            self.assertEqual(p.prerequisites()['packages'][-1], 'paru')

    def test_reboot_before_headers(self):
        def fake(*args):
            if args[:2] == ('pacman', '-Ql'):
                return 0, 'linux-cachyos /usr/lib/modules/7.new/pkgbase', ''
            return self.fake(*args)
        with patch.object(p, 'run', fake):
            data = p.prerequisites()
        self.assertTrue(data['kernel']['reboot'])
        self.assertNotIn('linux-cachyos-headers', data['packages'])

    def test_missing_pkgbase_never_guessed(self):
        (self.root/'usr/lib/modules/6.test/pkgbase').unlink()
        with patch.object(p, 'run', self.fake):
            self.assertIsNone(p.prerequisites()['kernel']['headers'])

    def test_plain_arch_aur_not_in_pacman(self):
        (self.root/'etc/os-release').write_text('ID=arch\n')
        def fake(*args):
            if args[:2] == ('pacman', '-Si'):
                return 1, '', 'not found'
            return self.fake(*args)
        with patch.object(p, 'run', fake), patch.object(p.shutil, 'which', return_value=None):
            data = p.prerequisites()
        self.assertFalse(data['helper_repo'])
        self.assertNotIn('yay', data['packages'])
