"""Dragon OS boot theme on a FAKE ESP / fake root in a temporary directory: nothing under the real /boot or /etc is touched.
Limine: apply, dry-run, idempotence, backups, syntax checks, entries (Windows) byte for byte, no EFI tools, regeneration (kept /
dropped → post hook), revert, config shadowing. GRUB: complete theme, managed block, idempotence, revert. Module: sudo-less run on
the fake tree, refuses without a terminal even with --yes."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
BIN = str(ROOT / 'bin/dragon-boot')
sys.path.insert(0, str(ROOT / 'dragon-core'))
import dragon_boot as db  # noqa: E402
from PIL import Image  # noqa: E402

LIMINE = '''# configuración del usuario
timeout: 10
default_entry: 2
remember_last_entry: yes
wallpaper: boot():/otro/fondo.png
interface_branding: Mi Arch
term_background: 00000000
editor_enabled: no

/Dragon OS
    protocol: linux
    path: boot():/abc123/linux/vmlinuz-linux
    cmdline: root=UUID=1234 rw quiet
    module_path: boot():/abc123/linux/initramfs-linux.img#deadbeef

/Dragon OS (fallback)
    protocol: linux
    path: boot():/abc123/linux/vmlinuz-linux
    cmdline: root=UUID=1234 rw
    module_path: boot():/abc123/linux/initramfs-linux-fallback.img#cafe

/Windows
    protocol: efi
    path: boot():/EFI/Microsoft/Boot/bootmgfw.efi
'''
GRUB_DEFAULT = '''GRUB_DEFAULT='0'
GRUB_TIMEOUT='5'
GRUB_DISTRIBUTOR='EndeavourOS'
GRUB_CMDLINE_LINUX_DEFAULT='nowatchdog loglevel=3'
GRUB_TIMEOUT_STYLE=menu
GRUB_GFXMODE=auto
GRUB_BACKGROUND='/usr/share/endeavouros/splash.png'
GRUB_DISABLE_RECOVERY='true'
'''


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def run(*args, env=None, ok=None):
    e = dict(os.environ, PYTHONDONTWRITEBYTECODE='1')
    e.update(env or {})
    r = subprocess.run([BIN, *args], capture_output=True, text=True, env=e)
    out = json.loads(r.stdout.strip().splitlines()[-1])
    if ok is not None:
        assert out['ok'] == ok, (args, r.stdout, r.stderr)
    return out


class Fake(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix='dboot'))
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.esp = self.tmp / 'esp'
        self.esp.mkdir()
        (self.esp / 'limine.conf').write_text(LIMINE)
        (self.esp / 'EFI/Microsoft/Boot').mkdir(parents=True)
        (self.esp / 'EFI/Microsoft/Boot/bootmgfw.efi').write_bytes(b'MZ-fake-windows')
        self.conf = self.esp / 'limine.conf'
        self.efi_log = self.tmp / 'efi.log'
        bindir = self.tmp / 'bin'
        bindir.mkdir()
        for tool in ('efibootmgr', 'bootctl'):
            (bindir / tool).write_text('#!/bin/sh\necho "%s $@" >> %s\nexit 0\n' % (tool, self.efi_log))
            (bindir / tool).chmod(0o755)
        self.env = dict(PATH='%s:%s' % (bindir, os.environ['PATH']))

    def apply(self, *extra):
        return run('apply', '--bootloader', 'limine', '--esp', str(self.esp), *extra, env=self.env)

    def backups(self):
        return sorted(p.name for p in self.esp.glob('limine.conf.bak-dragon-*'))

    def entries(self, text=None):
        return db.entries_of(text if text is not None else self.conf.read_text())


class LimineApply(Fake):
    def test_theme_block_is_valid_and_complete(self):
        out = self.apply()
        self.assertTrue(out['ok'] and out['changed'], out)
        text = self.conf.read_text()
        errors, warnings = db.validate_limine(text, require_block=True)
        self.assertEqual(errors, [])
        for line in ('interface_branding: Dragon OS', 'timeout: 3', 'wallpaper: boot():/dragon-os/wallpaper.jpg', 'wallpaper_style: centered',
                     'backdrop: 07060d', 'interface_branding_colour: c50ed2'):
            self.assertIn(line, text)
        pal = [l for l in text.splitlines() if l.startswith('term_palette:')][0].split(': ')[1].split(';')
        self.assertEqual(len(pal), 8)
        for c in ('c50ed2', '00c1e4', '7c3aed', '06c993'):        # the four colours of the identity are all in the palette
            self.assertIn(c, pal)
        self.assertEqual(pal[0], db.palette()['bg'])               # black = Theme.qml bg

    def test_palette_comes_from_theme_qml(self):
        theme = (ROOT / 'config/quickshell/Theme.qml').read_text()
        for name in ('bg', 'text', 'cyan', 'violet'):
            self.assertIn('"#%s"' % db.palette()[name], theme.lower())

    def test_entries_and_windows_are_byte_for_byte_identical(self):
        before = self.entries()
        self.apply()
        self.assertEqual(self.entries(), before)
        self.assertIn('/Windows', self.conf.read_text())
        self.assertIn('bootmgfw.efi', self.conf.read_text())
        self.assertEqual((self.esp / 'EFI/Microsoft/Boot/bootmgfw.efi').read_bytes(), b'MZ-fake-windows')
        self.assertEqual(db.windows_entries(self.conf.read_text()), ['Windows'])
        # the user's own settings that the theme does not own are kept as they were
        for line in ('default_entry: 2', 'remember_last_entry: yes', 'editor_enabled: no'):
            self.assertIn('\n' + line + '\n', self.conf.read_text())

    def test_users_conflicting_options_are_commented_not_deleted(self):
        self.apply()
        text = self.conf.read_text()
        self.assertIn('# dragon-boot desactivó: wallpaper: boot():/otro/fondo.png', text)
        self.assertIn('# dragon-boot desactivó: timeout: 10', text)
        self.assertIn('# dragon-boot desactivó: interface_branding: Mi Arch', text)

    def test_backup_with_date_next_to_the_file(self):
        self.apply()
        names = self.backups()
        self.assertEqual(len(names), 1)
        self.assertRegex(names[0], r'^limine\.conf\.bak-dragon-\d{8}-\d{6}$')
        self.assertEqual((self.esp / names[0]).read_text(), LIMINE)

    def test_idempotent_no_second_backup_no_rewrite(self):
        self.apply()
        digest, backups = sha(self.conf), self.backups()
        mtime = self.conf.stat().st_mtime_ns
        out = self.apply()
        self.assertFalse(out['changed'], out)
        self.assertEqual((sha(self.conf), self.backups(), self.conf.stat().st_mtime_ns), (digest, backups, mtime))

    def test_every_change_gets_its_own_backup_and_old_ones_stay(self):
        self.apply()
        first = self.backups()
        self.conf.write_text(self.conf.read_text().replace('timeout: 3', 'timeout: 3\n#').replace('\n#\n', '\n'))
        self.apply('--timeout', '7')
        second = self.backups()
        self.assertEqual(len(second), 2)
        self.assertTrue(set(first) <= set(second))

    def test_dry_run_writes_nothing_and_shows_the_diff(self):
        before = {str(p): sha(p) for p in self.esp.rglob('*') if p.is_file()}
        out = self.apply('--dry-run')
        self.assertTrue(out['ok'] and out['dry_run'] and out['changed'])
        self.assertIn('+interface_branding: Dragon OS', out['diff'])
        self.assertIn('# dragon-boot desactivó: timeout: 10', out['diff'])
        self.assertEqual(before, {str(p): sha(p) for p in self.esp.rglob('*') if p.is_file()})
        self.assertFalse((self.esp / 'dragon-os').exists())

    def test_never_calls_efi_tools(self):
        self.apply()
        self.apply('--dry-run')
        run('revert', '--bootloader', 'limine', '--esp', str(self.esp), env=self.env)
        self.assertFalse(self.efi_log.exists(), self.efi_log.read_text() if self.efi_log.exists() else '')
        import re
        engine = (ROOT / 'dragon-core/dragon_boot.py').read_text()
        programs = {m.group(1) for m in re.finditer(r"subprocess\.run\(\[([^,\]]+)", engine)}
        self.assertTrue(programs <= {"tool", "'grub-mkconfig'", "'grub-script-check'"}, programs)
        for name in ('lib/boot-tools.sh', 'config/boot/90-dragon-boot-theme', 'modules/boot.sh'):
            code = '\n'.join(l for l in (ROOT / name).read_text().splitlines() if not l.lstrip().startswith('#'))
            self.assertNotRegex(code, r'\b(efibootmgr|bootctl|efivar|limine-install|limine-update|grub-install)\b', name)

    def test_refuses_when_the_config_checksum_is_enrolled(self):
        etc = self.tmp / 'etc2'
        (etc / 'default').mkdir(parents=True)
        (etc / 'default/limine').write_text('ENABLE_ENROLL_LIMINE_CONFIG=yes\n')
        before = sha(self.conf)
        out = run('apply', '--bootloader', 'limine', '--esp', str(self.esp), env=dict(self.env, DRAGON_BOOT_ETC=str(etc)))
        self.assertFalse(out['ok'])
        self.assertEqual(out['error']['code'], 'enrolled_config')
        self.assertEqual((sha(self.conf), self.backups()), (before, []))
        (etc / 'default/limine').write_text('ENABLE_ENROLL_LIMINE_CONFIG=no\n')
        self.assertTrue(run('apply', '--bootloader', 'limine', '--esp', str(self.esp), env=dict(self.env, DRAGON_BOOT_ETC=str(etc)))['ok'])

    def test_refuses_a_config_that_is_already_broken(self):
        self.conf.write_text('timeout 10\n' + LIMINE)
        out = self.apply()
        self.assertFalse(out['ok'])
        self.assertEqual(out['error']['code'], 'invalid_current')
        self.assertEqual(self.backups(), [])
        self.assertFalse((self.esp / 'dragon-os').exists())

    def test_syntax_check_rejects_bad_values(self):
        good = db.merge_limine(LIMINE, db.palette(), db.load_settings(), 'boot():/dragon-os/wallpaper.jpg')
        for needle, bad in (('backdrop: 07060d', 'backdrop: nothex'), ('wallpaper_style: centered', 'wallpaper_style: wobbly'),
                            ('timeout: 3', 'timeout: soon'), ('term_background: 5007060d', 'term_background: 07060d')):
            errors, _ = db.validate_limine(good.replace(needle, bad), require_block=True)
            self.assertTrue(errors, bad)
        self.assertTrue(db.validate_limine(good.replace(db.END, ''), require_block=True)[0])
        self.assertTrue(db.validate_limine('hola\n' + LIMINE)[0])

    def test_wallpaper_is_cover_fitted_not_stretched_and_baseline(self):
        src = self.tmp / 'stripes.png'
        im = Image.new('RGB', (1000, 1000), 'black')
        for i in range(0, 1000, 200):
            im.paste((255, 255, 255), (0, i, 1000, i + 100))
        im.save(src)
        self.apply('--wallpaper', str(src), '--resolution', '1920x1080')
        out = Image.open(self.esp / 'dragon-os/wallpaper.jpg')
        self.assertEqual(out.size, (1920, 1080))
        self.assertNotIn('progressive', out.info)
        col = [out.getpixel((960, y))[0] for y in range(1080)]
        edges = [y for y in range(1, 1080) if (col[y] > 80) != (col[y - 1] > 80)]
        gaps = [b - a for a, b in zip(edges, edges[1:])]
        self.assertTrue(gaps and all(abs(g - 192) <= 3 for g in gaps[1:-1]), gaps)     # 100 px × 1.92: the aspect ratio is kept

    def test_shadowing_config_is_reported_and_the_one_limine_reads_is_edited(self):
        (self.esp / 'EFI/limine').mkdir(parents=True)
        shadow = self.esp / 'EFI/limine/limine.conf'
        shadow.write_text(LIMINE)
        d = run('detect', '--esp', str(self.esp))
        self.assertEqual(d['limine']['conf'], str(shadow))
        self.assertEqual(d['limine']['shadowed_by'], [str(self.conf)])
        self.apply()
        self.assertIn(db.BEGIN, shadow.read_text())
        self.assertEqual(self.conf.read_text(), LIMINE)

    def test_revert_restores_the_original_and_removes_only_its_own_folder(self):
        self.apply()
        (self.esp / 'otra-cosa').mkdir()
        out = run('revert', '--bootloader', 'limine', '--esp', str(self.esp), env=self.env)
        self.assertTrue(out['ok'] and out['changed'])
        self.assertEqual(self.conf.read_text(), LIMINE)
        self.assertFalse((self.esp / 'dragon-os').exists())
        self.assertTrue((self.esp / 'otra-cosa').exists())
        self.assertFalse(run('revert', '--bootloader', 'limine', '--esp', str(self.esp))['changed'])

    def test_no_entries_and_empty_files(self):
        self.conf.write_text('timeout: 5\n')
        self.assertTrue(self.apply()['ok'])
        self.assertEqual(db.validate_limine(self.conf.read_text(), True)[0], [])
        run('revert', '--bootloader', 'limine', '--esp', str(self.esp))
        self.assertEqual(self.conf.read_text(), 'timeout: 5\n')


class Regeneration(Fake):
    """The CachyOS limine-entry-tool rewrites limine.conf when a kernel changes; the theme must survive (docs/BOOT.md §Regeneración)."""
    def setUp(self):
        super().setUp()
        self.system = self.tmp / 'system'
        self.etc = self.tmp / 'etc'
        (self.etc / 'default').mkdir(parents=True)
        (self.etc / 'default/limine').write_text('ESP_PATH="%s"\n' % self.esp)
        stage = self.tmp / 'stage'
        run('stage', '--bootloader', 'limine', '--out', str(stage), ok=True)
        self.system.mkdir()
        shutil.copy(ROOT / 'dragon-core/dragon_boot.py', self.system)
        shutil.copy(stage / 'settings.json', self.system)
        shutil.copy(ROOT / 'assets/wallpapers/dragon-island.jpg', self.system / 'wallpaper-src.jpg')
        self.hook_env = dict(self.env, DRAGON_BOOT_SYSTEM_DIR=str(self.system), DRAGON_BOOT_ETC=str(self.etc))
        self.assertTrue(run('apply', '--bootloader', 'limine', '--esp', str(self.esp), '--settings', str(self.system / 'settings.json'),
                            '--wallpaper', str(self.system / 'wallpaper-src.jpg'), env=self.env)['ok'])

    def hook(self):
        return subprocess.run([str(ROOT / 'config/boot/90-dragon-boot-theme')], capture_output=True, text=True, env=dict(os.environ, **self.hook_env))

    def test_regeneration_that_keeps_globals_leaves_the_theme_alone(self):
        text = self.conf.read_text().replace('/Dragon OS (fallback)', '/Dragon OS (linux-zen)\n    protocol: linux\n    path: boot():/abc123/zen/vmlinuz\n\n/Dragon OS (fallback)')
        self.conf.write_text(text)
        before = sha(self.conf)
        r = self.hook()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(sha(self.conf), before)                               # nothing to put back: no rewrite, no backup noise
        self.assertIn('linux-zen', self.conf.read_text())

    def test_regeneration_that_drops_globals_is_repaired_by_the_post_hook(self):
        regenerated = 'timeout: 3\n\n' + '\n'.join(self.entries()).replace('/Dragon OS\n', '/Dragon OS (linux)\n', 1)
        self.conf.write_text(regenerated)
        self.assertNotIn(db.BEGIN, self.conf.read_text())
        r = self.hook()
        self.assertEqual(r.returncode, 0, r.stderr)
        text = self.conf.read_text()
        self.assertEqual(db.validate_limine(text, True)[0], [])
        self.assertEqual(self.entries(text), self.entries(regenerated))        # the NEW entries stay exactly as the tool wrote them
        self.assertIn('/Windows', text)
        self.assertTrue((self.esp / 'dragon-os/wallpaper.jpg').exists())
        again = sha(self.conf)
        self.assertEqual(self.hook().returncode, 0)
        self.assertEqual(sha(self.conf), again)

    def test_a_lost_wallpaper_is_restored_too(self):
        shutil.rmtree(self.esp / 'dragon-os')
        self.assertEqual(self.hook().returncode, 0)
        self.assertTrue((self.esp / 'dragon-os/wallpaper.jpg').exists())

    def test_the_hook_is_never_fatal(self):
        (self.system / 'settings.json').write_text('{broken')
        r = self.hook()
        self.assertLess(r.returncode, 100)
        shutil.rmtree(self.system)
        self.assertEqual(self.hook().returncode, 0)                            # not installed → nothing to do

    def test_the_hook_finds_the_esp_without_etc_default_limine(self):
        (self.etc / 'default/limine').unlink()
        db_detect = db.detect(str(self.esp))
        self.assertEqual(db_detect['limine']['conf'], str(self.conf))


class Detect(unittest.TestCase):
    def tree(self, grub=False, limine=False):
        root = Path(tempfile.mkdtemp(prefix='dbd'))
        self.addCleanup(shutil.rmtree, root, True)
        if grub:
            (root / 'boot/grub').mkdir(parents=True)
            (root / 'boot/grub/grub.cfg').write_text('# grub\n')
            (root / 'etc/default').mkdir(parents=True)
            (root / 'etc/default/grub').write_text(GRUB_DEFAULT)
        if limine:
            (root / 'efi').mkdir()
            (root / 'efi/limine.conf').write_text(LIMINE)
        return root

    def test_automatic_choice(self):
        self.assertEqual(db.detect(root=str(self.tree(grub=True)))['bootloader'], 'grub')
        self.assertEqual(db.detect(root=str(self.tree(limine=True)))['bootloader'], 'limine')
        self.assertEqual(db.detect(root=str(self.tree(grub=True, limine=True)))['bootloader'], 'limine')
        self.assertIsNone(db.detect(root=str(self.tree()))['bootloader'])
        self.assertEqual(db.detect(bootloader='grub', root=str(self.tree(limine=True)))['bootloader'], 'grub')

    def test_esp_candidates_follow_limine_entry_tool(self):
        root = self.tree(limine=True)
        d = db.detect(root=str(root))
        self.assertEqual(d['limine']['esp'], str(root / 'efi'))
        self.assertEqual(d['limine']['windows'], ['Windows'])


class Grub(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp(prefix='dbg'))
        self.addCleanup(shutil.rmtree, self.root, True)
        (self.root / 'etc/default').mkdir(parents=True)
        (self.root / 'boot/grub').mkdir(parents=True)
        self.default = self.root / 'etc/default/grub'
        self.default.write_text(GRUB_DEFAULT)
        (self.root / 'boot/grub/grub.cfg').write_text('menuentry "Windows" { chainloader /EFI/Microsoft/Boot/bootmgfw.efi }\n')
        self.cfg_hash = sha(self.root / 'boot/grub/grub.cfg')

    def apply(self, *extra):
        return run('apply', '--bootloader', 'grub', '--root', str(self.root), '--no-regen', *extra)

    def test_complete_theme_images_and_fonts(self):
        out = self.apply()
        self.assertTrue(out['ok'], out)
        theme = self.root / 'boot/grub/themes/dragon-os'
        names = {p.name for p in theme.iterdir()}
        for n in ('theme.txt', 'background.png', 'select_c.png', 'select_nw.png', 'select_se.png', 'progress_highlight_c.png', 'scroll_thumb_c.png'):
            self.assertIn(n, names)
        self.assertEqual(Image.open(theme / 'background.png').size, (1920, 1080))
        text = (theme / 'theme.txt').read_text()
        for needle in ('Dragon OS', '#c50ed2', '#07060d', '"__timeout__"', 'select_*.png'):
            self.assertIn(needle, text)
        if shutil.which('grub-mkfont'):
            self.assertTrue(any(n.endswith('.pf2') for n in names), names)
            self.assertIn('Dragon UI Regular 26', text)
        else:
            self.assertIn('Unifont', text)

    def test_default_grub_block_and_user_lines(self):
        self.apply()
        text = self.default.read_text()
        self.assertEqual(db.validate_grub_default(text), [])
        self.assertIn('GRUB_THEME="/boot/grub/themes/dragon-os/theme.txt"', text)
        self.assertIn('# dragon-boot desactivó: GRUB_BACKGROUND=', text)
        self.assertIn("GRUB_CMDLINE_LINUX_DEFAULT='nowatchdog loglevel=3'", text)       # not ours
        self.assertIn("GRUB_DISTRIBUTOR='EndeavourOS'", text)                              # entry names are not renamed
        self.assertEqual(len(list((self.root / 'etc/default').glob('grub.bak-dragon-*'))), 1)

    def test_idempotent(self):
        self.apply()
        digest = sha(self.default)
        n_backups = len(list((self.root / 'etc/default').glob('grub.bak-dragon-*')))
        theme_backups = list((self.root / 'boot/grub/themes').glob('dragon-os.bak-dragon-*'))
        out = self.apply()
        self.assertFalse(out['changed'], out)
        self.assertEqual(sha(self.default), digest)
        self.assertEqual(len(list((self.root / 'etc/default').glob('grub.bak-dragon-*'))), n_backups)
        self.assertEqual(list((self.root / 'boot/grub/themes').glob('dragon-os.bak-dragon-*')), theme_backups)

    def test_dry_run_and_grub_cfg_untouched(self):
        before = sha(self.default)
        out = self.apply('--dry-run')
        self.assertTrue(out['dry_run'])
        self.assertIn('+GRUB_THEME=', out['diff'])
        self.assertEqual(sha(self.default), before)
        self.assertFalse((self.root / 'boot/grub/themes').exists())
        self.apply()
        self.assertEqual(sha(self.root / 'boot/grub/grub.cfg'), self.cfg_hash)           # --no-regen: the menu (Windows) is not even rewritten

    def test_revert(self):
        self.apply()
        out = run('revert', '--bootloader', 'grub', '--root', str(self.root))
        self.assertTrue(out['changed'])
        self.assertEqual(self.default.read_text(), GRUB_DEFAULT)
        self.assertFalse((self.root / 'boot/grub/themes/dragon-os').exists())

    def test_no_grub(self):
        self.default.unlink()
        out = self.apply()
        self.assertFalse(out['ok'])
        self.assertEqual(out['error']['code'], 'no_grub_default')

    def test_preview_renders_both_menus_without_touching_anything(self):
        out = self.root / 'prev'
        for bl in ('limine', 'grub'):
            r = run('preview', '--bootloader', bl, '--out', str(out / (bl + '.png')), ok=True)
            self.assertEqual(Image.open(out / (bl + '.png')).size, (1920, 1080))
        self.assertEqual(run('preview', '--out', str(out / 'r.png'), '--resolution', '1366x768', ok=True)['ok'], True)
        self.assertEqual(Image.open(out / 'r.png').size, (1366, 768))


class Module(Fake):
    """lib/boot-tools.sh + modules/boot.sh on the fake tree; BOOT_SUDO="" replaces sudo (the steps still print what they run)."""
    def setUp(self):
        super().setUp()
        self.system = self.tmp / 'system'
        self.hooks = self.tmp / 'hooks'
        self.home = self.tmp / 'home'
        self.home.mkdir()

    def sh(self, code, **extra):
        env = dict(os.environ, HOME=str(self.home), REPO_DIR=str(ROOT), BOOT_SUDO='', BOOT_ESP=str(self.esp), BOOT_SYSTEM_DIR=str(self.system),
                   BOOT_HOOK_DIR=str(self.hooks), BOOT_ROOT=str(self.tmp / 'noroot'), PYTHONDONTWRITEBYTECODE='1', PATH=self.env['PATH'])
        env.update(extra)
        script = '''set -Eeuo pipefail
REPO_DIR="%s"; DRY_RUN="${DRY_RUN:-false}"; ASSUME_YES=true; NO_SUDO=false; LINK_MODE=symlink
. "$REPO_DIR/lib/common.sh"; . "$REPO_DIR/modules/boot.sh"
%s''' % (ROOT, code)
        return subprocess.run(['bash', '-c', script], capture_output=True, text=True, env=env, stdin=subprocess.DEVNULL)

    def test_refuses_to_touch_boot_without_a_terminal_even_with_yes(self):
        before = sha(self.conf)
        r = self.sh('boot_apply')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(sha(self.conf), before)
        self.assertFalse(self.system.exists())
        self.assertIn('no hay terminal', r.stdout + r.stderr)

    def test_full_apply_installs_engine_hook_and_theme(self):
        r = self.sh('boot_apply', DRAGON_BOOT_ASSUME_YES='1')
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn(db.BEGIN, self.conf.read_text())
        self.assertTrue((self.system / 'dragon_boot.py').is_file())
        self.assertTrue((self.system / 'settings.json').is_file())
        hook = self.hooks / '90-dragon-boot-theme'
        self.assertTrue(hook.is_file() and os.access(hook, os.X_OK))
        self.assertIn('Volver atrás', r.stdout + r.stderr)
        before = sha(self.conf)
        r = self.sh('boot_apply', DRAGON_BOOT_ASSUME_YES='1')
        self.assertEqual(sha(self.conf), before)
        self.assertEqual(len(self.backups()), 1)

    def test_dry_run_changes_nothing_and_prints_the_diff(self):
        before = {str(p): sha(p) for p in self.tmp.rglob('*') if p.is_file()}
        r = self.sh('boot_apply', DRY_RUN='true', DRAGON_BOOT_ASSUME_YES='1')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn('+interface_branding: Dragon OS', r.stdout)
        self.assertEqual(before, {str(p): sha(p) for p in self.tmp.rglob('*') if p.is_file()})

    def test_revert_from_the_module(self):
        self.sh('boot_apply', DRAGON_BOOT_ASSUME_YES='1')
        r = self.sh('boot_revert', DRAGON_BOOT_ASSUME_YES='1')
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertEqual(self.conf.read_text(), LIMINE)
        self.assertFalse((self.hooks / '90-dragon-boot-theme').exists())

    def test_nothing_detected_is_not_an_error(self):
        r = self.sh('boot_apply', BOOT_ESP=str(self.tmp / 'nada'), DRAGON_BOOT_ASSUME_YES='1')
        self.assertEqual(r.returncode, 0, r.stderr)


if __name__ == '__main__':
    unittest.main()
