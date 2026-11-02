"""Dragon OS boot theme (Limine first, GRUB as the alternative). Docs: docs/BOOT.md.

    dragon-boot detect   [--esp DIR] [--bootloader auto|limine|grub]
    dragon-boot preview  --out FILE.png [--bootloader limine|grub] [--wallpaper IMG] [--resolution WxH]
    dragon-boot stage    --bootloader limine|grub --out DIR [...]      build everything in DIR, touch nothing else
    dragon-boot apply    --bootloader limine|grub --esp DIR [--dry-run] [--settings FILE]   (root on a real /boot)
    dragon-boot reapply  [--esp DIR]                                   what the limine-entry-tool post hook runs
    dragon-boot verify   --bootloader limine|grub --esp DIR
    dragon-boot revert   --bootloader limine|grub --esp DIR

Every sub-command prints ONE JSON line {"ok":true,…} or {"ok":false,"error":{code,message,hint}} (like the other dragon-*).
Rules this tool keeps (docs/BOOT.md §Seguridad): it never calls efibootmgr or writes EFI variables, never removes or edits a boot
ENTRY (Windows included), backs up every file it replaces (`<file>.bak-dragon-YYYYmmdd-HHMMSS`, never overwritten, never deleted),
validates the new file before replacing the old one, and replaces files atomically (temporary file in the same directory + rename).
Only the GLOBAL part of limine.conf (before the first entry) is edited, inside a marked block; the user's own conflicting global
options are commented out (reversible), not deleted.
"""
import argparse
import datetime
import difflib
import json
import os
import re
import shutil
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
BEGIN = '# >>> dragon-boot: tema de Dragon OS (lo gestiona dragon-boot; no lo edites aquí) >>>'
END = '# <<< dragon-boot <<<'
DISABLED = '# dragon-boot desactivó: '
ASSET_DIR = 'dragon-os'                       # <volume root>/dragon-os/ next to limine.conf
SYSTEM_DIR = '/usr/local/lib/dragon-os-boot'   # root-owned copy used by `reapply` (the post hook)
SETTINGS_NAME = 'settings.json'
DEFAULTS = dict(branding='Dragon OS', timeout=3, resolution='1920x1080', style='centered', quality=90)

# the palette comes from Theme.qml (single source); these are the values it had on 2026-11-02 and the fallback when it is absent
FALLBACK = dict(bg='07060d', text='edebf5', textSoft='c8c4d8', textDim='a29eb6', muted='7f7a93', cyan='67e8f9', ok='86efac',
                warn='f5b04a', violet='7c3aed', accent='c50ed2', violetBase='b26bff', lavender='c8b6e6', danger='f87171')
BRAND = dict(magenta='c50ed2', cyan='00c1e4', violet='7c3aed', green='06c993')   # the four colours of the identity

LIMINE_GLOBAL = set('''timeout quiet serial serial_baudrate global_dtb default_entry remember_last_entry graphics wallpaper wallpaper_style
backdrop verbose terse randomise_memory randomize_memory hash_mismatch_panic measured_boot firmware_logo keyboard_layout mouse
interface_resolution interface_rotation interface_branding interface_branding_colour interface_branding_color interface_help_hidden
interface_help_colour interface_help_color interface_help_colour_bright interface_help_color_bright term_font term_font_size
term_font_scale term_font_spacing term_palette term_palette_bright term_background term_foreground term_background_bright
term_foreground_bright term_margin term_margin_gradient editor_enabled editor_highlighting editor_validation'''.split())
# the options the theme owns: a user's own line for any of these is commented out while the block is present
MANAGED = ['timeout', 'wallpaper', 'wallpaper_style', 'backdrop', 'interface_branding', 'interface_branding_colour',
           'interface_branding_color', 'interface_help_colour', 'interface_help_color', 'interface_help_colour_bright',
           'interface_help_color_bright', 'term_palette', 'term_palette_bright', 'term_background', 'term_foreground',
           'term_background_bright', 'term_foreground_bright', 'term_margin', 'term_margin_gradient']


class BootError(Exception):
    def __init__(self, code, message, hint=''):
        self.code, self.message, self.hint = code, message, hint
        super().__init__(message)


def emit(value):
    print(json.dumps(value, ensure_ascii=False, allow_nan=False, separators=(',', ':')), flush=True)


# ---------------------------------------------------------------- palette
def palette(theme=None):
    """Colours from Theme.qml (`readonly property color name: "#rrggbb"`), falling back to FALLBACK."""
    out = dict(FALLBACK)
    path = theme or os.path.join(REPO, 'config/quickshell/Theme.qml')
    try:
        text = open(path, encoding='utf-8').read()
    except OSError:
        return out
    for name in out:
        m = re.search(r'property color %s:\s*"#([0-9a-fA-F]{6})"' % name, text)
        if m:
            out[name] = m.group(1).lower()
    for name, pat in (('accent', r'readonly property color accent:\s*"#([0-9a-fA-F]{6})"'),):
        m = re.search(pat, text)
        if m:
            out[name] = m.group(1).lower()
    return out


def limine_colours(p):
    """term_palette (black red green brown blue magenta cyan gray) and bright (dark-gray … white), Dragon identity."""
    normal = [p['bg'], p['danger'], BRAND['green'], p['warn'], p['violet'], BRAND['magenta'], BRAND['cyan'], p['textSoft']]
    bright = [p['muted'], 'fca5a5', p['ok'], 'fcd34d', p['violetBase'], 'e879f9', p['cyan'], p['text']]
    return ';'.join(normal), ';'.join(bright)


# ---------------------------------------------------------------- wallpaper
def parse_resolution(text):
    m = re.fullmatch(r'(\d{3,5})x(\d{3,5})', str(text))
    if not m or not (320 <= int(m.group(1)) <= 7680 and 200 <= int(m.group(2)) <= 4320):
        raise BootError('invalid_resolution', 'Resolución no válida: %r' % text, 'Usa ANCHOxALTO, por ejemplo 1920x1080.')
    return int(m.group(1)), int(m.group(2))


