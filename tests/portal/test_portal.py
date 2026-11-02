"""Dragon Portal through the real xdg-desktop-portal: one test per option of OpenFile / SaveFile / SaveFiles, concurrency, and the
fall back to GTK. Private session bus (dbus-run-session), HOME/XDG temporary, simulated explorer (tests/portal/fake_explorer.py).
No window is ever opened and nothing outside the temporary directory is touched."""
import os
from pathlib import Path
import shutil
import unittest
from urllib.parse import quote

from support import Scenario, b, needs_session

FILTERS = ('a(sa(us))', [('Imágenes', [(0, '*.png'), (1, 'image/*')]), ('Texto', [(1, 'text/plain')])])
TEXT_FILTER = ('(sa(us))', ('Texto', [(1, 'text/plain')]))


def uri(path):
    return 'file://' + quote(os.fsencode(str(path)), safe='/')


def case(name, method, options=None, **extra):
    extra.setdefault('title', name)
    return dict(name=name, method=method, options=options or {}, **extra)


class Base(unittest.TestCase):
    scenario = None

    @classmethod
    def tearDownClass(cls):
        if cls.scenario:
            cls.scenario.cleanup()

    def ok(self, name):
        r = self.res[name]
        self.assertNotIn('timeout', r, name)
        self.assertNotIn('call_error', r, name)
        return r


