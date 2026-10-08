"""Generates config/config.jsonc, config/logo.txt and test/preview-config.jsonc (sample values)."""
import json, math, os, sys

MAG, VIO, VSOFT, CYA = "38;2;197;14;210", "38;2;124;58;237", "38;2;168;85;247", "38;2;0;193;228"
OK, WARN, ERR, TXT, DIM = "38;2;6;201;147", "38;2;249;174;88", "38;2;237;37;78", "38;2;230;232;239", "38;2;138;143;163"
ICON = dict(os=0xF303, kernel=0xF17C, uptime=0xF017, pkgs=0xF187, shell=0xF120, wm=0xF2D0, qs=0xF0D0, plug=0xF1E6,
            term=0xF120, theme=0xF1FC, icons=0xF009, font=0xF031, disp=0xF108, kbd=0xF11C, lock=0xF023,
            cpu=0xF2DB, gpu=0xF26C, mem=0xF1C0, disk=0xF0A0, bat=0xF240, net=0xF1EB)
I = {k: chr(v) for k, v in ICON.items()}

def c(code, s): return "{#%s}%s{#}" % (code, s)
def key(icon, label, color=CYA): return c(VIO, "│") + "  " + c(color, I[icon] + "  " + label.ljust(11))
def head(label): return {"type": "custom", "format": c(VIO, "├─") + " " + c(MAG, label.upper()) + " " + c(VIO, "─" * (26 - len(label)))}

QS = "qs --version 2>/dev/null | awk '{print $2}' | tr -d ','"
PLUG = "hyprctl plugin list 2>/dev/null | awk '/^Plugin /{print $2}' | paste -sd' '"
KBD = "hyprctl devices -j 2>/dev/null | jq -r '[.keyboards[]|select(.main)][0].active_keymap' 2>/dev/null"
LOGIN = "grep -h '^Current=' /etc/sddm.conf.d/*.conf /etc/sddm.conf 2>/dev/null | tail -1 | cut -d= -f2"

def cmd(icon, label, text, color=CYA):
    # fallback "—" so a machine without the piece still renders a clean line
    return {"type": "command", "key": key(icon, label, color), "text": "out=$(%s); echo \"${out:-—}\"" % text}

def modules(sample=None):
    def sysmod(t, icon, label, color=CYA, **kw):
        if sample is not None:
            return {"type": "custom", "key": key(icon, label, color), "format": sample[label]}
        return dict(type=t, key=key(icon, label, color), **kw)
    def cm(icon, label, text, color=CYA):
        if sample is not None:
            return {"type": "custom", "key": key(icon, label, color), "format": sample[label]}
        return cmd(icon, label, text, color)
    return [
        {"type": "title", "format": c(VIO, "╭─") + "  {user-name-colored}{at-symbol-colored}{host-name-colored}  " + c(VIO, "─────────────────"),
         "color": {"user": MAG, "at": DIM, "host": CYA}},
        {"type": "custom", "format": c(VIO, "│") + "  " + c(OK, "●") + " " + c(TXT, "núcleo en línea") + c(DIM, "  ·  dragon-island")},
        head("Sistema"),
        sysmod("os", "os", "SO", MAG, format="{pretty-name}"),
        sysmod("kernel", "kernel", "Kernel", MAG, format="{release}"),
        sysmod("uptime", "uptime", "Activo", MAG),
        sysmod("packages", "pkgs", "Paquetes", MAG),
        sysmod("shell", "shell", "Shell", MAG),
        head("Escritorio"),
        sysmod("wm", "wm", "Hyprland", VSOFT, format="{pretty-name} {version}"),
        cm("qs", "Quickshell", QS, VSOFT),
        cm("plug", "Plugins", PLUG, VSOFT),
        sysmod("terminal", "term", "Terminal", VSOFT, format="{pretty-name} {version}"),
        sysmod("theme", "theme", "Tema", VSOFT, format="{theme1}"),
        sysmod("icons", "icons", "Iconos", VSOFT, format="{icons1}"),
        sysmod("font", "font", "Fuente", VSOFT, format="{font1}"),
        sysmod("display", "disp", "Pantalla", VSOFT, format="{width}×{height} @ {refresh-rate}Hz"),
        cm("kbd", "Teclado", KBD, VSOFT),
        cm("lock", "Login", LOGIN, VSOFT),
        head("Hardware"),
        sysmod("cpu", "cpu", "CPU", CYA, format="{name} ({cores-physical}c/{cores-logical}t)"),
        sysmod("gpu", "gpu", "GPU", CYA, format="{name}"),
        sysmod("memory", "mem", "Memoria", CYA, format="{used} / {total} ({percentage})"),
        sysmod("disk", "disk", "Disco", CYA, folders="/", format="{size-used} / {size-total} ({size-percentage})"),
        sysmod("battery", "bat", "Batería", CYA, format="{capacity} · {status}"),
        sysmod("localip", "net", "Red", CYA, format="{ifname} · {ipv4}") if sample is not None else
            {"type": "wifi", "key": key("net", "Wi‑Fi", CYA), "format": "{ssid} · {protocol} · {signal-quality}"},
        {"type": "custom", "format": c(VIO, "╰─") + "  " + "".join(c(x, "███ ") for x in (MAG, VIO, VSOFT, CYA, OK, WARN, ERR))},
    ]