def default_wallpaper():
    for name in sorted(os.listdir(os.path.join(REPO, 'assets/wallpapers'))) if os.path.isdir(os.path.join(REPO, 'assets/wallpapers')) else []:
        if name.lower().endswith(('.jpg', '.jpeg', '.png')):
            return os.path.join(REPO, 'assets/wallpapers', name)
    raise BootError('no_wallpaper', 'No hay papel tapiz en assets/wallpapers', 'Pasa uno con --wallpaper.')


def render_wallpaper(src, dest, width, height, p, quality=90, fmt='jpeg'):
    """Cover-fit (crop, never stretch) to width×height, a soft dark veil so the menu text reads, baseline JPEG (or PNG).
    Limine reads BMP, PNG, JPEG and QOI (CONFIG.md `wallpaper`); progressive JPEG is avoided on purpose."""
    from PIL import Image, ImageOps
    with Image.open(src) as im:
        im = ImageOps.exif_transpose(im).convert('RGB')
        im = ImageOps.fit(im, (width, height), method=Image.LANCZOS, centering=(0.5, 0.5))
    veil = Image.new('RGB', (width, height), tuple(int(p['bg'][i:i + 2], 16) for i in (0, 2, 4)))
    im = Image.blend(im, veil, 0.28)
    os.makedirs(os.path.dirname(dest) or '.', exist_ok=True)
    if fmt == 'png':
        im.save(dest, 'PNG', optimize=True)
    else:
        im.save(dest, 'JPEG', quality=quality, progressive=False, optimize=True, subsampling=0)
    return dest


# ---------------------------------------------------------------- limine.conf
def split_limine(text):
    """(global lines, entries lines): the global part ends at the first line that starts an entry (`/` in column 0)."""
    lines = text.split('\n')
    for i, line in enumerate(lines):
        if line.startswith('/'):
            return lines[:i], lines[i:]
    return lines, []


def theme_block(p, settings, wallpaper_path):
    normal, bright = limine_colours(p)
    lines = [BEGIN,
             'timeout: %s' % settings['timeout'],
             'interface_branding: %s' % settings['branding'],
             'interface_branding_colour: %s' % BRAND['magenta'],
             'interface_help_colour: %s' % p['textDim'],
             'interface_help_colour_bright: %s' % p['textSoft'],
             'wallpaper: %s' % wallpaper_path,
             'wallpaper_style: %s' % settings['style'],
             'backdrop: %s' % p['bg'],
             'term_palette: %s' % normal,
             'term_palette_bright: %s' % bright,
             'term_background: 50%s' % p['bg'],
             'term_foreground: %s' % p['text'],
             'term_background_bright: 50%s' % p['violet'],
             'term_foreground_bright: ffffff',
             'term_margin: 64',
             'term_margin_gradient: 8',
             END]
    return lines


def _key(line):
    m = re.match(r'^([A-Za-z_]+)\s*:', line)
    return m.group(1).lower() if m else None


def strip_block(lines):
    """Remove the marked block and re-enable the lines it had commented out. Returns the lines."""
    out, inside = [], False
    for line in lines:
        if line.strip() == BEGIN:
            inside = True
            continue
        if inside:
            if line.strip() == END:
                inside = False
            continue
        out.append(line[len(DISABLED):] if line.startswith(DISABLED) else line)
    if inside:
        raise BootError('broken_block', 'Falta la marca de cierre del bloque de dragon-boot', 'Revisa el archivo a mano o restaura el respaldo.')
    return out


def merge_limine(text, p, settings, wallpaper_path):
    """New limine.conf text: the global part cleaned of any previous block, the user's conflicting options commented out, the block
    appended at the END of the global part. The entries (every line from the first `/Name`) are returned byte for byte."""
    glob, entries = split_limine(text)
    glob = strip_block(glob)
    while glob and glob[-1] == '':
        glob.pop()
    kept = [(DISABLED + l if (_key(l) in MANAGED) else l) for l in glob]
    new = kept + ([''] if kept else []) + theme_block(p, settings, wallpaper_path) + ([''] if entries else [])
    return '\n'.join(new + entries) if entries else '\n'.join(new) + '\n'


def unmerge_limine(text):
    glob, entries = split_limine(text)
    glob = strip_block(glob)
    while glob and glob[-1] == '':
        glob.pop()
    return '\n'.join(glob + ([''] if entries else []) + entries) if entries else '\n'.join(glob) + '\n'


def validate_limine(text, require_block=False):
    """→ (errors, warnings). Structural syntax of what Limine reads: global `key: value` lines before the first entry, entries
    starting with `/`, the dragon block well formed and with valid values. The real `limine` tool is not run (it is not installed here)."""
    errors, warnings = [], []
    glob, entries = split_limine(text)
    opens = sum(1 for l in glob if l.strip() == BEGIN)
    closes = sum(1 for l in glob if l.strip() == END)
    if opens != closes or opens > 1:
        errors.append('bloque de dragon-boot mal formado (%d aperturas, %d cierres)' % (opens, closes))
    if require_block and opens != 1:
        errors.append('falta el bloque de dragon-boot')
    seen = {}
    for n, line in enumerate(glob, 1):
        s = line.strip()
        if not s or s.startswith('#'):
            continue
        k = _key(line)
        if k is None:
            errors.append('línea %d: no es «opción: valor»: %r' % (n, s[:60]))
            continue
        if k not in LIMINE_GLOBAL:
            warnings.append('línea %d: opción global desconocida «%s» (¿versión distinta de Limine?)' % (n, k))
        if k in seen and k not in ('wallpaper',):
            warnings.append('línea %d: «%s» está repetida (primera en la %d)' % (n, k, seen[k]))
        seen.setdefault(k, n)
        value = line.split(':', 1)[1].strip()
        if '\x00' in line:
            errors.append('línea %d: carácter NUL' % n)
        if k in ('wallpaper', 'term_font') and not value:
            errors.append('línea %d: «%s» sin valor' % (n, k))
        if k in ('backdrop', 'interface_branding_colour', 'interface_branding_color', 'interface_help_colour', 'interface_help_color',
                 'interface_help_colour_bright', 'interface_help_color_bright', 'term_foreground', 'term_foreground_bright',
                 'term_background_bright') and not re.fullmatch(r'[0-9a-fA-F]{6}', value) and k != 'term_background_bright':
            errors.append('línea %d: «%s» debe ser RRGGBB' % (n, k))
        if k in ('term_background', 'term_background_bright') and not re.fullmatch(r'[0-9a-fA-F]{8}', value):
            errors.append('línea %d: «%s» debe ser TTRRGGBB' % (n, k))
        if k in ('term_palette', 'term_palette_bright'):
            parts = value.split(';')
            if len(parts) != 8 or not all(re.fullmatch(r'[0-9a-fA-F]{6}', x.strip()) for x in parts):
                errors.append('línea %d: «%s» necesita 8 colores RRGGBB separados por «;»' % (n, k))
        if k == 'timeout' and not (value == 'no' or re.match(r'^\d+(\.\d+)?', value)):
            errors.append('línea %d: «timeout» no es un número' % n)
        if k == 'wallpaper_style' and value not in ('tiled', 'centered', 'stretched'):
            errors.append('línea %d: «wallpaper_style» debe ser tiled, centered o stretched' % n)
    for n, line in enumerate(entries, len(glob) + 1):
        if line.startswith('/'):
            if not line.lstrip('/').strip():
                errors.append('línea %d: entrada sin nombre' % n)
        elif line.strip() and not line.startswith((' ', '\t', '#')):
            errors.append('línea %d: fuera de una entrada y sin sangría: %r' % (n, line[:60]))
    if not any(l.startswith('/') for l in entries):
        warnings.append('el archivo no tiene ninguna entrada de arranque')
    return errors, warnings


