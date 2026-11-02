import hashlib
import json
import math
from pathlib import Path
import sqlite3
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tool_support import ToolCase, FIXTURES, ROOT


class Prompts(ToolCase):
    def build(self, *args, stdin=None, code=0):
        return self.cli('dragon-prompt', 'build', '--project', 'test', '--template', 'libre', *args, stdin=stdin, code=code)

    def test_templates_and_determinism(self):
        listing = self.cli('dragon-prompt', 'templates', '--project', 'test')['templates']
        self.assertEqual(len(listing), 8)
        args = ('--card', self.card(), '--template', 'implementar-tarjeta')
        first = self.build(*args); self.assertEqual(first, self.build(*args))
        self.assertIn('Función ágil', first['text']); self.assertIn('## Instrucciones', first['text'])
        self.assertEqual(first['tokens'], math.ceil(len(first['text'].encode())/3.8))

    def test_all_database_blocks(self):
        key = self.card()
        self.cli('dragon-mem', 'card', 'criteria', 'add', key, '--text', 'Pasa prueba')
        self.cli('dragon-mem', 'comment', 'add', key, '--path', 'a.py', '--line', '4', '--text', 'Revisar aquí')
        for kind in ('note', 'decision'):
            self.cli('dragon-mem', 'note', 'add', '--project', 'test', '--kind', kind, '--title', kind, '--body', 'Cuerpo '+kind)
        self.cli('dragon-mem', 'project', 'set', 'test', '--test-cmd', 'pytest', '--build-cmd', 'make')
        blocks = ['card:', 'criteria:', 'comments:', 'note:1', 'decisions:1', 'commands:', 'paths:archivo inexistente.py']
        args = [v for b in blocks for v in ('--block', b)]
        r = self.build('--card', key, *args)
        for needle in ('Pasa prueba', 'a.py:4', 'Cuerpo note', 'Cuerpo decision', 'pytest', 'make', 'archivo inexistente.py'):
            self.assertIn(needle, r['text'])

    def test_redaction_off_and_selection(self):
        r = self.build('--block', 'text:API_TOKEN=private-value', '--block', 'selection:', '--stdin', stdin='Bearer supersecret')
        self.assertEqual(sum(b['redactions'] for b in r['blocks']), 2)
        self.assertNotIn('private-value', r['text']); self.assertNotIn('supersecret', r['text'])
        self.assertEqual(r['tokens'], math.ceil(len(r['text'].encode())/3.8))
        r = self.build('--block', 'log:must-not-run', '--off', 'extra-1')
        self.assertEqual(r['text'], ''); self.assertFalse(r['blocks'][0]['enabled'])

    def test_user_template_and_scope(self):
        blocks = (FIXTURES/'prompt-user.json').read_text()
        t = self.cli('dragon-mem', 'template', 'save', '--project', 'test', '--name', 'Propia', '--blocks', blocks)
        for name in ('Propia', str(t['id'])):
            r = self.build('--template', name, '--card', self.card(), '--stdin', stdin='Seleccionado')
            self.assertIn('Revisa sin modificar', r['text']); self.assertIn('Seleccionado', r['text'])
        self.cli('dragon-mem', 'template', 'save', '--name', 'Rota', '--blocks', '[{"type":"unknown"}]')
        self.assertEqual(self.build('--template', 'Rota', code=1)['error']['code'], 'invalid_template')

    def test_diff_and_log_limits(self):
        self.fake_tool('dragon-git', 'import json\nprint(json.dumps({"hunks":[{"header":"@@ -1 +1 @@","lines":[{"t":"add","text":str(n)} for n in range(200)]}]}))\n')
        self.fake_tool('dragon-docker', 'import json\nfor n in range(100): print(json.dumps({"msg":str(n),"level":"error" if n==55 else "info","count":1}))\n')
        r = self.build('--block', 'diff:a.py', '--block', 'log:container')
        self.assertTrue(all(b['truncated'] for b in r['blocks']))
        self.assertIn('recortadas 81 líneas', r['text']); self.assertIn('recortadas 60 líneas', r['text'])
        self.assertIn('\n55\n', r['text']); self.assertNotIn('\n99\n', r['text'])

    def test_log_collapses_repeats(self):
        self.fake_tool('dragon-docker', 'import json\nfor n in range(4): print(json.dumps({"msg":"ERROR repeated","level":"error","count":2}))\n')
        self.assertIn('(×8)', self.build('--block', 'log:c')['text'])

    def test_clipboard_selection(self):
        self.fake_tool('wl-paste', 'print("Texto seleccionado")\n')
        self.assertIn('Texto seleccionado', self.build('--block', 'selection:clipboard')['text'])

    def test_send_redacted_and_history_opt_in(self):
        dest = self.home/'out.md'
        r = self.cli('dragon-prompt', 'send', '--target', 'file:'+str(dest), '--stdin', '--project', 'test', '--template', 'API_KEY=metadata-secret', stdin='API_KEY=secret123')
        self.assertEqual(dest.read_text(), '[oculto:variable]'); self.assertEqual(dest.stat().st_mode & 0o777, 0o600)
        self.assertEqual(r['body_hash'], hashlib.sha256(dest.read_bytes()).hexdigest())
        with sqlite3.connect(self.db) as db:
            row = db.execute('select body,tokens_est,template from prompt_run').fetchone()
        self.assertEqual(row[2], '[oculto:variable]')
        self.assertIsNone(row[0]); self.assertEqual(row[1], r['tokens'])
        config = self.home/'config/dragon-island'; config.mkdir(parents=True)
        (config/'settings.json').write_text('{"promptHistory":true}')
        self.cli('dragon-prompt', 'send', '--target', 'file:'+str(dest), '--stdin', stdin='Persistir')
        with sqlite3.connect(self.db) as db: self.assertEqual(db.execute('select body from prompt_run order by id desc').fetchone()[0], 'Persistir')

    def test_send_herdr_and_clipboard(self):
        for name in ('dragon-herdr', 'wl-copy'):
            self.fake_tool(name, 'import sys,os,json\nfrom pathlib import Path\nPath(os.environ["HOME"],"delivery").write_text(json.dumps([sys.argv[1:],sys.stdin.read()]))\n')
        for target in ('herdr:agent-1', 'clipboard'):
            self.cli('dragon-prompt', 'send', '--target', target, '--stdin', '--no-enter', stdin='Bearer hidden123')
            args, text = json.loads((self.home/'delivery').read_text()); self.assertEqual(text, '[oculto:bearer]')
            if target.startswith('herdr:'): self.assertEqual(args, ['prompt', 'agent-1', '--stdin', '--no-enter'])

    def test_failed_send_not_recorded_and_input_limit(self):
        self.fake_tool('wl-copy', 'raise SystemExit(1)\n')
        self.cli('dragon-prompt', 'send', '--target', 'clipboard', '--stdin', stdin='No guardar', code=1)
        with sqlite3.connect(self.db) as db: self.assertEqual(db.execute('select count(*) from prompt_run').fetchone()[0], 0)
        self.assertEqual(self.build('--stdin', stdin='x'*(1024*1024+1), code=1)['error']['code'], 'input_too_large')
        self.assertEqual(self.cli('dragon-prompt', 'send', code=2)['error']['code'], 'invalid_usage')

    def test_migration_copy_backup_idempotence_and_dry_run(self):
        import subprocess
        self.cli('dragon-mem', 'init')
        env = dict(self.env, LINK_MODE='copy', ASSUME_YES='true')
        for number in ('044-mem-install.sh', '061-prompt-tools.sh'):
            r = subprocess.run(['bash', str(ROOT/'migrations'/number)], env=env, capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stdout+r.stderr)
        installed = self.home/'.local/bin/dragon-prompt'
        r = subprocess.run([str(installed), 'templates'], env=env, capture_output=True, text=True)
        self.assertEqual(len(json.loads(r.stdout)['templates']), 8, r.stderr)
        template = self.home/'config/dragon-prompt/templates/libre.json'
        template.write_text('USER EDIT')
        for flag in ('1', 'true'):
            r = subprocess.run(['bash', str(ROOT/'migrations/061-prompt-tools.sh')], env=dict(env, DRY_RUN=flag), capture_output=True)
            self.assertEqual(r.returncode, 0); self.assertEqual(template.read_text(), 'USER EDIT')
        for _ in range(2):
            r = subprocess.run(['bash', str(ROOT/'migrations/061-prompt-tools.sh')], env=env, capture_output=True)
            self.assertEqual(r.returncode, 0, r.stderr)
        backups = list((self.home/'state/dragon-island/backups').rglob('libre.json'))
        self.assertEqual(len(backups), 1); self.assertEqual(backups[0].read_text(), 'USER EDIT')

    def test_source_redactions_in_metadata(self):
        self.fake_tool('dragon-docker', 'import json\nprint(json.dumps({"msg":"[oculto:token]","level":"error","count":1}))\n')
        self.assertEqual(self.build('--block', 'log:container')['blocks'][0]['redactions'], 1)
