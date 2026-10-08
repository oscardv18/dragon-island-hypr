import subprocess, os, sys, html, pyte, glob
FF, cfg, out = sys.argv[1:4]
extra = sys.argv[4:]
env = dict(os.environ, HOME="/tmp/ffhome", COLUMNS="104", LINES="30", TERM="xterm-256color")
raw = subprocess.run([FF, "-c", cfg, "--pipe", "false", *extra], capture_output=True, env=env).stdout.decode("utf-8", "replace")
screen = pyte.Screen(104, 30); stream = pyte.Stream(screen); stream.feed(raw.replace("\n", "\r\n"))
def col(c, default):
    if c == "default": return default
    if len(c) == 6: return "#" + c
    return default
rows = []
for y in range(30):
    line = screen.buffer[y]; txt = ""
    for x in range(104):
        ch = line[x]; d = ch.data or " "
        st = f"color:{col(ch.fg, '#e6e8ef')};" + ("font-weight:700;" if ch.bold else "")
        txt += f'<span style="{st}">{html.escape(d)}</span>'
    rows.append(txt)
while rows and "".join(c for c in rows[-1] if False) == "" and all((screen.buffer[len(rows)-1][x].data or " ") == " " for x in range(104)): rows.pop()
fonts = glob.glob("nf/*Mono*.ttf") or glob.glob("nf/*.ttf")
nf = os.path.abspath(fonts[0]) if fonts else ""
jb = os.path.abspath("../../dragon-core/sddm/dragon-core/fonts/JetBrainsMono.ttf")
page = f"""<!doctype html><meta charset=utf-8><style>
@font-face{{font-family:JB;src:url(file://{jb});font-weight:100 800}}
@font-face{{font-family:NF;src:url(file://{nf})}}
body{{margin:0;background:#05060c;padding:22px 26px}}
pre{{margin:0;font:15px/1.28 JB,NF,monospace;color:#e6e8ef;white-space:pre}}
.win{{background:rgba(14,15,24,.96);border:1px solid #262838;border-radius:14px;padding:18px 22px;display:inline-block}}
.bar{{display:flex;gap:7px;margin-bottom:12px}}.bar i{{width:12px;height:12px;border-radius:50%;display:block}}
</style><div class=win><div class=bar><i style=background:#ed254e></i><i style=background:#f9ae58></i><i style=background:#06c993></i></div><pre>{chr(10).join(rows)}</pre></div>"""
open("preview.html", "w").write(page); print(len(rows), "rows; nerd font:", bool(nf))