@needs_session
class OpenFile(Base):
    @classmethod
    def setUpClass(cls):
        s = cls.scenario = Scenario()
        t = s.make_tree()
        cls.t = t
        weird = next(p for p in t.iterdir() if p.name.startswith('-x'))
        cls.weird = weird
        s.plan = {
            'basic': dict(action='accept', paths=[str(t / 'a.txt')]),
            'multiple': dict(action='accept', paths=[str(t / 'a.txt'), str(t / 'b.txt')]),
            'single-two': dict(action='accept', paths=[str(t / 'a.txt'), str(t / 'b.txt')]),
            'directory': dict(action='accept', paths=[str(t / 'd')]),
            'directory-file': dict(action='accept', paths=[str(t / 'a.txt')]),
            'file-dir': dict(action='accept', paths=[str(t / 'd')]),
            'filters': dict(action='accept', paths=[str(t / 'c.png')], filter=0),
            'filter-empty': dict(action='accept', paths=[str(t / 'a.txt')]),
            'folder': dict(action='accept', paths=[str(t / 'a.txt')]),
            'label': dict(action='accept', paths=[str(t / 'a.txt')]),
            'choices': dict(action='accept', paths=[str(t / 'a.txt')], choices={'enc': 'utf8', 'eol': 'nope'}),
            'cancel': dict(action='cancel'),
            'weird': dict(action='accept', paths=[str(weird)]),
            'relative': dict(action='accept', paths=['a.txt']),
            'missing': dict(action='accept', paths=[str(t / 'nada.txt')]),
            'close': dict(action='hang'),
            'long-title': dict(action='cancel'),
        }
        cls.res = s.run([
            case('basic', 'OpenFile', group='g1'),
            case('multiple', 'OpenFile', {'multiple': ('b', True)}, group='g1'),
            case('single-two', 'OpenFile', {'multiple': ('b', False)}, group='g1'),
            case('directory', 'OpenFile', {'directory': ('b', True)}, group='g1'),
            case('directory-file', 'OpenFile', {'directory': ('b', True)}, group='g1'),
            case('file-dir', 'OpenFile', group='g1'),
            case('filters', 'OpenFile', {'filters': FILTERS, 'current_filter': TEXT_FILTER}, group='g1'),
            case('filter-empty', 'OpenFile', {'current_filter': TEXT_FILTER}, group='g1'),
            case('folder', 'OpenFile', {'current_folder': ('ay', b(str(t / 'd')))}, group='g2'),
            case('label', 'OpenFile', {'accept_label': ('s', '_Adjuntar'), 'modal': ('b', False)}, group='g2'),
            case('choices', 'OpenFile', {'choices': ('a(ssa(ss)s)', [('enc', 'Codificación', [('utf8', 'UTF-8'), ('latin1', 'Latin-1')], 'latin1'),
                                                                     ('eol', 'Fin de línea', [('lf', 'LF'), ('crlf', 'CRLF')], '')])}, group='g2'),
            case('cancel', 'OpenFile', group='g2'),
            case('weird', 'OpenFile', group='g2'),
            case('relative', 'OpenFile', group='g2'),
            case('missing', 'OpenFile', group='g2'),
            case('close', 'OpenFile', close_after=2.5, group='g2'),
            case('long-title', 'OpenFile', title='Línea 1\nLínea 2 -- ' + 'x' * 400, group='g2'),
        ])

    def test_basic_single_file(self):
        r = self.ok('basic')
        self.assertEqual(r['response'], 0)
        self.assertEqual(r['results']['uris'], [uri(self.t / 'a.txt')])
        seen = self.scenario.seen_for('basic')
        self.assertEqual((seen['kind'], seen['multiple'], seen['directory']), ('open', False, False))
        self.assertEqual(seen['current_folder'], str(self.scenario.home))     # no current_folder → home

    def test_multiple(self):
        r = self.ok('multiple')
        self.assertEqual(r['results']['uris'], [uri(self.t / 'a.txt'), uri(self.t / 'b.txt')])
        self.assertTrue(self.scenario.seen_for('multiple')['multiple'])

    def test_multiple_false_refuses_two_files(self):
        r = self.ok('single-two')
        self.assertEqual(r['response'], 2)
        self.assertEqual(r['results'].get('uris', []), [])

    def test_directory(self):
        r = self.ok('directory')
        self.assertEqual(r['results']['uris'], [uri(self.t / 'd')])
        self.assertTrue(self.scenario.seen_for('directory')['directory'])

    def test_directory_refuses_a_file_and_files_refuse_a_directory(self):
        self.assertEqual(self.ok('directory-file')['response'], 2)
        self.assertEqual(self.ok('file-dir')['response'], 2)

    def test_filters_and_current_filter(self):
        seen = self.scenario.seen_for('filters')
        self.assertEqual([f['name'] for f in seen['filters']], ['Imágenes', 'Texto'])
        self.assertEqual(seen['filters'][0]['patterns'], [dict(type='glob', value='*.png'), dict(type='mime', value='image/*')])
        self.assertEqual(seen['current_filter'], 1)                            # «Texto» asked by the app
        r = self.ok('filters')
        self.assertEqual(r['results']['current_filter'], ['Imágenes', [[0, '*.png'], [1, 'image/*']]])   # what the user picked

    def test_current_filter_with_empty_filter_list(self):
        seen = self.scenario.seen_for('filter-empty')
        self.assertEqual(len(seen['filters']), 1)
        self.assertEqual((seen['filters'][0]['name'], seen['current_filter']), ('Texto', 0))

    def test_current_folder(self):
        self.assertEqual(self.scenario.seen_for('folder')['current_folder'], str(self.t / 'd'))
        self.assertEqual(self.ok('folder')['response'], 0)

    def test_accept_label_and_modal_do_not_break(self):
        seen = self.scenario.seen_for('label')
        self.assertEqual(seen['accept_label'], 'Adjuntar')                     # the mnemonic underscore is removed
        self.assertEqual(self.ok('label')['response'], 0)

    def test_choices(self):
        seen = self.scenario.seen_for('choices')
        self.assertEqual([(c['id'], c['selected']) for c in seen['choices']], [('enc', 'latin1'), ('eol', 'lf')])
        self.assertEqual(sorted(self.ok('choices')['results']['choices']), [['enc', 'utf8'], ['eol', 'lf']])  # invalid value → initial

    def test_cancel(self):
        r = self.ok('cancel')
        self.assertEqual((r['response'], r['results'].get('uris', [])), (1, []))

    def test_odd_file_names_make_valid_uris(self):
        r = self.ok('weird')
        got = r['results']['uris'][0]
        self.assertEqual(got, 'file://' + quote(os.fsencode(str(self.weird)), safe='/'))
        self.assertIn('%0A', got)                                              # the newline
        self.assertIn('%23%3F%25', got)                                        # # ? %
        self.assertTrue(got.isascii() and ' ' not in got and '\n' not in got)
        from gi.repository import Gio
        self.assertEqual(Gio.File.new_for_uri(got).get_path(), str(self.weird))

    def test_relative_or_missing_paths_are_refused(self):
        self.assertEqual(self.ok('relative')['response'], 2)
        self.assertEqual(self.ok('missing')['response'], 2)

    def test_closing_the_request_cancels_the_explorer(self):
        self.assertTrue(self.res['close'].get('closed'), self.res['close'])
        opened = [o for o in self.scenario.opens if o['title'] == 'close'][0]
        self.assertIn(opened['id'], self.scenario.cancels)
        self.assertEqual([g for g in self.scenario.gtk], [])                   # a long-open dialog is not a failure

    def test_title_is_one_bounded_line(self):
        seen = self.scenario.seen_for('Línea 1\nLínea 2 -- ' + 'x' * 400) or [s for s in self.scenario.seen if s['title'].startswith('Línea 1')][0]
        self.assertNotIn('\n', seen['title'])
        self.assertLessEqual(len(seen['title']), 200)


