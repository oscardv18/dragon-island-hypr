// dragon-core — SDDM greeter theme for dragon-island (Qt 6) · docs/design/07-login.png
// Uses only the SDDM greeter API: sddm, userModel, sessionModel, keyboard, config.
//
//   background   theme.conf `background` (default background.jpg; bin/dragon-sddm-sync copies the user's wallpaper here,
//                1920×1080 and sharp, by hand with sudo), blurred ONCE here (MultiEffect, moderate radius, colours
//                untouched), a veil darker towards the edges and a fine noise tile (noise.png, theme.conf `noise`) on top
//                that dithers the 8-bit banding a blurred dark gradient makes
//   accent       accent.conf in this folder ([General] accent / accentSoft / glow, written by dragon-sddm-sync from
//                the wallpaper palette); missing or invalid = the fixed Dragon lavender
//   centre       greeting by the hour, the shared neural core (components/NeuralCore.qml, from shared/neural-core) with
//                its HUD: calm at rest, listening while typing, verifying after Enter, alert on a wrong password;
//                the avatar (photo or initials) in its middle, name and login under it
//   orbit        the other users as satellites on the ellipse around the core, plus «Otro usuario» (type a login)
//   below        password field, session pill (opens the list), hint line
//   corners      date · time (top right), keyboard layout (bottom left), suspend / reboot / power off (bottom right),
//                all with the glass look of the islands

import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import QtCore
import "components"