def limine_candidates(esp):
    """Where Limine looks for its config, in ITS order (CONFIG.md «Location of the config file»), under a volume mounted at `esp`."""
    rel = ['EFI/limine/limine.conf', 'boot/limine/limine.conf', 'boot/limine.conf', 'limine/limine.conf', 'limine.conf']
    # on EFI `<EFI app path>/limine.conf` is first; limine-entry-tool installs limine_x64.efi in /EFI/limine/
    return [os.path.join(esp, r) for r in rel] + [os.path.join(esp, 'EFI/BOOT/limine.conf')]


def find_limine_conf(esp):
    found = [c for c in limine_candidates(esp) if os.path.isfile(c)]
    return found


def windows_entries(text):
    """Entry names that chainload Windows (bootmgfw.efi / bootmgr): informational, they are never edited."""
    names, current = [], None
    for line in text.split('\n'):
        if line.startswith('/'):
            current = line.lstrip('/').strip()
        elif current and re.search(r'(bootmgfw\.efi|bootmgr|Microsoft)', line, re.I) and ':' in line:
            if current not in names:
                names.append(current)
    return names


def entries_of(text):
    return split_limine(text)[1]


# ---------------------------------------------------------------- files
def stamp():
    return datetime.datetime.now().strftime('%Y%m%d-%H%M%S')


def backup(path, when=None):
    """`path.bak-dragon-<stamp>`, never overwriting an older backup. Returns the backup path or None when `path` does not exist."""
    if not os.path.exists(path):
        return None
    base = '%s.bak-dragon-%s' % (path, when or stamp())
    dest, n = base, 1
    while os.path.exists(dest):
        n += 1
        dest = '%s-%d' % (base, n)
    shutil.copy2(path, dest)
    return dest


def atomic_write(path, data, mode=0o644, binary=False):
    d = os.path.dirname(path) or '.'
    os.makedirs(d, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix='.dragon-boot-', dir=d)
    try:
        with os.fdopen(fd, 'wb' if binary else 'w', **({} if binary else {'encoding': 'utf-8'})) as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(tmp, mode)
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def unified(old, new, name):
    return ''.join(difflib.unified_diff(old.splitlines(True), new.splitlines(True), 'a/' + name, 'b/' + name))


# ---------------------------------------------------------------- detection
def detect(esp=None, bootloader='auto', root='/'):
    """What is in use. `root` lets the tests point at a fake tree (…/boot, …/etc)."""
    r = lambda p: os.path.join(root, p.lstrip('/'))
    candidates = [esp] if esp else [r(p) for p in ('/efi', '/boot', '/boot/efi', '/limine')]
    limine_conf = esp_found = None
    for c in candidates:
        if c and os.path.isdir(c):
            found = find_limine_conf(c)
            if found:
                limine_conf, esp_found = found[0], c
                break
    grub_cfg = next((r(p) for p in ('/boot/grub/grub.cfg', '/boot/grub2/grub.cfg') if os.path.isfile(r(p))), None)
    have_limine_tool = any(os.path.exists(r(p)) for p in ('/usr/bin/limine-entry-tool', '/usr/bin/limine-update', '/usr/bin/limine'))
    in_use = limine_conf or (have_limine_tool and not grub_cfg)
    chosen = bootloader if bootloader != 'auto' else ('limine' if in_use else ('grub' if grub_cfg else None))
    text = ''
    if limine_conf:
        try:
            text = open(limine_conf, encoding='utf-8', errors='replace').read()
        except OSError:
            text = ''
    return dict(bootloader=chosen, limine=dict(conf=limine_conf, esp=esp_found, shadowed_by=find_limine_conf(esp_found)[1:] if esp_found else [],
                                                tool=have_limine_tool, themed=BEGIN in text, windows=windows_entries(text)),
                grub=dict(cfg=grub_cfg, default=r('/etc/default/grub') if os.path.isfile(r('/etc/default/grub')) else None),
                efi=os.path.isdir(r('/sys/firmware/efi')))


# ---------------------------------------------------------------- Limine: plan / apply
def load_settings(args_settings=None, **over):
    s = dict(DEFAULTS)
    if args_settings and os.path.isfile(args_settings):
        s.update(json.load(open(args_settings, encoding='utf-8')))
    s.update({k: v for k, v in over.items() if v is not None})
    parse_resolution(s['resolution'])
    if not re.fullmatch(r'[\w .\-]{1,40}', str(s['branding'])):
        raise BootError('invalid_branding', 'La marca solo admite letras, números, espacio, punto y guion (máx. 40)')
    if str(s['timeout']) != 'no' and not re.fullmatch(r'\d{1,3}(\.\d{1,2})?', str(s['timeout'])):
        raise BootError('invalid_timeout', 'timeout debe ser un número de segundos o «no»')
    if s['style'] not in ('centered', 'stretched', 'tiled'):
        raise BootError('invalid_style', 'style debe ser centered, stretched o tiled')
    return s


