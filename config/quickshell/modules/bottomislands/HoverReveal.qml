// =============================================================================
// dragon-island — HoverReveal.qml
// State machine for something that only exists while the pointer asks for it: hidden → revealing → shown → hiding.
// Reusable (bottom islands today, the dock tomorrow). No visuals; a window feeds it the pointer and reads `progress`.
//
//   hidden     nothing drawn. Pointer in the strip for `intentMs` → revealing (a fast pass over the edge does nothing).
//   revealing  animating in (`progress` 0 → 1); settles into shown after durBottomShow.
//   shown      pointer away (and nothing holding it open) for `graceMs` → hiding. Coming back cancels the countdown.
//   hiding     animating out; the pointer coming back turns it round at once (no new intent wait).
//
// Inputs:  pointerInside, holdOpen (a popover / menu / drag is open), forced (IPC reveal: stays until hide()).
// Outputs: phase, active (phase != hidden: the input mask must cover the whole island), progress (0..1, may overshoot).
// Functions: reveal(), hide() (also what Esc does: the pointer being inside does not bring it back until it leaves), toggle().
// =============================================================================
import QtQuick
import "../.."

Item {
    id: root

    property bool pointerInside: false
    property bool holdOpen: false
    property bool forced: false
    property int intentMs: Theme.bottomIntentMs
    property int graceMs: Theme.bottomGraceMs

    property string phase: "hidden"
    readonly property bool active: phase !== "hidden"
    readonly property bool target: phase === "revealing" || phase === "shown"
    property real progress: 0
    property bool _suppressed: false          // hide() was asked while the pointer is still inside

    Behavior on progress {
        enabled: Theme.animationsEnabled
        NumberAnimation {
            duration: root.target ? Theme.durBottomShow : Theme.durBottomHide
            easing.type: root.target ? Easing.OutBack : Easing.InCubic
            easing.overshoot: 0.9
        }
    }
    onTargetChanged: progress = target ? 1 : 0

    readonly property bool _inside: pointerInside && !_suppressed
    readonly property bool _wanted: _inside || holdOpen || forced

    on_InsideChanged: root._evaluate()
    on_WantedChanged: root._evaluate()
    onPointerInsideChanged: if (!pointerInside) _suppressed = false

    function reveal(): void { _suppressed = false; forced = true; if (phase === "hidden" || phase === "hiding") _go("revealing"); }
    function hide(): void { forced = false; _suppressed = pointerInside; if (phase === "revealing" || phase === "shown") _go("hiding"); }
    function toggle(): void { if (phase === "hidden" || phase === "hiding") reveal(); else hide(); }

    function _go(p: string): void {
        intent.stop(); grace.stop(); settle.stop();
        phase = p;
        if (p === "revealing") settle.interval = Theme.durBottomShow;
        if (p === "hiding") settle.interval = Theme.durBottomHide;
        if (p === "revealing" || p === "hiding") settle.restart();
        _evaluate();
    }

    function _evaluate(): void {
        switch (phase) {
        case "hidden":
            if (_inside) { if (!intent.running) intent.restart(); } else intent.stop();
            break;
        case "revealing":
        case "shown":
            if (_wanted) grace.stop(); else if (!grace.running) grace.restart();
            break;
        case "hiding":
            if (_inside || forced) _go("revealing");
            break;
        }
    }

    Timer { id: intent; interval: root.intentMs; onTriggered: if (root._inside) root._go("revealing") }
    Timer { id: grace; interval: root.graceMs; onTriggered: if (!root._wanted) root._go("hiding") }
    Timer {
        id: settle
        onTriggered: {
            if (root.phase === "revealing") { root.phase = "shown"; root._evaluate(); }
            else if (root.phase === "hiding") { root.phase = "hidden"; root._evaluate(); }
        }
    }
}