def base(logo_src, modlist):
    return {
        "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
        "logo": {"type": "file", "source": logo_src, "color": {"1": MAG, "2": VIO, "3": CYA, "4": DIM},
                 "padding": {"top": 1, "left": 2, "right": 4}},
        "display": {"separator": "  ", "color": {"output": TXT, "separator": DIM}},
        "modules": modlist,
    }

# ── ASCII neural core (same maths as NeuralCore.qml, projected on a character grid) ──
def make_logo(W=42, H=19):
    cx, cy, R = W / 2 - 0.5, H / 2 - 0.5, H * 0.36
    XS = 2.0                                   # a terminal cell is ~2x taller than wide
    grid = {}
    def put(r, cc, ch, col, force=False):
        r, cc = round(r), round(cc)
        if 0 <= r < H and 0 <= cc < W and (force or (r, cc) not in grid): grid[(r, cc)] = (ch, col)
    ry, rx = 0.55, 0.40
    def view(x, y, z):
        x, z = x * math.cos(ry) + z * math.sin(ry), -x * math.sin(ry) + z * math.cos(ry)
        y, z = y * math.cos(rx) - z * math.sin(rx), y * math.sin(rx) + z * math.cos(rx)
        return x, y, z
    # silhouette of the sphere
    for t in range(0, 360, 4):
        a = math.radians(t); put(cy + math.sin(a) * R, cx + math.cos(a) * R * XS, "·", "4")
    # nodes
    n, golden = 120, math.pi * (3 - math.sqrt(5))
    P = []
    for i in range(n):
        y = 1 - 2 * i / (n - 1); r = math.sqrt(1 - y * y); th = golden * i
        x, y, z = view(math.cos(th) * r, y, math.sin(th) * r)
        P.append((cy + y * R, cx + x * R * XS, z))
    front = [p for p in P if p[2] > 0.0]
    # ring: a circle in a tilted plane, back half hidden behind the sphere
    ring = []
    for t in range(0, 360, 2):
        a = math.radians(t)
        x, y, z = math.cos(a) * 1.5, 0.0, math.sin(a) * 1.5
        y, z = y * math.cos(1.2) - z * math.sin(1.2), y * math.sin(1.2) + z * math.cos(1.2)   # tilt plane
        x, y = x * math.cos(-0.30) - y * math.sin(-0.30), x * math.sin(-0.30) + y * math.cos(-0.30)  # slant
        ring.append((cy + y * R, cx + x * R * XS, z))
    for r_, c_, z in ring:
        if z < 0 and math.hypot((c_ - cx) / XS, r_ - cy) > R * 0.98: put(r_, c_, "─", "3")
    # links between close front nodes
    for i, p in enumerate(front):
        near = sorted(((p[0]-q[0])**2 + ((p[1]-q[1]) / XS)**2, j) for j, q in enumerate(front) if j > i)[:3]
        for d, j in near:
            q = front[j]
            if d > 5.2: continue
            steps = int(max(abs(q[0] - p[0]), abs(q[1] - p[1]) / XS) * 1.6) + 1
            dr, dc = q[0] - p[0], (q[1] - p[1]) / XS
            ch = "│" if abs(dc) < 0.35 else ("─" if abs(dr) < 0.35 else ("╲" if dr * dc > 0 else "╱"))
            for s in range(1, steps):
                put(p[0] + dr * s / steps, p[1] + (q[1] - p[1]) * s / steps, ch, "2")
    for r_, c_, z in sorted(front, key=lambda p: p[2]):
        put(r_, c_, "●" if z > 0.45 else "•", "1" if z > 0.45 else "2", True)
    for r_, c_, z in ring:
        if z >= 0: put(r_, c_, "━" if abs(c_ - cx) < 11 else "─", "3", True)
    put(cy, cx, "◉", "3", True)
    lines = []
    for r in range(H):
        out, last = "", None
        for cc in range(W):
            if (r, cc) in grid:
                ch, col = grid[(r, cc)]
                if col != last: out += "$" + col; last = col
                out += ch
            else: out += " "
        lines.append(out.rstrip())
    return "\n".join(lines) + "\n"

if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    open(f"{out}/dragon-logo.txt", "w").write(make_logo())
    json.dump(base("~/.config/fastfetch/dragon-logo.txt", modules()), open(f"{out}/config.jsonc", "w"), ensure_ascii=False, indent=2)
    sample = {"SO": "EndeavourOS", "Kernel": "6.17.4-arch1-1", "Activo": "2 h 14 min", "Paquetes": "1247 (pacman), 31 (aur)", "Shell": "zsh 5.9",
              "Hyprland": "Hyprland 0.56.2", "Quickshell": "0.3.1", "Plugins": "hyprbars hyprfocus hyprglass", "Terminal": "Ghostty 1.2.0",
              "Tema": "dragon-island", "Iconos": "Candy-icons + Sweet-Folders", "Fuente": "Outfit (11pt)", "Pantalla": "1366×768 @ 60Hz",
              "Teclado": "English (US)", "Login": "dragon-core", "CPU": "Intel i5-1135G7 (4c/8t)", "GPU": "Intel Iris Xe Graphics",
              "Memoria": "3.1 GiB / 15.4 GiB (20%)", "Disco": "112 GiB / 476 GiB (24%)", "Batería": "86% · Descargando", "Red": "wlan0 · 192.168.1.42"}
    json.dump(base(os.path.abspath(f"{out}/dragon-logo.txt"), modules(sample)), open(f"{out}/preview-config.jsonc", "w"), ensure_ascii=False, indent=2)
    print("ok")
