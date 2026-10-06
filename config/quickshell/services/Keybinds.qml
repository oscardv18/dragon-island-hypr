// =============================================================================
// dragon-island — Keybinds.qml
// Service: Hyprland keybinds for the cheatsheet panel, read live from `hyprctl binds -j`.
// Descriptions follow "Grupo · Texto" (config/hypr/binds.lua); binds with the same group
// and text are merged into one row (e.g. SUPER + 1…5 → "SUPER + 1–5").
// =============================================================================
/**
 * Properties:
 *   - groups: list<var> [readonly] ([{ name, rows: [{ text, combos: [[ "SUPER", "SHIFT", "1–5" ], …] }] }],
 *       in the order they appear in binds.lua)
 *   - count: int [readonly] (number of rows)
 *   - loading: bool [readonly]
 *   - error: string [readonly] ("" when fine)
 *
 * Functions:
 *   - refresh(): void (re-read; the panel calls it when it opens, binds change on config reload)
 *   - search(query: string): list<var> (groups whose rows match the text, group name or keys)
 *   - prettyKey(key: string): string
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var groups: []
    readonly property int count: groups.reduce((n, g) => n + g.rows.length, 0)
    property bool loading: false
    property string error: ""

    // xkb modifier mask bits used by Hyprland
    readonly property var modBits: [
        { bit: 64, name: "SUPER" }, { bit: 4, name: "CTRL" }, { bit: 8, name: "ALT" }, { bit: 1, name: "SHIFT" }
    ]

    readonly property var keyNames: ({
        "return": "Enter", "escape": "Esc", "space": "Espacio", "tab": "Tab", "backspace": "Retroceso",
        "delete": "Supr", "print": "Impr Pant",
        "left": "←", "right": "→", "up": "↑", "down": "↓",
        "mouse:272": "Clic izq.", "mouse:273": "Clic der.", "mouse:274": "Clic central",
        "mouse_down": "Rueda ↓", "mouse_up": "Rueda ↑",
        "xf86audioraisevolume": "Vol +", "xf86audiolowervolume": "Vol −", "xf86audiomute": "Silencio",
        "xf86audiomicmute": "Mic", "xf86monbrightnessup": "Brillo +", "xf86monbrightnessdown": "Brillo −",
        "xf86audioplay": "Play", "xf86audiopause": "Pausa", "xf86audionext": "Siguiente", "xf86audioprev": "Anterior"
    })

    function prettyKey(key: string): string {
        const k = (key || "").trim();
        const mapped = root.keyNames[k.toLowerCase()];
        if (mapped) return mapped;
        return k.length === 1 ? k.toUpperCase() : k;
    }

    function _mods(mask: int): var {
        return root.modBits.filter(m => (mask & m.bit) !== 0).map(m => m.name);
    }

    // "1 2 3 4 5" → "1–5"; arrows / single letters → "← → ↑ ↓"; named keys → "Play / Pausa"
    function _joinKeys(keys: var): string {
        const nums = keys.map(k => parseInt(k, 10));
        if (keys.length > 2 && nums.every((n, i) => String(n) === keys[i] && (i === 0 || n === nums[i - 1] + 1)))
            return `${keys[0]}–${keys[keys.length - 1]}`;
        return keys.join(keys.every(k => k.length === 1) ? " " : " / ");
    }

    function _build(binds: var): void {
        const groupOrder = [];
        const groupsByName = {};
        for (const b of binds) {
            if ((b.submap || "") !== "") continue;            // only the default submap
            const desc = (b.description || "").trim();
            let group = "Otros", text = desc;
            const sep = desc.indexOf(" · ");
            if (sep > 0) { group = desc.substring(0, sep).trim(); text = desc.substring(sep + 3).trim(); }
            if (text.length === 0) text = `${b.dispatcher || ""} ${b.arg || ""}`.trim() || "(sin descripción)";

            if (!groupsByName[group]) { groupsByName[group] = { name: group, rows: [], byText: {} }; groupOrder.push(group); }
            const g = groupsByName[group];
            if (!g.byText[text]) { g.byText[text] = { text: text, buckets: [], byMods: {} }; g.rows.push(g.byText[text]); }
            const row = g.byText[text];

            const mods = _mods(b.modmask || 0);
            const modKey = mods.join("+");
            if (!row.byMods[modKey]) { row.byMods[modKey] = { mods: mods, keys: [] }; row.buckets.push(row.byMods[modKey]); }
            const key = prettyKey(b.key || "");
            if (row.byMods[modKey].keys.indexOf(key) < 0) row.byMods[modKey].keys.push(key);
        }
        root.groups = groupOrder.map(name => ({
            name: name,
            rows: groupsByName[name].rows.map(r => ({
                text: r.text,
                combos: r.buckets.map(bk => bk.mods.concat([_joinKeys(bk.keys)]))
            }))
        }));
    }

    Process {
        id: proc
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text);
                    root._build(Array.isArray(data) ? data : []);
                    root.error = root.groups.length === 0 ? "Hyprland no devolvió atajos" : "";
                } catch (e) {
                    root.error = "No se pudo leer `hyprctl binds -j`";
                }
                root.loading = false;
            }
        }
        onExited: (code, status) => {
            root.loading = false;
            if (code !== 0) root.error = "hyprctl no está disponible (¿estás en Hyprland?)";
        }
    }

    function refresh(): void {
        if (proc.running) return;
        root.loading = true;
        proc.running = true;
    }

    Component.onCompleted: refresh()

    function search(query: string): var {
        const q = (query || "").trim().toLowerCase();
        if (q.length === 0) return root.groups;
        return root.groups.map(g => {
            if (g.name.toLowerCase().includes(q)) return g;
            const rows = g.rows.filter(r => r.text.toLowerCase().includes(q)
                || r.combos.some(c => c.join(" + ").toLowerCase().includes(q)));
            return rows.length > 0 ? { name: g.name, rows: rows } : null;
        }).filter(g => g !== null);
    }
}
