// =============================================================================
// dragon-island — Dashboard.qml (inside the open island, 860 wide, padding 22 24 24)
// header · 3 columns [media + sliders] [2×3 toggles + power profile] [system + last 3 notifications] · grab handle
// =============================================================================
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"
import "../../components"

ColumnLayout {
    id: root

    property string screenName: ""

    spacing: Theme.dashColumnGap

    DashHeader {
        Layout.fillWidth: true
        screenName: root.screenName
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.dashColumnGap

        // ---- column 1: media + sliders ----
        ColumnLayout {
            Layout.preferredWidth: (root.width - Theme.dashColumnGap * 2) / 3
            Layout.maximumWidth: Layout.preferredWidth
            Layout.alignment: Qt.AlignTop
            spacing: Theme.spacingMd

            MediaCard { Layout.fillWidth: true }

            Card {
                Layout.fillWidth: true
                spacing: Theme.spacingMd

                Slider {
                    Layout.fillWidth: true
                    icon: Icons.volumeFor(Audio.volume, Audio.muted)
                    value: Audio.volume
                    dimmed: Audio.muted
                    enabled: Audio.sink !== null
                    onMoved: v => Audio.setVolume(v)
                    onIconClicked: Audio.toggleMute()
                }
                Slider {
                    Layout.fillWidth: true
                    visible: Brightness.available
                    icon: Icons.sun
                    value: Brightness.brightnessReal
                    onMoved: v => Brightness.setBrightnessReal(v)
                }
            }
        }

        // ---- column 2: toggles + power profile ----
        ColumnLayout {
            Layout.preferredWidth: (root.width - Theme.dashColumnGap * 2) / 3
            Layout.maximumWidth: Layout.preferredWidth
            Layout.alignment: Qt.AlignTop
            spacing: Theme.spacingMd

            QuickToggles {
                Layout.fillWidth: true
                screenName: root.screenName
            }

            Segmented {
                Layout.fillWidth: true
                model: Power.profiles.map(p => Object.assign({ icon: p.key === "power-saver" ? Icons.leaf : (p.key === "performance" ? Icons.rocket : Icons.balance) }, p))
                current: Power.currentProfileKey
                onSelected: key => Power.setProfileByName(key)
            }
        }

        // ---- column 3: system + notifications ----
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: Theme.spacingMd

            SystemCard { Layout.fillWidth: true }
            RecentNotifications {
                Layout.fillWidth: true
                screenName: root.screenName
            }
        }
    }

    // grab handle (48×5): click to close
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.handleHeight + Theme.spacingXs
        Rectangle {
            anchors.centerIn: parent
            width: Theme.handleWidth
            height: Theme.handleHeight
            radius: height / 2
            color: handleMouse.containsMouse ? Theme.textDim : Theme.muted
            Behavior on color { ColorAnimation { duration: Theme.durHover } }
        }
        MouseArea {
            id: handleMouse
            anchors.fill: parent
            anchors.margins: -Theme.spacingSm
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ShellState.close()
        }
    }
}