@needs_session
class SaveFile(Base):
    @classmethod
    def setUpClass(cls):
        s = cls.scenario = Scenario()
        t = cls.t = s.make_tree()
        s.plan = {
            'basic': dict(action='accept', paths=[str(t / 'nuevo.txt')]),
            'name-folder': dict(action='accept', paths=[str(t / 'd' / 'informe.pdf')]),
            'two': dict(action='accept', paths=[str(t / 'x.txt'), str(t / 'y.txt')]),
            'filters': dict(action='accept', paths=[str(t / 'img.png')], filter=0),
            'current-file': dict(action='accept', paths=[str(t / 'a.txt')]),
            'choices': dict(action='accept', paths=[str(t / 'n.txt')], choices={'fmt': 'csv'}),
            'cancel': dict(action='cancel'),
            'folder-name': dict(action='accept', paths=[str(t / 'd')]),
            'no-parent': dict(action='accept', paths=[str(t / 'nope' / 'x.txt')]),
            'weird': dict(action='accept', paths=[str(t / '-rf\n#a b.txt')]),
            'bad-name': dict(action='cancel'),
        }
        cls.res = s.run([
            case('basic', 'SaveFile', {'current_name': ('s', 'nuevo.txt')}),
            case('name-folder', 'SaveFile', {'current_name': ('s', 'informe.pdf'), 'current_folder': ('ay', b(str(t / 'd')))}),
            case('two', 'SaveFile'),
            case('filters', 'SaveFile', {'filters': FILTERS, 'current_filter': TEXT_FILTER, 'current_name': ('s', 'img')}),
            case('current-file', 'SaveFile', {'current_file': ('ay', b(str(t / 'a.txt')))}),
            case('choices', 'SaveFile', {'choices': ('a(ssa(ss)s)', [('fmt', 'Formato', [('txt', 'Texto'), ('csv', 'CSV')], 'txt')])}),
            case('cancel', 'SaveFile'),
            case('folder-name', 'SaveFile'),
            case('no-parent', 'SaveFile'),
            case('weird', 'SaveFile', {'current_name': ('s', '-rf\n#a b.txt')}),
            case('bad-name', 'SaveFile', {'current_name': ('s', '../../etc/passwd')}),
        ])

    def test_proposed_name(self):
        seen = self.scenario.seen_for('basic')
        self.assertEqual((seen['kind'], seen['current_name']), ('save', 'nuevo.txt'))
        r = self.ok('basic')
        self.assertEqual(r['results']['uris'], [uri(self.t / 'nuevo.txt')])

    def test_initial_folder(self):
        self.assertEqual(self.scenario.seen_for('name-folder')['current_folder'], str(self.t / 'd'))
        self.assertEqual(self.ok('name-folder')['results']['uris'], [uri(self.t / 'd' / 'informe.pdf')])

    def test_exactly_one_uri(self):
        self.assertEqual(self.ok('two')['response'], 2)

    def test_filters_and_current_filter(self):
        seen = self.scenario.seen_for('filters')
        self.assertEqual(seen['current_filter'], 1)
        self.assertEqual(self.ok('filters')['results']['current_filter'][0], 'Imágenes')

    def test_current_file_gives_name_and_folder(self):
        seen = self.scenario.seen_for('current-file')
        self.assertEqual((seen['current_name'], seen['current_folder']), ('a.txt', str(self.t)))

    def test_choices(self):
        self.assertEqual(self.ok('choices')['results']['choices'], [['fmt', 'csv']])

    def test_cancel(self):
        self.assertEqual(self.ok('cancel')['response'], 1)

    def test_destination_rules(self):
        self.assertEqual(self.ok('folder-name')['response'], 2)               # the name is a folder
        self.assertEqual(self.ok('no-parent')['response'], 2)                 # the folder does not exist

    def test_odd_names_are_percent_encoded(self):
        got = self.ok('weird')['results']['uris'][0]
        self.assertEqual(got, uri(self.t / '-rf\n#a b.txt'))
        self.assertTrue('%0A' in got and '%23' in got and '%20' in got)

    def test_proposed_name_cannot_climb_out(self):
        self.assertNotIn('/', self.scenario.seen_for('bad-name')['current_name'])


