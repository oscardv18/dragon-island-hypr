// LockView.qml — visual layer of the dragon-island lock screen (docs/design/06-bloqueo.png). Pure QtQuick (no
// Quickshell imports), so it renders and tests outside Quickshell (tests/qml/lock_mock.qml); Lock.qml feeds it data.
// Its palette is local on purpose (this file also has to work without Theme) and follows Theme's new identity.
//
// In:   mood, stateText, hint, hintError, busy, layoutLabel, capsLock, userName, realName, hostName, avatar (file URL or
//       ""), lockedAt (ms epoch), hasMedia, mediaTitle, mediaArtist, mediaPlaying, mediaArt, mediaProgress (0..1),
//       notifCount, notifApps ([{ name, icon, count }], the 3 with most unread are shown as satellites), captures
//       (count), batteryPct (-1 = no battery), wifiOn, muted, canSuspend, reducedMotion, pointCount, uiFont, monoFont
// Out:  submitted(password), layoutClicked(), mediaPrev(), mediaToggle(), mediaNext(), suspendClicked(),
//       powerClicked(), typed(text)
// Fns:  shake(), clear(), focusInput(), setText(t)
//
// Layout: "DRAGONOS · BLOQUEADO" top left · Wi-Fi / volume / layout / suspend / power top right · the neural core
// with its HUD (~440 px, 0.72) behind a 132 px thin clock and the date · notification apps as glass satellites on the
// dotted orbit · avatar + name + "bloqueado hace N min" · 340 × 46 password field with a 34 px round → button ·
// "Enter para desbloquear · Bloq Mayús …" · the mini player bottom left · the counts bottom right.
// The core listens while typing, verifies, turns alert on a wrong password and ok when it unlocks.

import QtQuick
import QtQuick.Shapes
import "../../components"

