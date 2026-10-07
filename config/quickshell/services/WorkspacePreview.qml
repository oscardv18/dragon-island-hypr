// =============================================================================
// dragon-island — WorkspacePreview.qml
// Service: state of the workspace hover preview (which workspace, where, on which monitor)
// =============================================================================
/**
 * The workspace pills call show() / hide(); the preview window (modules/bar/PreviewWindow.qml) follows
 * `open`. hide() waits a moment so the pointer can travel from the pill to the preview card, keep() (the
 * card is hovered) cancels it.
 *
 * Properties:
 *   - open: bool [readonly]
 *   - wsId: int [readonly]
 *   - anchorX: real [readonly] (screen x of the pill's centre)
 *   - screenName: string [readonly]
 *   - windows: list<var> [readonly] (Hypr.windowsOn(wsId))
 *
 * Functions:
 *   - show(wsId: int, anchorX: real, screenName: string): void   (no preview for an empty workspace)
 *   - hide(): void     keep(): void     close(): void
 */
pragma Singleton
import Quickshell
import QtQuick

Singleton {
    id: root

    property bool open: false
    property int wsId: 0
    property real anchorX: 0
    property string screenName: ""
    readonly property var windows: root.open ? Hypr.windowsOn(root.wsId) : []

    function show(id: int, x: real, screen: string): void {
        hideTimer.stop();
        if (Hypr.windowsOn(id).length === 0) { root.close(); return; }
        root.wsId = id;
        root.anchorX = x;
        root.screenName = screen;
        showTimer.restart();
    }

    function hide(): void { showTimer.stop(); hideTimer.restart(); }
    function keep(): void { hideTimer.stop(); }
    function close(): void { showTimer.stop(); hideTimer.stop(); root.open = false; }

    // a short delay before opening, so crossing the pills does not flash previews
    Timer { id: showTimer; interval: 350; onTriggered: root.open = true }
    Timer { id: hideTimer; interval: 280; onTriggered: root.open = false }
}
