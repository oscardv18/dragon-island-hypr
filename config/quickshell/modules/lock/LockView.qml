// LockView.qml — visual layer of the dragon-island lock screen (pure QtQuick, no Quickshell imports,
// so it can be rendered/tested outside Quickshell). Lock.qml / LockSurface.qml feed it data.
//
// In:   mood, stateText, hint, hintError, busy, layoutLabel, capsLock, userName, hostName,
//       hasMedia, mediaTitle, mediaArtist, mediaPlaying, notifCount, batteryPct (-1 = no battery),
//       canSuspend, uiFont, monoFont
// Out:  submitted(password), layoutClicked(), mediaPrev(), mediaToggle(), mediaNext(),
//       suspendClicked(), powerClicked(), typed(text)
// Fns:  shake(), clear(), focusInput(), setText(t)

import QtQuick
import QtQuick.Shapes
import "../../components"

Rectangle {
    id: view
    color: "#05060c"

    property string mood: "calm"
    property string stateText: "bloqueado"
    property string hint: ""
    property bool hintError: false
    property bool busy: false
    property string layoutLabel: ""
    property bool capsLock: false
    property string userName: ""
    property string hostName: ""
    property bool hasMedia: false
    property string mediaTitle: ""
    property string mediaArtist: ""
    property bool mediaPlaying: false
    property int notifCount: 0
    property real batteryPct: -1
    property bool canSuspend: true
    property bool reducedMotion: false
    property int pointCount: 240
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

    readonly property color cText: "#e6e8ef"
    readonly property color cDim: "#8a8fa3"
    readonly property color cLine: Qt.rgba(1, 1, 1, 0.10)
    readonly property color cSurface: Qt.rgba(0.086, 0.098, 0.145, 0.62)
    readonly property color cMagenta: "#c50ed2"
    readonly property color cViolet: "#7c3aed"
    readonly property color cCyan: "#00c1e4"
    readonly property color cOk: "#06c993"
    readonly property color cAlert: "#ed254e"
    readonly property real s: Math.max(0.8, Math.min(1.6, height / 900))

    Shape {   // vignette
        anchors.fill: parent
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: view.width / 2; centerY: view.height * 0.4
                focalX: centerX; focalY: centerY
                centerRadius: Math.max(view.width, view.height) * 0.75
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.75) }
            }
            PathRectangle { width: view.width; height: view.height }
        }
    }

    NeuralCore {
        id: core
        objectName: "core"
        width: view.height * 0.72; height: width
        anchors.horizontalCenter: parent.horizontalCenter
        y: view.height * 0.38 - height / 2
        mood: view.mood
        pointCount: view.pointCount
        reducedMotion: view.reducedMotion
        energy: pw.text.length > 0 ? Math.min(0.75, 0.25 + pw.text.length * 0.05) : 0.1
    }

    Item {
        anchors.fill: parent
        opacity: view.contentOpacity

        // ── clock inside the core ──
        Shape {
            id: lens
            width: Math.max(clockCol.width, 1) * 1.5; height: clockCol.height * 1.9
            anchors.centerIn: clockCol
            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: lens.width / 2; centerY: lens.height / 2
                    focalX: centerX; focalY: centerY
                    centerRadius: lens.width / 2
                    GradientStop { position: 0.0; color: Qt.rgba(0.02, 0.024, 0.047, 0.62) }
                    GradientStop { position: 0.6; color: Qt.rgba(0.02, 0.024, 0.047, 0.35) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
                PathRectangle { width: lens.width; height: lens.height }
            }
        }
        Column {
            id: clockCol
            // content layer fills the view, so core's coordinates are valid here
            x: core.x + (core.width - width) / 2
            y: core.y + (core.height - height) / 2
            spacing: 2 * view.s
            Text {
                id: clock
                anchors.horizontalCenter: parent.horizontalCenter
                color: view.cText
                font.family: view.monoFont; font.weight: Font.Light; font.pixelSize: 64 * view.s
                text: Qt.formatTime(new Date(), "HH:mm")
            }
            Text {
                id: dateText
                anchors.horizontalCenter: parent.horizontalCenter
                color: view.cDim
                font.family: view.uiFont; font.pixelSize: 13 * view.s; font.letterSpacing: 2.2 * view.s
                font.capitalization: Font.AllUppercase
                text: new Date().toLocaleDateString(Qt.locale("es_VE"), "dddd d 'de' MMMM")
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 8 * view.s
                color: view.mood === "alert" ? view.cAlert : (view.mood === "ok" ? view.cOk : view.cCyan)
                font.family: view.monoFont; font.pixelSize: 11 * view.s; font.letterSpacing: 3 * view.s
                font.capitalization: Font.AllUppercase
                text: view.stateText
                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }
        Timer {
            interval: 1000; running: true; repeat: true
            onTriggered: {
                const d = new Date()
                clock.text = Qt.formatTime(d, "HH:mm")
                dateText.text = d.toLocaleDateString(Qt.locale("es_VE"), "dddd d 'de' MMMM")
            }
        }

        // ── HUD ──
        component Chip: Rectangle {
            id: chip
            property alias label: chipText.text
            property color dot: "transparent"
            height: 26 * view.s
            width: chipRow.implicitWidth + 22 * view.s
            radius: height / 2
            color: view.cSurface
            border.color: view.cLine
            Row {
                id: chipRow
                anchors.centerIn: parent
                spacing: 7 * view.s
                Rectangle {
                    visible: chip.dot !== Qt.color("transparent")
                    width: 7 * view.s; height: width; radius: width / 2
                    color: chip.dot
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    id: chipText
                    color: view.cText
                    font.family: view.monoFont; font.pixelSize: 11 * view.s; font.letterSpacing: 1 * view.s
                    font.capitalization: Font.AllUppercase
                    textFormat: Text.StyledText
                }
            }
        }
        Row {
            anchors { left: parent.left; top: parent.top; margins: 24 * view.s }
            spacing: 12 * view.s
            Chip { label: "Sesión <b>bloqueada</b>"; dot: view.cMagenta }
            Chip { label: "Host <b>" + view.hostName + "</b>" }
        }
        Row {
            anchors { right: parent.right; top: parent.top; margins: 24 * view.s }
            spacing: 12 * view.s
            Chip { visible: view.capsLock; label: "<b>Bloq Mayús</b>"; dot: view.cAlert }
            Chip { visible: view.notifCount > 0; label: "Notificaciones <b>" + view.notifCount + "</b>"; dot: view.cMagenta }
            Chip { visible: view.batteryPct >= 0; label: "Batería <b>" + Math.round(view.batteryPct) + "%</b>"; dot: view.batteryPct < 20 ? view.cAlert : view.cOk }
        }

        // ── auth ──
        Column {
            id: auth
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.min(core.y + core.height * 0.92, view.height - height - 90 * view.s)
            spacing: 12 * view.s

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12 * view.s
                Item {
                    id: avatar
                    width: 46 * view.s; height: width
                    anchors.verticalCenter: parent.verticalCenter
                    Shape {
                        anchors.fill: parent
                        ShapePath {
                            strokeColor: Qt.rgba(1, 1, 1, 0.15); strokeWidth: 1
                            fillGradient: ConicalGradient {
                                centerX: avatar.width / 2; centerY: avatar.height / 2; angle: 200
                                GradientStop { position: 0.0; color: view.cMagenta }
                                GradientStop { position: 0.35; color: view.cViolet }
                                GradientStop { position: 0.7; color: view.cCyan }
                                GradientStop { position: 1.0; color: view.cMagenta }
                            }
                            PathAngleArc { centerX: avatar.width / 2; centerY: avatar.height / 2; radiusX: avatar.width / 2 - 1; radiusY: radiusX; sweepAngle: 360 }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: view.userName.charAt(0).toUpperCase()
                        color: "white"; font.family: view.uiFont; font.pixelSize: 20 * view.s; font.weight: Font.Bold
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: view.userName; color: view.cText; font.family: view.uiFont; font.pixelSize: 18 * view.s; font.weight: Font.Medium }
                    Text { text: "Hyprland · " + view.hostName; color: view.cDim; font.family: view.monoFont; font.pixelSize: 12 * view.s }
                }
            }

            Rectangle {
                id: field
                anchors.horizontalCenter: parent.horizontalCenter
                width: 360 * view.s; height: 48 * view.s
                radius: height / 2
                color: view.cSurface
                border.width: 1
                border.color: view.mood === "alert" ? Qt.rgba(0.93, 0.15, 0.31, 0.75)
                            : pw.activeFocus ? Qt.rgba(0, 0.76, 0.89, 0.55) : view.cLine
                Behavior on border.color { ColorAnimation { duration: 250 } }
                transform: Translate { id: shakeT }

                Rectangle {
                    anchors.fill: parent; anchors.margins: -4
                    radius: height / 2
                    color: "transparent"; border.width: 4
                    border.color: view.mood === "alert" ? Qt.rgba(0.93, 0.15, 0.31, 0.16) : Qt.rgba(0, 0.76, 0.89, 0.12)
                    visible: pw.activeFocus || view.mood === "alert"
                }
                TextInput {
                    id: pw
                    objectName: "pw"
                    anchors { left: parent.left; right: layoutTag.left; verticalCenter: parent.verticalCenter; leftMargin: 18 * view.s; rightMargin: 8 * view.s }
                    color: view.cText
                    font.family: view.monoFont; font.pixelSize: 15 * view.s; font.letterSpacing: 2.5 * view.s
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    passwordMaskDelay: 0
                    clip: true
                    focus: true
                    readOnly: view.busy
                    selectionColor: view.cViolet
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
                    id: layoutTag
                    visible: view.layoutLabel !== ""
                    anchors { right: go.left; verticalCenter: parent.verticalCenter; rightMargin: 8 * view.s }
                    width: visible ? layoutText.implicitWidth + 14 * view.s : 0
                    height: 22 * view.s; radius: 8 * view.s
                    color: "transparent"; border.color: view.cLine
                    Text { id: layoutText; anchors.centerIn: parent; text: view.layoutLabel; color: view.cDim; font.family: view.monoFont; font.pixelSize: 11 * view.s }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { view.layoutClicked(); pw.forceActiveFocus() } }
                }
                Rectangle {
                    id: go
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 6 * view.s }
                    width: 36 * view.s; height: width; radius: width / 2
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: view.cMagenta }
                        GradientStop { position: 1; color: view.cViolet }
                    }
                    opacity: view.busy ? 0.5 : 1
                    CoreIcon { anchors.centerIn: parent; name: "arrow"; size: 16 * view.s; stroke: 2.4; color: "white" }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pw.accepted() }
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
                width: 420 * view.s
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: view.hint !== "" ? view.hint : (view.capsLock ? "Bloq Mayús está activo." : "")
                color: view.hintError ? view.cAlert : view.cDim
                font.family: view.uiFont; font.pixelSize: 12 * view.s
                height: Math.max(implicitHeight, 16 * view.s)
            }

            // now playing
            Rectangle {
                visible: view.hasMedia
                anchors.horizontalCenter: parent.horizontalCenter
                height: 40 * view.s
                width: mediaRow.implicitWidth + 24 * view.s
                radius: height / 2
                color: view.cSurface; border.color: view.cLine
                Row {
                    id: mediaRow
                    anchors.centerIn: parent
                    spacing: 10 * view.s
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, 260 * view.s); elide: Text.ElideRight
                        text: view.mediaTitle + (view.mediaArtist ? "  ·  " + view.mediaArtist : "")
                        color: view.cText; font.family: view.uiFont; font.pixelSize: 13 * view.s
                    }
                    Repeater {
                        model: [["prev", 0], [view.mediaPlaying ? "pause" : "play", 1], ["next", 2]]
                        delegate: Item {
                            required property var modelData
                            width: 26 * view.s; height: width
                            anchors.verticalCenter: parent.verticalCenter
                            CoreIcon { anchors.centerIn: parent; name: modelData[0]; size: 14 * view.s; stroke: 2; color: view.cText }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: modelData[1] === 0 ? view.mediaPrev() : (modelData[1] === 1 ? view.mediaToggle() : view.mediaNext())
                            }
                        }
                    }
                }
            }
        }

        Text {
            anchors { left: parent.left; bottom: parent.bottom; margins: 24 * view.s }
            text: "dragon-island · núcleo neural"
            color: Qt.rgba(0.54, 0.56, 0.64, 0.6)
            font.family: view.monoFont; font.pixelSize: 11 * view.s; font.letterSpacing: 1.5 * view.s
            font.capitalization: Font.AllUppercase
        }
        component PowerButton: Rectangle {
            id: pb
            property string glyph
            property bool danger: false
            signal activated()
            width: 42 * view.s; height: width; radius: width / 2
            color: hover.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : view.cSurface
            border.color: view.cLine
            CoreIcon { anchors.centerIn: parent; name: pb.glyph; size: 17 * view.s; color: pb.danger ? "#ff6b88" : view.cText }
            MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pb.activated() }
        }
        Row {
            anchors { right: parent.right; bottom: parent.bottom; margins: 24 * view.s }
            spacing: 8 * view.s
            PowerButton { visible: view.canSuspend; glyph: "moon"; onActivated: view.suspendClicked() }
            PowerButton { glyph: "power"; danger: true; onActivated: view.powerClicked() }
        }
    }
}