def plan_limine(esp, settings, source=None, wallpaper=None, conf=None, current_text=None, stage_assets=None):
    """Build (without writing to the ESP) the new limine.conf and the asset to deploy.
    Returns dict(conf, old, new, diff, wallpaper_rel, errors, warnings, windows). `current_text` = the config content (tests / sudo cat)."""
    p = palette()
    p.update(settings.get('palette') or {})        # frozen snapshot taken at install time (the post hook has no Theme.qml)
    found = find_limine_conf(esp) if conf is None else [conf]
    if not found and current_text is None:
        raise BootError('no_limine_conf', 'No encuentro limine.conf bajo %s' % esp,
                        'Busca en: %s. Ejecuta dragon-boot detect.' % ', '.join(os.path.relpath(c, esp) for c in limine_candidates(esp)[:5]))
    conf = conf or found[0]
    old = current_text if current_text is not None else open(conf, encoding='utf-8', errors='surrogateescape').read()
    errs, _ = validate_limine(old)
    hard = [e for e in errs if 'bloque' not in e]
    if hard:
        raise BootError('invalid_current', 'El limine.conf actual ya tiene problemas de sintaxis; no lo toco: ' + '; '.join(hard[:3]),
                        'Arréglalo o restaura un respaldo antes de tematizar.')
    ext = 'jpg'
    rel = 'boot():/%s/wallpaper.%s' % (ASSET_DIR, ext)
    new = merge_limine(old, p, settings, rel)
    errors, warnings = validate_limine(new, require_block=True)
    if entries_of(old) != entries_of(new):                      # the invariant: entries are never touched
        errors.append('las entradas de arranque habrían cambiado (no se aplica)')
    return dict(conf=conf, old=old, new=new, diff=unified(old, new, os.path.basename(conf)), wallpaper_rel=rel, errors=errors,
                warnings=warnings, windows=windows_entries(old), palette=p)


def enroll_enabled(etc=None):
    """`ENABLE_ENROLL_LIMINE_CONFIG=yes` (limine-entry-tool): the config checksum is embedded in the Limine binary and ANY edit of
    limine.conf makes it refuse to boot until it is enrolled again. We never edit under that setting."""
    etc = etc or os.environ.get('DRAGON_BOOT_ETC', '/etc')
    value = None
    for f in (os.path.join(etc, 'limine-entry-tool.conf'), os.path.join(etc, 'default/limine')):      # later file overrides
        try:
            for line in open(f, encoding='utf-8', errors='replace'):
                m = re.match(r'^\s*ENABLE_ENROLL_LIMINE_CONFIG=["\']?(\w+)', line)
                if m:
                    value = m.group(1).lower()
        except OSError:
            pass
    return value == 'yes'


def apply_limine(esp, settings, wallpaper=None, dry_run=False, conf=None, current_text=None, etc=None):
    if enroll_enabled(etc):
        raise BootError('enrolled_config', 'limine-entry-tool tiene ENABLE_ENROLL_LIMINE_CONFIG=yes: editar limine.conf impediría arrancar',
                        'Ponlo en «no» en /etc/default/limine (y ejecuta limine-update), o tematiza a mano y ejecuta limine-enroll-config después.')
    pl = plan_limine(esp, settings, wallpaper=wallpaper, conf=conf, current_text=current_text)
    if pl['errors']:
        raise BootError('invalid_new', 'El archivo nuevo no pasa la comprobación: ' + '; '.join(pl['errors']), 'No se escribió nada.')
    root = os.path.dirname(os.path.dirname(pl['conf'])) if pl['conf'].endswith(('/EFI/limine/limine.conf', '/boot/limine/limine.conf')) else os.path.dirname(pl['conf'])
    assets = os.path.join(esp, ASSET_DIR)
    w, h = parse_resolution(settings['resolution'])
    actions = []
    changed = pl['new'] != pl['old']
    wall_dest = os.path.join(assets, 'wallpaper.jpg')
    stored = os.path.join(SYSTEM_DIR, 'wallpaper.jpg')
    src = wallpaper or default_wallpaper()
    if dry_run:
        actions = ['renderizar %s a %dx%d → %s' % (os.path.basename(src), w, h, wall_dest), 'respaldar %s' % pl['conf'],
                   'escribir %s' % pl['conf']] if changed or not os.path.exists(wall_dest) else []
        return dict(ok=True, dry_run=True, conf=pl['conf'], changed=changed, diff=pl['diff'], actions=actions,
                    windows=pl['windows'], warnings=pl['warnings'], entries_untouched=True)
    done = []
    tmp_wall = tempfile.mkdtemp(prefix='dragon-boot-')
    try:
        rendered = render_wallpaper(src, os.path.join(tmp_wall, 'wallpaper.jpg'), w, h, pl['palette'], settings['quality'])
        data = open(rendered, 'rb').read()
        if not os.path.isfile(wall_dest) or open(wall_dest, 'rb').read() != data:
            atomic_write(wall_dest, data, binary=True)
            done.append('wallpaper')
        if changed:
            b = backup(pl['conf'])
            atomic_write(pl['conf'], pl['new'])
            done.append('conf')
            return dict(ok=True, changed=True, conf=pl['conf'], backup=b, done=done, windows=pl['windows'], warnings=pl['warnings'], entries_untouched=True)
        return dict(ok=True, changed=bool(done), conf=pl['conf'], backup=None, done=done, windows=pl['windows'], warnings=pl['warnings'], entries_untouched=True)
    finally:
        shutil.rmtree(tmp_wall, ignore_errors=True)


def revert_limine(esp, conf=None):
    found = [conf] if conf else find_limine_conf(esp)
    if not found:
        raise BootError('no_limine_conf', 'No encuentro limine.conf bajo %s' % esp)
    path = found[0]
    text = open(path, encoding='utf-8', errors='surrogateescape').read()
    if BEGIN not in text:
        return dict(ok=True, changed=False, conf=path)
    new = unmerge_limine(text)
    errors, _ = validate_limine(new)
    if errors:
        raise BootError('invalid_new', 'El resultado no pasa la comprobación: ' + '; '.join(errors[:3]), 'No se escribió nada.')
    b = backup(path)
    atomic_write(path, new)
    shutil.rmtree(os.path.join(esp, ASSET_DIR), ignore_errors=True)       # our own folder; nothing else is deleted
    return dict(ok=True, changed=True, conf=path, backup=b)


