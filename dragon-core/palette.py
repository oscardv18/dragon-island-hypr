"""dragon-palette v1: deterministic, bounded wallpaper analysis; no network.

Public JSON/CLI contract: docs/design/PROMPT-identidad-fase-3-codex.md.
Pillow is imported only by generate, so reset/apply work without it.
"""

import argparse
import colorsys
import hashlib
import json
import math
import os
from pathlib import Path
import sys
import tempfile


DRAGON = {
    "accent": "#C8B6E6", "accentSoft": "#DCCFF0", "accentDeep": "#7E6BA8",
    "glow": "#B26BFF", "onAccent": "#16121F", "tint": "#0D0B16",
    "swatches": ["#C8B6E6", "#DCCFF0", "#7E6BA8", "#B26BFF", "#0D0B16"],
}


def config_home():
    return Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config")))


def state_home():
    return Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "dragon-island"


def atomic_write(path, content):
    """Same-directory rename; leave the old complete file visible until replace."""
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent,
                                         prefix="." + path.name + ".", delete=False) as out:
            temporary = out.name
            out.write(content)
            out.flush()
            os.fsync(out.fileno())
        os.replace(temporary, path)
    finally:
        if temporary and os.path.exists(temporary):
            os.unlink(temporary)


def linear(value):
    return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4


def rgb(hex_color):
    return tuple(int(hex_color[i:i + 2], 16) / 255 for i in (1, 3, 5))


def hex_rgb(values):
    return "#" + "".join(f"{round(max(0, min(1, v)) * 255):02X}" for v in values)


def luminance(color):
    return sum(c * w for c, w in zip(map(linear, rgb(color)), (0.2126, 0.7152, 0.0722)))


def contrast(first, second):
    high, low = sorted((luminance(first), luminance(second)), reverse=True)
    return (high + 0.05) / (low + 0.05)


def oklab(values):
    r, g, b = map(linear, values)
    l = (0.4122214708*r + 0.5363325363*g + 0.0514459929*b) ** (1/3)
    m = (0.2119034982*r + 0.6806995451*g + 0.1073969566*b) ** (1/3)
    s = (0.0883024619*r + 0.2817188376*g + 0.6299787005*b) ** (1/3)
    return (0.2104542553*l + 0.7936177850*m - 0.0040720468*s,
            1.9779984951*l - 2.4285922050*m + 0.4505937099*s,
            0.0259040371*l + 0.7827717662*m - 0.8086757660*s)


def oklch(lightness, chroma, hue):
    """Map into sRGB by reducing chroma, preserving OKLCH lightness and hue."""
    def convert(c):
        a, b = c * math.cos(hue), c * math.sin(hue)
        l = (lightness + 0.3963377774*a + 0.2158037573*b) ** 3
        m = (lightness - 0.1055613458*a - 0.0638541728*b) ** 3
        s = (lightness - 0.0894841775*a - 1.2914855480*b) ** 3
        return (4.0767416621*l - 3.3077115913*m + 0.2309699292*s,
                -1.2684380046*l + 2.6097574011*m - 0.3413193965*s,
                -0.0041960863*l - 0.7034186147*m + 1.7076147010*s)
    low, high = 0.0, chroma
    for _ in range(20):
        if all(0 <= v <= 1 for v in convert(high)):
            break
        middle = (low + high) / 2
        if all(0 <= v <= 1 for v in convert(middle)):
            low = middle
        else:
            high = middle
    values = convert(high)
    return hex_rgb(12.92*v if v <= 0.0031308 else 1.055*v**(1/2.4) - 0.055 for v in values)


def extract(image_path):
    from PIL import Image, ImageOps

    source = Path(image_path).expanduser().resolve()
    with Image.open(source) as image:
        # JPEG draft reduces decoding work before the full image is allocated.
        image.draft("RGB", (128, 128))
        image = ImageOps.exif_transpose(image)
        image.thumbnail((128, 128), Image.Resampling.LANCZOS)
        if "A" in image.getbands() or "transparency" in image.info:
            rgba = image.convert("RGBA")
            base = Image.new("RGBA", rgba.size, DRAGON["tint"])
            image = Image.alpha_composite(base, rgba)
        reduced = image.convert("RGB")
    digest = hashlib.sha1(f"{reduced.width}x{reduced.height}:RGB:".encode() + reduced.tobytes()).hexdigest()
    quantized = reduced.quantize(colors=12, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    palette = quantized.getpalette()
    groups = sorted(((count, tuple(palette[index*3:index*3+3]))
                     for count, index in quantized.getcolors()), key=lambda item: (-item[0], item[1]))
    candidates = []
    for count, values in groups:
        values = tuple(v/255 for v in values)
        _, saturation, value = colorsys.rgb_to_hsv(*values)
        lightness, a, b = oklab(values)
        chroma = math.hypot(a, b)
        if saturation >= 0.16 and chroma >= 0.035 and 0.16 < lightness < 0.95 and value > 0.12:
            candidates.append((count * min(saturation, 0.65), chroma, math.atan2(b, a)))
    result = {"version": 1, "source": str(source), "sourceHash": digest,
              "fallback": not candidates, **DRAGON}
    if not candidates:
        return result
    _, chroma, hue = max(candidates)
    chroma = max(0.06, min(chroma, 0.14))
    accent = oklch(0.76, chroma, hue)
    on_accent = max((DRAGON["onAccent"], "#FFFFFF", "#000000"), key=lambda c: contrast(accent, c))
    swatches = []
    for _, values in groups:
        color = hex_rgb(v/255 for v in values)
        if all(math.dist(oklab(rgb(color)), oklab(rgb(other))) >= 0.06 for other in swatches):
            swatches.append(color)
        if len(swatches) == 5:
            break
    swatches += [swatches[-1]] * (5 - len(swatches))
    result.update(accent=accent, accentSoft=oklch(0.86, chroma*0.6, hue),
                  accentDeep=oklch(0.54, chroma*0.9, hue), glow=oklch(0.68, chroma*1.4, hue),
                  onAccent=on_accent, tint=oklch(0.10, 0.018, hue), swatches=swatches)
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    # Accept flags before or after the subcommand without resetting prior values.
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--quiet", action="store_true")
    subcommands = parser.add_subparsers(dest="command", required=True)
    for name in ("generate", "apply", "reset", "status"):
        sub = subcommands.add_parser(name)
        sub.add_argument("--dry-run", action="store_true", default=argparse.SUPPRESS)
        sub.add_argument("--quiet", action="store_true", default=argparse.SUPPRESS)
        if name == "generate":
            sub.add_argument("image")
    args = parser.parse_args(argv)
    try:
        path = state_home() / "palette.json"
        if args.command == "generate":
            result = extract(args.image)
            if not args.dry_run:
                atomic_write(path, json.dumps(result, indent=2) + "\n")
            if not args.quiet:
                print(json.dumps(result, indent=2))
        elif args.command == "apply":
            from palette_runtime import application_lock, apply_palette, read_palette
            with application_lock(args.dry_run):
                apply_palette(read_palette(), args.dry_run, args.quiet)
        elif args.command == "reset":
            from palette_runtime import application_lock, reset_palette
            with application_lock(args.dry_run):
                reset_palette(args.dry_run, args.quiet)
        elif args.command == "status":
            if path.exists():
                data = json.loads(path.read_text())
                print(f"enabled {data['source']}")
            else:
                print("disabled Dragon")
    except (OSError, ValueError, ImportError) as error:
        print(f"dragon-palette: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
