import importlib.util
import json
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('installer_profiles', ROOT/'lib/installer_profiles.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class Profiles(unittest.TestCase):
    def test_default_selection_and_deduplication(self):
        profiles, packages = module.load_profiles()
        self.assertEqual(profiles, ['base', 'keyring', 'taller', 'archivos', 'editor'])
        names = [p['name'] for p in packages]
        self.assertEqual(len(names), len(set(names)))
        self.assertFalse(any('brave' in n for n in names))
        self.assertNotIn('android-studio', names)
        self.assertIn('7zip', names)
        self.assertNotIn('p7zip', names)

    def test_taller_is_one_profile(self):
        _, packages = module.load_profiles(['taller'])
        self.assertEqual({p['name'] for p in packages},
                         {'docker', 'docker-compose', 'docker-buildx', 'lazygit', 'lazydocker'})
        manifest = json.loads((ROOT/'packages/profiles.json').read_text())
        self.assertIn('herdr', str(manifest['profiles']['taller']['opt_in']))

    def test_explicit_modules_and_unknown_profile(self):
        profiles, _ = module.load_profiles(modules=['editor'])
        self.assertEqual(profiles, ['base', 'editor'])
        with self.assertRaises(ValueError):
            module.load_profiles(['typo'])

    def test_generated_document(self):
        subprocess.run([str(ROOT/'scripts/gen-package-table.sh'), '--check'], check=True)
