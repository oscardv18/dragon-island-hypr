// A rounded group of SettingsRow (Ajustes panel): white 3.5 % with a hairline border.
import QtQuick
import "../.."

Rectangle {
    default property alias rows: col.data
    implicitHeight: col.implicitHeight
    radius: Theme.cardRadius - 4
    color: Theme.alpha(Theme.text, 0.035)
    border.width: 1
    border.color: Theme.hairline
    Column { id: col; width: parent.width }
}
