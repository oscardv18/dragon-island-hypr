// Fecha y hora (docs/design/29-paneles-fecha.png): the clock with seconds and the full date · world clocks (Ajustes ›
// Apariencia › Relojes del mundo; «+» opens Ajustes) · the month with a dot under the days that have events (khal),
// month navigation (arrows, wheel) · the agenda of the chosen day (today by default) · «+ Evento» (khal new, through
// Clock) · timer, stopwatch and alarms (services/Timers.qml: the island tells when they are due) · «Enfoque 25».
// The notification centre is its own popover now (NotificationsPopover, SUPER + N); the bell chip opens it.
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"
import "../../components"

PopoverFrame {
    id: root
    title: "Fecha y hora"

    property int viewYear: Clock.currentDate.getFullYear()
    property int viewMonth: Clock.currentDate.getMonth()
    property date selected: new Date()
    readonly property var cells: Clock.monthGrid(viewYear, viewMonth)
    readonly property bool selectedIsToday: Clock.dayKey(selected) === Clock.todayKey
    readonly property var agenda: Clock.eventsFor(selected)
    property string tool: ""        // "" · "event" · "timer" · "alarm": the inline form under the chips

    function shift(delta: int): void {
        const d = new Date(viewYear, viewMonth + delta, 1);
        viewYear = d.getFullYear();
        viewMonth = d.getMonth();
        Clock.requestMonth(viewYear, viewMonth);
    }
    function cap(s: string): string { return s.charAt(0).toUpperCase() + s.slice(1); }

    onOpened: {
        Updates.refresh();
        const now = new Date();
        viewYear = now.getFullYear();
        viewMonth = now.getMonth();
        selected = now;
        tool = "";
        Clock.requestMonth(viewYear, viewMonth);
        Clock.refreshEvents();
    }

    headerRight: HudChip {
        visible: Notifs.count > 0
        icon: Icons.bell
        label: `${Notifs.count}`
        tone: Notifs.unreadCount > 0 ? Theme.cyan : Theme.textSoft
        onClicked: ShellState.toggleAt("notifications", ShellState.panelScreen, ShellState.anchorX, ShellState.anchorSide, ShellState.anchorCenter)
    }

    // ---- clock ----
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacingMd
        Row {
            Layout.alignment: Qt.AlignBottom
            Text {
                text: `${String(Clock.hours).padStart(2, "0")}:${String(Clock.minutes).padStart(2, "0")}`
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.sizeHero
                font.weight: Theme.weightSemiBold
            }
            Text {
                anchors.baseline: parent.children[0].baseline
                text: `:${String(Clock.seconds).padStart(2, "0")}`
                color: Theme.cyan
                font.family: Theme.fontMono
                font.pixelSize: Theme.sizeTitle + 2
                font.weight: Theme.weightMedium
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0
            UiText { text: root.cap(Clock.days[Clock.currentDate.getDay()]); weight: Theme.weightSemiBold }
            UiText { Layout.fillWidth: true; text: `${Clock.currentDate.getDate()} de ${Clock.monthName(Clock.currentDate.getMonth())} de ${Clock.currentDate.getFullYear()}`; color: Theme.textDim; size: Theme.sizeCaption + 1.5 }
        }
    }

    // ---- world clocks ----
    Flow {
        Layout.fillWidth: true
        spacing: Theme.spacingXs + 2
        Repeater {
            model: Clock.worldClocks
            delegate: Rectangle {
                required property var modelData
                implicitHeight: Theme.hudChip
                implicitWidth: wcRow.implicitWidth + Theme.spacingMd * 2
                radius: height / 2
                color: Theme.hudRowFill
                border.width: 1
                border.color: Theme.hudCardEdge
                Row {
                    id: wcRow
                    anchors.centerIn: parent
                    spacing: Theme.spacingXs + 1
                    UiText { text: modelData.time; mono: true; size: Theme.sizeCaption + 1.5; color: Theme.cyan; weight: Theme.weightMedium }
                    UiText { text: modelData.name + (modelData.dayShift > 0 ? " +1" : (modelData.dayShift < 0 ? " −1" : "")); size: Theme.sizeCaption + 1.5 }
                }
            }
        }
        HudChip { label: "+"; onClicked: { ShellState.open("settings", ShellState.panelScreen); } }
    }

    // ---- month ----
    HudCard {
        spacing: Theme.spacingXs
        RowLayout {
            Layout.fillWidth: true
            UiText { Layout.fillWidth: true; text: `${root.cap(Clock.monthName(root.viewMonth))} ${root.viewYear}`; weight: Theme.weightSemiBold }
            IconButton { icon: Icons.chevronLeft; size: Theme.hudChip - 6; iconSize: Theme.iconSm; onClicked: root.shift(-1) }
            IconButton { icon: Icons.chevronRight; size: Theme.hudChip - 6; iconSize: Theme.iconSm; onClicked: root.shift(1) }
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 7
            columnSpacing: 0
            rowSpacing: 2
            Repeater {
                model: Clock.weekdayLetters
                delegate: HudCaption { required property string modelData; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: modelData }
            }
            Repeater {
                model: root.cells
                delegate: Item {
                    id: cell
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: Theme.calendarCell - 4
                    readonly property bool isSelected: !modelData.isToday
                        && Clock.dayKey(root.selected) === Clock.dayKey(new Date(modelData.year, modelData.month, modelData.day))
                    Rectangle {
                        anchors.centerIn: parent
                        width: Theme.calendarCell + 8
                        height: Theme.calendarCell - 6
                        radius: 7
                        color: cell.modelData.isToday ? Theme.cyan : (cellMouse.containsMouse ? Theme.hudRowHover : Theme.transparent)
                        border.width: cell.isSelected ? 1 : 0
                        border.color: Theme.alpha(Theme.text, 0.45)
                    }
                    UiText {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -1
                        text: `${cell.modelData.day}`
                        mono: true
                        size: Theme.sizeCaption + 1.5
                        weight: cell.modelData.isToday ? Theme.weightBold : Theme.weightRegular
                        color: cell.modelData.isToday ? Theme.islandInk : (cell.modelData.inMonth ? Theme.text : Theme.muted)
                    }
                    Rectangle {
                        visible: cell.modelData.hasEvents
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 3
                        width: 3; height: 3; radius: 1.5
                        color: cell.modelData.isToday ? Theme.islandInk : Theme.textSoft
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
            WheelHandler { onWheel: e => root.shift(e.angleDelta.y > 0 ? -1 : 1) }
        }
    }

    // ---- agenda of the chosen day ----
    RowLayout {
        Layout.fillWidth: true
        HudCaption { Layout.fillWidth: true; text: root.selectedIsToday ? "Hoy" : `${Clock.days[root.selected.getDay()]} ${root.selected.getDate()} de ${Clock.monthName(root.selected.getMonth())}` }
        HudCaption { visible: Clock.eventsLoading; text: "cargando…" }
    }
    Repeater {
        model: root.agenda
        delegate: HudRow {
            required property var modelData
            required property int index
            clickable: false
            title: modelData.title
            leading: Row {
                spacing: Theme.spacingMd
                Rectangle { width: 3; height: Theme.hudRow - 14; radius: 1.5; anchors.verticalCenter: parent.verticalCenter
                    color: [Theme.cyan, Theme.lavender, Theme.warn][index % 3] }
                UiText { text: modelData.allDay ? "todo" : modelData.start; mono: true; size: Theme.sizeCaption + 1.5; color: Theme.lavender; width: 40; anchors.verticalCenter: parent.verticalCenter }
            }
            HudCaption { text: modelData.calendar; width: Math.min(implicitWidth, 70) }
        }
    }
    UiText {
        visible: root.agenda.length === 0
        Layout.fillWidth: true
        text: Clock.hasEventSource ? "Sin eventos" : (Clock.eventsError || "Sin calendario configurado")
        color: Theme.textDim
        size: Theme.sizeCaption + 1
    }

    // ---- tools ----
    Flow {
        Layout.fillWidth: true
        spacing: Theme.spacingXs + 2
        HudChip { visible: Clock.hasEventSource; label: "+ Evento"; active: root.tool === "event"; onClicked: root.tool = root.tool === "event" ? "" : "event" }
        HudChip {
            label: Timers.timerRunning ? `Temporizador ${Timers.format(Timers.timerRemaining)}` : "Temporizador"
            active: Timers.timerRunning || root.tool === "timer"
            onClicked: Timers.timerRunning ? Timers.stopTimer() : (root.tool = root.tool === "timer" ? "" : "timer")
        }
        HudChip {
            label: Timers.stopwatchRunning || Timers.stopwatchElapsed > 0 ? `Cronómetro ${Timers.format(Timers.stopwatchElapsed)}` : "Cronómetro"
            active: Timers.stopwatchRunning
            onClicked: Timers.toggleStopwatch()
        }
        HudChip { visible: Timers.stopwatchElapsed > 0 && !Timers.stopwatchRunning; label: "↺"; onClicked: Timers.resetStopwatch() }
        HudChip { label: Timers.nextAlarm ? `Alarma ${Timers.nextAlarm}` : "Alarma"; active: root.tool === "alarm"; onClicked: root.tool = root.tool === "alarm" ? "" : "alarm" }
        HudChip { label: Focus.active ? `Enfoque ${Math.ceil(Focus.remaining / 60)}` : "Enfoque 25"; active: Focus.active; onClicked: Focus.active ? Focus.stop() : Focus.start(25) }
    }

    // inline forms
    ColumnLayout {
        visible: root.tool === "event"
        Layout.fillWidth: true
        spacing: Theme.spacingXs + 2
        HudCaption { text: `Nuevo evento · ${root.selected.getDate()} de ${Clock.monthName(root.selected.getMonth())}` }
        InputField { id: evTitle; Layout.fillWidth: true; placeholder: "Título"; onAccepted: evSave.clicked(); onEscapePressed: root.tool = "" }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSm
            InputField { id: evStart; Layout.fillWidth: true; placeholder: "Inicio 10:00 (vacío = todo el día)"; onAccepted: evSave.clicked() }
            InputField { id: evEnd; Layout.preferredWidth: 90; placeholder: "Fin"; onAccepted: evSave.clicked() }
            HudChip {
                id: evSave
                label: "Crear"
                active: true
                enabled: evTitle.text.trim().length > 0
                onClicked: { Clock.createEvent(root.selected, evStart.text.trim(), evEnd.text.trim(), evTitle.text.trim()); evTitle.text = ""; evStart.text = ""; evEnd.text = ""; root.tool = ""; }
            }
        }
    }
    UiText { visible: Clock.lastCreateError.length > 0; Layout.fillWidth: true; text: Clock.lastCreateError; color: Theme.warn; size: Theme.sizeCaption + 1 }
    Flow {
        visible: root.tool === "timer"
        Layout.fillWidth: true
        spacing: Theme.spacingXs + 2
        Repeater {
            model: [1, 5, 10, 15, 25, 45]
            delegate: HudChip { required property int modelData; label: `${modelData} min`; onClicked: { Timers.startTimer(modelData); root.tool = ""; } }
        }
    }
    ColumnLayout {
        visible: root.tool === "alarm"
        Layout.fillWidth: true
        spacing: Theme.spacingXs + 2
        Repeater {
            model: Timers.alarms
            delegate: HudRow {
                required property var modelData
                clickable: false
                title: modelData.time
                ToggleSwitch { checked: modelData.on; onToggled: Timers.toggleAlarm(modelData.time) }
                HudChip { label: "Quitar"; tone: Theme.warn; onClicked: Timers.removeAlarm(modelData.time) }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSm
            InputField { id: alarmField; Layout.fillWidth: true; placeholder: "Nueva alarma 07:00"; onAccepted: alarmAdd.clicked(); onEscapePressed: root.tool = "" }
            HudChip { id: alarmAdd; label: "Añadir"; active: true; onClicked: { Timers.addAlarm(alarmField.text); alarmField.text = ""; } }
        }
    }
}
