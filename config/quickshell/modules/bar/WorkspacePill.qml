// Workspace pill: height 22, radius 8.
// active: brand gradient + name + glow · occupied: surface3 + 4 px coloured dot · empty: textDim, no background.
// Width and colour change over 200 ms OutCubic.
import QtQuick
import QtQuick.Effects
import "../.."
import "../../services"
import "../../components"

Item {
    id: pill

    required property int index
    readonly property var ws: Hypr.workspaces[index] ?? null
    readonly property int wsId: index + 1
    readonly property bool active: ws?.active ?? false
    readonly property bool occupied: ws?.occupied ?? false
    readonly property bool urgent: ws?.urgent ?? false
    readonly property string name: ws?.name ?? `${wsId}`
    readonly property color dotColor: urgent ? Theme.error : Theme.wsDotColors[index % Theme.wsDotColors.length]

    implicitHeight: Theme.pillHeight
    implicitWidth: active ? Math.max(Theme.pillActiveMinWidth, label.implicitWidth + Theme.pillPadH * 2)
                          : Math.max(Theme.pillMinWidth, content.implicitWidth + Theme.pillPadH * 2)
    width: implicitWidth
    height: implicitHeight
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    Behavior on implicitWidth { NumberAnimation { duration: Theme.durPill; easing.type: Easing.OutCubic } }

    RectangularShadow {
        anchors.fill: brand
        radius: Theme.pillRadius
        blur: Theme.glowBlurSmall
        color: Theme.glowStrong
        opacity: pill.active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durPill } }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.pillRadius
        color: pill.occupied ? Theme.surface3 : Theme.transparent
        opacity: pill.active ? 0 : 1
        Behavior on color { ColorAnimation { duration: Theme.durPill; easing.type: Easing.OutCubic } }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.pillRadius
        color: Theme.hoverOverlay
        visible: mouse.containsMouse && !pill.active
    }

    BrandFill {
        id: brand
        anchors.fill: parent
        radius: Theme.pillRadius
        opacity: pill.active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durPill; easing.type: Easing.OutCubic } }
    }

    // inactive content: [dot] number
    Row {
        id: content
        anchors.centerIn: parent
        spacing: Theme.spacingXs
        opacity: pill.active ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.durPill } }

        Rectangle {
            visible: pill.occupied || pill.urgent
            width: Theme.pillDot
            height: Theme.pillDot
            radius: width / 2
            color: pill.dotColor
            anchors.verticalCenter: parent.verticalCenter
        }
        UiText {
            text: `${pill.wsId}`
            mono: true
            size: Theme.sizeCaption
            weight: Theme.weightSemiBold
            color: pill.occupied ? Theme.textSoft : Theme.textDim
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // active content: name
    UiText {
        id: label
        anchors.centerIn: parent
        text: pill.name
        mono: true
        size: Theme.sizeCaption
        weight: Theme.weightBold
        color: Theme.onBrand
        opacity: pill.active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durPill } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Hypr.focusWorkspace(pill.wsId)
    }
}
