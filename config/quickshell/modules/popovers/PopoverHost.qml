// Places the open popover 8 px below the bar, right edge aligned to the capsule that opened it
// (ShellState.anchorRight), clamped to the screen. Only one is shown (ShellState.openPanel).
import QtQuick
import "../.."
import "../../services"
import "../notifications"

Item {
    id: host

    property string panel: "none"
    property string screenName: ""

    readonly property real popTop: Theme.barMarginTop + Theme.barHeight + Theme.popoverGap
    readonly property real rightEdge: ShellState.anchorRight >= 0 ? ShellState.anchorRight : width - Theme.barMarginSide

    function xFor(w: real): real {
        return Math.max(Theme.barMarginSide, Math.min(width - w - Theme.barMarginSide, rightEdge - w));
    }

    PerfPopover          { shown: host.panel === "perf";          x: host.xFor(width); y: host.popTop }
    WifiPopover          { shown: host.panel === "wifi";          x: host.xFor(width); y: host.popTop }
    BluetoothPopover     { shown: host.panel === "bt";            x: host.xFor(width); y: host.popTop }
    AudioPopover         { shown: host.panel === "audio";         x: host.xFor(width); y: host.popTop }
    BatteryPopover       { shown: host.panel === "battery";       x: host.xFor(width); y: host.popTop; screenName: host.screenName }
    NotificationCenter   { shown: host.panel === "notifications"; x: host.xFor(width); y: host.popTop }
    CalendarPopover      { shown: host.panel === "calendar";      x: host.xFor(width); y: host.popTop }
}
