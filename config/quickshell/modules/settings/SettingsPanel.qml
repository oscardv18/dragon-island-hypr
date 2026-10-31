// =============================================================================
// dragon-island — SettingsPanel.qml (SUPER + F2) · docs/design/08-ajustes.png
// Side navigation (Apariencia, Barra superior, Launcher, Privacidad, Energía; Bloqueo e inicio, Fondo y colores and
// Atajos come in later phases and stay hidden) and the pages:
//   Barra superior  four style cards (schematic thumbnail, cyan 1.5 px ring on the chosen one; the real bar changes
//                   at once), "Contenido de la isla" (Música / Ventana / Fecha), "Mostrar CPU y RAM",
//                   "Ocultar automáticamente"
//   Apariencia      "Cristal" (ahumado · clásico · líquido, services/Glass.qml), "Contorno de ventanas" (escuadras · solo hilo · nada), "Relojes del mundo" (Fecha y hora), "Intensidad del acento" (sutil ↔ intenso, live sample), "Paleta desde el fondo", "Aplicar a las apps"
//   Launcher        "Launcher Gravedad" (off = the previous orbital launcher), "Alt+Tab orbital", "Reducir movimiento"
// Every control writes through Settings (settings.json), so it persists and other monitors follow.
// Keys: 1–4 pick the bar style A–D · Tab switches page · Esc closes.
// =============================================================================
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"
import "../../components"