Rectangle {
    id: root
    width: 1366
    height: 768
    color: cInk

    // ── tokens (the new identity, Theme.qml: SDDM cannot import the shell) ──
    readonly property color cInk: "#07060d"
    readonly property color cText: "#edebf5"
    readonly property color cSoft: "#c8c4d8"
    readonly property color cDim: "#a29eb6"
    readonly property color cCyan: "#67e8f9"
    readonly property color cOk: "#86efac"
    readonly property color cAlert: "#ed254e"
    readonly property color cDanger: "#ff6b88"
    readonly property color cLine: Qt.rgba(1, 1, 1, 0.10)
    readonly property color cGlass: Qt.rgba(13 / 255, 11 / 255, 22 / 255, 0.62)
    readonly property color cGlassHi: Qt.rgba(1, 1, 1, 0.10)
    readonly property color cVeil: Qt.rgba(5 / 255, 4 / 255, 10 / 255, 1)
    readonly property real s: Math.max(0.8, Math.min(1.6, height / 768))   // UI scale

    // accent: accent.conf → Dragon
    function hex(v, def) { return typeof v === "string" && /^#[0-9a-fA-F]{6}$/.test(v) ? v : def }
    // read once with value() (declared properties would be written back to the file when the greeter closes);
    // QSettings reads an INI [General] section as the top level, hence the bare keys
    property color cAccent: "#c8b6e6"
    property color cAccentSoft: "#e896ec"
    property color cGlow: "#b26bff"
    Settings {
        id: accentFile
        location: Qt.resolvedUrl("accent.conf")
        Component.onCompleted: {
            root.cAccent = root.hex(value("accent", ""), root.cAccent)
            root.cAccentSoft = root.hex(value("accentSoft", ""), root.cAccentSoft)
            root.cGlow = root.hex(value("glow", ""), root.cGlow)
        }
    }

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
    property bool manual: userModel.count === 0      // «Otro usuario»: type the login
    readonly property string currentUser: manual ? manualUser.text : (users.currentItem ? users.currentItem.uname : "")
    readonly property string displayName: manual ? (manualUser.text || "Otro usuario") : (users.currentItem ? users.currentItem.displayName : "")
    readonly property bool hasLayouts: keyboard && keyboard.layouts && keyboard.layouts.length > 0
    readonly property string layoutLabel: hasLayouts && keyboard.layouts[keyboard.currentLayout]
        ? keyboard.layouts[keyboard.currentLayout].shortName.toUpperCase() : ""
    property date now: new Date()
    readonly property string greeting: {
        const h = now.getHours()
        return h >= 5 && h < 12 ? "Buenos días" : (h >= 12 && h < 19 ? "Buenas tardes" : "Buenas noches")
    }
    function initials(n) {
        const w = String(n).trim().split(/\s+/).filter(x => x.length > 0)
        if (w.length === 0) return "?"
        return (w.length > 1 ? w[0].charAt(0) + w[w.length - 1].charAt(0) : w[0].slice(0, 2)).toUpperCase()
    }

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
        hint.err = false
        hint.text = ""
        sddm.login(currentUser, pw.text, sessionIndex)
    }

    Connections {
        target: sddm
        function onLoginSucceeded() { core.mood = "ok" }
        function onLoginFailed() {
            core.mood = "alert"          // before busy: the typing Binding must not win
            root.busy = false
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
    Timer { id: calmTimer; interval: 1600; onTriggered: if (core.mood === "alert") core.mood = "calm" }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }

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

    // ── background: the wallpaper, blurred, under a dark veil ──
    Image {
        id: bg
        anchors.fill: parent
        source: root.cfg("background", "background.jpg")
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize: Qt.size(root.width, root.height)
        visible: false
    }
    MultiEffect {   // the only blur
        anchors.fill: parent
        source: bg
        visible: bg.status === Image.Ready
        blurEnabled: true
        blur: 1.0
        blurMax: 32
        autoPaddingEnabled: false
    }
    // veil: theme.conf `veil` in the middle, darker towards the edges
    readonly property real veilMid: Math.max(0, Math.min(1, parseFloat(cfg("veil", "0.62")) || 0))
    readonly property real veilEdge: veilMid + (1 - veilMid) * 0.65
    Shape {
        anchors.fill: parent
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: root.width / 2; centerY: root.height / 2
                focalX: centerX; focalY: centerY
                centerRadius: Math.hypot(root.width, root.height) / 2
                GradientStop { position: 0.0; color: Qt.rgba(root.cVeil.r, root.cVeil.g, root.cVeil.b, root.veilMid) }
                GradientStop { position: 0.45; color: Qt.rgba(root.cVeil.r, root.cVeil.g, root.cVeil.b, root.veilMid) }
                GradientStop { position: 1.0; color: Qt.rgba(root.cVeil.r, root.cVeil.g, root.cVeil.b, root.veilEdge) }
            }
            PathRectangle { width: root.width; height: root.height }
        }
    }
    Image {   // grain over the blur and the veil: ±3 levels of 8 bits break the bands; 0 = off
        anchors.fill: parent
        source: "noise.png"
        fillMode: Image.Tile
        smooth: false
        opacity: Math.max(0, Math.min(0.2, parseFloat(root.cfg("noise", "0.03")) || 0))
        visible: opacity > 0
    }

    // ── top right: date · time ──
    Text {
        anchors { right: parent.right; top: parent.top; rightMargin: 48 * root.s; topMargin: 32 * root.s }
        textFormat: Text.StyledText
        text: root.now.toLocaleDateString(Qt.locale(root.cfg("locale", "es_VE")), "ddd d MMM").replace(/\./g, "")
              + " · <b>" + Qt.formatTime(root.now, "HH:mm") + "</b>"
        color: root.cSoft
        font.family: root.monoFont
        font.pixelSize: 13 * root.s
    }

    // ── greeting ──
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.11
        spacing: 10 * root.s
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "DRAGONOS"
            color: root.cDim
            font.family: root.monoFont
            font.pixelSize: 11 * root.s
            font.letterSpacing: 4 * root.s
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.greeting
            color: root.cText
            font.family: root.uiFont
            font.weight: Font.Light
            font.pixelSize: 40 * root.s
        }
    }

    // ── the orbit and the users on it ──
    readonly property real ccx: width / 2
    readonly property real ccy: height * 0.47
    readonly property real orbitRx: Math.min(width * 0.22, 440 * s)
    readonly property real orbitRy: orbitRx * 0.28
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {   // outer, faint and dashed
            strokeColor: Qt.rgba(1, 1, 1, 0.07)
            strokeWidth: 1
            strokeStyle: ShapePath.DashLine
            dashPattern: [2, 4]
            fillColor: "transparent"
            PathAngleArc { centerX: root.ccx; centerY: root.ccy - root.orbitRy * 0.35; radiusX: root.orbitRx * 1.4; radiusY: root.orbitRy * 1.6; sweepAngle: 360 }
        }
        ShapePath {   // the users' orbit
            strokeColor: Qt.rgba(1, 1, 1, 0.14)
            strokeWidth: 1
            fillColor: "transparent"
            PathAngleArc { centerX: root.ccx; centerY: root.ccy - root.orbitRy * 0.35; radiusX: root.orbitRx; radiusY: root.orbitRy; sweepAngle: 360 }
        }
    }

    // ── the core ──
    NeuralCore {
        id: core
        objectName: "core"
        width: root.height * 0.54; height: width
        x: root.ccx - width / 2
        y: root.ccy + 40 * root.s - height / 2
        hud: true
        identity: [root.cAccentSoft, root.cAccent, root.cCyan]
        pointCount: parseInt(root.cfg("pointCount", "240"))
        reducedMotion: root.cfg("reducedMotion", "false") === "true"
        energy: pw.text.length > 0 ? Math.min(0.75, 0.25 + pw.text.length * 0.05) : 0.12
    }
    // typing = listening (the core's own mood stays for verifying / alert / ok)
    Binding {
        target: core
        property: "mood"
        value: pw.text.length > 0 ? "listening" : "calm"
        when: !root.busy && core.mood !== "alert" && core.mood !== "ok"
        restoreMode: Binding.RestoreNone
    }

    // avatar in the middle of the core
    Item {
        id: avatar
        width: 92 * root.s; height: width
        x: core.x + core.width / 2 - width / 2
        y: core.y + core.height / 2 - height / 2
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(0.20, 0.16, 0.30, 1) }
                GradientStop { position: 1; color: Qt.rgba(0.09, 0.07, 0.14, 1) }
            }
            border.width: 2.5 * root.s
            border.color: core.mood === "alert" ? root.cAlert : (core.mood === "verifying" ? root.cAccent : root.cCyan)
            Behavior on border.color { ColorAnimation { duration: 300 } }
        }
        Text {
            anchors.centerIn: parent
            visible: !face.visible
            text: root.initials(root.displayName)
            color: root.cText
            font.family: root.uiFont
            font.pixelSize: 32 * root.s
            font.weight: Font.Medium
        }
        Canvas {   // round photo drawn with a clip path (works on every scene-graph backend)
            id: face
            anchors.fill: parent
            property string src: !root.manual && users.currentItem && users.currentItem.avatar ? "file://" + users.currentItem.avatar.replace(/^file:\/\//, "") : ""
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
                ctx.arc(width / 2, height / 2, width / 2 - 3 * root.s, 0, Math.PI * 2)
                ctx.closePath()
                ctx.clip()
                ctx.drawImage(src, 0, 0, width, height)
            }
        }
    }

    // satellites: the other users + «Otro usuario»
    component Satellite: Item {
        id: sat
        property string label: ""
        property string mark: ""
        property bool plus: false
        property real angle: 0
        signal picked()
        width: 64 * root.s; height: 70 * root.s
        x: root.ccx + Math.cos(angle) * root.orbitRx - width / 2
        y: root.ccy - root.orbitRy * 0.35 + Math.sin(angle) * root.orbitRy - 20 * root.s
        Rectangle {
            id: dot
            anchors.horizontalCenter: parent.horizontalCenter
            width: 40 * root.s; height: width; radius: width / 2
            color: satMouse.containsMouse ? root.cGlassHi : root.cGlass
            border.color: root.cLine
            Text {
                anchors.centerIn: parent
                visible: !sat.plus
                text: sat.mark
                color: root.cSoft
                font.family: root.uiFont; font.pixelSize: 13 * root.s; font.weight: Font.DemiBold
            }
            CoreIcon { anchors.centerIn: parent; visible: sat.plus; name: "plus"; size: 16 * root.s; stroke: 1.6; color: root.cSoft }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: dot.bottom
            anchors.topMargin: 6 * root.s
            text: sat.label
            color: root.cDim
            font.family: root.uiFont; font.pixelSize: 12 * root.s
        }
        MouseArea { id: satMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sat.picked() }
    }
    Repeater {
        id: others
        model: userModel
        delegate: Satellite {
            required property int index
            required property string name
            required property string realName
            readonly property int slot: index < users.currentIndex ? index : index - 1   // the current user is in the core
            visible: index !== users.currentIndex && slot < 2
            angle: [Math.PI + 0.35, Math.PI - 0.45][Math.max(0, Math.min(1, slot))]   // upper left, then lower left
            label: realName !== "" ? realName.split(" ")[0] : name
            mark: root.initials(realName !== "" ? realName : name)
            onPicked: { root.manual = false; users.currentIndex = index; pw.text = ""; pw.forceActiveFocus() }
        }
    }
    Satellite {
        visible: !root.manual
        angle: -0.35
        plus: true
        label: "Otro usuario"
        onPicked: { root.manual = true; manualUser.text = ""; manualUser.forceActiveFocus() }
    }
    Satellite {   // back to the listed users
        visible: root.manual && userModel.count > 0
        angle: -0.35
        mark: root.initials(users.currentItem ? users.currentItem.displayName : "")
        label: users.currentItem ? users.currentItem.displayName.split(" ")[0] : ""
        onPicked: { root.manual = false; pw.forceActiveFocus() }
    }

    // ── who, password, session ──
    Column {
        id: auth
        anchors.horizontalCenter: parent.horizontalCenter
        y: avatar.y + avatar.height + 14 * root.s
        spacing: 2 * root.s

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !root.manual
            text: root.displayName
            color: root.cText
            font.family: root.uiFont; font.pixelSize: 24 * root.s; font.weight: Font.Medium
            style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.4)
        }
        TextInput {   // «Otro usuario» (or no listed users)
            id: manualUser
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.manual
            width: 220 * root.s
            horizontalAlignment: TextInput.AlignHCenter
            color: root.cText
            font.family: root.uiFont; font.pixelSize: 22 * root.s
            KeyNavigation.tab: pw
            onAccepted: pw.forceActiveFocus()
            Text { anchors.fill: parent; horizontalAlignment: Text.AlignHCenter; visible: !parent.text; text: "Usuario"; color: root.cDim; font: parent.font }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !root.manual
            text: root.currentUser
            color: root.cDim
            font.family: root.monoFont; font.pixelSize: 12 * root.s
        }

        Item { width: 1; height: 14 * root.s }

        // password field
        Rectangle {
            id: field
            anchors.horizontalCenter: parent.horizontalCenter
            width: 340 * root.s; height: 46 * root.s
            radius: height / 2
            color: root.cGlass
            border.width: 1
            border.color: core.mood === "alert" ? Qt.rgba(0.93, 0.15, 0.31, 0.75)
                        : pw.activeFocus ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.45) : root.cLine
            Behavior on border.color { ColorAnimation { duration: 250 } }
            transform: Translate { id: shakeT }

            CoreIcon {
                id: lockIcon
                anchors { left: parent.left; leftMargin: 18 * root.s; verticalCenter: parent.verticalCenter }
                name: "lock"; size: 15 * root.s; stroke: 1.8; color: root.cDim
            }
            TextInput {
                id: pw
                objectName: "pw"
                anchors { left: lockIcon.right; right: go.left; verticalCenter: parent.verticalCenter; leftMargin: 12 * root.s; rightMargin: 8 * root.s }
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
                selectionColor: root.cGlow
                onTextEdited: { core.pulse(); if (core.mood === "alert") core.mood = "calm" }
                onAccepted: root.doLogin()
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
                id: go
                anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 6 * root.s }
                width: 34 * root.s; height: width; radius: width / 2
                color: Qt.rgba(root.cCyan.r, root.cCyan.g, root.cCyan.b, goMouse.containsMouse ? 0.30 : 0.18)
                border.color: Qt.rgba(root.cCyan.r, root.cCyan.g, root.cCyan.b, 0.55)
                opacity: root.busy ? 0.5 : 1
                CoreIcon { anchors.centerIn: parent; name: "arrow"; size: 15 * root.s; stroke: 2; color: root.cText }
                MouseArea { id: goMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.doLogin() }
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
            topPadding: 6 * root.s
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: keyboard.capsLock ? "Bloq Mayús está activo." : ""
            color: err ? root.cAlert : root.cDim
            font.family: root.uiFont; font.pixelSize: 12 * root.s
            height: Math.max(implicitHeight, 22 * root.s)
        }

        // session pill: opens the list of sessions
        Rectangle {
            id: sessionPill
            anchors.horizontalCenter: parent.horizontalCenter
            height: 32 * root.s
            width: sessionRow.implicitWidth + 30 * root.s
            radius: height / 2
            color: sessionMouse.containsMouse || sessionMenu.visible ? root.cGlassHi : root.cGlass
            border.color: root.cLine
            Row {
                id: sessionRow
                anchors.centerIn: parent
                spacing: 8 * root.s
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 6 * root.s; height: width; radius: width / 2; color: root.cAccent }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Sesión: " + sessionList.currentName
                    color: root.cText
                    font.family: root.uiFont; font.pixelSize: 13 * root.s
                }
                CoreIcon { anchors.verticalCenter: parent.verticalCenter; name: "chevron"; size: 13 * root.s; stroke: 2; color: root.cDim; rotation: sessionMenu.visible ? 180 : 0 }
            }
            MouseArea {
                id: sessionMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: sessionMenu.visible = !sessionMenu.visible
            }
        }
    }

    // the session list, over everything, under the pill
    Rectangle {
        id: sessionMenu
        visible: false
        z: 10
        width: Math.max(200 * root.s, sessionList.contentWidth + 16 * root.s)
        height: sessionList.contentHeight + 12 * root.s
        x: root.width / 2 - width / 2
        y: auth.y + auth.height + 8 * root.s
        radius: 14 * root.s
        color: Qt.rgba(13 / 255, 11 / 255, 22 / 255, 0.92)
        border.color: root.cLine
        ListView {
            id: sessionList
            property string currentName: currentItem ? currentItem.sname : ""
            anchors { fill: parent; margins: 6 * root.s }
            interactive: false
            spacing: 2 * root.s
            model: sessionModel
            currentIndex: root.sessionIndex
            contentWidth: 200 * root.s
            delegate: Rectangle {
                id: row
                required property int index
                required property string name
                readonly property string sname: name
                width: sessionList.width
                height: 30 * root.s
                radius: 10 * root.s
                color: rowMouse.containsMouse ? root.cGlassHi : (index === root.sessionIndex ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.16) : "transparent")
                Text {
                    anchors { left: parent.left; leftMargin: 12 * root.s; verticalCenter: parent.verticalCenter }
                    text: row.name
                    color: row.index === root.sessionIndex ? root.cText : root.cSoft
                    font.family: root.uiFont; font.pixelSize: 13 * root.s
                }
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { root.sessionIndex = row.index; sessionMenu.visible = false; pw.forceActiveFocus() }
                }
            }
        }
    }

    // ── corners: keyboard layout, power ──
    component GlassButton: Rectangle {
        id: gb
        property string glyph: ""
        property string label: ""
        property bool danger: false
        signal activated()
        width: label !== "" ? Math.max(46 * root.s, gbText.implicitWidth + 28 * root.s) : 50 * root.s
        height: label !== "" ? 46 * root.s : 50 * root.s
        radius: 14 * root.s
        color: gbMouse.containsMouse ? root.cGlassHi : root.cGlass
        border.color: root.cLine
        CoreIcon { anchors.centerIn: parent; visible: gb.glyph !== ""; name: gb.glyph; size: 18 * root.s; stroke: 1.8; color: gb.danger ? root.cDanger : root.cText }
        Text {
            id: gbText
            anchors.centerIn: parent
            visible: gb.label !== ""
            text: gb.label
            color: root.cText
            font.family: root.monoFont; font.pixelSize: 13 * root.s; font.weight: Font.Bold
        }
        MouseArea { id: gbMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: gb.activated() }
    }
    Row {
        anchors { left: parent.left; bottom: parent.bottom; margins: 32 * root.s }
        spacing: 10 * root.s
        GlassButton {
            visible: root.layoutLabel !== ""
            label: root.layoutLabel
            onActivated: { keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length; pw.forceActiveFocus() }
        }
        GlassButton {
            visible: keyboard.capsLock
            glyph: "caps"
            onActivated: pw.forceActiveFocus()
        }
    }
    Row {
        anchors { right: parent.right; bottom: parent.bottom; margins: 32 * root.s }
        spacing: 10 * root.s
        GlassButton { visible: sddm.canSuspend; glyph: "moon"; onActivated: sddm.suspend() }
        GlassButton { visible: sddm.canReboot; glyph: "restart"; onActivated: sddm.reboot() }
        GlassButton { visible: sddm.canPowerOff; glyph: "power"; danger: true; onActivated: sddm.powerOff() }
    }
}
