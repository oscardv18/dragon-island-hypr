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
        })).concat(root.panelGroups);
    }

    // Keys that work INSIDE the panels (no Hyprland bind): listed here so everything is in one place. Keep in step with
    // docs/KEYBINDS.md ("Teclado dentro de los paneles").
    readonly property var panelGroups: [
        { name: "Referencia de herdr (dentro)", rows: [
            { text: "Filtrar atajos, comandos y estados", combos: [["escribir"]] },
            { text: "Cambiar de pestaña", combos: [["Tab"]] },
            { text: "Desplazar", combos: [["↑", "↓"]] },
            { text: "Cerrar", combos: [["Esc"]] }
        ] },
        { name: "Lanzador orbital (dentro)", rows: [
            { text: "Filtrar apps; el mejor resultado pasa al frente", combos: [["escribir"]] },
            { text: "Girar el anillo", combos: [["←", "→"], ["↑", "↓"], ["Tab"], ["rueda"]] },
            { text: "Lanzar la app al frente", combos: [["Enter"]] },
            { text: "Fijar / quitar de favoritos la app del frente", combos: [["Ctrl+F"]] },
            { text: "Sin resultados: buscar en la Tienda", combos: [["Ctrl+I"]] },
            { text: "Calcular (Enter copia)", combos: [["=2*(3+4)"]] },
            { text: "Ejecutar en Ghostty", combos: [[">comando"]] },
            { text: "Buscar en la Tienda", combos: [["+nombre", "Enter"]] } ] },
        { name: "Tienda (dentro)", rows: [
            { text: "Buscar en repos oficiales y AUR / filtrar", combos: [["escribir"]] },
            { text: "Mover por la lista", combos: [["↑", "↓"]] },
            { text: "Marcar y bajar (multi-selección)", combos: [["Tab"], ["Espacio"]] },
            { text: "Instalar / eliminar / actualizar según la pestaña", combos: [["Enter"]] },
            { text: "Cerrar visor o diálogo; luego la Tienda", combos: [["Esc"]] } ] },
        { name: "herdr (dentro; antes Ctrl+B)", rows: [
            { text: "Nueva pestaña · dividir vertical · horizontal", combos: [["c"], ["v"], ["-"]] },
            { text: "Mover el foco entre paneles", combos: [["h", "j", "k", "l"]] },
            { text: "Cerrar panel · zoom", combos: [["x"], ["z"]] },
            { text: "Nuevo espacio · selector de espacios", combos: [["Shift+N"], ["w"]] },
            { text: "Separar (la sesión sigue viva) · ayuda", combos: [["q"], ["?"]] } ] },
        { name: "Fondos de pantalla (dentro)", rows: [
            { text: "Filtrar por nombre", combos: [["escribir"]] },
            { text: "Mover la selección", combos: [["←", "→", "↑", "↓"]] },
            { text: "Aplicar el fondo", combos: [["Enter"], ["clic"]] } ] },
        { name: "Portapapeles / Menú de energía (dentro)", rows: [
            { text: "Portapapeles: copiar · borrar entrada (búsqueda vacía)", combos: [["Enter"], ["Supr"]] },
            { text: "Energía: mover · ejecutar · atajo directo", combos: [["← →"], ["Enter"], ["1–5"]] } ] },
        { name: "Terminal zsh: completar con Tab", rows: [
            { text: "Abre el buscador (Enter elige, Esc cancela)", combos: [["Tab"]] },
            { text: "Carpeta: vista previa con eza", combos: [["cd", "Tab"]] },
            { text: "Archivo: vista previa con bat", combos: [["nvim", "Tab"]] },
            { text: "git: el diff del archivo", combos: [["git add", "Tab"]] },
            { text: "git: ramas y commits con su log", combos: [["git checkout", "Tab"]] },
            { text: "git: historial en gráfico", combos: [["git log", "Tab"]] },
            { text: "Proceso: usuario, CPU, memoria", combos: [["kill", "Tab"]] },
            { text: "Variable: su valor", combos: [["export", "Tab"]] },
            { text: "Paquete: su ficha (-Si)", combos: [["pacman -S", "Tab"]] },
            { text: "Aceptar la carpeta y seguir dentro", combos: [["/"]] },
            { text: "Cambiar de grupo de resultados", combos: [["<"], [">"]] } ] },
        { name: "Terminal zsh: fzf y zoxide", rows: [
            { text: "Buscar en el historial", combos: [["Ctrl", "R"]] },
            { text: "Buscar archivos y pegar la ruta", combos: [["Ctrl", "T"]] },
            { text: "Buscar carpetas y entrar", combos: [["Alt", "C"]] },
            { text: "Saltar a la carpeta más usada", combos: [["z dir"]] },
            { text: "Elegir una carpeta frecuente", combos: [["zi"]] },
            { text: "Aceptar la sugerencia gris", combos: [["→"], ["End"]] },
            { text: "No guardar el comando en el historial", combos: [["␣comando"]] } ] },
        { name: "Terminal zsh: eza", rows: [
            { text: "Lista con iconos", combos: [["ls"]] },
            { text: "Larga: permisos, tamaño, git", combos: [["ll"]] },
            { text: "Larga con ocultos", combos: [["la"]] },
            { text: "Árbol de 2 niveles", combos: [["lt"]] },
            { text: "Mostrar archivo con bat", combos: [["cat archivo"]] } ] },
        { name: "Cualquier panel", rows: [
            { text: "Cerrar", combos: [["Esc"], ["clic fuera"]] } ] }
    ]

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
