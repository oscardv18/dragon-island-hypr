"""Pure logic of Dragon Portal (portal_core.py + the `take` / `reply` / `status` CLI): no bus, no explorer."""
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'dragon-core'))
import portal_core as core  # noqa: E402


class Temp(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix='dpc', dir='/tmp')
        self.addCleanup(subprocess.run, ['rm', '-rf', self.tmp])
        rt = Path(self.tmp) / 'rt'
        rt.mkdir(mode=0o700)
        self.rt = rt
        old = os.environ.get('XDG_RUNTIME_DIR')
        os.environ['XDG_RUNTIME_DIR'] = str(rt)
        self.addCleanup(lambda: os.environ.__setitem__('XDG_RUNTIME_DIR', old) if old else os.environ.pop('XDG_RUNTIME_DIR', None))


class Uris(unittest.TestCase):
    def test_encoding(self):
        self.assertEqual(core.uri_for_path('/tmp/a b'), 'file:///tmp/a%20b')
        self.assertEqual(core.uri_for_path('/tmp/-rf\n#?%é'), 'file:///tmp/-rf%0A%23%3F%25%C3%A9')
        self.assertEqual(core.uri_for_path('/tmp/./x/../y//z'), 'file:///tmp/y/z')

    def test_non_utf8_bytes_survive(self):
        path = os.fsdecode(b'/tmp/\xff\xfe.txt')
        self.assertEqual(core.uri_for_path(path), 'file:///tmp/%FF%FE.txt')

    def test_refuses_relative_or_nul(self):
        for bad in ('a.txt', '', '/tmp/a\0b', None):
            with self.assertRaises(core.PortalError):
                core.uri_for_path(bad)


class Options(unittest.TestCase):
    def test_current_folder_bytes(self):
        self.assertEqual(core.bytes_to_path(b'/tmp/x\0'), '/tmp/x')
        self.assertEqual(core.bytes_to_path(b'relative\0'), '')
        self.assertEqual(core.bytes_to_path(b''), '')

    def test_file_names_are_plain_names(self):
        names = core.file_names([b'../../x.txt\0', b'..\0', b'.\0', b'\0', b'a/b\0', b'-n\n.txt\0'])
        self.assertEqual(names, ['.._.._x.txt', 'a_b', '-n\n.txt'])

    def test_title_and_label_are_one_clean_line(self):
        r = core.build_request('open', 'org.x', 'a\nb\x1b[0m\t' + 'z' * 500, {'accept_label': '_Abrir'}, '/home/x')
        self.assertEqual(r['title'][:5], 'a b [')
        self.assertLessEqual(len(r['title']), 200)
        self.assertEqual(r['accept_label'], 'Abrir')

    def test_only_valid_filter_rules_are_kept(self):
        f = core.parse_filter(('Mix', [(0, '*.a'), (7, 'x'), (1, ''), (1, 'text/*')]))
        self.assertEqual(f['patterns'], [dict(type='glob', value='*.a'), dict(type='mime', value='text/*')])

    def test_choices_initial_value(self):
        c = core.parse_choices([('a', 'A', [('x', 'X'), ('y', 'Y')], 'y'), ('b', 'B', [('p', 'P')], ''), ('', 'no id', [], '')])
        self.assertEqual([(i['id'], i['selected']) for i in c], [('a', 'y'), ('b', 'p')])

    def test_multiple_and_directory_only_for_open(self):
        r = core.build_request('save', '', 't', {'multiple': True, 'directory': True}, '/h')
        self.assertEqual((r['multiple'], r['directory']), (False, False))

    def test_ids_are_hex_and_unique(self):
        a, b = core.new_id(), core.new_id()
        self.assertNotEqual(a, b)
        self.assertEqual(core.check_id(a), a)
        for bad in ('../x', 'A' * 32, '', 5, 'a' * 31):
            with self.assertRaises(core.PortalError):
                core.check_id(bad)


