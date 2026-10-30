import ast
import importlib.util
import json
import math
import os
from pathlib import Path
import subprocess
import time
from unittest.mock import patch
from support import EngineCase, ROOT
from search_calc import calculate, Parser
from search_cmd import search as commands
from search_web import search as web
from search_emoji import search as emoji, use


class CalculatorTests(EngineCase):
    def test_more_than_forty_valid_cases(self):
        cases = {
            '2+2': '4', '2+3*4': '14', '(2+3)*4': '20', '2^3^2': '512',
            '-2^2': '-4', '(-2)^2': '4', '2^-3': '0.125', '10%3': '1',
            '20% de 350': '70', '350 + 20%': '420', '350 - 20%': '280', '350 + -20%': '280',
            '15% de propina sobre 48': '7.2', '15% tip on 48': '7.2',
            '20%': '0.2', '(20%) * 350': '70', '350 * 20%': '70',
            '1,5 + 2,5': '4', '2.500+0.500': '3', '1e3 / 2': '500',
            'sqrt(81)': '9', 'sin(0)': '0', 'cos(0)': '1', 'tan(0)': '0',
            'log(100)': '2', 'ln(e)': '1', 'abs(-5)': '5', 'round(1.6)': '2',
            'round(1.234;2)': '1.23', 'pi*0': '0', '0xFF': '255', '0b1010': '10',
            '255 a hex': '0xff', 'ff a decimal': '255', '10 to bin': '0b1010',
            '0xff a decimal': '255', '1 km a m': '1000', '100 cm to m': '1',
            '1 in a cm': '2.54', '1 ft a in': '12', '1 mi to km': '1.609344',
            '1 kg a g': '1000', '1000 mg a g': '1', '1 lb to kg': '0.45359237',
            '1 l a ml': '1000', '1 gal a l': '3.785411784', '1 cup to ml': '236.5882365',
            '0 c a f': '32', '32 f a c': '0', '273,15 k a c': '0',
            '100 °C a °F': '212', '1 h a min': '60', '2 días a h': '48',
            '1 semana a d': '7', '1 KB a B': '1000', '1 MB a KB': '1000',
            '1 GiB a MiB': '1024', '8 bits a bytes': '1', '(1+2) km a m': '3000',
            ' 2 + 2  ': '4', '1/4': '0.25'}
        self.assertGreater(len(cases), 40)
        for query, expected in cases.items():
            with self.subTest(query=query):
                self.assertEqual(calculate(query), expected)

    def test_invalid_and_hostile(self):
        for query in ('', ' ', '1/0', 'sqrt(-1)', 'log(0)', '1e999', '9^9^9',
                      '__import__("os").system("touch /tmp/no")', 'open("x")',
                      '[1]*9999999', '2**3', '2+unknown', '5 m a kg', '1 kg a USD',
                      '1+', 'round(2;9999)', '(-1)^0.5', '2;3', '9'*2000,
                      '('*200 + '1' + ')'*200, '1+2j'):
            with self.subTest(query=query):
                self.assertIsNone(calculate(query))

    def test_no_dynamic_execution_or_network_in_engine_sources(self):
        for path in (ROOT / 'dragon-core').glob('*.py'):
            if path.name.startswith('palette'):
                continue
            tree = ast.parse(path.read_text())
            for node in ast.walk(tree):
                if isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
                    self.assertNotIn(node.func.id, ('eval', 'exec', 'compile'), str(path))
                if isinstance(node, (ast.Import, ast.ImportFrom)):
                    names = [x.name for x in node.names] if isinstance(node, ast.Import) else [node.module]
                    self.assertFalse(any(name and name.split('.')[0] in ('socket', 'requests', 'http', 'ftplib') for name in names))

    def test_deadline_and_size(self):
        parser = Parser('1+1')
        parser.deadline = 0
        with self.assertRaises(ValueError):
            parser.parse()
        start = time.perf_counter()
        self.assertIsNone(calculate('9^9^9'))
        self.assertLess(time.perf_counter() - start, .05)

    def test_cli_contract_and_errors(self):
        data = self.cli('dragon-search', 'calc', '20% de 350', '--json')
        self.assertEqual(set(data), {'mode', 'query', 'results'})
        row = data['results'][0]
        self.assertEqual(set(row), {'id', 'title', 'sub', 'icon', 'kind', 'action', 'score'})
        self.assertEqual(row['action'], {'type': 'copy', 'value': '70'})
        self.assertEqual(self.cli('dragon-search', 'calc', '-2^2', '--json')['results'][0]['title'], '-4')
        self.assertEqual(self.cli('dragon-search', 'calc', 'not valid', '--json')['results'], [])
        process = subprocess.run([str(ROOT / 'bin/dragon-search'), 'unknown', '--json'], capture_output=True)
        self.assertEqual(process.returncode, 2)
        self.assertEqual(self.cli('dragon-search', 'calc', '1', '--limit', '0', '--json')['results'], [])


