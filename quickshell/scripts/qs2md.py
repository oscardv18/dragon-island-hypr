#!/usr/bin/env python3
"""Convert Quickshell typegen JSON (data/modules) into compact Markdown references, one file per module."""
import json, os, re, sys

src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)

TOKEN = re.compile(r"TYPE99(.*?)99TYPE")


def detok(m):
    mod = name = member = None
    for part in m.group(1).split("99"):
        if not part:
            continue
        k, v = part[0], part[1:]
        if k == "M":
            mod = v.replace("QS_", "", 1).replace("QT_", "", 1).replace("_", ".")
        elif k == "N":
            name = v
        elif k == "V":
            member = v
    s = ".".join(x for x in [name, member] if x)
    if not s and mod:
        s = mod
    return f"`{s}`"


def clean(text):
    if not text:
        return ""
    parts = text.split("```")
    for i, seg in enumerate(parts):
        if i % 2 == 1:  # inside fenced code: plain names
            parts[i] = TOKEN.sub(lambda m: detok(m).strip("`"), seg)
        else:
            parts[i] = TOKEN.sub(detok, seg)
    text = "```".join(parts)
    # strip hugo shortcodes
    text = re.sub(r"\{\{%.*?%\}\}", "", text)
    return text.strip()


def tname(t):
    if t is None:
        return "void"
    if "gadget" in t:
        return "{ " + ", ".join(f"{k}: {tname(v)}" for k, v in t["gadget"].items()) + " }"
    n = t.get("name", "?")
    of = t.get("of")
    if of:
        n = f"{n}<{tname(of)}>"
    return n


def item(head, details):
    det = clean(details or "")
    if not det:
        return [head]
    if "\n" not in det:
        return [f"{head} — {det}"]
    first, _, rest = det.partition("\n")
    out = [f"{head} — {first}"]
    out += [("  " + l) if l.strip() else "" for l in rest.split("\n")]
    return out


def oneline(text):
    text = clean(text)
    first = text.split("\n\n")[0].replace("\n", " ").strip()
    return first


by_mod = {}
for mod in sorted(os.listdir(src)):
    mdir = os.path.join(src, mod)
    if not os.path.isdir(mdir):
        continue
    for f in sorted(os.listdir(mdir)):
        if f == "index.json" or not f.endswith(".json"):
            continue
        d = json.load(open(os.path.join(mdir, f)))
        by_mod.setdefault(mod, []).append(d)

index_lines = []
for mod, types in by_mod.items():
    idx_path = os.path.join(src, mod, "index.json")
    mdesc = ""
    if os.path.exists(idx_path):
        idx = json.load(open(idx_path))
        mdesc = clean(idx.get("description") or "")
    lines = [f"# {mod}", "", f"`import {mod}`", ""]
    if mdesc:
        lines += [mdesc, ""]
    for d in types:
        flags = d.get("flags") or []
        kind = "enum" if "enum" in flags else ("singleton" if "singleton" in flags else d.get("type", "class"))
        sup = d.get("super")
        header = f"## {d['name']}"
        meta = [f"*{kind}*"]
        if sup:
            meta.append(f"extends `{tname(sup)}`")
        if "uncreatable" in flags:
            meta.append("uncreatable (obtained from other objects)")
        lines += [header, " · ".join(meta), ""]
        det = clean(d.get("details") or d.get("description") or "")
        if det:
            lines += [det, ""]
        props = d.get("properties") or {}
        if props:
            lines.append("**Properties**")
            for pn, p in props.items():
                fl = p.get("flags") or []
                tags = []
                if "readonly" in fl:
                    tags.append("readonly")
                if "default" in fl:
                    tags.append("default")
                if "required" in fl:
                    tags.append("required")
                tag = f" [{', '.join(tags)}]" if tags else ""
                lines += item(f"- `{pn}`: {tname(p.get('type'))}{tag}", p.get("details"))
            lines.append("")
        funcs = d.get("functions") or []
        if funcs:
            lines.append("**Functions**")
            for fn in funcs:
                params = ", ".join(f"{p['name']}: {tname(p.get('type'))}" for p in fn.get("params", []))
                lines += item(f"- `{fn['name']}({params})`: {tname(fn.get('ret'))}", fn.get("details"))
            lines.append("")
        sigs = d.get("signals") or {}
        if sigs:
            lines.append("**Signals**")
            for sn, s in sigs.items():
                params = ", ".join(f"{p['name']}: {tname(p.get('type'))}" for p in s.get("params", []))
                lines += item(f"- `{sn}({params})` — handler `on{sn[0].upper()}{sn[1:]}`", s.get("details"))
            lines.append("")
        var = d.get("variants") or {}
        if var:
            lines.append("**Values:** " + ", ".join(f"`{d['name']}.{v}`" for v in var))
            lines.append("")
    fname = mod + ".md"
    open(os.path.join(out, fname), "w").write("\n".join(lines))
    index_lines.append((mod, fname, len(types), [t["name"] for t in types]))

with open(os.path.join(out, "_INDEX.md"), "w") as f:
    f.write("# Quickshell API index (generated from source tag v0.3.1)\n\n")
    for mod, fname, n, names in index_lines:
        f.write(f"- **{mod}** → `{fname}` ({n} types): {', '.join(names)}\n")
print("ok", len(index_lines))
