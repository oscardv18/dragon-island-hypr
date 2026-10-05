// Calendario: clock with seconds · month grid (Mon first, L M X J V S D) · today = brand gradient,
// days with events = cyan ring · today's agenda
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"
import "../../components"

PopoverFrame {
    id: root
    popWidth: Theme.popoverWidthSm + Theme.spacingLg

    property int viewYear: Clock.currentDate.getFullYear()
    property int viewMonth: Clock.currentDate.getMonth()
    readonly property var cells: Clock.monthGrid(viewYear, viewMonth)

    function shift(delta: int): void {
        const d = new Date(viewYear, viewMonth + delta, 1);
        viewYear = d.getFullYear();
        viewMonth = d.getMonth();
    }

    onOpened: {
        viewYear = Clock.currentDate.getFullYear();
        viewMonth = Clock.currentDate.getMonth();
    }

    // clock with seconds
    RowLayout {
        Layout.fillWidth: true
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            UiText { text: Clock.timeWithSeconds; mono: true; size: Theme.sizeGreeting + Theme.spacingXs; weight: Theme.weightSemiBold }
            UiText { text: Clock.fullDate; color: Theme.textDim; Layout.fillWidth: true }
        }
    }

    // month header
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingXs
        UiText {
            Layout.fillWidth: true
            text: `${Clock.monthName(root.viewMonth).charAt(0).toUpperCase()}${Clock.monthName(root.viewMonth).slice(1)} ${root.viewYear}`
            size: Theme.sizeTitle
            weight: Theme.weightSemiBold
        }
        IconButton { icon: Icons.chevronLeft; size: Theme.capsuleHeight + Theme.spacingXs; iconSize: Theme.iconMd; onClicked: root.shift(-1) }
        IconButton { icon: Icons.chevronRight; size: Theme.capsuleHeight + Theme.spacingXs; iconSize: Theme.iconMd; onClicked: root.shift(1) }
    }

    GridLayout {
        id: grid
        Layout.fillWidth: true
        columns: 7
        columnSpacing: 0
        rowSpacing: Theme.spacingXs

        Repeater {
            model: Clock.weekdayLetters
            delegate: UiText {
                required property string modelData
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                caption: true
                text: modelData
            }
        }

        Repeater {
            model: root.cells
            delegate: Item {
                id: cell
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: Theme.calendarCell

                BrandFill {
                    anchors.centerIn: parent
                    width: Theme.calendarCell
                    height: Theme.calendarCell
                    radius: width / 2
                    visible: cell.modelData.isToday
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: Theme.calendarCell
                    height: Theme.calendarCell
                    radius: width / 2
                    color: Theme.transparent
                    border.width: 1.5
                    border.color: Theme.cyan
                    visible: cell.modelData.hasEvents && !cell.modelData.isToday
                }
                UiText {
                    anchors.centerIn: parent
                    text: `${cell.modelData.day}`
                    mono: true
                    size: Theme.sizeBody
                    weight: cell.modelData.isToday ? Theme.weightBold : Theme.weightRegular
                    color: cell.modelData.isToday ? Theme.onBrand : (cell.modelData.inMonth ? Theme.text : Theme.muted)
                }
            }
        }

        WheelHandler {
            onWheel: e => root.shift(e.angleDelta.y > 0 ? -1 : 1)
        }
    }

    // today's agenda
    Card {
        Layout.fillWidth: true
        UiText { caption: true; text: "Hoy" }
        Repeater {
            model: Clock.eventsFor(Clock.currentDate)
            delegate: UiText {
                required property var modelData
                Layout.fillWidth: true
                text: `${modelData.time ?? ""}  ${modelData.title ?? ""}`
            }
        }
        UiText {
            visible: Clock.eventsFor(Clock.currentDate).length === 0
            Layout.fillWidth: true
            text: Clock.hasEventSource ? "Sin eventos" : "Sin eventos · no hay calendario configurado"
            color: Theme.textDim
            size: Theme.sizeCaption + 1
        }
    }
}
