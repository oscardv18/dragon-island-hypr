// Segmented control (power profile): model = [{ key, label, icon?, available }]
import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: root
    property var model: []
    property string current: ""
    signal selected(string key)

    implicitHeight: Theme.capsuleHeight + Theme.spacingSm
    implicitWidth: Theme.popoverWidthSm
    radius: Theme.rowRadius
    color: Theme.surface2

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingXs
        spacing: Theme.spacingXs

        Repeater {
            model: root.model
            delegate: Item {
                id: seg
                required property var modelData
                readonly property bool isCurrent: modelData.key === root.current
                Layout.fillWidth: true
                Layout.fillHeight: true
                enabled: modelData.available !== false
                opacity: enabled ? 1 : 0.4

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.capsuleRadius
                    visible: !seg.isCurrent && segMouse.containsMouse
                    color: Theme.surfaceHi
                }
                BrandFill {
                    anchors.fill: parent
                    radius: Theme.capsuleRadius
                    visible: seg.isCurrent
                }
                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spacingXs
                    Glyph {
                        visible: (seg.modelData.icon ?? "").length > 0
                        icon: seg.modelData.icon ?? ""
                        size: Theme.iconSm
                        color: seg.isCurrent ? Theme.onBrand : Theme.textSoft
                    }
                    UiText {
                        text: seg.modelData.label
                        size: Theme.sizeCaption + 1
                        weight: Theme.weightMedium
                        color: seg.isCurrent ? Theme.onBrand : Theme.textSoft
                    }
                }
                MouseArea {
                    id: segMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selected(seg.modelData.key)
                }
            }
        }
    }
}