def verify_limine(esp):
    found = find_limine_conf(esp)
    if not found:
        raise BootError('no_limine_conf', 'No encuentro limine.conf bajo %s' % esp)
    text = open(found[0], encoding='utf-8', errors='surrogateescape').read()
    errors, warnings = validate_limine(text)
    themed = BEGIN in text
    wall = os.path.isfile(os.path.join(esp, ASSET_DIR, 'wallpaper.jpg'))
    return dict(ok=not errors, conf=found[0], themed=themed, wallpaper=wall, errors=errors, warnings=warnings,
                shadowed_by=found[1:], windows=windows_entries(text))


# ---------------------------------------------------------------- preview (no system access)
def _font(size, mono=False):
    from PIL import ImageFont
    names = (['/usr/share/fonts/TTF/JetBrainsMonoNerdFontMono-Regular.ttf', '/usr/share/fonts/TTF/0xProtoNerdFontMono-Regular.ttf',
              '/usr/share/fonts/liberation/LiberationMono-Regular.ttf'] if mono else
             ['/usr/share/fonts/outfit-font/Outfit-Medium.ttf', '/usr/share/fonts/liberation/LiberationSans-Regular.ttf'])
    for n in names:
        if os.path.exists(n):
            return ImageFont.truetype(n, size)
    return ImageFont.load_default()


