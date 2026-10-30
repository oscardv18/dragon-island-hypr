// =============================================================================
// dragon-island — RecordingMode.qml
// Service: the recording mode (docs/design/25-grabacion.png). Data and side effects only; the UI reads it.
// =============================================================================
/**
 * Turns on by itself (Settings.recordingMode "auto") while the screen is recorded by the shell (Toggles.isRecording)
 * or shared / captured through the portal (Privacy.screen: OBS on Wayland, calls sharing the screen).
 * Known limit: without obs-websocket a capturing OBS cannot be told apart from a recording one, so the mode turns on
 * as soon as OBS captures the screen.
 * Rules (Ajustes › Privacidad, Settings.record*):
 *   hold       notifications are kept without popup or peek (Notifs.holdAll); when it ends the island says
 *              "N notificaciones retenidas"
 *   hideTitles the bar hides window titles and the live context (WindowContext.masked: "título oculto")
 *   clipboard  the clipboard history is paused (Clipboard.setPaused)
 *   frame      a 2 px alpha(error, .75) frame around every screen (modules/recording/RecordingFrame.qml)
 * The "on-screen keys" rule of the mockup is not implemented: there is no clean way to read every key press from a
 * Wayland client without root / the input group (HANDOFF 8c).
 *
 * Properties:
 *   - active: bool [readonly] (island state "recording")
 *   - shellRecording: bool [readonly] (the shell's own wf-recorder: a click on the island stops it)
 *   - apps: list<string> [readonly] (the apps capturing the screen, when it is not the shell)
 *   - seconds: int [readonly] (time since the mode started)
 *   - showFrame: bool [readonly] · hideTitles: bool [readonly]
 *
 * Functions:
 *   - stop(): void (stops the shell's recording; nothing to stop for other apps)
 */
pragma Singleton
import Quickshell
import QtQuick
import ".."

Singleton {
    id: root

    readonly property bool shellRecording: Toggles.isRecording
    readonly property var apps: Privacy.screenApps
    readonly property bool active: Settings.recordingMode !== "off" && (shellRecording || Privacy.screen)
    readonly property bool showFrame: active && Settings.recordFrame
    readonly property bool hideTitles: active && Settings.recordHideTitles

    property int seconds: 0
    Timer { interval: 1000; repeat: true; running: root.active; onTriggered: root.seconds++ }

    function stop(): void { if (Toggles.isRecording) Toggles.toggleRecording(); }

    onActiveChanged: {
        if (active) {
            root.seconds = 0;
            Notifs.releaseHeld();
            Notifs.holdAll = Settings.recordHold;
            if (Settings.recordPauseClipboard) Clipboard.setPaused(true);
        } else {
            Notifs.holdAll = false;
            Clipboard.setPaused(false);
            const n = Notifs.releaseHeld();
            if (n > 0) IslandState.notice(n === 1 ? "1 notificación retenida" : `${n} notificaciones retenidas`, "bell", Theme.durNotice * 2);
        }
    }
}
