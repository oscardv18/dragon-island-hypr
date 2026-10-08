// dragon-core — SDDM greeter theme for dragon-island (Qt 6)
// Uses only the SDDM greeter API: sddm, userModel, sessionModel, keyboard, config.

import QtQuick
import QtQuick.Shapes
import "components"

Rectangle {
    id: root
    width: 1366
    height: 768
    color: "#05060c"

    // ── theme tokens ────────────────────────────────────────────────
    readonly property color cVoid: "#05060c"
    readonly property color cText: "#e6e8ef"
    readonly property color cDim: "#8a8fa3"
    readonly property color cLine: Qt.rgba(1, 1, 1, 0.10)
    readonly property color cSurface: Qt.rgba(0.086, 0.098, 0.145, 0.62)
    readonly property color cMagenta: "#c50ed2"
    readonly property color cViolet: "#7c3aed"
    readonly property color cCyan: "#00c1e4"
    readonly property color cOk: "#06c993"
    readonly property color cAlert: "#ed254e"
    readonly property real s: Math.max(0.8, Math.min(1.6, height / 900))   // UI scale

    function cfg(key, def) {
        const v = config[key]
        return (v === undefined || v === null || v === "") ? def : v
    }
    readonly property string uiFont: fUi.status === FontLoader.Ready ? fUi.font.family : cfg("fontUi", "sans-serif")
    readonly property string monoFont: fMono.status === FontLoader.Ready ? fMono.font.family : cfg("fontMono", "monospace")
    FontLoader { id: fUi; source: "fonts/Outfit.ttf" }
    FontLoader { id: fMono; source: "fonts/JetBrainsMono.ttf" }

    // ── state ───────────────────────────────────────────────────────
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property bool busy: false
    property string stateText: "en espera"
    readonly property string currentUser: users.currentItem ? users.currentItem.uname : manualUser.text
    readonly property bool hasLayouts: keyboard && keyboard.layouts && keyboard.layouts.length > 0
    readonly property string layoutLabel: hasLayouts && keyboard.layouts[keyboard.currentLayout]
        ? keyboard.layouts[keyboard.currentLayout].shortName.toUpperCase() : ""

    Component.onCompleted: {
        // always start on the primary layout (us) so the password is typed the way it was set
        const idx = parseInt(cfg("defaultLayoutIndex", "0"))
        if (hasLayouts && idx < keyboard.layouts.length) keyboard.currentLayout = idx
        pw.forceActiveFocus()
    }

    function doLogin() {
        if (busy || currentUser === "") return
        busy = true
        core.mood = "verifying"
        stateText = "verificando"
        hint.err = false
        hint.text = ""
        sddm.login(currentUser, pw.text, sessionIndex)
    }

    Connections {
        target: sddm
        function onLoginSucceeded() {
            core.mood = "ok"
            root.stateText = "acceso concedido"
        }
        function onLoginFailed() {
            root.busy = false
            core.mood = "alert"
            root.stateText = "acceso denegado"
            pw.text = ""
            hint.err = true
            hint.text = "Contraseña incorrecta." + (root.layoutLabel ? " Revisa la distribución de teclado (" + root.layoutLabel + ")." : "")
                + (keyboard.capsLock ? " Bloq Mayús está activo." : "")
            shake.restart()
            calmTimer.restart()
            pw.forceActiveFocus()
        }
        function onInformationMessage(message) {
            hint.err = false
            hint.text = message
        }
    }
    Timer {
        id: calmTimer; interval: 1400
        onTriggered: { core.mood = "calm"; root.stateText = "en espera" }
    }

    // hidden user list (gives us name / realName / icon of the selected user)
    ListView {
        id: users
        // must stay "visible" with a real size, otherwise ListView instantiates no delegate
        width: 1; height: 1; opacity: 0; enabled: false; interactive: false
        model: userModel
        currentIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
        delegate: Item {
            width: 1; height: 1
            required property string name
            required property string realName
            required property string icon
            readonly property string uname: name
            readonly property string displayName: realName !== "" ? realName : name
            readonly property string avatar: icon
        }
    }

    // ── background ──────────────────────────────────────────────────
    Image {
        anchors.fill: parent
        source: root.cfg("background", "")
        visible: source !== "" && status === Image.Ready
        fillMode: Image.PreserveAspectCrop
        opacity: parseFloat(root.cfg("backgroundOpacity", "0.22"))
        asynchronous: true
    }
    Shape {   // vignette
        anchors.fill: parent
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: root.width / 2; centerY: root.height * 0.4
                focalX: centerX; focalY: centerY
                centerRadius: Math.max(root.width, root.height) * 0.75
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.75) }
            }
            PathRectangle { width: root.width; height: root.height }
        }
    }

    // ── the core ────────────────────────────────────────────────────
    NeuralCore {
        id: core
        objectName: "core"
        width: root.height * 0.72; height: width
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.38 - height / 2
        pointCount: parseInt(root.cfg("pointCount", "240"))
        reducedMotion: root.cfg("reducedMotion", "false") === "true"
        energy: pw.text.length > 0 ? Math.min(0.75, 0.25 + pw.text.length * 0.05) : 0.12
    }

    // clock inside the core
    Shape {   // dark lens behind the clock: keeps it legible over the nodes (no shader effects needed)
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
        anchors.centerIn: core
        spacing: 2 * root.s
        Text {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.cText
            font.family: root.monoFont
            font.weight: Font.Light
            font.pixelSize: 64 * root.s
            text: Qt.formatTime(new Date(), "HH:mm")
            style: Text.Normal
        }
        Text {
            id: dateText
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.cDim
            font.family: root.uiFont
            font.pixelSize: 13 * root.s
            font.letterSpacing: 2.2 * root.s
            font.capitalization: Font.AllUppercase
            text: new Date().toLocaleDateString(Qt.locale(root.cfg("locale", "es_VE")), "dddd d 'de' MMMM")
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: 8 * root.s
            color: core.mood === "alert" ? root.cAlert : (core.mood === "ok" ? root.cOk : root.cCyan)
            font.family: root.monoFont
            font.pixelSize: 11 * root.s
            font.letterSpacing: 3 * root.s
            font.capitalization: Font.AllUppercase
            text: root.stateText
            Behavior on color { ColorAnimation { duration: 300 } }
        }
    }
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            const d = new Date()
            clock.text = Qt.formatTime(d, "HH:mm")
            dateText.text = d.toLocaleDateString(Qt.locale(root.cfg("locale", "es_VE")), "dddd d 'de' MMMM")
        }
    }

    // ── HUD (top) ───────────────────────────────────────────────────
    component Chip: Rectangle {
        id: chip
        property alias label: chipText.text
        property color dot: "transparent"
        height: 26 * root.s
        width: chipRow.implicitWidth + 22 * root.s
        radius: height / 2
        color: root.cSurface
        border.color: root.cLine
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 7 * root.s
            Rectangle {
                visible: chip.dot !== Qt.color("transparent")
                width: 7 * root.s; height: width; radius: width / 2
                color: chip.dot
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                id: chipText
                color: root.cText
                font.family: root.monoFont
                font.pixelSize: 11 * root.s
                font.letterSpacing: 1 * root.s
                font.capitalization: Font.AllUppercase
                textFormat: Text.StyledText
            }
        }
    }

    Row {
        anchors { left: parent.left; top: parent.top; margins: 24 * root.s }
        spacing: 12 * root.s
        Chip { label: "Núcleo <b>en línea</b>"; dot: root.cOk }
        Chip { label: "Host <b>" + sddm.hostName + "</b>" }
    }
    Row {
        anchors { right: parent.right; top: parent.top; margins: 24 * root.s }
        spacing: 12 * root.s
        Chip { visible: keyboard.capsLock; label: "<b>Bloq Mayús</b>"; dot: root.cAlert }
        Chip { visible: root.layoutLabel !== ""; label: "Teclado <b>" + root.layoutLabel + "</b>" }
    }

    // ── auth block ──────────────────────────────────────────────────
    Column {
        id: auth
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.min(core.y + core.height * 0.92, root.height - height - 90 * root.s)
        spacing: 12 * root.s

        // who
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12 * root.s
            Item {
                id: avatar
                width: 46 * root.s; height: width
                anchors.verticalCenter: parent.verticalCenter
                Shape {
                    anchors.fill: parent
                    ShapePath {
                        strokeColor: Qt.rgba(1, 1, 1, 0.15); strokeWidth: 1
                        fillGradient: ConicalGradient {
                            centerX: avatar.width / 2; centerY: avatar.height / 2; angle: 200
                            GradientStop { position: 0.0; color: root.cMagenta }
                            GradientStop { position: 0.35; color: root.cViolet }
                            GradientStop { position: 0.7; color: root.cCyan }
                            GradientStop { position: 1.0; color: root.cMagenta }
                        }
                        PathAngleArc { centerX: avatar.width / 2; centerY: avatar.height / 2; radiusX: avatar.width / 2 - 1; radiusY: radiusX; sweepAngle: 360 }
                    }
                }
                Text {
                    anchors.centerIn: parent
                    visible: !face.visible
                    text: root.currentUser.charAt(0).toUpperCase()
                    color: "white"; font.family: root.uiFont; font.pixelSize: 20 * root.s; font.weight: Font.Bold
                }
                Canvas {   // round avatar drawn with a clip path (works on every scene-graph backend)
                    id: face
                    anchors.fill: parent
                    property string src: users.currentItem && users.currentItem.avatar ? "file://" + users.currentItem.avatar.replace(/^file:\/\//, "") : ""
                    property bool ready: false
                    visible: ready
                    onSrcChanged: { ready = false; if (src !== "") loadImage(src) }
                    Component.onCompleted: if (src !== "") loadImage(src)
                    onImageLoaded: { ready = isImageLoaded(src); requestPaint() }
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        if (!ready) return
                        ctx.beginPath()
                        ctx.arc(width / 2, height / 2, width / 2 - 2, 0, Math.PI * 2)
                        ctx.closePath()
                        ctx.clip()
                        ctx.drawImage(src, 0, 0, width, height)
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: userModel.count > 1
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: users.currentIndex = (users.currentIndex + 1) % userModel.count
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    visible: userModel.count > 0
                    text: users.currentItem ? users.currentItem.displayName : ""
                    color: root.cText; font.family: root.uiFont; font.pixelSize: 18 * root.s; font.weight: Font.Medium
                }
                TextInput {   // only when SDDM lists no users
                    id: manualUser
                    visible: userModel.count === 0
                    width: 180 * root.s
                    color: root.cText; font.family: root.uiFont; font.pixelSize: 18 * root.s
                    KeyNavigation.tab: pw
                    Text { visible: !parent.text; text: "Usuario"; color: root.cDim; font: parent.font }
                }
                Text {
                    text: sessionList.currentName + " · " + sddm.hostName
                    color: root.cDim; font.family: root.monoFont; font.pixelSize: 12 * root.s
                }
            }
        }

        // password field
        Rectangle {
            id: field
            anchors.horizontalCenter: parent.horizontalCenter
            width: 360 * root.s; height: 48 * root.s
            radius: height / 2
            color: root.cSurface
            border.width: 1
            border.color: core.mood === "alert" ? Qt.rgba(0.93, 0.15, 0.31, 0.75)
                        : pw.activeFocus ? Qt.rgba(0, 0.76, 0.89, 0.55) : root.cLine
            Behavior on border.color { ColorAnimation { duration: 250 } }
            transform: Translate { id: shakeT }

            Rectangle {   // focus halo
                anchors.fill: parent; anchors.margins: -4
                radius: height / 2
                color: "transparent"
                border.width: 4
                border.color: core.mood === "alert" ? Qt.rgba(0.93, 0.15, 0.31, 0.16) : Qt.rgba(0, 0.76, 0.89, 0.12)
                visible: pw.activeFocus || core.mood === "alert"
            }

            TextInput {
                id: pw
                objectName: "pw"
                anchors { left: parent.left; right: layoutTag.left; verticalCenter: parent.verticalCenter; leftMargin: 18 * root.s; rightMargin: 8 * root.s }
                color: root.cText
                font.family: root.monoFont
                font.pixelSize: 15 * root.s
                font.letterSpacing: 2.5 * root.s
                echoMode: TextInput.Password
                passwordCharacter: "•"
                passwordMaskDelay: 0
                clip: true
                focus: true
                enabled: !root.busy
                selectionColor: root.cViolet
                onTextEdited: { core.pulse(); if (core.mood === "alert") { core.mood = "calm"; root.stateText = "en espera" } }
                onAccepted: root.doLogin()
                onTextChanged: if (core.mood === "calm" || core.mood === "verifying") root.stateText = text.length ? "escribiendo" : "en espera"
                Keys.onEscapePressed: text = ""
                Text {
                    visible: !parent.text
                    text: "Contraseña"
                    color: root.cDim
                    font.family: root.uiFont
                    font.pixelSize: 15 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Rectangle {
                id: layoutTag
                visible: root.layoutLabel !== ""
                anchors { right: go.left; verticalCenter: parent.verticalCenter; rightMargin: 8 * root.s }
                width: visible ? layoutText.implicitWidth + 14 * root.s : 0
                height: 22 * root.s; radius: 8 * root.s
                color: "transparent"; border.color: root.cLine
                Text { id: layoutText; anchors.centerIn: parent; text: root.layoutLabel; color: root.cDim; font.family: root.monoFont; font.pixelSize: 11 * root.s }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length; pw.forceActiveFocus() }
                }
            }
            Rectangle {
                id: go
                anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 6 * root.s }
                width: 36 * root.s; height: width; radius: width / 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: root.cMagenta }
                    GradientStop { position: 1; color: root.cViolet }
                }
                opacity: root.busy ? 0.5 : 1
                CoreIcon { anchors.centerIn: parent; name: "arrow"; size: 16 * root.s; stroke: 2.4; color: "white" }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.doLogin() }
            }
        }
        SequentialAnimation {
            id: shake
            NumberAnimation { target: shakeT; property: "x"; to: -8; duration: 60 }
            NumberAnimation { target: shakeT; property: "x"; to: 7; duration: 70 }
            NumberAnimation { target: shakeT; property: "x"; to: -5; duration: 70 }
            NumberAnimation { target: shakeT; property: "x"; to: 3; duration: 70 }
            NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 60 }
        }

        Text {
            id: hint
            property bool err: false
            anchors.horizontalCenter: parent.horizontalCenter
            width: 420 * root.s
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: keyboard.capsLock ? "Bloq Mayús está activo." : ""
            color: err ? root.cAlert : root.cDim
            font.family: root.uiFont; font.pixelSize: 12 * root.s
            height: Math.max(implicitHeight, 16 * root.s)
        }

        // sessions
        ListView {
            id: sessionList
            property string currentName: currentItem ? currentItem.sname : ""
            anchors.horizontalCenter: parent.horizontalCenter
            orientation: ListView.Horizontal
            spacing: 8 * root.s
            interactive: false
            width: Math.min(contentWidth, root.width - 48)
            height: 30 * root.s
            model: sessionModel
            currentIndex: root.sessionIndex
            delegate: Rectangle {
                id: pill
                required property int index
                required property string name
                readonly property string sname: name
                readonly property bool active: index === root.sessionIndex
                height: 30 * root.s
                width: pillText.implicitWidth + 28 * root.s
                radius: height / 2
                color: active ? Qt.rgba(0.77, 0.05, 0.82, 0.16) : root.cSurface
                border.color: active ? Qt.rgba(0.77, 0.05, 0.82, 0.55) : root.cLine
                Text {
                    id: pillText
                    anchors.centerIn: parent
                    text: pill.name
                    color: pill.active ? root.cText : root.cDim
                    font.family: root.uiFont; font.pixelSize: 13 * root.s
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { root.sessionIndex = pill.index; pw.forceActiveFocus() }
                }
            }
        }
    }

    // ── footer ──────────────────────────────────────────────────────
    Text {
        anchors { left: parent.left; bottom: parent.bottom; margins: 24 * root.s }
        text: "dragon-island · núcleo neural"
        color: Qt.rgba(0.54, 0.56, 0.64, 0.6)
        font.family: root.monoFont; font.pixelSize: 11 * root.s; font.letterSpacing: 1.5 * root.s
        font.capitalization: Font.AllUppercase
    }

    component PowerButton: Rectangle {
        id: pb
        property string glyph
        property bool danger: false
        signal activated()
        width: 42 * root.s; height: width; radius: width / 2
        color: hover.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : root.cSurface
        border.color: root.cLine
        CoreIcon { anchors.centerIn: parent; name: pb.glyph; size: 17 * root.s; color: pb.danger ? "#ff6b88" : root.cText }
        MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pb.activated() }
    }
    Row {
        anchors { right: parent.right; bottom: parent.bottom; margins: 24 * root.s }
        spacing: 8 * root.s
        PowerButton { visible: sddm.canSuspend; glyph: "moon"; onActivated: sddm.suspend() }
        PowerButton { visible: sddm.canReboot; glyph: "restart"; onActivated: sddm.reboot() }
        PowerButton { visible: sddm.canPowerOff; glyph: "power"; danger: true; onActivated: sddm.powerOff() }
    }
}
