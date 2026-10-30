// =============================================================================
// dragon-island — Settings.qml
// Service: user preferences: animation speed (reduced motion), bar style and look, accent intensity.
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
 *   Keys added by the new identity (a missing or invalid value falls back to the default):
 *   - barStyle: string [readonly] ("A" thin notch · "B" dynamic island · "C" joined bar · "D" minimal; default "B")
 *   - barStyles: list<string> [readonly] (["A", "B", "C", "D"], the cycle order)
 *   - barSize: string [readonly] ("compacta" · "normal" · "amplia": height of the islands / strip; default "normal")
 *   - islandContent: string [readonly] (what the notch shows with no special activity: "media" · "window" · "date"; default "media")
 *   - barMetrics: bool [readonly] (CPU / RAM rings and the network line in the right island; default true)
 *   - barAutohide: bool [readonly] (dim the bar to 0.35 over a maximized window; style D hides until the top edge is touched; default false)
 *   - accentIntensity: real [readonly] (0–1, how much purple the active states carry; default 0.3)
 *   - wallpaperPalette: bool [readonly] (the shell's accent follows the wallpaper palette, services/WallPalette.qml; default true)
 *   - paletteApplyExternal: bool [readonly] (dragon-palette also tints herdr, Ghostty, kitty, Starship and fastfetch; default true)
 *   - longCommandSeconds: int [readonly] (a shell command at least this long reports to the island; ≥ 5, default 30)
 *   - recordingMode: string [readonly] ("auto": the recording mode follows a recording / a screen share · "off"; default "auto")
 *   - recordHold / recordHideTitles / recordPauseClipboard / recordFrame: bool [readonly] (its rules; default true)
 *   - focusMuteApps: list<string> [readonly] (apps kept silent during focus mode; default ["Telegram"])
 *   - idleDimSeconds / idleLockSeconds / idleScreenOffSeconds / idleSuspendSeconds: int [readonly] (the idle sequence:
 *       warn + dim, lock, screens off, suspend; defaults 240 / 300 / 330 / 1200; bin/dragon-idle reads them too)
 *   - idleInhibitAgents: bool [readonly] (a working herdr agent holds the idle sequence back; default true)
 *
 * Functions:
 *   - setMotionScale(scale: real): void (writes settings.json; negative = follow KDE again)
 *   - setReducedMotion(on: bool): void
 *   - setBarStyle(style: string): void ("A" | "B" | "C" | "D", case-insensitive; anything else is ignored)
 *   - cycleBarStyle(): void (A → B → C → D → A)
 *   - setBarSize(size: string): void ("compacta" | "normal" | "amplia"; anything else is ignored)
 *   - setIslandContent(content: string): void ("media" | "window" | "date")
 *   - setBarMetrics(on: bool): void
 *   - setBarAutohide(on: bool): void
 *   - setAccentIntensity(x: real): void (clamped to 0–1)
 *   - setWallpaperPalette(on: bool): void (only the setting: WallPalette.setEnabled also generates / resets the palette)
 *   - setPaletteApplyExternal(on: bool): void (only the setting: WallPalette.setApplyExternal also applies it)
 *   - setLongCommandSeconds(s: int): void
 *   - setRecordingMode(mode: string): void ("auto" | "off")
 *   - setFlag(key: string, on: bool): void (any boolean key above, e.g. "recordFrame")
 *   - setSeconds(key: string, s: int): void (any idle*Seconds key)
 *
 * IPC (`qs ipc call settings <fn>`): motion(scale: real), reducedMotion(on: bool), barStyle(s: string), cycleBarStyle(),
 *   barSize(s: string), accent(x: real), islandContent(s: string), metrics(on: bool), autohide(on: bool), wallpaperPalette(on: bool),
 *   paletteApplyExternal(on: bool),
 *   current(): string (every setting, one per line)
 *
 * shell.qml binds Theme.motionScale, Theme.barStyle, Theme.barSize and Theme.accentIntensity to these.
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

    readonly property var barStyles: ["A", "B", "C", "D"]
    readonly property string barStyle: barStyles.indexOf(root._data.barStyle) >= 0 ? root._data.barStyle : "B"
    readonly property var barSizes: ["compacta", "normal", "amplia"]
    readonly property string barSize: barSizes.indexOf(root._data.barSize) >= 0 ? root._data.barSize : "normal"
    readonly property string islandContent: ["media", "window", "date"].indexOf(root._data.islandContent) >= 0 ? root._data.islandContent : "media"
    readonly property bool barMetrics: typeof root._data.barMetrics === "boolean" ? root._data.barMetrics : true
    readonly property bool barAutohide: typeof root._data.barAutohide === "boolean" ? root._data.barAutohide : false
    readonly property real accentIntensity: {
        const v = Number(root._data.accentIntensity);
        return root._data.accentIntensity !== undefined && root._data.accentIntensity !== null && !isNaN(v) ? Math.max(0, Math.min(1, v)) : 0.3;
    }
    readonly property int longCommandSeconds: {
        const v = Number(root._data.longCommandSeconds);
        return root._data.longCommandSeconds !== undefined && !isNaN(v) ? Math.max(5, Math.round(v)) : 30;
    }
    function _flag(key: string, def: bool): bool { return typeof root._data[key] === "boolean" ? root._data[key] : def; }
    readonly property var focusMuteApps: Array.isArray(root._data.focusMuteApps) ? root._data.focusMuteApps.filter(a => typeof a === "string") : ["Telegram"]
    function _secs(key: string, def: int): int { const v = Number(root._data[key]); return root._data[key] !== undefined && !isNaN(v) && v > 0 ? Math.round(v) : def; }
    readonly property int idleDimSeconds: _secs("idleDimSeconds", 240)
    readonly property int idleLockSeconds: _secs("idleLockSeconds", 300)
    readonly property int idleScreenOffSeconds: _secs("idleScreenOffSeconds", 330)
    readonly property int idleSuspendSeconds: _secs("idleSuspendSeconds", 1200)
    readonly property bool idleInhibitAgents: _flag("idleInhibitAgents", true)
    readonly property string recordingMode: root._data.recordingMode === "off" ? "off" : "auto"
    readonly property bool recordHold: _flag("recordHold", true)
    readonly property bool recordHideTitles: _flag("recordHideTitles", true)
    readonly property bool recordPauseClipboard: _flag("recordPauseClipboard", true)
    readonly property bool recordFrame: _flag("recordFrame", true)
    readonly property bool wallpaperPalette: typeof root._data.wallpaperPalette === "boolean" ? root._data.wallpaperPalette : true
    readonly property bool paletteApplyExternal: _flag("paletteApplyExternal", true)

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

    function _set(key: string, value): void {
        const d = Object.assign({}, root._data);
        d[key] = value;
        root._data = d;
        _save();
    }

    function setBarStyle(style: string): void {
        const st = String(style).toUpperCase();
        if (root.barStyles.indexOf(st) < 0) { console.warn(`Settings: unknown bar style "${style}"`); return; }
        _set("barStyle", st);
    }
    function cycleBarStyle(): void { setBarStyle(root.barStyles[(root.barStyles.indexOf(root.barStyle) + 1) % root.barStyles.length]); }
    function setBarSize(size: string): void {
        const sz = String(size).toLowerCase();
        if (root.barSizes.indexOf(sz) < 0) { console.warn(`Settings: unknown bar size "${size}"`); return; }
        _set("barSize", sz);
    }
    function setIslandContent(content: string): void {
        if (["media", "window", "date"].indexOf(content) < 0) { console.warn(`Settings: unknown island content "${content}"`); return; }
        _set("islandContent", content);
    }
    function setBarMetrics(on: bool): void { _set("barMetrics", on); }
    function setBarAutohide(on: bool): void { _set("barAutohide", on); }
    function setAccentIntensity(x: real): void { _set("accentIntensity", Math.round(Math.max(0, Math.min(1, x)) * 100) / 100); }
    function setWallpaperPalette(on: bool): void { _set("wallpaperPalette", on); }
    function setPaletteApplyExternal(on: bool): void { _set("paletteApplyExternal", on); }
    function setLongCommandSeconds(s: int): void { _set("longCommandSeconds", Math.max(5, Math.round(s))); }
    function setRecordingMode(mode: string): void { if (["auto", "off"].indexOf(mode) >= 0) _set("recordingMode", mode); }
    function setFlag(key: string, on: bool): void { _set(key, on); }
    function setSeconds(key: string, s: int): void { _set(key, Math.max(10, Math.round(s))); }

    IpcHandler {
        target: "settings"
        function motion(scale: real): void { root.setMotionScale(scale); }
        function reducedMotion(on: bool): void { root.setReducedMotion(on); }
        function barStyle(s: string): void { root.setBarStyle(s); }
        function cycleBarStyle(): void { root.cycleBarStyle(); }
        function barSize(s: string): void { root.setBarSize(s); }
        function accent(x: real): void { root.setAccentIntensity(x); }
        function islandContent(s: string): void { root.setIslandContent(s); }
        function metrics(on: bool): void { root.setBarMetrics(on); }
        function autohide(on: bool): void { root.setBarAutohide(on); }
        function wallpaperPalette(on: bool): void { root.setWallpaperPalette(on); }
        function paletteApplyExternal(on: bool): void { root.setPaletteApplyExternal(on); }
        function current(): string {
            return [`motionScale=${root.motionScale} (${root.source})`, `barStyle=${root.barStyle}`, `barSize=${root.barSize}`, `islandContent=${root.islandContent}`,
                    `barMetrics=${root.barMetrics}`, `barAutohide=${root.barAutohide}`, `accentIntensity=${root.accentIntensity}`,
                    `wallpaperPalette=${root.wallpaperPalette}`, `paletteApplyExternal=${root.paletteApplyExternal}`, `longCommandSeconds=${root.longCommandSeconds}`, `recordingMode=${root.recordingMode}`].join("\n");
        }
    }
}
