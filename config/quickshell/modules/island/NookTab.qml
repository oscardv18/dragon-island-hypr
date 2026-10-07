// Nook tab: media card | divider | [calendar strip · quick toggles · system stats]
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"
import "../../components"

RowLayout {
    id: root

    property string screenName: ""

    spacing: Theme.notchColGap

    MediaNook {
        Layout.preferredWidth: Theme.notchMediaWidth
        Layout.maximumWidth: Theme.notchMediaWidth
        Layout.fillHeight: true
    }

    Rectangle {
        Layout.preferredWidth: 1
        Layout.fillHeight: true
        color: Theme.divider
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Theme.spacingSm

        CalendarStrip { Layout.fillWidth: true }
        NotchToggles { Layout.fillWidth: true; screenName: root.screenName }
        NotchStats { Layout.fillWidth: true; Layout.fillHeight: true }
    }
}
