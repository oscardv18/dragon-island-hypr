// Single-line text input (launcher search, Wi-Fi password)
import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: root

    property alias text: input.text
    property alias echoMode: input.echoMode
    property string placeholder: ""
    property string icon: ""
    property real fontSize: Theme.sizeBodyLg
    readonly property alias input: input

    signal accepted()
    signal navigate(int delta)     // Up / Down / Tab / Shift+Tab
    signal escapePressed()
    signal deleteOnEmpty()         // Supr with an empty field (e.g. delete the highlighted entry)

    implicitHeight: Theme.touchTarget
    implicitWidth: Theme.popoverWidthSm
    radius: Theme.rowRadius
    color: Theme.surface2
    border.width: 1
    border.color: input.activeFocus ? Theme.alpha(Theme.accent, 0.6) : Theme.hairline

    function focusInput(): void { input.forceActiveFocus(); }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingMd
        anchors.rightMargin: Theme.spacingMd
        spacing: Theme.spacingSm

        Glyph {
            visible: root.icon.length > 0
            icon: root.icon
            size: Theme.iconLg
            color: Theme.textDim
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            TextInput {
                id: input
                anchors.fill: parent
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                selectionColor: Theme.alpha(Theme.accent, 0.5)
                selectedTextColor: Theme.onBrand
                font.family: Theme.fontUi
                font.pixelSize: Math.round(root.fontSize)
                clip: true
                onAccepted: root.accepted()
                Keys.onUpPressed: root.navigate(-1)
                Keys.onDownPressed: root.navigate(1)
                Keys.onTabPressed: root.navigate(1)
                Keys.onBacktabPressed: root.navigate(-1)
                Keys.onEscapePressed: root.escapePressed()
                Keys.onDeletePressed: e => {
                    if (input.text.length === 0) root.deleteOnEmpty();
                    else e.accepted = false;      // normal forward delete
                }
            }

            UiText {
                anchors.fill: parent
                visible: input.text.length === 0
                text: root.placeholder
                size: root.fontSize
                color: Theme.textDim
            }
        }
    }
}
