// =============================================================================
// dragon-island — Settings.qml
// Service: user preferences. Today: animation speed (reduced motion).
// =============================================================================
/**
 * Properties:
 *   - motionScale: real [readonly] (multiplier for every animation, 0 = none)
 *       priority: ~/.config/dragon-island/settings.json "motionScale"
 *                 → KDE "Velocidad de animación" (kdeglobals [KDE] AnimationDurationFactor)
 *                 → 1.0
 *   - reducedMotion: bool [readonly] (motionScale === 0)
 *   - source: string [readonly] ("settings" | "kde" | "default")
 *   - wallpaperDir: string [readonly] (settings.json "wallpaperDir", "~" allowed; default ~/Pictures/Wallpapers)
 *
 * Functions:
 *   - setMotionScale(scale: real): void (writes settings.json; negative = follow KDE again)
 *   - setReducedMotion(on: bool): void
 *
 * IPC (`qs ipc call settings <fn>`): motion(scale: real), reducedMotion(on: bool), current(): string
 *
 * shell.qml binds Theme.motionScale to motionScale.
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`
    readonly property string settingsPath: `${configHome}/dragon-island/settings.json`

    property real _userScale: -1   // from settings.json, -1 = not set
    property real _kdeScale: -1    // from kdeglobals, -1 = not set

    readonly property real motionScale: _userScale >= 0 ? _userScale : (_kdeScale >= 0 ? _kdeScale : 1.0)
    readonly property bool reducedMotion: motionScale === 0
    readonly property string source: _userScale >= 0 ? "settings" : (_kdeScale >= 0 ? "kde" : "default")

    property var _data: ({})

    readonly property string wallpaperDir: {
        const home = Quickshell.env("HOME");
        const d = typeof root._data.wallpaperDir === "string" && root._data.wallpaperDir.length > 0 ? root._data.wallpaperDir : "~/Pictures/Wallpapers";
        return d.startsWith("~") ? home + d.slice(1) : d;
    }

    FileView {
        id: settingsFile
        path: root.settingsPath
        printErrors: false
        watchChanges: true
        onFileChanged: settingsFile.reload()
        onLoaded: {
            try { root._data = JSON.parse(settingsFile.text()) || {}; } catch (e) { root._data = {}; }
            const v = Number(root._data.motionScale);
            root._userScale = root._data.motionScale !== undefined && !isNaN(v) && v >= 0 ? Math.min(v, 4) : -1;
        }
        onLoadFailed: root._userScale = -1
    }

    // Plasma's "Animation speed" slider; shared because Plasma is installed next to us
    FileView {
        id: kdeFile
        path: `${root.configHome}/kdeglobals`
        printErrors: false
        watchChanges: true
        onFileChanged: kdeFile.reload()
        onLoaded: {
            let inKde = false;
            root._kdeScale = -1;
            for (const raw of kdeFile.text().split("\n")) {
                const line = raw.trim();
                if (line.startsWith("[")) { inKde = line === "[KDE]"; continue; }
                if (inKde && line.startsWith("AnimationDurationFactor=")) {
                    const v = parseFloat(line.substring(line.indexOf("=") + 1));
                    if (!isNaN(v) && v >= 0) root._kdeScale = Math.min(v, 4);
                }
            }
        }
        onLoadFailed: root._kdeScale = -1
    }

    // mkdir + write in one process (the directory may not exist yet); watchChanges reloads it
    Process { id: writer }

    function _save(): void {
        writer.exec(["sh", "-c", 'mkdir -p "$(dirname "$2")" && printf "%s\\n" "$1" > "$2"',
                     "sh", JSON.stringify(root._data, null, 2), root.settingsPath]);
    }

    function setMotionScale(scale: real): void {
        const d = Object.assign({}, root._data);
        if (scale < 0) delete d.motionScale;
        else d.motionScale = Math.min(scale, 4);
        root._data = d;
        root._userScale = scale < 0 ? -1 : d.motionScale;
        _save();
    }

    function setReducedMotion(on: bool): void { setMotionScale(on ? 0 : -1); }

    IpcHandler {
        target: "settings"
        function motion(scale: real): void { root.setMotionScale(scale); }
        function reducedMotion(on: bool): void { root.setReducedMotion(on); }
        function current(): string { return `motionScale=${root.motionScale} (${root.source})`; }
    }
}
