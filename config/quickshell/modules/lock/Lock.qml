// Lock.qml — dragon-island session lock (replaces hyprlock; hyprlock stays as fallback)
//
// Usage: add `Lock {}` once in shell.qml.
// IPC (target "lock"):  qs ipc call lock lock      → lock now
//                       qs ipc call lock isLocked  → "true"/"false"
// There is deliberately NO unlock over IPC.
//
// State shared by every monitor's surface:
//   locked, mood, stateText, hint, hintError, busy, buffer, layoutLabel, capsLock
// Hooks to wire to existing services (optional): notifCount

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pam
import Quickshell.Services.Mpris
import Quickshell.Services.UPower

Scope {
    id: lockRoot

    // ── public state ──
    property bool locked: false
    property string mood: "calm"
    property string stateText: "bloqueado"
    property string hint: ""
    property bool hintError: false
    property bool busy: false
    property string buffer: ""
    property string layoutLabel: ""
    property bool capsLock: false
    property real contentOpacity: 1
    property int notifCount: 0          // TODO wire: Notifs.unreadCount (or similar) from services/
    property string pamConfig: "hyprlock"   // /etc/pam.d/hyprlock ships with hyprlock ("auth include login")

    readonly property string userName: Quickshell.env("USER") || ""
    property string hostName: ""

    readonly property var player: {
        const ps = Mpris.players.values
        for (let i = 0; i < ps.length; i++) if (ps[i].isPlaying) return ps[i]
        return ps.length > 0 ? ps[0] : null
    }
    readonly property real batteryPct: UPower.displayDevice && UPower.displayDevice.isLaptopBattery
        ? UPower.displayDevice.percentage * 100 : -1

    signal failed()   // surfaces shake on this

    function lock() {
        if (locked) return
        buffer = ""; hint = ""; hintError = false; busy = false
        mood = "calm"; stateText = "bloqueado"; contentOpacity = 1
        // always come back on the primary layout (us): the password was set with it
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "0"])
        layoutProc.running = true
        locked = true
    }

    function submit(password) {
        if (busy || password.length === 0) return
        busy = true
        mood = "verifying"; stateText = "verificando"
        hint = ""; hintError = false
        _pending = password
        if (!pam.start()) _startFailed()
    }

    property string _pending: ""

    function _startFailed() {
        if (pam.config === "hyprlock") {   // file missing → fall back to the standard login stack
            pam.config = "login"
            if (pam.start()) return
        }
        busy = false; _pending = ""
        mood = "alert"; stateText = "error de autenticación"
        hint = "No se pudo iniciar PAM. Usa la TTY o hyprlock."; hintError = true
    }

    PamContext {
        id: pam
        config: lockRoot.pamConfig

        onResponseRequiredChanged: {
            if (!pam.responseRequired) return
            if (lockRoot._pending !== "") { pam.respond(lockRoot._pending); lockRoot._pending = "" }
            else pam.abort()
        }
        onPamMessage: {
            // faillock / account messages ("The account is locked due to …") are shown verbatim
            if (pam.messageIsError && pam.message !== "") { lockRoot.hint = pam.message; lockRoot.hintError = true }
        }
        onCompleted: result => {
            lockRoot._pending = ""
            if (result === PamResult.Success) {
                lockRoot.mood = "ok"; lockRoot.stateText = "acceso concedido"
                unlockAnim.start()
                return
            }
            lockRoot.busy = false
            lockRoot.buffer = ""
            lockRoot.mood = "alert"
            lockRoot.stateText = result === PamResult.MaxTries ? "demasiados intentos" : "acceso denegado"
            if (!lockRoot.hintError || lockRoot.hint === "")
                lockRoot.hint = "Contraseña incorrecta." + (lockRoot.layoutLabel ? " Revisa la distribución de teclado (" + lockRoot.layoutLabel + ")." : "")
                    + (lockRoot.capsLock ? " Bloq Mayús está activo." : "")
            lockRoot.hintError = true
            lockRoot.failed()
            calmTimer.restart()
        }
    }

    Timer {
        id: calmTimer; interval: 1400
        onTriggered: if (lockRoot.mood === "alert") { lockRoot.mood = "calm"; lockRoot.stateText = "bloqueado" }
    }

    SequentialAnimation {
        id: unlockAnim
        PauseAnimation { duration: 650 }
        NumberAnimation { target: lockRoot; property: "contentOpacity"; to: 0; duration: 300; easing.type: Easing.OutCubic }
        ScriptAction { script: { lockRoot.locked = false; lockRoot.busy = false; lockRoot.buffer = "" } }
    }

    // ── keyboard layout + caps lock (Hyprland) ──
    function _short(name) {
        const n = (name || "").toLowerCase()
        if (n.indexOf("latin") >= 0 || n.indexOf("latam") >= 0) return "LATAM"
        if (n.indexOf("english") >= 0 || n === "us") return "US"
        return (name || "").slice(0, 5).toUpperCase()
    }
    Process {
        id: layoutProc
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kbs = JSON.parse(this.text).keyboards || []
                    const main = kbs.find(k => k.main) || kbs[0]
                    if (main) { lockRoot.layoutLabel = lockRoot._short(main.active_keymap); lockRoot.capsLock = !!main.capsLock }
                } catch (e) {}
            }
        }
    }
    Timer {   // caps lock has no event: poll only while locked
        running: lockRoot.locked; interval: 600; repeat: true
        onTriggered: layoutProc.running = true
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout") {
                const parts = event.data.split(",")
                lockRoot.layoutLabel = lockRoot._short(parts[parts.length - 1])
            }
        }
    }
    Process {
        running: true
        command: ["uname", "-n"]
        stdout: StdioCollector { onStreamFinished: lockRoot.hostName = this.text.trim() }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { lockRoot.lock() }
        function isLocked(): bool { return lockRoot.locked }
    }

    // ── the lock itself ──
    WlSessionLock {
        id: sessionLock
        locked: lockRoot.locked

        WlSessionLockSurface {
            id: surface
            color: "#05060c"

            LockView {
                id: lv
                anchors.fill: parent
                mood: lockRoot.mood
                stateText: lockRoot.stateText
                hint: lockRoot.hint
                hintError: lockRoot.hintError
                busy: lockRoot.busy
                layoutLabel: lockRoot.layoutLabel
                capsLock: lockRoot.capsLock
                userName: lockRoot.userName
                hostName: lockRoot.hostName
                notifCount: lockRoot.notifCount
                batteryPct: lockRoot.batteryPct
                contentOpacity: lockRoot.contentOpacity
                hasMedia: lockRoot.player !== null && (lockRoot.player.trackTitle || "") !== ""
                mediaTitle: lockRoot.player ? (lockRoot.player.trackTitle || "") : ""
                mediaArtist: lockRoot.player ? (lockRoot.player.trackArtist || "") : ""
                mediaPlaying: lockRoot.player ? lockRoot.player.isPlaying : false
                // the core is the expensive part: only animate it on the focused monitor
                reducedMotion: surface.screen !== null && Hyprland.focusedMonitor !== null
                               && surface.screen.name !== Hyprland.focusedMonitor.name

                onTyped: t => { lockRoot.buffer = t; if (lockRoot.mood === "alert") { lockRoot.mood = "calm"; lockRoot.stateText = "bloqueado"; lockRoot.hint = ""; lockRoot.hintError = false } }
                onSubmitted: p => lockRoot.submit(p)
                onLayoutClicked: Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"])
                onMediaPrev: if (lockRoot.player && lockRoot.player.canGoPrevious) lockRoot.player.previous()
                onMediaToggle: if (lockRoot.player && lockRoot.player.canTogglePlaying) lockRoot.player.togglePlaying()
                onMediaNext: if (lockRoot.player && lockRoot.player.canGoNext) lockRoot.player.next()
                onSuspendClicked: Quickshell.execDetached(["systemctl", "suspend"])
                onPowerClicked: Quickshell.execDetached(["systemctl", "poweroff"])

                Connections {
                    target: lockRoot
                    function onBufferChanged() { lv.setText(lockRoot.buffer) }   // keep every monitor in sync
                    function onFailed() { lv.shake(); lv.focusInput() }
                }
                Component.onCompleted: focusInput()
            }
        }
    }
}
