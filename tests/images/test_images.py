import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]


class ImageTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='dragon-images-')
        self.addCleanup(temporary.cleanup)
        self.home = Path(temporary.name)
        environment = dict(HOME=str(self.home), PYTHONDONTWRITEBYTECODE='1')
        for name in ('CONFIG', 'STATE', 'DATA', 'CACHE'):
            environment[f'XDG_{name}_HOME'] = str(self.home / name.lower())
        environment['XDG_RUNTIME_DIR'] = str(self.home / 'runtime')
        self.environment = patch.dict(os.environ, environment)
        self.environment.start()
        self.addCleanup(self.environment.stop)

    def run_script(self, script, *args):
        return subprocess.run(['/bin/bash', str(ROOT / script), *map(str, args)],
                              text=True, capture_output=True, timeout=30)

    def test_limit_accepts_boundary_and_rejects_oversize(self):
        path = self.home / 'image with spaces.PNG'
        path.write_bytes(b'\0' * 1500000)
        self.assertEqual(self.run_script('tests/check-images.sh', self.home).returncode, 0)
        path.write_bytes(b'\0' * 1500001)
        result = self.run_script('tests/check-images.sh', self.home)
        self.assertEqual(result.returncode, 1)
        self.assertIn('scripts/optimize-images.sh', result.stderr)

    def test_missing_optimizer_is_an_error(self):
        path = self.home / 'image.png'
        path.touch()
        os.environ['PATH'] = str(self.home)
        result = self.run_script('scripts/optimize-images.sh', '--dry-run', path)
        self.assertEqual(result.returncode, 1)
        self.assertIn('Falta oxipng u optipng', result.stderr)

    def test_optimizer_fallback_dry_run_and_lossless_pixels(self):
        # Shims make both optimizer branches deterministic even without optional tools.
        shims = self.home / 'shims'
        shims.mkdir()
        for name in ('find', 'sort', 'stat', 'mktemp', 'cp', 'cat', 'rm', 'bash'):
            (shims / name).symlink_to(shutil.which(name))
        marker = self.home / 'called'
        for tool in ('optipng', 'oxipng'):
            optimizer = shims / tool
            optimizer.write_text(f'#!/bin/bash\nprintf "%s" {tool} > "{marker}"\n')
            optimizer.chmod(0o755)
            path = self.home / 'image with spaces.png'
            shutil.copyfile(ROOT / 'docs/screenshots/launcher.png', path)
            os.environ['PATH'] = str(shims)
            before = (path.stat(), hashlib.sha256(path.read_bytes()).digest())
            result = self.run_script('scripts/optimize-images.sh', '--dry-run', path)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(marker.exists())
            self.assertEqual((path.stat(), hashlib.sha256(path.read_bytes()).digest()), before)
            result = self.run_script('scripts/optimize-images.sh', path)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(marker.read_text(), tool)
            self.assertEqual(hashlib.sha256(path.read_bytes()).digest(), before[1])
            marker.unlink()

    @unittest.skipUnless(shutil.which('magick'), 'ImageMagick unavailable')
    def test_resize_preserves_aspect_ratio_and_never_upscales(self):
        shims = self.home / 'shims'
        shims.mkdir()
        optimizer = shims / 'oxipng'
        optimizer.write_text('#!/bin/bash\nexit 0\n')
        optimizer.chmod(0o755)
        os.environ['PATH'] = str(shims) + os.pathsep + os.environ['PATH']
        path = self.home / 'wide.png'
        subprocess.run(['magick', '-size', '2732x1536', 'xc:purple', str(path)], check=True)
        result = self.run_script('scripts/optimize-images.sh', '--resize', path)
        self.assertEqual(result.returncode, 0, result.stderr)
        size = subprocess.check_output(['magick', 'identify', '-format', '%wx%h', str(path)], text=True)
        self.assertEqual(size, '1366x768')
        before = path.read_bytes()
        self.assertEqual(self.run_script('scripts/optimize-images.sh', '--resize', path).returncode, 0)
        self.assertEqual(path.read_bytes(), before)
