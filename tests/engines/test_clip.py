import fcntl
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time
from support import EngineCase, ROOT
from dragon_clip import classify, meta, pins
from dragon_clip_store import annotate
from engine_common import atomic_json, locked, state_path


class ClassifierTests(EngineCase):
    def test_every_kind_and_spanish_labels(self):
        path = self.home / 'real file'
        path.write_text('fixture')
        inputs = [('cmd', 'echo hola', False, 'command', 'Comando'),
                  ('link', 'https://example.org/a?q=1', False, 'link', 'Enlace'),
                  ('path', str(path), False, 'path', 'Ruta'),
                  ('color', '#aBc', False, 'color', 'Color'),
                  ('image', 'Imagen', True, 'image', 'Imagen'),
                  ('text', 'texto de ejemplo', False, 'text', 'Texto')]
        entries = [dict(id=i, text=text, isImage=image) for i, text, image, _, _ in inputs]
        rows = self.cli('dragon-clip', 'classify', '--json', input=json.dumps(entries))
        self.assertEqual([row['kind'] for row in rows], [entry[3] for entry in inputs])
        self.assertEqual([row['label'] for row in rows], [entry[4] for entry in inputs])
        self.assertEqual([row['id'] for row in rows], [entry[0] for entry in inputs])
        self.assertTrue(all(set(row) == {'id', 'kind', 'label', 'preview'} for row in rows))
        self.assertFalse((self.home / 'state').exists())

    def test_colors_invalid_colors_and_missing_paths(self):
        for value in ('#123', '#123abc', 'rgb(12, 255, 0)', 'hsl(270, 50%, 20%)'):
            self.assertEqual(classify([dict(id=1, text=value)])[0]['kind'], 'color', value)
        for value in ('#12345', 'rgb(999, 0, 0)', 'rgb(nan, 0, 0)', 'hsl(0, 101%, 10%)', '/does/not/exist/fixture'):
            self.assertEqual(classify([dict(id=1, text=value)])[0]['kind'], 'text', value)
        self.assertEqual(classify([dict(id=1, text='')])[0]['preview'], '')

    def test_mask_before_truncating_and_opaque_tokens(self):
        for value in ('sk-abcdefghijklmnopqrstuvwxyz', 'ghp_123456abcdefghijklmnop',
                      'AKIA1234567890ABCDEF', 'aB12' * 10, 'abc12345' * 5,
                      'Authorization: Bearer secret', 'https://user:password@example.org'):
            row = classify([dict(id='secret', text=value)])[0]
            self.assertTrue(row['secret'], value)
            self.assertNotIn(value, row['preview'])
            self.assertIn('••••', row['preview'])
            self.assertLessEqual(len(row['preview']), 120)
        row = classify([dict(id='end', text='ordinary text ' * 20 + 'sk-abcdefghijklmnopqrstuvwxyz')])[0]
        self.assertTrue(row['secret'])
        self.assertEqual(len(row['preview']), 120)
        self.assertNotIn('secret', classify([dict(id=2, text='ordinary text')])[0])

    def test_invalid_input(self):
        self.assertIn('error', self.cli('dragon-clip', 'classify', '--json', input='{}', code=1))
        self.cli('dragon-clip', 'classify', '--json', input='[{}]', code=1)

    def test_pins_idempotent_list_add_remove(self):
        self.assertEqual(pins(), {'pins': []})
        self.assertFalse((self.home / 'state').exists())
        self.cli('dragon-clip', 'pins', 'add', '12', '--json')
        self.cli('dragon-clip', 'pins', 'add', '12', '--json')
        self.assertEqual(pins(), {'pins': ['12']})
        self.assertEqual(pins('add', '14'), {'pins': ['12', '14']})
        self.assertEqual(pins('remove', '12'), {'pins': ['14']})
        self.assertEqual(pins('remove', '12'), {'pins': ['14']})
        self.assertEqual(state_path('clip-pins.json').stat().st_mode & 0o777, 0o600)
        with self.assertRaises(ValueError):
            pins('add', '12\n34')


