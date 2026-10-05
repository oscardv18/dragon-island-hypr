// Dashboard header: "Buenas tardes, <name>" · date · host · uptime | lock · suspend · power (red tint)
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"
import "../../components"

RowLayout {
    id: root
    property string screenName: ""

    spacing: Theme.spacingSm

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingXs / 2

        UiText {
            Layout.fillWidth: true
            text: `${Clock.greeting}, ${Session.userName}`
            size: Theme.sizeGreeting
            weight: Theme.weightSemiBold
        }
        UiText {
            Layout.fillWidth: true
            text: [Clock.fullDate, Session.hostName, Clock.uptimeFormatted ? `activo ${Clock.uptimeFormatted}` : ""]
                  .filter(s => s.length > 0).join("  ·  ")
            size: Theme.sizeBody
            color: Theme.textDim
        }
    }

    IconButton {
        icon: Icons.lock
        onClicked: { ShellState.close(); Session.lock(); }
    }
    IconButton {
        icon: Icons.sleep
        onClicked: { ShellState.close(); Session.suspend(); }
    }
    IconButton {
        icon: Icons.power
        iconColor: Theme.error
        bgColor: Theme.errorTint
        hoverColor: Theme.alpha(Theme.error, 0.28)
        onClicked: ShellState.open("power", root.screenName)
    }
}
