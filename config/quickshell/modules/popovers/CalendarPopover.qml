// Calendario + notificaciones + actualizaciones. Left column: clock with seconds · month grid (Mon first, L M X J V S D) · today = brand gradient,
// days with events = cyan ring (khal) · agenda of the selected day (today by default)
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"
import "../../components"
import "../notifications"

PopoverFrame {
    id: root
    popWidth: Theme.calendarPopoverWidth

    property int viewYear: Clock.currentDate.getFullYear()
    property int viewMonth: Clock.currentDate.getMonth()
    property date selected: new Date()
    readonly property var cells: Clock.monthGrid(viewYear, viewMonth)
    readonly property bool selectedIsToday: Clock.dayKey(selected) === Clock.todayKey
    readonly property var agenda: Clock.eventsFor(selected)

    function shift(delta: int): void {
        const d = new Date(viewYear, viewMonth + delta, 1);
        viewYear = d.getFullYear();
        viewMonth = d.getMonth();
        Clock.requestMonth(viewYear, viewMonth);
    }

    onClosed: Notifs.markAllRead()

    onOpened: {
        Notifs.markAllRead();
        Updates.refresh();
        const now = new Date();
        viewYear = now.getFullYear();
        viewMonth = now.getMonth();
        selected = now;
        Clock.requestMonth(viewYear, viewMonth);
        Clock.refreshEvents();
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingLg

        // ---- calendar ----
        ColumnLayout {
            Layout.preferredWidth: Theme.popoverWidthSm + Theme.spacingLg - Theme.popoverPad * 2
            Layout.maximumWidth: Layout.preferredWidth
            Layout.fillWidth: false
            Layout.alignment: Qt.AlignTop
            spacing: Theme.spacingMd

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

                        readonly property bool isSelected: !modelData.isToday
                            && Clock.dayKey(root.selected) === Clock.dayKey(new Date(modelData.year, modelData.month, modelData.day))

                        Rectangle {
                            anchors.centerIn: parent
                            width: Theme.calendarCell
                            height: Theme.calendarCell
                            radius: width / 2
                            color: cellMouse.containsMouse || cell.isSelected ? Theme.surfaceHi : Theme.transparent
                        }
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
                        MouseArea {
                            id: cellMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selected = new Date(cell.modelData.year, cell.modelData.month, cell.modelData.day)
                        }
                    }
                }

                WheelHandler {
                    onWheel: e => root.shift(e.angleDelta.y > 0 ? -1 : 1)
                }
            }

            // agenda of the selected day
            Card {
                Layout.fillWidth: true
                RowLayout {
                    Layout.fillWidth: true
                    UiText {
                        Layout.fillWidth: true
                        caption: true
                        text: root.selectedIsToday ? "Hoy"
                              : `${Clock.days[root.selected.getDay()]} ${root.selected.getDate()} de ${Clock.monthName(root.selected.getMonth())}`
                    }
                    UiText {
                        visible: Clock.eventsLoading
                        text: "Cargando…"
                        size: Theme.sizeCaption
                        color: Theme.textDim
                    }
                }
                Repeater {
                    model: root.agenda
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Theme.spacingSm
                        Rectangle {
                            Layout.preferredWidth: Theme.pillDot
                            Layout.preferredHeight: Theme.calendarCell * 0.8
                            radius: width / 2
                            color: modelData.allDay ? Theme.violetSoft : Theme.cyan
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            UiText { Layout.fillWidth: true; text: modelData.title; weight: Theme.weightMedium }
                            UiText {
                                Layout.fillWidth: true
                                text: [modelData.time, modelData.location, modelData.calendar].filter(x => x.length > 0).join(" · ")
                                size: Theme.sizeCaption
                                color: Theme.textDim
                            }
                        }
                    }
                }
                UiText {
                    visible: root.agenda.length === 0
                    Layout.fillWidth: true
                    text: Clock.hasEventSource ? "Sin eventos" : (Clock.eventsError || "Sin calendario configurado")
                    color: Theme.textDim
                    size: Theme.sizeCaption + 1
                }
            }

        }

        Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: Theme.divider }

        // ---- notifications + updates ----
        NotificationsColumn {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
        }
    }
}
