// Places the open popover 8 px below the bar, right edge aligned to the capsule that opened it
// (ShellState.anchorX / anchorSide), clamped to the screen. Only one is shown (ShellState.openPanel).
import QtQuick
import "../.."
import "../../services"
import "../notifications"

Item {
    id: host

    property string panel: "none"
    property string screenName: ""

    readonly property real popTop: Theme.barMarginTop + Theme.barHeight + Theme.popoverGap
    readonly property bool leftSide: ShellState.anchorSide === "left" && ShellState.anchorX >= 0

    // Right island: the popover's right edge on the capsule's right edge. Left island: left edge on the
    // capsule's left edge. Clamped to 14 px from the screen edges. IPC (no capsule): the bar's right edge.
    function xFor(w: real): real {
        const m = Theme.barMarginSide;
        if (ShellState.anchorX < 0) return width - m - w;
        const x = leftSide ? ShellState.anchorX : ShellState.anchorX - w;
        return Math.max(m, Math.min(width - w - m, x));
    }

    PerfPopover          { id: perf; shown: host.panel === "perf";          x: host.xFor(width); originX: host.leftSide ? 0 : width; y: host.popTop }
    WifiPopover          { id: wifi; shown: host.panel === "wifi";          x: host.xFor(width); originX: host.leftSide ? 0 : width; y: host.popTop }
    BluetoothPopover     { id: bt; shown: host.panel === "bt";            x: host.xFor(width); originX: host.leftSide ? 0 : width; y: host.popTop }
    AudioPopover         { id: audio; shown: host.panel === "audio";         x: host.xFor(width); originX: host.leftSide ? 0 : width; y: host.popTop }
    BatteryPopover       { id: battery; shown: host.panel === "battery";       x: host.xFor(width); originX: host.leftSide ? 0 : width; y: host.popTop; screenName: host.screenName }
    PrivacyPopover       { id: privacy; shown: host.panel === "privacy";       x: host.xFor(width); originX: host.leftSide ? 0 : width; y: host.popTop }
    CalendarPopover      { id: calendar; shown: host.panel === "calendar";      x: host.xFor(width); originX: host.leftSide ? 0 : width; y: host.popTop }
}