Rectangle {
    id: view
    color: cInk

    property string mood: "calm"
    property string stateText: "bloqueado"
    property string hint: ""
    property bool hintError: false
    property bool busy: false
    property string layoutLabel: ""
    property bool capsLock: false
    property string userName: ""
    property string realName: ""
    property string hostName: ""
    property string avatar: ""
    property real lockedAt: Date.now()
    property bool hasMedia: false
    property string mediaTitle: ""
    property string mediaArtist: ""
    property bool mediaPlaying: false
    property string mediaArt: ""
    property real mediaProgress: 0
    property int notifCount: 0
    property var notifApps: []
    property int captures: 0
    property real batteryPct: -1
    property bool wifiOn: true
    property bool muted: false
    property bool canSuspend: true
    property bool reducedMotion: false
    property int pointCount: 200
    property string uiFont: "Outfit"
    property string monoFont: "JetBrainsMono Nerd Font"
    property real contentOpacity: 1

    signal submitted(string password)
    signal typed(string text)
    signal layoutClicked()
    signal mediaPrev()
    signal mediaToggle()
    signal mediaNext()
    signal suspendClicked()
    signal powerClicked()

    function shake() { shakeAnim.restart() }
    function clear() { pw.text = "" }
    function focusInput() { pw.forceActiveFocus() }
    function setText(t) { if (pw.text !== t) pw.text = t }

    // the new identity (Theme.qml): text / textSoft / textDim, lavender, cyan, warn, error, ok, islandInk, badge
    readonly property color cInk: "#07060d"
    readonly property color cText: "#edebf5"
    readonly property color cSoft: "#c8c4d8"
    readonly property color cDim: "#a29eb6"
    readonly property color cLavender: "#c8b6e6"
    readonly property color cCyan: "#67e8f9"
    readonly property color cWarn: "#f5b04a"
    readonly property color cAlert: "#ed254e"
    readonly property color cOk: "#86efac"
    readonly property color cBadge: "#8b6bb8"
    readonly property color cLine: Qt.rgba(1, 1, 1, 0.10)
    readonly property color cGlass: Qt.rgba(13 / 255, 11 / 255, 22 / 255, 0.62)
    readonly property real s: Math.max(0.75, Math.min(1.6, height / 900))

    property real nowMs: Date.now()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: view.nowMs = Date.now() }
    readonly property int lockedMinutes: Math.max(0, Math.floor((nowMs - lockedAt) / 60000))

    // ── background: a soft vignette over the ink ──
    Shape {
        anchors.fill: parent
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: view.width / 2; centerY: view.height * 0.38
                focalX: centerX; focalY: centerY
                centerRadius: Math.max(view.width, view.height) * 0.7
                GradientStop { position: 0.0; color: Qt.rgba(0.20, 0.15, 0.30, 0.55) }
                GradientStop { position: 0.55; color: Qt.rgba(0.05, 0.04, 0.09, 0.4) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.8) }
            }
            PathRectangle { width: view.width; height: view.height }
        }
    }

    // ── the core behind the clock: HUD on, ~440 px, 0.72 ──
    NeuralCore {
        id: core
        objectName: "core"
        width: 440 * view.s * 1.25; height: width       // the core draws the sphere at 0.25 of its side; the HUD needs room
        anchors.horizontalCenter: parent.horizontalCenter
        y: view.height * 0.36 - height / 2
        opacity: 0.72
        hud: true
        pointCount: view.pointCount
        reducedMotion: view.reducedMotion
        mood: view.mood === "calm" && pw.text.length > 0 ? "listening" : view.mood
        energy: pw.text.length > 0 ? Math.min(0.6, 0.2 + pw.text.length * 0.04) : 0.08
    }

    Item {
        anchors.fill: parent
        opacity: view.contentOpacity

        // ── clock ──
        Column {
            id: clockCol
            anchors.horizontalCenter: parent.horizontalCenter
            y: core.y + core.height / 2 - clock.height * 0.62
            spacing: 0
            Text {
                id: clock
                anchors.horizontalCenter: parent.horizontalCenter
                color: view.cText
                font.family: view.uiFont; font.weight: Font.ExtraLight; font.pixelSize: 132 * view.s
                text: Qt.formatTime(new Date(view.nowMs), "HH:mm")
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                color: view.cSoft
                font.family: view.uiFont; font.pixelSize: 17 * view.s
                text: { const t = new Date(view.nowMs).toLocaleDateString(Qt.locale("es_ES"), "dddd, d 'de' MMMM"); return t.charAt(0).toUpperCase() + t.slice(1); }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 6 * view.s
                visible: view.mood !== "calm"
                color: view.mood === "alert" ? view.cAlert : (view.mood === "ok" ? view.cOk : view.cCyan)
                font.family: view.monoFont; font.pixelSize: 11 * view.s; font.letterSpacing: 3 * view.s
                font.capitalization: Font.AllUppercase
                text: view.stateText
                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }

        // ── satellites: the apps with unread notifications on the core's dotted orbit (rx 1.38 r, ry 0.34 r, −0.18 rad)
        Repeater {
            model: view.notifApps.slice(0, 3)
            delegate: Item {
                id: sat
                required property var modelData
                required property int index
                readonly property real r: core.radius
                readonly property real ang: [Math.PI, 0, Math.PI * 0.62][index]      // left, right, front-left
                readonly property real ex: Math.cos(ang) * r * 1.38
                readonly property real ey: Math.sin(ang) * r * 0.34
                width: 42 * view.s
                height: width
                x: core.x + core.width / 2 + ex * Math.cos(-0.18) - ey * Math.sin(-0.18) - width / 2
                y: core.y + core.height / 2 + ex * Math.sin(-0.18) + ey * Math.cos(-0.18) - height / 2
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: view.cGlass
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.16)
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.14) }
                        GradientStop { position: 0.5; color: Qt.rgba(13 / 255, 11 / 255, 22 / 255, 0.7) }
                    }
                }
                Image {
                    anchors.centerIn: parent
                    width: parent.width * 0.5; height: width
                    source: sat.modelData.icon || ""
                    sourceSize: Qt.size(64, 64)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }
                Rectangle {
                    visible: sat.modelData.count > 0
                    x: parent.width - width * 0.7
                    y: -height * 0.3
                    height: 18 * view.s
                    width: Math.max(height, badgeText.implicitWidth + 10 * view.s)
                    radius: height / 2
                    color: view.cBadge
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.25)
                    Text { id: badgeText; anchors.centerIn: parent; text: sat.modelData.count > 99 ? "99+" : `${sat.modelData.count}`; color: view.cText; font.family: view.monoFont; font.pixelSize: 10 * view.s; font.weight: Font.Bold }
                }
            }
        }

        // ── top left / top right ──
        Text {
            anchors { left: parent.left; top: parent.top; margins: 32 * view.s }
            text: "DRAGONOS · BLOQUEADO"
            color: view.cDim
            font.family: view.monoFont; font.pixelSize: 12 * view.s; font.letterSpacing: 3 * view.s
        }
        Row {
            anchors { right: parent.right; top: parent.top; margins: 28 * view.s }
            spacing: 10 * view.s
            LockTopIcon { glyph: "wifi"; scaleFactor: view.s; color: view.wifiOn ? view.cText : view.cDim }
            LockTopIcon { glyph: view.muted ? "mute" : "volume"; scaleFactor: view.s; color: view.muted ? view.cDim : view.cText }
            Text {
                visible: view.layoutLabel !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: view.layoutLabel
                color: view.cText
                font.family: view.monoFont; font.pixelSize: 12 * view.s
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { view.layoutClicked(); pw.forceActiveFocus() } }
            }
            Item { width: 8 * view.s; height: 1 }
            LockTopIcon { visible: view.canSuspend; glyph: "moon"; scaleFactor: view.s; color: view.cText; clickable: true; onActivated: view.suspendClicked() }
            LockTopIcon { glyph: "power"; scaleFactor: view.s; color: view.cAlert; clickable: true; onActivated: view.powerClicked() }
        }

        // ── user + password ──
        Column {
            id: auth
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.min(core.y + core.height * 0.86, view.height - height - 120 * view.s)
            spacing: 14 * view.s

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12 * view.s
                Item {
                    id: avatarBox
                    width: 44 * view.s; height: width
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {   // soft cyan ring
                        anchors.fill: parent; anchors.margins: -4 * view.s
                        radius: width / 2
                        color: "transparent"
                        border.width: 2 * view.s
                        border.color: Qt.rgba(0.40, 0.91, 0.98, 0.35)
                    }
                    Rectangle {
                        id: avatarDisc
                        anchors.fill: parent
                        radius: width / 2
                        color: Qt.rgba(0.17, 0.13, 0.27, 1)
                        clip: true
                        Image {
                            id: face
                            anchors.fill: parent
                            source: view.avatar
                            sourceSize: Qt.size(96, 96)
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready
                            layer.enabled: visible
                        }
                        Text {
                            visible: face.status !== Image.Ready
                            anchors.centerIn: parent
                            text: (view.realName || view.userName).split(/\s+/).filter(w => w.length > 0).slice(0, 2).map(w => w.charAt(0).toUpperCase()).join("")
                            color: view.cText; font.family: view.uiFont; font.pixelSize: 16 * view.s; font.weight: Font.DemiBold
                        }
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text { text: view.realName || view.userName; color: view.cText; font.family: view.uiFont; font.pixelSize: 18 * view.s; font.weight: Font.DemiBold }
                    Text {
                        text: `${view.userName} · bloqueado ${view.lockedMinutes < 1 ? "ahora" : "hace " + view.lockedMinutes + " min"}`
                        color: view.cDim; font.family: view.monoFont; font.pixelSize: 11 * view.s
                    }
                }
            }

            Rectangle {
                id: field
                anchors.horizontalCenter: parent.horizontalCenter
                width: 340 * view.s; height: 46 * view.s
                radius: height / 2
                color: view.cGlass
                border.width: 1
                border.color: view.mood === "alert" ? Qt.rgba(0.93, 0.15, 0.31, 0.75)
                            : pw.activeFocus ? Qt.rgba(0.78, 0.71, 0.90, 0.45) : view.cLine
                Behavior on border.color { ColorAnimation { duration: 250 } }
                transform: Translate { id: shakeT }

                CoreIcon {
                    id: lockGlyph
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 18 * view.s }
                    name: "lock"; size: 14 * view.s; color: view.cDim
                }
                TextInput {
                    id: pw
                    objectName: "pw"
                    anchors { left: lockGlyph.right; right: go.left; verticalCenter: parent.verticalCenter; leftMargin: 12 * view.s; rightMargin: 8 * view.s }
                    color: view.cText
                    font.family: view.monoFont; font.pixelSize: 15 * view.s; font.letterSpacing: 2.5 * view.s
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    passwordMaskDelay: 0
                    clip: true
                    focus: true
                    readOnly: view.busy
                    selectionColor: view.cBadge
                    onTextEdited: { core.pulse(); view.typed(text) }
                    onAccepted: if (!view.busy && text.length > 0) view.submitted(text)
                    Keys.onEscapePressed: { text = ""; view.typed("") }
                    Text {
                        visible: !parent.text
                        text: "Contraseña"
                        color: view.cDim; font.family: view.uiFont; font.pixelSize: 15 * view.s
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                Rectangle {
                    id: go
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 6 * view.s }
                    width: 34 * view.s; height: width; radius: width / 2
                    color: goMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.09)
                    opacity: view.busy ? 0.5 : 1
                    CoreIcon { anchors.centerIn: parent; name: "arrow"; size: 15 * view.s; stroke: 2.2; color: view.cText }
                    MouseArea { id: goMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pw.accepted() }
                }
            }
            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: shakeT; property: "x"; to: -8; duration: 60 }
                NumberAnimation { target: shakeT; property: "x"; to: 7; duration: 70 }
                NumberAnimation { target: shakeT; property: "x"; to: -5; duration: 70 }
                NumberAnimation { target: shakeT; property: "x"; to: 3; duration: 70 }
                NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 60 }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 440 * view.s
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: view.hint !== "" ? view.hint : `Enter para desbloquear · Bloq Mayús ${view.capsLock ? "activado" : "desactivado"}`
                color: view.hintError ? view.cAlert : (view.capsLock && view.hint === "" ? view.cWarn : view.cSoft)
                font.family: view.uiFont; font.pixelSize: 13 * view.s
            }
        }

        // ── mini player, bottom left ──
        Rectangle {
            visible: view.hasMedia
            anchors { left: parent.left; bottom: parent.bottom; margins: 32 * view.s }
            width: 320 * view.s; height: 74 * view.s
            radius: 16 * view.s
            color: view.cGlass
            border.color: view.cLine
            Rectangle {
                id: art
                x: 14 * view.s; anchors.verticalCenter: parent.verticalCenter
                width: 46 * view.s; height: width; radius: 10 * view.s
                color: Qt.rgba(1, 1, 1, 0.08)
                clip: true
                Image { anchors.fill: parent; source: view.mediaArt; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(96, 96); visible: status === Image.Ready }
                CoreIcon { visible: view.mediaArt === ""; anchors.centerIn: parent; name: "music"; size: 18 * view.s; color: view.cDim }
            }
            Column {
                anchors { left: art.right; leftMargin: 12 * view.s; right: playBtn.left; rightMargin: 12 * view.s; verticalCenter: parent.verticalCenter }
                spacing: 8 * view.s
                Text { width: parent.width; elide: Text.ElideRight; text: view.mediaTitle; color: view.cText; font.family: view.uiFont; font.pixelSize: 14 * view.s; font.weight: Font.DemiBold }
                Rectangle {
                    width: parent.width; height: 3 * view.s; radius: height / 2
                    color: Qt.rgba(1, 1, 1, 0.15)
                    Rectangle { width: parent.width * Math.max(0, Math.min(1, view.mediaProgress)); height: parent.height; radius: height / 2; color: view.cText }
                }
            }
            Rectangle {
                id: playBtn
                anchors { right: parent.right; rightMargin: 14 * view.s; verticalCenter: parent.verticalCenter }
                width: 34 * view.s; height: width; radius: width / 2
                color: Qt.rgba(1, 1, 1, 0.10)
                CoreIcon { anchors.centerIn: parent; name: view.mediaPlaying ? "pause" : "play"; size: 14 * view.s; stroke: 2; color: view.cText }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: view.mediaToggle() }
            }
        }

        // ── counts, bottom right ──
        Text {
            anchors { right: parent.right; bottom: parent.bottom; margins: 36 * view.s }
            visible: text.length > 0
            text: [view.notifCount > 0 ? `${view.notifCount} ${view.notifCount === 1 ? "MENSAJE" : "MENSAJES"}` : "",
                   view.captures > 0 ? `${view.captures} ${view.captures === 1 ? "CAPTURA" : "CAPTURAS"}` : "",
                   view.batteryPct >= 0 ? `BATERÍA ${Math.round(view.batteryPct)} %` : ""].filter(t => t.length > 0).join("  ·  ")
            color: view.cDim
            font.family: view.monoFont; font.pixelSize: 12 * view.s; font.letterSpacing: 2 * view.s
        }
    }
}