Item {
    id: root

    property bool shown: false
    property string page: "bar"            // "appearance" | "bar" | "launcher" | "privacy" | "power"
    // `qs ipc call settings page <key>` opens Ajustes on that page
    Connections {
        target: Settings
        function onPageChanged() { if (root.pages.some(p => p.key === Settings.page)) root.page = Settings.page; }
    }
    property real t: 0

    readonly property var pages: [
        { key: "appearance", label: "Apariencia",     icon: Icons.palette },
        { key: "bar",        label: "Barra superior", icon: Icons.barTop },
        { key: "launcher",   label: "Launcher",       icon: Icons.apps },
        { key: "privacy",    label: "Privacidad",     icon: Icons.eyeOff },
        { key: "power",      label: "Energía",        icon: Icons.sleep }
    ]
    readonly property var titles: ({
        appearance: ["Apariencia", "Cuánto acento llevan los estados activos y de dónde sale la paleta."],
        bar:        ["Barra superior", "El cambio se aplica al instante y Hyprland ajusta el espacio reservado."],
        launcher:   ["Launcher", "Cómo se abren las apps, las ventanas y el portapapeles."],
        privacy:    ["Privacidad", "El modo grabación se activa solo mientras grabas o compartes la pantalla."],
        power:      ["Energía", "Qué pasa cuando dejas el equipo sin usar."]
    })
    function minutes(s: int): string { return s % 60 === 0 ? `${s / 60} min` : `${(s / 60).toFixed(1)} min`; }
    readonly property var styles: [
        { key: "A", name: "A · Notch",  text: "Pegado al borde, islas a los lados" },
        { key: "B", name: "B · Island", text: "Píldora flotante que cambia de forma" },
        { key: "C", name: "C · Unida",  text: "Franja completa, notch del mismo alto" },
        { key: "D", name: "D · Mínima", text: "Solo puntos y hora; se despliega al acercarte" }
    ]

    function key(e): void {
        if (e.key >= Qt.Key_1 && e.key <= Qt.Key_4 && root.page === "bar") { Settings.setBarStyle(root.styles[e.key - Qt.Key_1].key); e.accepted = true; }
        else if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) {
            const keys = root.pages.map(p => p.key), i = keys.indexOf(root.page);
            root.page = keys[(i + (e.key === Qt.Key_Backtab ? keys.length - 1 : 1)) % keys.length];
            e.accepted = true;
        }
    }

    onShownChanged: {
        anim.stop();
        anim.to = shown ? 1 : 0;
        anim.duration = shown ? Theme.durEmerge : Theme.durOut;
        anim.easing.bezierCurve = shown ? Theme.curveEmergente : Theme.curveSalida;
        anim.start();
    }
    NumberAnimation { id: anim; target: root; property: "t"; easing.type: Easing.BezierSpline }

    // ---- the card ----
    Rectangle {
        id: card
        width: Math.min(Theme.settingsWidth, root.width - Theme.barMarginSide * 2)
        height: Math.min(Theme.settingsHeight, root.height - (Theme.barMarginTop + Theme.barHeight + Theme.popoverGap) * 2)
        x: (root.width - width) / 2
        y: Math.max(Theme.barMarginTop + Theme.barHeight + Theme.popoverGap, (root.height - height) / 2)
        radius: Theme.popoverRadius
        color: Theme.popoverBg
        border.width: 1
        border.color: Theme.glassBorder
        visible: root.t > 0.001
        opacity: Math.min(1, root.t)
        transform: [
            Scale { origin.x: card.width / 2; origin.y: card.height / 2; xScale: Theme.popoverScaleFrom + (1 - Theme.popoverScaleFrom) * root.t; yScale: xScale },
            Translate { y: -Theme.popoverShift * (1 - root.t) }
        ]

        // swallow clicks so they do not reach the close-on-click-outside area
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

        // ---- side navigation ----
        Item {
            id: nav
            width: Theme.settingsNavWidth
            height: parent.height

            Rectangle {   // divider
                anchors.right: parent.right
                width: 1
                height: parent.height
                color: Theme.hairline
            }

            Column {
                x: Theme.spacingLg
                y: Theme.popoverPad + 4
                width: parent.width - Theme.spacingLg * 2
                spacing: Theme.spacingXs

                UiText {
                    text: "AJUSTES"
                    mono: true
                    size: Theme.sizeCaption
                    color: Theme.textDim
                    font.letterSpacing: 2
                    bottomPadding: Theme.spacingMd
                    leftPadding: Theme.spacingSm
                }

                Repeater {
                    model: root.pages
                    delegate: Rectangle {
                        id: navItem
                        required property var modelData
                        readonly property bool current: root.page === modelData.key
                        width: parent.width
                        height: 40
                        radius: Theme.rowRadius
                        color: current ? Theme.hoverOverlay : (navMouse.containsMouse ? Theme.alpha(Theme.text, 0.04) : Theme.transparent)
                        Behavior on color { ColorAnimation { duration: Theme.durHover } }
                        Row {
                            x: Theme.spacingMd
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingMd
                            Glyph { anchors.verticalCenter: parent.verticalCenter; icon: navItem.modelData.icon; size: Theme.iconMd; color: navItem.current ? Theme.text : Theme.textDim }
                            UiText { anchors.verticalCenter: parent.verticalCenter; text: navItem.modelData.label; size: Theme.sizeBodyLg; weight: navItem.current ? Theme.weightSemiBold : Theme.weightRegular; color: navItem.current ? Theme.text : Theme.textSoft }
                        }
                        MouseArea { id: navMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.page = navItem.modelData.key }
                    }
                }
            }
        }

        // ---- page ----
        Item {
            id: pageArea
            x: nav.width + Theme.spacingLg + 4
            y: Theme.popoverPad + 4
            width: parent.width - x - Theme.spacingLg - 4
            height: parent.height - y - Theme.popoverPad

            // header shared by both pages
            Column {
                id: header
                width: parent.width
                spacing: Theme.spacingXs
                Item {
                    width: parent.width
                    height: titleText.implicitHeight
                    UiText {
                        id: titleText
                        text: root.titles[root.page][0]
                        size: Theme.sizeGreeting
                        weight: Theme.weightSemiBold
                    }
                    Rectangle {
                        visible: root.page === "bar"
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 26
                        width: hint.implicitWidth + Theme.spacingMd * 2
                        radius: 8
                        color: Theme.neutralFill
                        UiText { id: hint; anchors.centerIn: parent; text: "Super + Alt + B · cambiar estilo"; mono: true; size: Theme.sizeCaption + 1; color: Theme.textSoft }
                    }
                }
                UiText {
                    text: root.titles[root.page][1]
                    color: Theme.textDim
                }
            }

            // the pages scroll below the header (Barra superior is taller than a 768 px screen allows)
            Flickable {
                id: pageFlick
                y: header.height + Theme.spacingLg
                width: parent.width
                height: parent.height - y
                contentWidth: width
                contentHeight: Math.max(barPage.visible ? barPage.implicitHeight : 0, appearancePage.visible ? appearancePage.implicitHeight : 0,
                                        privacyPage.visible ? privacyPage.implicitHeight : 0, powerPage.visible ? powerPage.implicitHeight : 0)
                clip: true
                boundsBehavior: Flickable.StopAtBounds

            // ======== Barra superior ========
            Column {
                id: barPage
                visible: root.page === "bar"
                width: parent.width
                spacing: Theme.spacingLg

                // four style cards
                Row {
                    id: cards
                    width: parent.width
                    spacing: Theme.spacingMd
                    readonly property real cardWidth: (width - spacing * 3) / 4

                    Repeater {
                        model: root.styles
                        delegate: Rectangle {
                            id: styleCard
                            required property var modelData
                            required property int index
                            readonly property bool chosen: Settings.barStyle === modelData.key
                            width: cards.cardWidth
                            height: styleCol.implicitHeight + Theme.spacingMd * 2
                            radius: Theme.cardRadius - 4
                            color: cardMouse.containsMouse && !chosen ? Theme.alpha(Theme.text, 0.06) : Theme.alpha(Theme.text, 0.035)
                            border.width: chosen ? 1.5 : 1
                            border.color: chosen ? Theme.cyan : Theme.hairline
                            Behavior on color { ColorAnimation { duration: Theme.durHover } }
                            Behavior on border.color { ColorAnimation { duration: Theme.durStd } }

                            Column {
                                id: styleCol
                                x: Theme.spacingMd
                                y: Theme.spacingMd
                                width: parent.width - Theme.spacingMd * 2
                                spacing: Theme.spacingSm

                                BarThumb { width: parent.width; style: styleCard.modelData.key }

                                Item {
                                    width: parent.width
                                    height: nameText.implicitHeight
                                    UiText { id: nameText; text: styleCard.modelData.name; weight: Theme.weightSemiBold; size: Theme.sizeBodyLg }
                                    UiText { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: `${Theme.barZoneFor(styleCard.modelData.key, Settings.barSize)} px`; mono: true; size: Theme.sizeCaption; color: Theme.textDim }
                                }
                                UiText {
                                    width: parent.width
                                    text: styleCard.modelData.text
                                    size: Theme.sizeCaption + 1
                                    color: Theme.textDim
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                }
                            }
                            MouseArea { id: cardMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Settings.setBarStyle(styleCard.modelData.key) }
                        }
                    }
                }

                // options
                SettingsGroup {
                    width: parent.width
                    SettingsRow {
                        title: "Tamaño de la barra"
                        subtitle: "Alto de las islas; la zona reservada se ajusta sola"
                        Segmented {
                            implicitWidth: 250
                            model: [{ key: "compacta", label: "Compacta" }, { key: "normal", label: "Normal" }, { key: "amplia", label: "Amplia" }]
                            current: Settings.barSize
                            onSelected: k => Settings.setBarSize(k)
                        }
                    }
                    SettingsRow {
                        title: "Contenido de la isla"
                        subtitle: "Qué muestra el notch cuando no hay actividad especial"
                        Segmented {
                            implicitWidth: 250
                            model: [{ key: "media", label: "Música" }, { key: "window", label: "Ventana" }, { key: "date", label: "Fecha" }]
                            current: Settings.islandContent
                            onSelected: k => Settings.setIslandContent(k)
                        }
                    }
                    SettingsRow {
                        title: "Mostrar CPU y RAM"
                        subtitle: "Métricas compactas junto a la hora"
                        ToggleSwitch { checked: Settings.barMetrics; onToggled: Settings.setBarMetrics(!Settings.barMetrics) }
                    }
                    SettingsRow {
                        title: "Avisar de comandos largos"
                        subtitle: "Un comando de la terminal que dura al menos esto avisa en la isla al terminar"
                        Stepper {
                            value: Settings.longCommandSeconds
                            step: 10
                            from: 10
                            to: 600
                            format: v => `${v} s`
                            onChanged: v => Settings.setLongCommandSeconds(v)
                        }
                    }
                    SettingsRow {
                        last: true
                        title: "Ocultar automáticamente"
                        subtitle: Settings.barStyle === "D" ? "La barra mínima se esconde hasta que acercas el cursor al borde" : "La barra se atenúa con ventanas maximizadas"
                        ToggleSwitch { checked: Settings.barAutohide; onToggled: Settings.setBarAutohide(!Settings.barAutohide) }
                    }
                }
            }

            // ======== Apariencia ========
            Column {
                id: appearancePage
                visible: root.page === "appearance"
                width: parent.width
                spacing: Theme.spacingLg

                SettingsGroup {
                    width: parent.width
                    SettingsRow {
                        title: "Cristal"
                        subtitle: (Glass.styles.find(g => g.key === Glass.requested) ?? Glass.styles[0]).detail
                        Segmented {
                            implicitWidth: 280
                            model: Glass.styles
                            current: Glass.requested
                            onSelected: k => Glass.setStyle(k)
                        }
                    }
                    SettingsRow {
                        title: "Contorno de ventanas"
                        subtitle: Settings.windowFrame === "escuadras" ? "Línea superior y cuatro escuadras cian en la ventana enfocada, como los paneles"
                                : Settings.windowFrame === "hilo" ? "Solo la línea superior en la ventana enfocada"
                                : "Sin contorno: solo el borde nativo de 1 px"
                        Segmented {
                            implicitWidth: 280
                            model: [{ key: "escuadras", label: "Escuadras" }, { key: "hilo", label: "Solo hilo" }, { key: "nada", label: "Nada" }]
                            current: Settings.windowFrame
                            onSelected: k => Settings.setWindowFrame(k)
                        }
                    }
                    SettingsRow {
                        title: "Relojes del mundo"
                        subtitle: "En Fecha y hora. «Nombre=Zona», separados por comas (Enter guarda)"
                        InputField {
                            implicitWidth: 330
                            fontSize: Theme.sizeBody
                            text: Settings.worldClocksText()
                            placeholder: "Madrid=Europe/Madrid, Tokio=Asia/Tokyo"
                            onAccepted: Settings.setWorldClocks(text)
                        }
                    }
                    SettingsRow {
                        title: "Intensidad del acento"
                        subtitle: "Cuánto acento llevan los estados activos"
                        Row {
                            spacing: Theme.spacingMd
                            UiText { anchors.verticalCenter: parent.verticalCenter; text: "sutil"; mono: true; size: Theme.sizeCaption + 1; color: Theme.textDim }
                            Slider {
                                anchors.verticalCenter: parent.verticalCenter
                                implicitWidth: 230
                                showValue: false
                                value: Settings.accentIntensity
                                onMoved: v => Settings.setAccentIntensity(v)
                            }
                            UiText { anchors.verticalCenter: parent.verticalCenter; text: "intenso"; mono: true; size: Theme.sizeCaption + 1; color: Theme.textDim }
                            // live sample of an active state
                            AccentFill {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 28
                                height: 28
                                radius: 8
                            }
                        }
                    }
                    SettingsRow {
                        title: "Paleta desde el fondo"
                        subtitle: !Settings.wallpaperPalette ? "El acento es el Dragon fijo"
                                : (WallPalette.busy ? "Leyendo los colores del fondo…"
                                : (WallPalette.ready && WallPalette.fallback ? "El fondo es muy apagado: se usa el acento Dragon"
                                : (WallPalette.ready ? "El shell toma sus colores del fondo" : "Se generará al aplicar un fondo")))
                        Row {
                            spacing: Theme.spacingMd
                            // the colours of the current wallpaper (14-fondos)
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingXs
                                visible: Settings.wallpaperPalette && WallPalette.ready
                                Repeater {
                                    model: WallPalette.swatches
                                    delegate: Rectangle {
                                        required property color modelData
                                        width: Theme.swatchDot
                                        height: width
                                        radius: width / 2
                                        color: modelData
                                        border.width: 1
                                        border.color: Theme.glassBorder
                                    }
                                }
                            }
                            ToggleSwitch {
                                anchors.verticalCenter: parent.verticalCenter
                                checked: Settings.wallpaperPalette
                                onToggled: WallPalette.setEnabled(!Settings.wallpaperPalette)
                            }
                        }
                    }
                    SettingsRow {
                        last: true
                        title: "Aplicar a las apps"
                        subtitle: "herdr, Ghostty, kitty, Starship y fastfetch usan la misma paleta"
                        ToggleSwitch {
                            enabled: Settings.wallpaperPalette
                            checked: Settings.paletteApplyExternal
                            onToggled: WallPalette.setApplyExternal(!Settings.paletteApplyExternal)
                        }
                    }
                }

                // preview of the active states with the current intensity
                Row {
                    spacing: Theme.spacingMd
                    Repeater {
                        model: ["Wi‑Fi", "Bluetooth", "29"]
                        delegate: AccentFill {
                            required property string modelData
                            width: label.implicitWidth + Theme.spacingLg * 2
                            height: 36
                            radius: Theme.rowRadius
                            UiText { id: label; anchors.centerIn: parent; text: parent.modelData; color: Theme.lavenderInk; weight: Theme.weightMedium }
                        }
                    }
                }
            }

            // ======== Privacidad: the recording mode (docs/design/25-grabacion.png) ========
            Column {
                id: privacyPage
                visible: root.page === "privacy"
                width: parent.width
                spacing: Theme.spacingLg

                SettingsGroup {
                    width: parent.width
                    SettingsRow {
                        title: "Modo grabación"
                        subtitle: "Automático: mientras grabas (SUPER + SHIFT + R) o una app captura la pantalla (OBS, una llamada)"
                        Segmented {
                            implicitWidth: 230
                            model: [{ key: "auto", label: "Automático" }, { key: "off", label: "Desactivado" }]
                            current: Settings.recordingMode
                            onSelected: k => Settings.setRecordingMode(k)
                        }
                    }
                    SettingsRow {
                        title: "Retener notificaciones"
                        subtitle: "Se guardan sin aviso y la isla dice cuántas al terminar"
                        ToggleSwitch { checked: Settings.recordHold; onToggled: Settings.setFlag("recordHold", !Settings.recordHold) }
                    }
                    SettingsRow {
                        title: "Ocultar títulos de ventanas"
                        subtitle: "La barra no muestra chats, rutas ni el contexto vivo"
                        ToggleSwitch { checked: Settings.recordHideTitles; onToggled: Settings.setFlag("recordHideTitles", !Settings.recordHideTitles) }
                    }
                    SettingsRow {
                        title: "Pausar el portapapeles"
                        subtitle: "Lo que copies no entra en el historial"
                        ToggleSwitch { checked: Settings.recordPauseClipboard; onToggled: Settings.setFlag("recordPauseClipboard", !Settings.recordPauseClipboard) }
                    }
                    SettingsRow {
                        last: true
                        title: "Marco de grabación"
                        subtitle: "Un borde rojo fino recuerda que grabas"
                        ToggleSwitch { checked: Settings.recordFrame; onToggled: Settings.setFlag("recordFrame", !Settings.recordFrame) }
                    }
                }
                UiText {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                    text: "Sin obs-websocket no se distingue que OBS capture la pantalla de que la grabe: en automático el modo se activa en cuanto OBS la captura. Mostrar las teclas pulsadas no está disponible: Wayland no deja leerlas sin permisos de administrador."
                    size: Theme.sizeCaption + 1
                    color: Theme.textDim
                }
            }

            // ======== Launcher: the Gravity launcher and the motion it may use ========
            Column {
                id: launcherPage
                visible: root.page === "launcher"
                width: parent.width
                spacing: Theme.spacingLg

                SettingsGroup {
                    width: parent.width
                    SettingsRow {
                        title: "Launcher Gravedad"
                        subtitle: "Anillos de apps alrededor del núcleo; apagado vuelve el launcher orbital de antes"
                        ToggleSwitch { checked: Settings.launcherGravity; onToggled: Settings.setFlag("launcherGravity", !Settings.launcherGravity) }
                    }
                    SettingsRow {
                        title: "Alt+Tab orbital"
                        subtitle: "Anillo de ventanas con captura; apagado, Alt+Tab queda libre para las apps"
                        ToggleSwitch { checked: Settings.switcherOrbital; onToggled: Settings.setFlag("switcherOrbital", !Settings.switcherOrbital) }
                    }
                    SettingsRow {
                        last: true
                        title: "Reducir movimiento"
                        subtitle: "Los anillos dejan de girar; solo se mueve lo que tú mueves"
                        ToggleSwitch { checked: Settings.reduceMotion; onToggled: Settings.setFlag("reduceMotion", !Settings.reduceMotion) }
                    }
                }
            }

            // ======== Energía: the idle sequence (docs/design/26-inactividad.png) ========
            Column {
                id: powerPage
                visible: root.page === "power"
                width: parent.width
                spacing: Theme.spacingLg

                SettingsGroup {
                    width: parent.width
                    SettingsRow {
                        title: "Atenuar y avisar"
                        subtitle: "La pantalla baja y la isla avisa antes de bloquear"
                        Stepper { value: Settings.idleDimSeconds; step: 60; from: 60; to: 3600; format: v => root.minutes(v); onChanged: v => Settings.setSeconds("idleDimSeconds", v) }
                    }
                    SettingsRow {
                        title: "Bloquear"
                        subtitle: "El núcleo aparece y se queda en reposo"
                        Stepper { value: Settings.idleLockSeconds; step: 60; from: 60; to: 7200; format: v => root.minutes(v); onChanged: v => Settings.setSeconds("idleLockSeconds", v) }
                    }
                    SettingsRow {
                        title: "Apagar pantallas"
                        Stepper { value: Settings.idleScreenOffSeconds; step: 30; from: 60; to: 7200; format: v => root.minutes(v); onChanged: v => Settings.setSeconds("idleScreenOffSeconds", v) }
                    }
                    SettingsRow {
                        title: "Suspender"
                        Stepper { value: Settings.idleSuspendSeconds; step: 300; from: 300; to: 14400; format: v => root.minutes(v); onChanged: v => Settings.setSeconds("idleSuspendSeconds", v) }
                    }
                    SettingsRow {
                        last: true
                        title: "No avanzar con agentes trabajando"
                        subtitle: "Mientras un agente de herdr trabaja la secuencia espera"
                        ToggleSwitch { checked: Settings.idleInhibitAgents; onToggled: Settings.setFlag("idleInhibitAgents", !Settings.idleInhibitAgents) }
                    }
                }
                Row {
                    spacing: Theme.spacingSm
                    Glyph { anchors.verticalCenter: parent.verticalCenter; icon: Icons.shield; size: Theme.iconMd; color: Theme.cyan }
                    UiText { anchors.verticalCenter: parent.verticalCenter; text: "No avanza si hay un vídeo en reproducción, un agente trabajando o el modo grabación activo."; color: Theme.textDim }
                }
            }
            }
        }
    }
}