class CommandTests(EngineCase):
    def test_path_and_histories_no_duplicates_no_execution(self):
        executable = self.shim('test-editor', 'raise SystemExit("must never execute")\n')
        os.environ['PATH'] = str(executable.parent) + ':' + str(executable.parent)
        Path(os.environ['HISTFILE']).write_text(': 1761830000:0;test-editor file\nls -la\nls -la\n: 1761830001:2;echo hello\\\nworld\n', encoding='utf-8')
        rows = commands('test-editor')
        self.assertEqual(len(rows), 2)
        bare = next(row for row in rows if row['title'] == 'test-editor')
        self.assertEqual(bare['action'], dict(type='exec', argv=['test-editor'], terminal=False))
        hist = next(row for row in rows if row['title'] != 'test-editor')
        self.assertEqual(hist['action'], dict(type='exec', argv=['sh', '-c', 'test-editor file'], terminal=True))
        self.assertEqual(len(commands('ls -la')), 1)
        self.assertEqual(commands('echo')[0]['title'], 'echo hello\nworld')

    def test_secret_history_and_invalid_utf8(self):
        lines = ['export API_KEY=secret', 'FOO_TOKEN=abc tool', 'MY_PASSWORD=abc tool',
                 'PASSWORD=abc', 'curl -H "Authorization: Bearer abc"',
                 'curl https://user:pass@example.org', 'echo sk-abcdefgh123456',
                 'echo ghp_abcdefghijkl', 'echo AKIA1234567890123456', 'echo safe']
        Path(os.environ['HISTFILE']).write_bytes(('\n'.join(lines)).encode() + b'\necho \xff\n')
        os.environ['PATH'] = ''
        titles = [row['title'] for row in commands('echo')]
        self.assertEqual(sorted(titles), ['echo safe', 'echo �'])
        self.assertEqual(commands('curl'), [])

    def test_recent_frequency_ranking(self):
        Path(os.environ['HISTFILE']).write_text(': 1000000:0;tool old\n: 2000000:0;tool new\n: 2000000:0;tool new\n')
        os.environ['PATH'] = ''
        with patch('search_cmd.time.time', return_value=2000000):
            self.assertEqual(commands('tool')[0]['title'], 'tool new')
        path = self.shim('not-executable', '')
        path.chmod(0o644)
        self.assertEqual(commands('not-executable'), [])


class WebTests(EngineCase):
    def test_defaults_prefixes_and_encoding(self):
        for prefix, title in [('gh', 'GitHub'), ('yt', 'YouTube'), ('aw', 'ArchWiki'), ('mdn', 'MDN'),
                              ('wiki', 'Wikipedia (ES)'), ('so', 'Stack Overflow')]:
            with self.subTest(prefix=prefix):
                self.assertEqual(web(prefix + ' quickshell', 'es')[0]['title'], title)
        self.assertEqual(web('wiki test', 'en')[0]['title'], 'Wikipedia (EN)')
        self.assertEqual(web('gh\tquickshell', 'es')[0]['title'], 'GitHub')
        rows = web('gh café & #hola', 'es')
        self.assertEqual(len(rows), 9)
        self.assertTrue(rows[0]['action']['value'].endswith('caf%C3%A9%20%26%20%23hola'))
        self.assertEqual(rows[0]['sub'], 'café & #hola')
        self.assertEqual(web('hi', 'es')[0]['title'], 'DuckDuckGo')
        self.assertEqual(web('', 'es'), [])
        self.assertEqual(web('gh', 'es'), [])

    def test_custom_and_broken_configuration(self):
        path = Path(os.environ['XDG_CONFIG_HOME']) / 'dragon-island/search-engines.json'
        path.parent.mkdir(parents=True)
        path.write_text(json.dumps({'default': 'local', 'engines': [dict(id='local', name='Own', prefix='o', url='https://example.org/?q={query}')]}))
        self.assertEqual(web('o mañana', 'en')[0]['action']['value'], 'https://example.org/?q=ma%C3%B1ana')
        for bad in ('{', '[]', '{"engines":[]}', '{"engines":[{"id":"bad","name":"Bad","url":"javascript:{query}"}]}'):
            path.write_text(bad)
            self.assertEqual(web('hi', 'es')[0]['title'], 'DuckDuckGo')


class EmojiTests(EngineCase):
    def test_bilingual_accent_and_recency_read_only_search(self):
        self.assertEqual(emoji('corazón', 'es'), emoji('CORAZON', 'es'))
        self.assertTrue(emoji('flecha', 'es'))
        self.assertTrue(emoji('arrow', 'en'))
        rows = emoji('corazon', 'es')
        selected = rows[-1]
        self.assertFalse((self.home / 'state').exists())
        self.cli('dragon-search', 'emoji-use', selected['id'])
        self.assertEqual(emoji('corazon', 'es')[0]['id'], selected['id'])
        self.assertEqual(emoji('corazon', 'en')[0]['action']['value'], selected['title'])
        self.assertTrue(emoji('∞', 'es'))
        self.assertFalse(emoji('no existe xyz', 'es'))
        self.cli('dragon-search', 'emoji-use', 'invalid', code=1)

    def test_dataset_reproducible(self):
        spec = importlib.util.spec_from_file_location('build_emoji', ROOT / 'scripts/build-emoji-data.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        rows = json.loads((ROOT / 'dragon-core/search-data/emoji.json').read_text())
        self.assertEqual(rows, module.build())
        self.assertGreater(len(rows), 100)
        self.assertEqual(len({row['id'] for row in rows}), len(rows))


class TimingTests(EngineCase):
    def test_cli_modes_under_150ms(self):
        # Normal installed PATH, synthetic zsh history; includes process and wrapper startup.
        Path(os.environ['HISTFILE']).write_text(''.join(f': 1761830000:0;git status --fixture-{i}\n' for i in range(4000)))
        for mode, query in [('calc', '20% de 350'), ('cmd', 'git'), ('cmd', ''), ('web', 'gh quickshell'), ('emoji', 'corazón')]:
            durations = []
            for _ in range(5):
                start = time.perf_counter()
                rows = self.cli('dragon-search', mode, query, '--json')['results']
                durations.append((time.perf_counter() - start) * 1000)
                self.assertTrue(rows)
                self.assertEqual(rows, sorted(rows, key=lambda row: -row['score']))
                self.assertTrue(all(0 <= row['score'] <= 1 for row in rows))
            print(f'\nTIMING {mode}: ' + ' / '.join(f'{duration:.1f} ms' for duration in durations))
            self.assertLess(max(durations), 150, mode)
