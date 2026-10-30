// =============================================================================
// dragon-island — Capture.qml
// Service: screenshots from the island (docs/design/13-capturas.png). Replaces grimblast.
// =============================================================================
/**
 * SUPER + SHIFT + S → open("region"): the capture bar (island state "capture") and modules/capture/CaptureWindow.qml
 * (the frozen screen) on the focused monitor. Print → fullscreen(): the whole focused monitor at once, no bar.
 * Shooting hides the overlay first, waits Theme.durCaptureHide (+ the delay), then `grim -g` the live screen.
 * Every capture is saved in the XDG pictures folder ("Captura_<fecha>.png") and announced as a SILENT notification
 * of the app "Capturas" (Notifs keeps it in the center, grouped, without popup or peek); the island says what
 * happened ("Copiada · guardada en Imágenes", Theme.durNotice).
 *
 * Properties:
 *   - active: bool [readonly] (the capture bar / overlay is open)
 *   - screenName: string [readonly] (monitor of the capture)
 *   - mode: string ("region" | "window" | "screen")
 *   - delay: int (0 | 3 seconds, applied when shooting)
 *   - dir: string [readonly] (where captures are saved)
 *   - canAnnotate: bool [readonly] (satty or swappy is installed) · annotator: string [readonly]
 *   - canOcr: bool [readonly] (tesseract is installed WITH Spanish or English data) · ocrLangs: string [readonly] ("spa+eng")
 *   - busy: bool [readonly] (a capture is being taken)
 *
 * Functions:
 *   - open(mode: string): void          close(): void          setMode(mode: string): void
 *   - toggleDelay(): void               fullscreen(): void (Print)          openFolder(): void
 *   - shoot(geometry: string, action: string): void (geometry "x,y wxh" in global coordinates;
 *       action "copy" (copy + save) | "save" | "annotate" | "ocr" | "record" (Toggles recording of that area))
 *
 * IPC (`qs ipc call capture <fn>`): open(mode: string), toggle(), screen(), close(), shoot(geometry: string, action: string)
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import ".."

Singleton {
    id: root

    property bool active: false
    property string screenName: ""
    property string mode: "region"
    property int delay: 0
    property bool busy: false
    property string dir: `${Quickshell.env("HOME")}/Pictures`
    property string annotator: ""
    property string ocrLangs: ""
    readonly property bool canOcr: ocrLangs.length > 0
    readonly property bool canAnnotate: annotator.length > 0

    function open(m: string): void {
        if (root.busy) return;
        root.mode = ["region", "window", "screen"].indexOf(m) >= 0 ? m : "region";
        root.screenName = Hyprland.focusedMonitor?.name ?? "";
        Hyprland.refreshToplevels();
        ShellState.close();
        root.active = true;
    }
    function close(): void { root.active = false; }
    function setMode(m: string): void { if (["region", "window", "screen"].indexOf(m) >= 0) root.mode = m; }
    function toggleDelay(): void { root.delay = root.delay > 0 ? 0 : 3; }
    function openFolder(): void { Quickshell.execDetached(["xdg-open", root.dir]); }

    function fullscreen(): void {
        const mon = Hyprland.focusedMonitor;
        if (!mon || root.busy) return;
        root.screenName = mon.name;
        root._run(`${mon.x},${mon.y} ${mon.width}x${mon.height}`, "copy", 0);
    }

    function shoot(geometry: string, action: string): void {
        if (root.busy) return;
        root.active = false;          // the overlay unmaps before grim looks at the screen
        if (action === "record") { hideWait.then = () => Toggles.startRecording(geometry); hideWait.restart(); return; }
        root._run(geometry, action, root.delay);
    }

    function _run(geometry: string, action: string, delaySec: int): void {
        root.busy = true;
        shot.action = action;
        shot.command = ["sh", "-c", root._script, "sh", geometry, action, root.dir, String(delaySec), root.annotator, root.ocrLangs];
        hideWait.then = () => { shot.running = true; };
        hideWait.restart();
    }

    Timer {
        id: hideWait
        property var then: null
        interval: Theme.durCaptureHide
        onTriggered: if (then) { const f = then; then = null; f(); }
    }

    // $1 geometry · $2 action · $3 folder · $4 delay · $5 annotator · $6 OCR languages. Prints the file (or the recognised text for ocr).
    readonly property string _script: '
        sleep "$4"
        mkdir -p "$3"
        if [ "$2" = ocr ]; then f=$(mktemp --suffix=.png); else f="$3/Captura_$(date +%Y-%m-%d_%H-%M-%S).png"; fi
        grim -g "$1" "$f" || exit 1
        case "$2" in
            copy) wl-copy -t image/png < "$f" ;;
            annotate) if [ "$5" = satty ]; then satty --filename "$f" --output-filename "$f" --early-exit >/dev/null 2>&1 & else swappy -f "$f" -o "$f" >/dev/null 2>&1 & fi ;;
            ocr) t=$(tesseract "$f" - -l "$6" 2>/dev/null); rm -f "$f"; printf "%s" "$t" | wl-copy; printf "OCR\\n%s" "$t"; exit 0 ;;
        esac
        case "$2" in copy) msg="Copiada y guardada en Imágenes" ;; *) msg="Guardada en Imágenes" ;; esac
        notify-send -a Capturas -i "$f" -h "string:image-path:$f" "Captura" "$msg"
        printf "%s" "$f"'

    Process {
        id: shot
        property string action: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const out = this.text;
                if (shot.action === "ocr") {
                    const n = out.replace(/^OCR\n/, "").trim().length;
                    IslandState.notice(n > 0 ? `Texto copiado · ${n} caracteres` : "No se reconoció texto", "check", Theme.durNotice);
                } else if (out.length > 0) {
                    IslandState.notice(shot.action === "copy" ? "Copiada · guardada en Imágenes"
                                     : (shot.action === "annotate" ? "Guardada · abriendo el editor" : "Guardada en Imágenes"), "check", Theme.durNotice);
                }
            }
        }
        onExited: (code, status) => {
            root.busy = false;
            if (code !== 0) IslandState.notice("La captura falló", "close", Theme.durNotice);
        }
    }

    // where to save + which optional tools exist (once)
    Process {
        running: true
        command: ["sh", "-c", 'd=$(xdg-user-dir PICTURES 2>/dev/null); [ -n "$d" ] && [ "$d" != "$HOME" ] || d="$HOME/Pictures"; echo "$d"; command -v satty >/dev/null && echo satty || { command -v swappy >/dev/null && echo swappy || echo -; }; command -v tesseract >/dev/null && tesseract --list-langs 2>/dev/null | grep -xE "spa|eng" | paste -sd+ - || echo']
        stdout: StdioCollector {
            onStreamFinished: {
                const l = this.text.split("\n");
                if (l[0]) root.dir = l[0];
                root.annotator = l[1] && l[1] !== "-" ? l[1] : "";
                root.ocrLangs = (l[2] ?? "").trim();
            }
        }
    }

    IpcHandler {
        target: "capture"
        function open(mode: string): void { root.open(mode); }
        function toggle(): void { if (root.active) root.close(); else root.open("region"); }
        function screen(): void { root.fullscreen(); }
        function close(): void { root.close(); }
        function shoot(geometry: string, action: string): void { root.shoot(geometry, action); }
    }
}
