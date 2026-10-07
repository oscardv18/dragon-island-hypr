// Calendar strip: month (caption) + 5 days around today (today = brand gradient) + next event or "Nada para hoy".
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"
import "../../components"

ColumnLayout {
    id: root
    spacing: Theme.spacingXs

    readonly property date today: Clock.currentDate
    readonly property var todays: Clock.eventsFor(today)
    // first event that has not ended its start time yet (all-day events always count)
    readonly property var nextEvent: todays.find(e => e.allDay || e.time.split("–")[0] >= Clock.time) ?? null

    Component.onCompleted: {
        Clock.requestMonth(today.getFullYear(), today.getMonth());
        Clock.refreshEvents();
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingSm

        ColumnLayout {
            Layout.fillWidth: false
            Layout.preferredWidth: 56
            Layout.maximumWidth: 56
            spacing: 0
            UiText {
                Layout.fillWidth: true
                caption: true
                text: Clock.monthsShort[root.today.getMonth()]
                color: Theme.accent
            }
            UiText {
                Layout.fillWidth: true
                text: `${root.today.getFullYear()}`
                mono: true
                size: Theme.sizeCaption + 1
                color: Theme.textDim
            }
        }

        Repeater {
            model: 5
            delegate: Item {
                id: day
                required property int index
                readonly property date date: new Date(root.today.getFullYear(), root.today.getMonth(), root.today.getDate() + index - 2)
                readonly property bool isToday: index === 2
                readonly property bool hasEvents: Clock.eventsFor(date).length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: 42

                BrandFill {
                    anchors.fill: parent
                    radius: Theme.capsuleRadius + 2
                    visible: day.isToday
                }
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.capsuleRadius + 2
                    visible: !day.isToday
                    color: Theme.surface2
                }
                Column {
                    anchors.centerIn: parent
                    spacing: 0
                    UiText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Clock.daysShort[day.date.getDay()].slice(0, 3).toUpperCase()
                        size: Theme.sizeCaption - 1
                        weight: Theme.weightSemiBold
                        color: day.isToday ? Theme.alpha(Theme.onBrand, 0.85) : Theme.textDim
                    }
                    UiText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: `${day.date.getDate()}`
                        mono: true
                        size: Theme.sizeBodyLg
                        weight: day.isToday ? Theme.weightBold : Theme.weightMedium
                        color: day.isToday ? Theme.onBrand : Theme.text
                    }
                }
                // day with events
                Rectangle {
                    visible: day.hasEvents && !day.isToday
                    width: Theme.pillDot
                    height: width
                    radius: width / 2
                    color: Theme.cyan
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 3
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingSm
        Rectangle {
            visible: root.nextEvent !== null
            Layout.preferredWidth: 3
            Layout.preferredHeight: 14
            radius: 1.5
            color: Theme.cyan
        }
        UiText {
            Layout.fillWidth: true
            text: root.nextEvent ? `${root.nextEvent.allDay ? "Hoy" : root.nextEvent.time.split("–")[0]} · ${root.nextEvent.title}` : "Nada para hoy"
            size: Theme.sizeCaption + 1
            color: root.nextEvent ? Theme.textSoft : Theme.textDim
        }
    }
}
