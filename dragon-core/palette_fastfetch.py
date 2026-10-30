"""Merge only colors into Fastfetch's JSONC in memory; never rewrite its config.

Fastfetch 2.x accepts a single configuration (including stdin), with no includes.
Explicit -c/--config arguments bypass the palette, so presets still work normally.
"""
import json
import os
from pathlib import Path
import re
import subprocess
import sys

from palette import config_home

# The existing Dragonized theme uses these SGR values, including inside format
# strings. Semantic colors use fixed values from the phase 3 contract.
SGR_KEYS = {
    '38;2;197;14;210': 'accent', '38;2;124;58;237': 'accent_deep',
    '38;2;168;85;247': 'glow', '38;2;0;193;228': 'cyan',
    '38;2;6;201;147': 'ok', '38;2;249;174;88': 'warn',
}
STRING = r'"(?:\\.|[^"\\])*"'


def loads_jsonc(text):
    # Strings win before comment delimiters, preserving URLs and escaped quotes.
    text = re.sub(STRING + r'|//[^\n]*|/\*[\s\S]*?\*/',
                  lambda m: m[0] if m[0].startswith('"') else ' ', text)
    text = re.sub(STRING + r'|,\s*(?=[}\]])',
                  lambda m: m[0] if m[0].startswith('"') else '', text)
    return json.loads(text)


def tint_config(config, colors):
    def color_string(value):
        if value in SGR_KEYS:
            return colors[SGR_KEYS[value]]
        return re.sub(r'\{#(38;2;\d+;\d+;\d+)\}',
                      lambda m: '{#' + colors[SGR_KEYS[m[1]]] + '}' if m[1] in SGR_KEYS else m[0], value)

    def visit(value, in_color=False):
        if isinstance(value, dict):
            return {key: visit(item, in_color or key in ('color', 'key', 'format'))
                    for key, item in value.items()}
        if isinstance(value, list):
            return [visit(item, in_color) for item in value]
        if isinstance(value, str) and in_color:
            return color_string(value)
        return value
    return visit(config)


def main(argv=None):
    args = list(sys.argv[1:] if argv is None else argv)
    if any(a in ('-c', '--config') or a.startswith('--config=') for a in args):
        os.execvp('fastfetch', ['fastfetch', *args])
    cfg = config_home()
    source = cfg / 'fastfetch/config.jsonc'
    colors = cfg / 'dragon-island/palette/fastfetch-colors.json'
    if not source.exists() or not colors.exists():
        os.execvp('fastfetch', ['fastfetch', *args])
    try:
        data = tint_config(loads_jsonc(source.read_text()), json.loads(colors.read_text()))
        return subprocess.run(['fastfetch', '--config', '-', *args],
                              input=json.dumps(data), text=True, check=False).returncode
    except (OSError, ValueError, KeyError) as error:
        print(f'dragon-fastfetch: {error}; usando la configuración original', file=sys.stderr)
        os.execvp('fastfetch', ['fastfetch', *args])


if __name__ == '__main__':
    sys.exit(main())