class Replies(Temp):
    def req(self, kind='open', **kw):
        r = core.build_request(kind, '', 't', kw.pop('options', {}), '/h')
        r.update(kw)
        return r

    def test_cancel_and_mismatch(self):
        r = self.req()
        self.assertEqual(core.reply_to_results(r, dict(id=r['id'], response='cancel')), (1, {}))
        with self.assertRaises(core.PortalError):
            core.reply_to_results(r, dict(id='0' * 32, response='cancel'))

    def test_open_rules(self):
        a, b = Path(self.tmp) / 'a', Path(self.tmp) / 'b'
        a.write_text('')
        b.write_text('')
        r = self.req()
        self.assertEqual(core.reply_to_results(r, dict(id=r['id'], response='accept', paths=[str(a)]))[1]['uris'], [core.uri_for_path(str(a))])
        for paths in ([], [str(a), str(b)], ['rel'], [str(a) + 'x'], [self.tmp]):
            with self.assertRaises(core.PortalError, msg=paths):
                core.reply_to_results(r, dict(id=r['id'], response='accept', paths=paths))
        r['multiple'] = True
        self.assertEqual(len(core.reply_to_results(r, dict(id=r['id'], response='accept', paths=[str(a), str(b)]))[1]['uris']), 2)

    def test_filter_index_must_exist(self):
        a = Path(self.tmp) / 'a'
        a.write_text('')
        r = self.req(filters=[dict(name='x', patterns=[])])
        for given, want in ((0, 0), (1, None), (-1, None), (True, None), ('0', None)):
            got = core.reply_to_results(r, dict(id=r['id'], response='accept', paths=[str(a)], filter=given))[1]['filter_index']
            self.assertEqual(got, want, given)

    def test_save_files_unique_names(self):
        d = Path(self.tmp)
        (d / 'x.txt').write_text('')
        r = self.req('save_files', files=['x.txt', 'x.txt', '.rc', '.rc'])
        uris = core.reply_to_results(r, dict(id=r['id'], response='accept', paths=[str(d)]))[1]['uris']
        self.assertEqual([u.rsplit('/', 1)[1] for u in uris], ['x%20%281%29.txt', 'x%20%282%29.txt', '.rc', '.rc%20%281%29'])


class Channel(Temp):
    def test_directories_and_files_are_private(self):
        core.write_private_json(core.channel('req'), 'a.json', dict(x=1))
        for p in (self.rt / 'dragon-portal', self.rt / 'dragon-portal/req'):
            self.assertEqual(stat.S_IMODE(p.stat().st_mode), 0o700)
        self.assertEqual(stat.S_IMODE((self.rt / 'dragon-portal/req/a.json').stat().st_mode), 0o600)
        self.assertEqual(core.read_private_json(core.channel('req'), 'a.json'), dict(x=1))
        self.assertEqual([p.name for p in (self.rt / 'dragon-portal/req').iterdir()], ['a.json'])      # no temporary left

    def test_refuses_loose_permissions_links_and_foreign_dirs(self):
        d = core.channel('rep')
        core.write_private_json(d, 'a.json', {})
        os.chmod(os.path.join(d, 'a.json'), 0o644)
        with self.assertRaises(core.PortalError):
            core.read_private_json(d, 'a.json')
        os.symlink('/etc/passwd', os.path.join(d, 'l.json'))
        with self.assertRaises(core.PortalError):
            core.read_private_json(d, 'l.json')
        self.assertIsNone(core.read_private_json(d, 'missing.json'))

    def test_a_link_in_place_of_the_channel_is_refused(self):
        os.symlink('/tmp', self.rt / 'dragon-portal')
        with self.assertRaises(core.PortalError):
            core.channel('req')

    def test_loose_directory_is_tightened(self):
        os.mkdir(self.rt / 'dragon-portal', 0o755)
        core.channel('req')
        self.assertEqual(stat.S_IMODE((self.rt / 'dragon-portal').stat().st_mode), 0o700)

    def test_sweep_removes_old_files_only(self):
        d = core.channel('req')
        core.write_private_json(d, 'old.json', {})
        core.write_private_json(d, 'new.json', {})
        os.utime(os.path.join(d, 'old.json'), (1, 1))
        core.sweep(3600)
        self.assertEqual(sorted(os.listdir(d)), ['new.json'])