@needs_session
class SaveFiles(Base):
    @classmethod
    def setUpClass(cls):
        s = cls.scenario = Scenario()
        t = cls.t = s.make_tree()
        (t / 'd' / 'foto.png').write_text('x')
        s.plan = {
            'basic': dict(action='accept', paths=[str(t / 'd')]),
            'exists': dict(action='accept', paths=[str(t / 'd')]),
            'sanitize': dict(action='accept', paths=[str(t / 'd')]),
            'choices': dict(action='accept', paths=[str(t / 'd')], choices={'q': 'hi'}),
            'cancel': dict(action='cancel'),
            'file-not-folder': dict(action='accept', paths=[str(t / 'a.txt')]),
            'folder': dict(action='accept', paths=[str(t / 'd')]),
        }
        files = lambda *names: ('aay', [b(n) for n in names])
        cls.res = s.run([
            case('basic', 'SaveFiles', {'files': files('uno.txt', 'dos.txt')}),
            case('exists', 'SaveFiles', {'files': files('foto.png', 'foto.png', 'otra.png')}),
            case('sanitize', 'SaveFiles', {'files': files('.hidden', 'ñandú.txt', '-n\n.txt')}),
            case('choices', 'SaveFiles', {'files': files('q.txt'), 'choices': ('a(ssa(ss)s)', [('q', 'Calidad', [('lo', 'Baja'), ('hi', 'Alta')], 'lo')])}),
            case('cancel', 'SaveFiles', {'files': files('q.txt')}),
            case('file-not-folder', 'SaveFiles', {'files': files('q.txt')}),
            case('folder', 'SaveFiles', {'files': files('q.txt'), 'current_folder': ('ay', b(str(t / 'd')))}),
        ])

    def test_names_are_appended_to_the_folder_in_order(self):
        d = self.t / 'd'
        self.assertEqual(self.ok('basic')['results']['uris'], [uri(d / 'uno.txt'), uri(d / 'dos.txt')])
        self.assertTrue(self.scenario.seen_for('basic')['save_folder'])
        self.assertEqual(self.scenario.seen_for('basic')['files'], ['uno.txt', 'dos.txt'])

    def test_existing_and_repeated_names_get_unique(self):
        d = self.t / 'd'
        self.assertEqual(self.ok('exists')['results']['uris'], [uri(d / 'foto (1).png'), uri(d / 'foto (2).png'), uri(d / 'otra.png')])

    def test_odd_names_stay_in_the_folder(self):
        uris = self.ok('sanitize')['results']['uris']
        d = self.t / 'd'
        self.assertEqual(uris, [uri(d / '.hidden'), uri(d / 'ñandú.txt'), uri(d / '-n\n.txt')])
        self.assertTrue(all(u.startswith(uri(d) + '/') for u in uris))

    def test_choices(self):
        self.assertEqual(self.ok('choices')['results']['choices'], [['q', 'hi']])

    def test_cancel(self):
        self.assertEqual(self.ok('cancel')['response'], 1)

    def test_destination_must_be_a_folder(self):
        self.assertEqual(self.ok('file-not-folder')['response'], 2)

    def test_current_folder(self):
        self.assertEqual(self.scenario.seen_for('folder')['current_folder'], str(self.t / 'd'))


