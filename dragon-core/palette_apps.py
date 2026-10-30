"""External app templates and strictly delimited Starship palette updates.

No subprocesses here. Herdr 0.9.5 has inline overrides but no color-file include;
its config is deliberately left alone (see handoff and template README).
"""
from pathlib import Path
import re
import json
from string import Template
import tomllib

TEMPLATES = Path(__file__).with_name("palette-templates")
BEGIN, END = "# >>> dragon-palette", "# <<< dragon-palette"
BLOCK = re.compile(r"(?ms)^# >>> dragon-palette\n.*?^# <<< dragon-palette(?:\n|$)")
COLOR_NAMES = {
    "#30C0FF": "accent_soft", "#F04DFF": "accent", "#FFB644": "warn",
    "#22EEF7": "cyan", "#FF426D": "directory_accent", "#FFEB65": "git_state",
    "#FF3D48": "error", "#70FF58": "success",
}


def render(palette, legacy=False):
    previous = json.loads((TEMPLATES / 'legacy.json').read_text()) if legacy else {}
    def template(name, values):
        return Template((TEMPLATES / name).read_text()).substitute(values)
    terminal = dict(cursor=palette['accent'], cursorText=palette['onAccent'],
                    selectionBg=palette['accentDeep'], selectionFg=palette['accentSoft'],
                    color4=palette['accentDeep'], color12=palette['accent'],
                    tabBg=palette['accentDeep'], tabFg=palette['accentSoft'])
    ghostty = template('ghostty.theme', previous.get('ghostty', terminal))
    starship = dict(palette, directoryAccent=palette['accent'], gitState='#F5B04A',
                    ok='#86EFAC', warn='#F5B04A', cyan='#67E8F9')
    sgr = {key: '38;2;' + ';'.join(str(int(palette[token][i:i+2], 16)) for i in (1, 3, 5))
           for key, token in (('accent','accent'), ('accent_deep','accentDeep'), ('glow','glow'))}
    sgr.update(cyan='38;2;103;232;249', ok='38;2;134;239;172', warn='38;2;245;176;74')
    return {
        'dragon-dynamic': ghostty,
        'ghostty.conf': template('ghostty.conf', dict(ghostty_colors=ghostty.rstrip())),
        'dragon-dynamic.conf': template('kitty.conf', previous.get('kitty', terminal)),
        'starship.toml': template('starship.toml', previous.get('starship', starship)),
        'fastfetch-colors.json': template('fastfetch-colors.json', previous.get('fastfetch', sgr)),
    }


def update_starship(text, block):
    """Apply only the block installed by migration 030; never adopt a user file."""
    if text.count(BEGIN) != 1 or text.count(END) != 1 or not BLOCK.search(text):
        raise ValueError("Starship: falta el bloque de migración 030 o está mal delimitado")
    old = tomllib.loads(text)
    if old.get("palette") != "dragon":
        raise ValueError("Starship: palette no es dragon; se conserva la elección del usuario")
    result = BLOCK.sub(lambda _: block, text, count=1)
    tomllib.loads(result)
    return result


def convert_starship(text, block):
    """One-time conversion: replace color tokens only in TOML style/format strings.

    Preserve comments, all formatting and unknown colors. tomllib validates both
    input and output; malformed/foreign palette tables are never overwritten.
    """
    data = tomllib.loads(text)
    if BEGIN in text or END in text:
        return update_starship(text, block)
    if "dragon" in data.get("palettes", {}):
        raise ValueError("Starship: ya existe una paleta dragon sin marcadores")
    if data.get("palette", "dragon") != "dragon":
        raise ValueError("Starship: ya usa otra paleta; no se convierte automáticamente")
    parts, pos = [], 0
    # TOML quoted strings and comments, including multiline strings. The string
    # alternative wins before '#', so inline hex values are not comments.
    token = re.compile(r'"""(?:[\s\S]*?)"""|\x27\x27\x27(?:[\s\S]*?)\x27\x27\x27|"(?:\\.|[^"\\])*"|\x27[^\x27]*\x27|#[^\n]*')
    for match in token.finditer(text):
        value = match.group()
        parts.append(text[pos:match.start()])
        prefix = text[text.rfind('\n', 0, match.start()) + 1:match.start()]
        field = re.search(r'(?:^|\s)(?:([\w-]+)|"([\w-]+)"|\x27([\w-]+)\x27)\s*=\s*$', prefix)
        name = next((part for part in field.groups() if part), '') if field else ''
        if not value.startswith("#") and (name in ('format', 'style') or name.endswith(('_style', '_symbol'))):
            value = re.sub(r"#[0-9A-Fa-f]{6}\b", lambda m: COLOR_NAMES.get(m[0].upper(), m[0]), value)
        parts.append(value)
        pos = match.end()
    parts.append(text[pos:])
    result = "".join(parts)
    if "palette" not in data:
        result = 'palette = "dragon"\n' + result
    result = result.rstrip() + "\n\n" + block
    tomllib.loads(result)
    return result