class Cli(Temp):
    def run_cli(self, *args, stdin=''):
        env = dict(os.environ, XDG_RUNTIME_DIR=str(self.rt), PYTHONDONTWRITEBYTECODE='1')
        done = subprocess.run([str(ROOT / 'bin/dragon-portal'), *args], input=stdin.encode(), capture_output=True, env=env)
        return done.returncode, json.loads(done.stdout)

    def test_take_and_reply_roundtrip(self):
        req = core.build_request('open', 'org.x', 'Elige', {}, '/h')
        core.write_private_json(core.channel('req'), req['id'] + '.json', req)
        rc, out = self.run_cli('take', req['id'], '--json')
        self.assertEqual((rc, out['ok'], out['request']['title']), (0, True, 'Elige'))
        self.assertTrue((self.rt / 'dragon-portal/req' / (req['id'] + '.taken')).exists())
        rc, out = self.run_cli('reply', req['id'], stdin=json.dumps(dict(response='accept', paths=['/tmp/a'], id='f' * 32)))
        self.assertEqual((rc, out), (0, dict(ok=True)))
        saved = core.read_private_json(core.channel('rep'), req['id'] + '.json')
        self.assertEqual((saved['id'], saved['paths']), (req['id'], ['/tmp/a']))     # the id comes from the command line, not from the body

    def test_errors_are_json_with_code_message_hint(self):
        for args, code in ((('take', 'nope'), 'invalid_id'), (('take', 'a' * 32), 'unknown_request'), (('bogus',), 'invalid_usage')):
            rc, out = self.run_cli(*args)
            self.assertEqual((out['ok'], out['error']['code']), (False, code))
            self.assertEqual(set(out['error']), {'code', 'message', 'hint'})
        req = core.build_request('open', '', 't', {}, '/h')
        core.write_private_json(core.channel('req'), req['id'] + '.json', req)
        for body, code in (('no json', 'invalid_json'), ('{"response":"x"}', 'invalid_reply'), ('[]', 'invalid_reply')):
            rc, out = self.run_cli('reply', req['id'], stdin=body)
            self.assertEqual((rc, out['error']['code']), (1, code), body)

    def test_status_lists_pending(self):
        req = core.build_request('open', '', 't', {}, '/h')
        core.write_private_json(core.channel('req'), req['id'] + '.json', req)
        rc, out = self.run_cli('status')
        self.assertEqual(out['pending'], [req['id']])

    def test_paths_with_newlines_and_dashes_travel_in_json_only(self):
        req = core.build_request('save', '', 't', {}, '/h')
        core.write_private_json(core.channel('req'), req['id'] + '.json', req)
        path = '/tmp/-rf\nx "quoted" $(id).txt'
        self.run_cli('reply', req['id'], stdin=json.dumps(dict(response='accept', paths=[path])))
        self.assertEqual(core.read_private_json(core.channel('rep'), req['id'] + '.json')['paths'], [path])


class FolderOption(unittest.TestCase):
    def test_missing_current_folder_falls_back_to_home(self):
        r = core.build_request('open', '', 't', {'current_folder': b'/no/such/folder\0'}, '/home/x')
        self.assertEqual(r['current_folder'], '/home/x')
        r = core.build_request('open', '', 't', {'current_folder': b'/tmp\0'}, '/home/x')
        self.assertEqual(r['current_folder'], '/tmp')
        r = core.build_request('save', '', 't', {'current_folder': b'/no/such\0', 'current_file': b'/tmp/a.txt\0'}, '/home/x')
        self.assertEqual((r['current_folder'], r['current_name']), ('/tmp', 'a.txt'))
        r = core.build_request('save', '', 't', {'current_file': b'/no/such/a.txt\0'}, '/home/x')
        self.assertEqual((r['current_folder'], r['current_name']), ('/home/x', 'a.txt'))


if __name__ == '__main__':
    unittest.main()
