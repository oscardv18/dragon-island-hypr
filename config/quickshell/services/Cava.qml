// =============================================================================
// dragon-island — Cava.qml
// Service: the real audio wave of the isla de mando's music card, from `cava` (raw ascii output on stdout), only while
// some view wants it (the island expanded and something playing). Without cava the view draws soft decorative bars.
// =============================================================================
/**
 * Properties:
 *   - available: bool [readonly] (cava is installed)
 *   - bars: list<real> [readonly] (Theme.waveBars values 0..1, ~30 fps while running)
 *   - running: bool [readonly]
 *
 * Functions:
 *   - want(on: bool): void (reference counted; the process runs only while > 0 and cava exists)
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import ".."

Singleton {
    id: root

    property bool available: false
    property var bars: []
    property int _refs: 0
    readonly property bool running: proc.running

    function want(on: bool): void { root._refs = Math.max(0, root._refs + (on ? 1 : -1)); }

    Process {
        command: ["sh", "-c", "command -v cava"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.available = this.text.trim().length > 0 }
    }

    Process {
        id: proc
        running: root.available && root._refs > 0
        command: ["sh", "-c", `cfg="\${XDG_RUNTIME_DIR:-/tmp}/dragon-cava.conf"
cat > "$cfg" <<CFG
[general]
bars = ${Theme.waveBars}
framerate = 30
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 100
bar_delimiter = 59
frame_delimiter = 10
CFG
exec cava -p "$cfg"`]
        stdout: SplitParser {
            onRead: line => {
                const v = line.split(";").filter(x => x.length > 0).map(x => Math.min(1, Number(x) / 100));
                if (v.length > 0) root.bars = v;
            }
        }
        onRunningChanged: if (!running) root.bars = []
    }
}