def render_preview(out, bootloader='limine', wallpaper=None, resolution='1920x1080', settings=None, entries=None):
    """What the menu will look like: the wallpaper exactly as it will be deployed, with the palette, branding, help line and the
    countdown. An approximation of Limine's text menu (layout drawn here, colours and wallpaper are the real values)."""
    from PIL import Image, ImageDraw
    s = settings or load_settings()
    p = palette()
    w, h = parse_resolution(resolution)
    tmp = tempfile.mkdtemp(prefix='dragon-boot-')
    try:
        base = Image.open(render_wallpaper(wallpaper or default_wallpaper(), os.path.join(tmp, 'w.jpg'), w, h, p)).convert('RGBA')
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    hexc = lambda x, a=255: tuple(int(x[i:i + 2], 16) for i in (0, 2, 4)) + (a,)
    glass = Image.new('RGBA', (w, h), (0, 0, 0, 0))          # translucent shapes live here and are composited (drawing alpha on RGBA replaces pixels)
    g = ImageDraw.Draw(glass)
    d = ImageDraw.Draw(base)
    u = max(1, h // 1080)
    entries = entries or ['Dragon OS (linux)', 'Dragon OS (linux-fallback)', 'Windows']
    if bootloader == 'grub':
        title_f, item_f, small_f = _font(44 * u), _font(26 * u), _font(20 * u)
        bw, bh = int(w * 0.44), int(h * 0.46)
        x0, y0 = int(w * 0.28), int(h * 0.26)
        for i in range(len(entries)):
            y = y0 + i * 50 * u
            if i == 0:
                g.rounded_rectangle((x0, y, x0 + bw, y + 40 * u + 28 * u), 10 * u, fill=hexc(BRAND['violet'], 110), outline=hexc(BRAND['cyan']), width=2 * u)
        base = Image.alpha_composite(base, glass)
        d = ImageDraw.Draw(base)
        d.text((w // 2, int(h * 0.12)), s['branding'], font=title_f, fill=hexc(BRAND['magenta']), anchor='mm')
        for i, name in enumerate(entries):
            y = y0 + i * 50 * u + 34 * u
            d.text((x0 + 28 * u, y), name, font=item_f, fill=hexc('ffffff' if i == 0 else p['textSoft']), anchor='lm')
        top = int(h * 0.78)
        d.rectangle((x0, top, x0 + bw, top + 6 * u), fill=hexc(p['muted'], 90))
        d.rectangle((x0, top, x0 + int(bw * 0.7), top + 6 * u), fill=hexc(BRAND['cyan']))
        d.text((w // 2, int(h * 0.81) + 10 * u), 'Arranca en %s s' % s['timeout'], font=small_f, fill=hexc(p['textDim']), anchor='mm')
        d.text((w // 2, int(h * 0.94)), '↑ ↓ elegir   Enter arrancar   e editar   c consola', font=small_f, fill=hexc(p['muted']), anchor='mm')
    else:
        mono, mono_s = _font(26 * u, True), _font(22 * u, True)
        m = 64 * u
        g.rectangle((m // 2, m // 2, w - m // 2, h - m // 2), fill=hexc(p['bg'], 255 - 0x50))     # term_background TT=50: 0x50/255 transparent
        base = Image.alpha_composite(base, glass)
        glass = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        g = ImageDraw.Draw(glass)
        y = int(h * 0.34)
        for i in range(len(entries)):
            if i == 0:
                g.rectangle((m, y, w - m, y + 42 * u), fill=hexc(p['violet'], 255 - 0x50))
        base = Image.alpha_composite(base, glass)
        d = ImageDraw.Draw(base)
        d.text((m, m), s['branding'], font=_font(34 * u, True), fill=hexc(BRAND['magenta']))
        d.text((m, m + 56 * u), '↑↓ elegir   Enter arrancar   e editar   c consola', font=mono_s, fill=hexc(p['textDim']))
        for i, name in enumerate(entries):
            d.text((m + 18 * u, y + i * 48 * u + 21 * u), ('> ' if i == 0 else '  ') + name, font=mono, fill=hexc('ffffff' if i == 0 else p['text']), anchor='lm')
        d.text((m, h - m - 8 * u), 'Arrancando «%s» en %s s…' % (entries[0], s['timeout']), font=mono_s, fill=hexc(BRAND['cyan']))
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    base.convert('RGB').save(out, 'PNG', optimize=True)
    return out


# ---------------------------------------------------------------- GRUB: complete theme (images + fonts)
GRUB_BEGIN = '# >>> dragon-boot: tema de Dragon OS (lo gestiona dragon-boot) >>>'
GRUB_END = '# <<< dragon-boot <<<'
GRUB_MANAGED = ['GRUB_THEME', 'GRUB_BACKGROUND', 'GRUB_TIMEOUT', 'GRUB_TIMEOUT_STYLE', 'GRUB_GFXMODE']
GRUB_FONTS = [('Outfit-Medium.ttf', ['/usr/share/fonts/outfit-font', '/usr/share/fonts/TTF', '/usr/share/fonts/OTF']),
              ('LiberationSans-Regular.ttf', ['/usr/share/fonts/liberation'])]


def _hex(c, a=255):
    return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


def grub_theme_txt(p, settings, fonts):
    ui = lambda n: '"%s %d"' % (fonts['name'], n) if fonts else '"Unifont Regular 16"'
    return '''# Dragon OS — tema de GRUB (generado por dragon-boot; paleta de Theme.qml)
desktop-image: "background.png"
desktop-color: "#%(bg)s"
title-text: ""
terminal-font: "Unifont Regular 16"
terminal-left: "0"
terminal-top: "0"
terminal-width: "100%%"
terminal-height: "100%%"
terminal-border: "0"

+ label {
    top = 9%%
    left = 0
    width = 100%%
    align = "center"
    text = "%(brand)s"
    font = %(f44)s
    color = "#%(magenta)s"
}

+ boot_menu {
    left = 28%%
    top = 26%%
    width = 44%%
    height = 46%%
    item_font = %(f26)s
    item_color = "#%(textSoft)s"
    selected_item_font = %(f26)s
    selected_item_color = "#ffffff"
    icon_width = 0
    icon_height = 0
    item_icon_space = 0
    item_height = 40
    item_padding = 14
    item_spacing = 10
    selected_item_pixmap_style = "select_*.png"
    scrollbar = true
    scrollbar_width = 6
    scrollbar_thumb = "scroll_thumb_*.png"
}

+ progress_bar {
    id = "__timeout__"
    left = 28%%
    top = 78%%
    width = 44%%
    height = 6
    show_text = false
    bar_style = "progress_bar_*.png"
    highlight_style = "progress_highlight_*.png"
}

+ label {
    id = "__timeout__"
    left = 0
    top = 81%%
    width = 100%%
    align = "center"
    text = "Arranca en %%d s"
    font = %(f20)s
    color = "#%(textDim)s"
}

+ label {
    left = 0
    top = 94%%
    width = 100%%
    align = "center"
    text = "↑ ↓ elegir   Enter arrancar   e editar   c consola"
    font = %(f20)s
    color = "#%(muted)s"
}
''' % dict(p, brand=settings['branding'], magenta=BRAND['magenta'], f44=ui(44), f26=ui(26), f20=ui(20))


def stage_grub_theme(out, settings, wallpaper=None, have_mkfont=None):
    """Complete GRUB theme in `out`: theme.txt, background.png (cover-fit), the 9-slice pixmaps and the .pf2 fonts (grub-mkfont,
    skipped with a note when it or the TTF is missing → GRUB falls back to Unifont)."""
    import subprocess
    from PIL import Image, ImageDraw
    p = palette()
    p.update(settings.get('palette') or {})
    w, h = parse_resolution(settings['resolution'])
    os.makedirs(out, exist_ok=True)
    render_wallpaper(wallpaper or default_wallpaper(), os.path.join(out, 'background.png'), w, h, p, fmt='png')
    # selected-item box: 9-slice (select_c centre, select_n/s/e/w edges, select_ne… corners), a violet glass with a cyan outline
    r, size = 10, 64
    box = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(box).rounded_rectangle((0, 0, size - 1, size - 1), r, fill=_hex(BRAND['violet'], 110), outline=_hex(BRAND['cyan'], 255), width=2)
    cut = r + 2
    parts = {'nw': (0, 0, cut, cut), 'n': (cut, 0, size - cut, cut), 'ne': (size - cut, 0, size, cut), 'w': (0, cut, cut, size - cut),
             'c': (cut, cut, size - cut, size - cut), 'e': (size - cut, cut, size, size - cut), 'sw': (0, size - cut, cut, size),
             's': (cut, size - cut, size - cut, size), 'se': (size - cut, size - cut, size, size)}
    for name, box_ in parts.items():
        box.crop(box_).save(os.path.join(out, 'select_%s.png' % name))
    # scrollbar thumb and progress bar (timeout): 3 slices each (c plus ends), flat colours of the identity
    for prefix, colour in (('scroll_thumb', BRAND['magenta']), ('progress_highlight', BRAND['cyan']), ('progress_bar', p['muted'])):
        for name in ('c', 'w', 'e'):
            Image.new('RGBA', (4, 4), _hex(colour, 255 if prefix != 'progress_bar' else 90)).save(os.path.join(out, '%s_%s.png' % (prefix, name)))
    fonts = None
    notes = []
    mk = shutil.which('grub-mkfont') if have_mkfont is None else have_mkfont
    ttf = next((os.path.join(d, n) for n, dirs in GRUB_FONTS for d in dirs if os.path.isfile(os.path.join(d, n))), None) if mk else None
    if mk and ttf:
        ok = True
        tool = mk if isinstance(mk, str) else 'grub-mkfont'
        for size_ in (20, 26, 44):
            r_ = subprocess.run([tool, '-n', 'Dragon UI', '-s', str(size_), '-o', os.path.join(out, 'dragon-ui-%d.pf2' % size_), ttf],
                                capture_output=True, text=True)
            ok = ok and r_.returncode == 0
        fonts = dict(name='Dragon UI Regular') if ok else None
        if not ok:
            notes.append('grub-mkfont falló: se usa Unifont')
    else:
        notes.append('sin grub-mkfont o sin la tipografía: se usa Unifont')
    if fonts:
        fonts['name'] = 'Dragon UI Regular'
    open(os.path.join(out, 'theme.txt'), 'w', encoding='utf-8').write(grub_theme_txt(p, settings, fonts))
    return dict(dir=out, files=sorted(os.listdir(out)), fonts=bool(fonts), notes=notes)


def grub_default_block(settings, theme_path):
    return [GRUB_BEGIN,
            'GRUB_THEME="%s"' % theme_path,
            'GRUB_TIMEOUT=%s' % int(float(settings['timeout'])) if str(settings['timeout']) != 'no' else 'GRUB_TIMEOUT=-1',
            'GRUB_TIMEOUT_STYLE=menu',
            'GRUB_GFXMODE=auto',
            GRUB_END]


def merge_grub_default(text, settings, theme_path):
    lines = text.split('\n')
    out, inside = [], False
    for line in lines:
        if line.strip() == GRUB_BEGIN:
            inside = True
            continue
        if inside:
            if line.strip() == GRUB_END:
                inside = False
            continue
        out.append(line[len(DISABLED):] if line.startswith(DISABLED) else line)
    if inside:
        raise BootError('broken_block', 'Falta la marca de cierre en /etc/default/grub')
    while out and out[-1] == '':
        out.pop()
    out = [(DISABLED + l if re.match(r'^(%s)=' % '|'.join(GRUB_MANAGED), l) else l) for l in out]
    return '\n'.join(out + [''] + grub_default_block(settings, theme_path)) + '\n'


def unmerge_grub_default(text):
    out, inside = [], False
    for line in text.split('\n'):
        if line.strip() == GRUB_BEGIN:
            inside = True
            continue
        if inside:
            if line.strip() == GRUB_END:
                inside = False
            continue
        out.append(line[len(DISABLED):] if line.startswith(DISABLED) else line)
    while out and out[-1] == '':
        out.pop()
    return '\n'.join(out) + '\n'


def validate_grub_default(text):
    errors = []
    for n, line in enumerate(text.split('\n'), 1):
        s = line.strip()
        if not s or s.startswith('#'):
            continue
        if not re.match(r'^[A-Za-z_][A-Za-z0-9_]*=', s):
            errors.append('línea %d: no es «CLAVE=valor»: %r' % (n, s[:50]))
        if s.count('"') % 2 or s.count("'") % 2:
            errors.append('línea %d: comillas sin cerrar' % n)
    if text.count(GRUB_BEGIN) != text.count(GRUB_END):
        errors.append('bloque de dragon-boot mal formado')
    return errors


def apply_grub(root, settings, wallpaper=None, dry_run=False, regen=True):
    """`root` is '/' on a real system (the tests pass a fake tree with boot/grub, etc/default/grub)."""
    r = lambda x: os.path.join(root, x.lstrip('/'))
    default, theme_dir = r('/etc/default/grub'), r('/boot/grub/themes/dragon-os')
    if not os.path.isfile(default):
        raise BootError('no_grub_default', 'No existe %s' % default, 'GRUB no parece estar instalado aquí.')
    old = open(default, encoding='utf-8', errors='surrogateescape').read()
    new = merge_grub_default(old, settings, '/boot/grub/themes/dragon-os/theme.txt')
    errs = validate_grub_default(new)
    if errs:
        raise BootError('invalid_new', 'El archivo nuevo no pasa la comprobación: ' + '; '.join(errs), 'No se escribió nada.')
    diff = unified(old, new, 'etc/default/grub')
    if dry_run:
        return dict(ok=True, dry_run=True, changed=new != old, diff=diff, theme_dir=theme_dir,
                    actions=['crear %s (theme.txt, imágenes, fuentes)' % theme_dir, 'respaldar %s' % default, 'escribir %s' % default] +
                            (['grub-mkconfig -o %s (comprobado con grub-script-check)' % r('/boot/grub/grub.cfg')] if regen else []), entries_untouched=True)
    tmp = tempfile.mkdtemp(prefix='dragon-boot-')
    try:
        st = stage_grub_theme(os.path.join(tmp, 'dragon-os'), settings, wallpaper)
        if new == old and _same_tree(st['dir'], theme_dir):          # nothing to do: no churn, no new backups
            return dict(ok=True, changed=False, theme_dir=theme_dir, fonts=st['fonts'], notes=st['notes'], entries_untouched=True)
        moved = None
        os.makedirs(os.path.dirname(theme_dir), exist_ok=True)
        if os.path.isdir(theme_dir):
            moved = '%s.bak-dragon-%s' % (theme_dir, stamp())
            os.rename(theme_dir, moved)
        shutil.copytree(st['dir'], theme_dir)
        b = backup(default) if new != old else None
        if new != old:
            atomic_write(default, new)
        cfg = None
        if regen:
            cfg = regen_grub_cfg(root)
        return dict(ok=True, changed=True, backup=b, theme_dir=theme_dir, theme_backup=moved, fonts=st['fonts'], notes=st['notes'], grub_cfg=cfg, entries_untouched=True)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def _same_tree(a, b):
    if not os.path.isdir(b):
        return False
    fa, fb = sorted(os.listdir(a)), sorted(os.listdir(b))
    return fa == fb and all(open(os.path.join(a, n), 'rb').read() == open(os.path.join(b, n), 'rb').read() for n in fa)


def regen_grub_cfg(root='/'):
    """grub-mkconfig into a temporary file, grub-script-check it, back the old grub.cfg up and replace it. Windows entries come from
    the system's own os-prober step; this tool never touches them."""
    import subprocess
    cfg = os.path.join(root, 'boot/grub/grub.cfg')
    tmp = tempfile.mkdtemp(prefix='dragon-boot-')
    try:
        new = os.path.join(tmp, 'grub.cfg')
        r = subprocess.run(['grub-mkconfig', '-o', new], capture_output=True, text=True)
        if r.returncode != 0 or not os.path.isfile(new):
            raise BootError('mkconfig_failed', 'grub-mkconfig falló: ' + r.stderr.strip()[-200:], 'No se tocó grub.cfg.')
        chk = subprocess.run(['grub-script-check', new], capture_output=True, text=True)
        if chk.returncode != 0:
            raise BootError('check_failed', 'grub-script-check rechazó el grub.cfg nuevo: ' + chk.stderr.strip()[-200:], 'No se tocó grub.cfg.')
        b = backup(cfg)
        atomic_write(cfg, open(new, encoding='utf-8', errors='surrogateescape').read())
        return dict(path=cfg, backup=b)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def revert_grub(root):
    r = lambda x: os.path.join(root, x.lstrip('/'))
    default = r('/etc/default/grub')
    old = open(default, encoding='utf-8', errors='surrogateescape').read()
    if GRUB_BEGIN not in old:
        return dict(ok=True, changed=False)
    new = unmerge_grub_default(old)
    errs = validate_grub_default(new)
    if errs:
        raise BootError('invalid_new', '; '.join(errs))
    b = backup(default)
    atomic_write(default, new)
    shutil.rmtree(r('/boot/grub/themes/dragon-os'), ignore_errors=True)
    return dict(ok=True, changed=True, backup=b, note='ejecuta grub-mkconfig -o /boot/grub/grub.cfg para regenerar el menú')


# ---------------------------------------------------------------- CLI
def system_dir():
    return os.environ.get('DRAGON_BOOT_SYSTEM_DIR', SYSTEM_DIR)


def cmd_reapply(args):
    """Post hook of limine-entry-tool: put the theme back if a regeneration dropped it. Never fatal (exit 0, or 1-99)."""
    sd = system_dir()
    sf = os.path.join(sd, SETTINGS_NAME)
    if not os.path.isfile(sf):
        return dict(ok=True, changed=False, note='dragon-boot no está instalado en el sistema')
    settings = load_settings(sf)
    esp = args.esp or detect().get('limine', {}).get('esp')
    if not esp:
        raise BootError('no_esp', 'No encuentro la partición de arranque', 'Pasa --esp.')
    src = next((os.path.join(sd, n) for n in os.listdir(sd) if n.startswith('wallpaper-src')), None)
    found = find_limine_conf(esp)
    if found:
        text = open(found[0], encoding='utf-8', errors='surrogateescape').read()
        errs, _ = validate_limine(text, require_block=True)
        if not errs and os.path.isfile(os.path.join(esp, ASSET_DIR, 'wallpaper.jpg')) and merge_limine(text, palette_of(settings), settings, 'boot():/%s/wallpaper.jpg' % ASSET_DIR) == text:
            return dict(ok=True, changed=False, note='el tema sigue aplicado')
    return apply_limine(esp, settings, wallpaper=src)


def palette_of(settings):
    p = palette()
    p.update(settings.get('palette') or {})
    return p


def build_parser():
    ap = argparse.ArgumentParser(prog='dragon-boot', add_help=True)
    ap.add_argument('--json', action='store_true')
    sub = ap.add_subparsers(dest='cmd')
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument('--bootloader', choices=('auto', 'limine', 'grub'), default='auto')
    common.add_argument('--esp')
    common.add_argument('--root', default='/', help='GRUB: árbol raíz (pruebas)')
    common.add_argument('--wallpaper')
    common.add_argument('--resolution')
    common.add_argument('--branding')
    common.add_argument('--timeout')
    common.add_argument('--style')
    common.add_argument('--settings')
    common.add_argument('--json', action='store_true')
    for name in ('detect', 'verify', 'revert', 'reapply', 'stage', 'apply', 'preview'):
        sp = sub.add_parser(name, parents=[common])
        if name in ('stage', 'preview'):
            sp.add_argument('--out', required=True)
        if name == 'apply':
            sp.add_argument('--dry-run', dest='dry_run', action='store_true')
            sp.add_argument('--no-regen', dest='regen', action='store_false')
        if name == 'stage':
            sp.add_argument('--no-regen', dest='regen', action='store_false')
    return ap


def main(argv=None):
    args = build_parser().parse_args(argv)
    try:
        if not args.cmd:
            print(__doc__)
            return 0
        settings = None
        if args.cmd in ('stage', 'apply', 'preview'):
            settings = load_settings(args.settings, resolution=args.resolution, branding=args.branding, timeout=args.timeout, style=args.style)
        if args.cmd == 'detect':
            d = detect(args.esp, args.bootloader, args.root)
            d['limine']['enroll'] = enroll_enabled()
            emit(dict(ok=True, **d))
            return 0
        bl = args.bootloader
        if bl == 'auto' and args.cmd in ('stage', 'apply', 'verify', 'revert'):
            bl = detect(args.esp, 'auto', args.root)['bootloader']
            if not bl:
                raise BootError('no_bootloader', 'No detecto ni Limine ni GRUB', 'Pasa --bootloader limine|grub.')
        if args.cmd == 'preview':
            render_preview(args.out, 'grub' if bl == 'grub' else 'limine', args.wallpaper, settings['resolution'], settings)
            emit(dict(ok=True, preview=args.out, bootloader='grub' if bl == 'grub' else 'limine'))
        elif args.cmd == 'reapply':
            emit(cmd_reapply(args))
        elif args.cmd == 'stage':
            os.makedirs(args.out, exist_ok=True)
            if bl == 'grub':
                st = stage_grub_theme(os.path.join(args.out, 'dragon-os'), settings, args.wallpaper)
                emit(dict(ok=True, bootloader='grub', **{k: v for k, v in st.items() if k != 'dir'}, dir=st['dir']))
            else:
                w, h = parse_resolution(settings['resolution'])
                render_wallpaper(args.wallpaper or default_wallpaper(), os.path.join(args.out, 'wallpaper.jpg'), w, h, dict(palette(), **(settings.get('palette') or {})), settings['quality'])
                json.dump(dict(settings, palette=palette_of(settings)), open(os.path.join(args.out, SETTINGS_NAME), 'w'), ensure_ascii=False, indent=1)
                emit(dict(ok=True, bootloader='limine', dir=args.out, files=sorted(os.listdir(args.out))))
        elif args.cmd == 'apply':
            if bl == 'grub':
                emit(apply_grub(args.root, settings, args.wallpaper, args.dry_run, args.regen))
            else:
                esp = args.esp or detect(None, 'limine', args.root)['limine']['esp']
                if not esp:
                    raise BootError('no_esp', 'No encuentro la partición de arranque con limine.conf', 'Pasa --esp /boot (o /efi).')
                emit(apply_limine(esp, settings, args.wallpaper, args.dry_run))
        elif args.cmd == 'verify':
            emit(verify_limine(args.esp) if bl != 'grub' else dict(ok=True, themed=BEGIN not in '' and GRUB_BEGIN in open(os.path.join(args.root, 'etc/default/grub')).read()))
        elif args.cmd == 'revert':
            emit(revert_grub(args.root) if bl == 'grub' else revert_limine(args.esp))
        return 0
    except BootError as exc:
        emit(dict(ok=False, error=dict(code=exc.code, message=exc.message, hint=exc.hint)))
        return 1
    except OSError as exc:
        emit(dict(ok=False, error=dict(code='io_error', message=str(exc), hint='¿Hace falta sudo para escribir en /boot?')))
        return 1


if __name__ == '__main__':
    sys.exit(main())
