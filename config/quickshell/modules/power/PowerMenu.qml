// =============================================================================
// dragon-island — PowerMenu.qml (SUPER + Escape)
// Bloquear · Suspender · Cerrar sesión · Reiniciar · Apagar
// Keyboard: ←/→ (or Tab) to move · Enter/Space to run · 1–5 shortcut · Esc to close.
// =============================================================================
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"
import "../../components"

Item {
    id: root

    property bool shown: false
    readonly property Item frameItem: card.visible ? card.frameItem : null   // blur region of the window
    property int current: 0

    readonly property var actions: [
        { key: "lock",     label: "Bloquear",      icon: Icons.lock,    danger: false },
        { key: "suspend",  label: "Suspender",     icon: Icons.sleep,   danger: false },
        { key: "logout",   label: "Cerrar sesión", icon: Icons.logout,  danger: false },
        { key: "reboot",   label: "Reiniciar",     icon: Icons.restart, danger: true },
        { key: "poweroff", label: "Apagar",        icon: Icons.power,   danger: true }
    ]

    function focusMenu(): void { keyItem.forceActiveFocus(); }

    function run(index: int): void {
        const a = actions[index];
        if (!a) return;
        ShellState.close();
        Session.run(a.key);
    }

    onShownChanged: if (shown) current = 0

    PopoverFrame {
        id: card
        shown: root.shown
        title: "Energía"
        popWidth: root.actions.length * (Theme.powerButton + Theme.spacingMd) + Theme.popoverPad * 2 - Theme.spacingMd
        originX: width / 2
        x: (root.width - width) / 2
        y: (root.height - height) / 2

        Item {
            id: keyItem
            Layout.preferredHeight: 0
            Layout.preferredWidth: 0
            focus: root.shown
            Keys.onLeftPressed: root.current = (root.current + root.actions.length - 1) % root.actions.length
            Keys.onRightPressed: root.current = (root.current + 1) % root.actions.length
            Keys.onTabPressed: root.current = (root.current + 1) % root.actions.length
            Keys.onBacktabPressed: root.current = (root.current + root.actions.length - 1) % root.actions.length
            Keys.onReturnPressed: root.run(root.current)
            Keys.onEnterPressed: root.run(root.current)
            Keys.onSpacePressed: root.run(root.current)
            Keys.onEscapePressed: ShellState.close()
            Keys.onPressed: e => {
                const n = parseInt(e.text);
                if (n >= 1 && n <= root.actions.length) { root.run(n - 1); e.accepted = true; }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingMd

            Repeater {
                model: root.actions
                delegate: Item {
                    id: btn
                    required property var modelData
                    required property int index
                    readonly property bool selected: root.current === index
                    Layout.preferredWidth: Theme.powerButton
                    Layout.preferredHeight: Theme.powerButton + Theme.spacingLg + Theme.sizeBody

                    Rectangle {
                        id: face
                        width: Theme.powerButton
                        height: Theme.powerButton
                        radius: Theme.cardRadius
                        color: btn.modelData.danger
                               ? (btn.selected ? Theme.alpha(Theme.error, 0.32) : Theme.errorTint)
                               : (btn.selected ? Theme.surfaceHi : Theme.surface2)
                        border.width: btn.selected ? 1 : 0
                        border.color: btn.modelData.danger ? Theme.error : Theme.accent
                        Behavior on color { ColorAnimation { duration: Theme.durHover } }

                        Glyph {
                            anchors.centerIn: parent
                            icon: btn.modelData.icon
                            size: Theme.iconLg * 1.6
                            color: btn.modelData.danger ? Theme.error : Theme.text
                        }
                    }
                    UiText {
                        anchors.top: face.bottom
                        anchors.topMargin: Theme.spacingSm
                        anchors.horizontalCenter: face.horizontalCenter
                        text: btn.modelData.label
                        size: Theme.sizeCaption + 1
                        color: btn.selected ? Theme.text : Theme.textDim
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.current = btn.index
                        onClicked: root.run(btn.index)
                    }
                }
            }
        }
    }
}
