// =============================================================================
// dragon-island — SettingsPanel.qml (SUPER + F2) · docs/design/08-ajustes.png
// Side navigation (Apariencia, Barra superior; Launcher, Bloqueo e inicio, Fondo y colores and Atajos come in later
// phases and stay hidden) and the pages:
//   Barra superior  four style cards (schematic thumbnail, cyan 1.5 px ring on the chosen one; the real bar changes
//                   at once), "Contenido de la isla" (Música / Ventana / Fecha), "Mostrar CPU y RAM",
//                   "Ocultar automáticamente"
//   Apariencia      "Intensidad del acento" (sutil ↔ intenso, live sample), "Colores desde el fondo de pantalla"
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
    property string page: "bar"            // "appearance" | "bar"
    property real t: 0

    readonly property var pages: [
        { key: "appearance", label: "Apariencia",     icon: Icons.palette },
        { key: "bar",        label: "Barra superior", icon: Icons.barTop }
    ]
    readonly property var styles: [
        { key: "A", name: "A · Notch",  text: "Pegado al borde, islas a los lados" },
        { key: "B", name: "B · Island", text: "Píldora flotante que cambia de forma" },
        { key: "C", name: "C · Unida",  text: "Franja completa, notch del mismo alto" },
        { key: "D", name: "D · Mínima", text: "Solo puntos y hora; se despliega al acercarte" }
    ]

    function key(e): void {
        if (e.key >= Qt.Key_1 && e.key <= Qt.Key_4 && root.page === "bar") { Settings.setBarStyle(root.styles[e.key - Qt.Key_1].key); e.accepted = true; }
        else if (e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) { root.page = root.page === "bar" ? "appearance" : "bar"; e.accepted = true; }
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
                        text: root.page === "bar" ? "Barra superior" : "Apariencia"
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
                    text: root.page === "bar" ? "El cambio se aplica al instante y Hyprland ajusta el espacio reservado."
                                              : "Cuánto púrpura llevan los estados activos y de dónde sale la paleta."
                    color: Theme.textDim
                }
            }

            // ======== Barra superior ========
            Column {
                visible: root.page === "bar"
                y: header.height + Theme.spacingLg
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
                        last: true
                        title: "Ocultar automáticamente"
                        subtitle: Settings.barStyle === "D" ? "La barra mínima se esconde hasta que acercas el cursor al borde" : "La barra se atenúa con ventanas maximizadas"
                        ToggleSwitch { checked: Settings.barAutohide; onToggled: Settings.setBarAutohide(!Settings.barAutohide) }
                    }
                }
            }

            // ======== Apariencia ========
            Column {
                visible: root.page === "appearance"
                y: header.height + Theme.spacingLg
                width: parent.width
                spacing: Theme.spacingLg

                SettingsGroup {
                    width: parent.width
                    SettingsRow {
                        title: "Intensidad del acento"
                        subtitle: "Cuánto púrpura llevan los estados activos"
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
                        last: true
                        title: "Colores desde el fondo de pantalla"
                        subtitle: "Toma la paleta del fondo actual (llega en una próxima versión; la preferencia ya se guarda)"
                        ToggleSwitch { checked: Settings.wallpaperPalette; onToggled: Settings.setWallpaperPalette(!Settings.wallpaperPalette) }
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
        }
    }
}