class StoreTests(EngineCase):
    def setUp(self):
        super().setUp()
        self.shim('wl-paste', '''import os, sys, time
if os.environ.get('MIME_HANG'): time.sleep(2)
if '--list-types' in sys.argv:
    print('text/plain')
    if os.environ.get('HINT'): print('x-kde-passwordManagerHint')
else:
    if os.environ.get('HINT_HANG'): time.sleep(2)
    print(os.environ.get('HINT_VALUE', 'secret'), end='')
''')
        self.shim('cliphist', '''import os, sys, pathlib, time
home = pathlib.Path(os.environ['HOME'])
if sys.argv[1] == 'store':
    if os.environ.get('STORE_FAIL'): sys.exit(4)
    if os.environ.get('STORE_HANG'): time.sleep(4)
    (home / 'stored-copy').write_bytes(sys.stdin.buffer.read())
else:
    identifier = sys.stdin.buffer.read()
    if identifier != b'12\\t\\n': sys.exit(1)
    sys.stdout.buffer.write((home / 'stored-copy').read_bytes())
''')
        self.shim('hyprctl', '''import os, sys, time
if os.environ.get('HYPR_HANG'): time.sleep(2)
if os.environ.get('HYPR_FAIL'): sys.exit(1)
print('{"class":"ghostty","title":"must not persist","pid":123}')
''')

    def store(self, payload=b'normal clipboard\n', code=0):
        process = subprocess.run([str(ROOT / 'bin/dragon-clip-store')], input=payload,
                                 capture_output=True, timeout=5)
        self.assertEqual(process.returncode, code, process.stderr)
        self.assertEqual(process.stdout, b'')
        return process

    def test_normal_copy_metadata_hash_and_lookup(self):
        payload = b'exact bytes\x00\xff\n'
        self.store(payload)
        self.assertEqual((self.home / 'stored-copy').read_bytes(), payload)
        path = state_path('clip-meta.json')
        contents = path.read_text()
        items = json.loads(contents)['items']
        self.assertEqual(list(items), [hashlib.sha256(payload).hexdigest()])
        metadata = items[hashlib.sha256(payload).hexdigest()]
        self.assertEqual(metadata['app'], 'ghostty')
        self.assertIsInstance(metadata['time'], int)
        self.assertNotIn('exact bytes', contents)
        self.assertNotIn('title', contents)
        self.assertNotIn('pid', contents)
        self.assertEqual(self.cli('dragon-clip', 'meta', '12', '--json'), metadata)
        self.assertEqual(meta('9999'), {})

    def test_password_manager_hint_and_sensitive_state_do_not_store(self):
        os.environ['HINT'] = '1'
        self.store(b'secret-password')
        self.assertFalse((self.home / 'stored-copy').exists())
        self.assertFalse(state_path('clip-meta.json').exists())
        del os.environ['HINT']
        os.environ['CLIPBOARD_STATE'] = 'sensitive'
        self.store()
        self.assertFalse((self.home / 'stored-copy').exists())

    def test_advertised_but_unreadable_password_hint_does_not_store(self):
        os.environ.update(HINT='1', HINT_HANG='1')
        self.store(b'secret-password')
        self.assertFalse((self.home / 'stored-copy').exists())
        self.assertFalse(state_path('clip-meta.json').exists())

    def test_nonsecret_hint_is_stored(self):
        os.environ.update(HINT='1', HINT_VALUE='public')
        self.store()
        self.assertTrue((self.home / 'stored-copy').exists())

    def test_recording_pause_survives_upgrade(self):
        flag = Path(os.environ['XDG_RUNTIME_DIR']) / 'dragon-island/clipboard-paused'
        flag.parent.mkdir(parents=True)
        flag.touch()
        self.store(b'paused copy')
        self.assertFalse((self.home / 'stored-copy').exists())
        self.assertFalse(state_path('clip-meta.json').exists())

    def test_hyprctl_failure_or_timeout_does_not_lose_copy(self):
        for variable in ('HYPR_FAIL', 'HYPR_HANG'):
            with self.subTest(variable=variable):
                os.environ[variable] = '1'
                start = time.perf_counter()
                self.store()
                self.assertLess(time.perf_counter() - start, 1)
                data = json.loads(state_path('clip-meta.json').read_text())['items']
                self.assertTrue(all(set(row) == {'time'} for row in data.values()))
                self.assertEqual(set(meta('12')), {'time'})
                self.assertTrue((self.home / 'stored-copy').exists())
                del os.environ[variable]

    def test_mime_timeout_still_stores_normal_copy(self):
        os.environ['MIME_HANG'] = '1'
        self.store()
        self.assertTrue((self.home / 'stored-copy').exists())

    def test_metadata_corruption_or_unwritable_directory_does_not_lose_copy(self):
        path = state_path('clip-meta.json')
        path.parent.mkdir(parents=True)
        path.write_text('{bad')
        self.store()
        self.assertTrue((self.home / 'stored-copy').exists())
        self.assertEqual(path.read_text(), '{bad')
        path.unlink()
        path.mkdir()
        self.store(b'second copy')
        self.assertEqual((self.home / 'stored-copy').read_bytes(), b'second copy')

    def test_busy_metadata_lock_is_nonblocking(self):
        path = state_path('clip-meta.json')
        with locked(path):
            start = time.perf_counter()
            self.store()
            self.assertLess(time.perf_counter() - start, 1)
        self.assertTrue((self.home / 'stored-copy').exists())
        self.assertFalse(path.exists())

    def test_metadata_retention_and_latest_hash_wins(self):
        path = state_path('clip-meta.json')
        with locked(path):
            atomic_json(path, {'version': 1, 'items': {str(i): {'time': i} for i in range(5000)}})
        annotate(b'new content', 5001)
        items = json.loads(path.read_text())['items']
        self.assertEqual(len(items), 5000)
        self.assertNotIn('0', items)
        digest = hashlib.sha256(b'new content').hexdigest()
        self.assertEqual(items[digest]['time'], 5001)
        annotate(b'new content', 5002)
        self.assertEqual(len(json.loads(path.read_text())['items']), 5000)
        self.assertEqual(json.loads(path.read_text())['items'][digest]['time'], 5002)

    def test_external_store_failure_is_reported_and_never_faked(self):
        os.environ['STORE_FAIL'] = '1'
        self.store(code=4)
        self.assertFalse(state_path('clip-meta.json').exists())
        del os.environ['STORE_FAIL']
        os.environ['STORE_HANG'] = '1'
        start = time.perf_counter()
        self.store(code=1)
        self.assertLess(time.perf_counter() - start, 3)
        self.assertFalse(state_path('clip-meta.json').exists())
