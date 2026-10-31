// Places the open popover Theme.hudGap below the bar, right edge aligned to the capsule that opened it
// (ShellState.anchorX / anchorSide), clamped to the screen. Only one is shown (ShellState.openPanel).
// The HUD beam runs from the capsule's centre (ShellState.anchorCenter) down to the frame: beamX is local to it.
import QtQuick
import "../.."
import "../../services"
import "../notifications"

Item {
    id: host

    property string panel: "none"
    property string screenName: ""

    readonly property real popTop: Theme.barMarginTop + Theme.barHeight + Theme.hudGap
    readonly property bool leftSide: ShellState.anchorSide === "left" && ShellState.anchorX >= 0

    // Right island: the popover's right edge on the capsule's right edge. Left island: left edge on the
    // capsule's left edge. Clamped to 14 px from the screen edges. IPC (no capsule): the bar's right edge.
    function xFor(w: real): real {
        const m = Theme.barMarginSide;
        if (ShellState.anchorX < 0) return width - m - w;
        const x = leftSide ? ShellState.anchorX : ShellState.anchorX - w;
        return Math.max(m, Math.min(width - w - m, x));
    }
    // the beam's x, local to a popover at x `px` of width `w` (IPC: under the clock, near the right edge)
    function beamFor(px: real, w: real): real {
        return ShellState.anchorCenter >= 0 ? ShellState.anchorCenter - px : w - Theme.hudRadius * 3;
    }

    PerfPopover      { shown: host.panel === "perf";      x: host.xFor(width); y: host.popTop; beamX: host.beamFor(x, width) }
    WifiPopover      { shown: host.panel === "wifi";      x: host.xFor(width); y: host.popTop; beamX: host.beamFor(x, width) }
    BluetoothPopover { shown: host.panel === "bt";        x: host.xFor(width); y: host.popTop; beamX: host.beamFor(x, width) }
    AudioPopover     { shown: host.panel === "audio";     x: host.xFor(width); y: host.popTop; beamX: host.beamFor(x, width) }
    BatteryPopover   { shown: host.panel === "battery";   x: host.xFor(width); y: host.popTop; beamX: host.beamFor(x, width); screenName: host.screenName }
    PrivacyPopover   { shown: host.panel === "privacy";   x: host.xFor(width); y: host.popTop; beamX: host.beamFor(x, width) }
    AgentsPopover    { shown: host.panel === "agents";    x: host.xFor(width); y: host.popTop; beamX: host.beamFor(x, width) }
    CalendarPopover  { shown: host.panel === "calendar";  x: host.xFor(width); y: host.popTop; beamX: host.beamFor(x, width) }
    NotificationsPopover { shown: host.panel === "notifications"; x: host.xFor(width); y: host.popTop; beamX: host.beamFor(x, width) }
}
