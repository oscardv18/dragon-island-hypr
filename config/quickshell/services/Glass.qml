// =============================================================================
// dragon-island — Glass.qml
// Service: the glass material (Ajustes › Apariencia › Cristal, docs/design/28-emergentes.png).
//   ahumado  native Hyprland blur with fine grain, dark fill, a 1 px light edge on top (lavender → cyan) — default
//   clasico  native blur, thin border, no grain and no light edge
//   liquido  hyprglass (only offered while the plugin is loaded)
// Settings.glassStyle is what the user chose; this service mirrors it into ~/.config/dragon-island/glass-style
// (config/hypr/glassstyle.lua reads it when the Hyprland config loads) and runs `hyprctl reload`, so look.lua,
// rules.lua and glass.lua switch blur / hyprglass live. Never two blurs on one layer: the native layer rules exist
// only when hyprglass is off (rules.lua).
// =============================================================================
/**
 * Properties:
 *   - requested: string [readonly] (Settings.glassStyle)
 *   - liquidAvailable: bool [readonly] (hyprglass is loaded: `hyprctl plugin list`, checked at start and after a reload)
 *   - style: string [readonly] ("ahumado" | "clasico" | "liquido": what is drawn; liquido without the plugin = ahumado)
 *   - styles: list<var> [readonly] ({ key, label, detail, available } for the Ajustes selector)
 *
 * Functions:
 *   - setStyle(key: string): void (Settings.setGlassStyle + apply)
 *   - refresh(): void (re-detects hyprglass)
 *
 * IPC (`qs ipc call glass <fn>`): set(style: string), current(): string
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string requested: Settings.glassStyle
    property bool liquidAvailable: false
    property bool _detected: false
    readonly property string style: requested === "liquido" && !liquidAvailable ? "ahumado" : requested
    readonly property var styles: [
        { key: "ahumado", label: "Ahumado", available: true,
          detail: "Desenfoque tradicional, grano fino y un filo de luz arriba. Se lee como un material propio sin distorsionar lo de atrás." },
        { key: "clasico", label: "Clásico", available: true,
          detail: "Desenfoque nativo y un borde fino. Sin grano ni filo de luz." },
        { key: "liquido", label: "Líquido", available: root.liquidAvailable,
          detail: root.liquidAvailable ? "El cristal líquido de hyprglass: refracción en el borde y brillo especular."
                                       : "Necesita el plugin hyprglass (componente «Efecto cristal» del instalador)." }
    ]

    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`
    readonly property string stylePath: `${configHome}/dragon-island/glass-style`

    function setStyle(key: string): void {
        if (key === "liquido" && !root.liquidAvailable) return;
        Settings.setGlassStyle(key);
    }

    function refresh(): void { detect.running = true; }

    // ---- hyprglass loaded? ----
    Process {
        id: detect
        command: ["hyprctl", "plugin", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.liquidAvailable = /Plugin hyprglass\b/.test(text);
                root._detected = true;
                root._sync();
            }
        }
    }

    // ---- the file Hyprland reads ----
    FileView {
        id: styleFile
        path: root.stylePath
        printErrors: false
        watchChanges: true
        onFileChanged: styleFile.reload()
        onLoaded: { root._onDisk = styleFile.text().trim(); root._sync(); }
        onLoadFailed: { root._onDisk = ""; root._sync(); }
    }

    property string _onDisk: ""

    // the file follows the user's choice; when it changes, Hyprland reloads its config (look / rules / glass)
    function _sync(): void {
        if (!root._detected || writer.running) return;
        if (root._onDisk === root.requested) return;
        writer.exec(["sh", "-c", 'mkdir -p "$(dirname "$2")" && printf "%s\\n" "$1" > "$2" && hyprctl reload >/dev/null',
                     "sh", root.requested, root.stylePath]);
    }
    onRequestedChanged: _sync()

    Process {
        id: writer
        onExited: { styleFile.reload(); root.refresh(); }
    }

    Component.onCompleted: detect.running = true

    IpcHandler {
        target: "glass"
        function set(style: string): void { root.setStyle(style); }
        function current(): string { return `requested=${root.requested}\nstyle=${root.style}\nliquidAvailable=${root.liquidAvailable}`; }
    }
}