@needs_session
class Concurrency(Base):
    def test_simultaneous_requests_do_not_mix(self):
        s = Scenario()
        self.addCleanup(s.cleanup)
        t = s.make_tree()
        names = ['a.txt', 'b.txt', 'c.png']
        s.plan = {'req%d' % i: dict(action='accept', delay=0.3 * (3 - i), paths=[str(t / n)]) for i, n in enumerate(names)}
        s.plan['req3'] = dict(action='cancel', delay=0.1)
        cases = [case('req%d' % i, 'OpenFile', group='all') for i in range(4)]
        res = s.run(cases)
        for i, n in enumerate(names):
            self.assertEqual(res['req%d' % i]['results']['uris'], [uri(t / n)], i)
        self.assertEqual(res['req3']['response'], 1)
        ids = [o['id'] for o in s.opens]
        self.assertEqual(len(set(ids)), 4)


@needs_session
class FallbackToGtk(Base):
    def run_one(self, action, **env):
        s = Scenario(extra_env=env)
        self.addCleanup(s.cleanup)
        s.plan = {'x': dict(action=action)}
        res = s.run([case('x', 'OpenFile')])
        return s, res['x']

    def test_explorer_that_never_takes_the_request(self):
        s, r = self.run_one('no_take')
        self.assertEqual(r['results']['uris'], ['file:///gtk/fallback'])
        self.assertGreaterEqual(r['elapsed'], 1.8)                             # waited the acknowledgement time
        self.assertEqual([g['method'] for g in s.gtk if 'method' in g], ['OpenFile'])

    def test_opener_that_fails_falls_back_at_once(self):
        s, r = self.run_one('opener_fail')
        self.assertEqual(r['results']['uris'], ['file:///gtk/fallback'])
        self.assertLess(r['elapsed'], 1.8)

    def test_explorer_that_dies_after_taking_it(self):
        s, r = self.run_one('die')
        self.assertEqual(r['results']['uris'], ['file:///gtk/fallback'])
        self.assertTrue(s.cancels)                                              # it was told to close its window

    def test_a_dialog_the_user_keeps_open_is_not_a_failure(self):
        s = Scenario()
        self.addCleanup(s.cleanup)
        s.plan = {'x': dict(action='hang')}
        r = s.run([case('x', 'OpenFile', close_after=4.5)])['x']
        self.assertTrue(r.get('closed'))
        self.assertEqual(s.gtk, [])

    def test_save_calls_are_forwarded_with_their_method(self):
        s = Scenario(extra_env=dict(DRAGON_PORTAL_QS='/nonexistent/qs'))
        self.addCleanup(s.cleanup)
        res = s.run([case('s1', 'SaveFile', {'current_name': ('s', 'a.txt')}), case('s2', 'SaveFiles', {'files': ('aay', [b('z.txt')])})])
        self.assertEqual(res['s1']['results']['uris'], ['file:///gtk/fallback'])
        self.assertEqual(res['s2']['results']['uris'], ['file:///gtk/fallback'])
        self.assertEqual(sorted(g['method'] for g in s.gtk), ['SaveFile', 'SaveFiles'])

    def test_close_during_the_fallback_reaches_gtk(self):
        s = Scenario(extra_env=dict(FAKE_GTK_DELAY='4'))
        self.addCleanup(s.cleanup)
        s.plan = {'x': dict(action='opener_fail')}
        r = s.run([case('x', 'OpenFile', close_after=2)])['x']
        self.assertTrue(r.get('closed'))
        self.assertTrue([g for g in s.gtk if 'close' in g], s.gtk)


if __name__ == '__main__':
    unittest.main()
