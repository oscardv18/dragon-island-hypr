// Popover container: surface0 94 % + blur (layer rule), radius 22, padding 18.
// Opens with opacity 0→1, translateY −10→0, scale 0.96→1, 280 ms OutBack, origin top-right.
import QtQuick
import QtQuick.Layouts
import ".."

Item {
    id: root

    property bool shown: false
    property string title: ""
    property real popWidth: Theme.popoverWidth
    default property alias content: body.data
    property alias headerRight: headerRight.data
    property real t: 0
    property real originX: width    // scale origin: top-right for popovers, centre for launcher/power
    readonly property Item frameItem: frame             // the visible card: the window's blur region follows it
    readonly property real frameRadius: Theme.popoverRadius

    signal opened()
    signal closed()

    width: popWidth
    implicitHeight: frame.implicitHeight
    height: implicitHeight
    visible: t > 0.001
    opacity: Math.min(1, Math.max(0, t))

    transform: [
        Scale {
            origin.x: root.originX
            origin.y: 0
            xScale: Theme.popoverScaleFrom + (1 - Theme.popoverScaleFrom) * root.t
            yScale: xScale
        },
        Translate { y: -Theme.popoverShift * (1 - root.t) }
    ]

    // Explicit animation (not a Behavior) so direction-dependent duration/easing are set before it starts
    NumberAnimation {
        id: anim
        target: root
        property: "t"
    }

    onShownChanged: {
        anim.stop();
        anim.to = shown ? 1 : 0;
        anim.duration = shown ? Theme.durPopover : Theme.durPopoverOut;
        anim.easing.type = shown ? Easing.OutBack : Easing.OutCubic;
        anim.start();
        if (shown) root.opened(); else root.closed();
    }

    Rectangle {
        id: frame
        width: parent.width
        implicitHeight: col.implicitHeight + Theme.popoverPad * 2
        height: implicitHeight
        radius: Theme.popoverRadius
        color: Theme.popoverBg
        border.width: 1
        border.color: Theme.hairline

        // swallow clicks so they don't reach the click-outside catcher underneath
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onWheel: w => w.accepted = true
        }

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: Theme.popoverPad
            spacing: Theme.spacingMd

            RowLayout {
                visible: root.title.length > 0
                Layout.fillWidth: true
                spacing: Theme.spacingSm

                UiText {
                    Layout.fillWidth: true
                    text: root.title
                    size: Theme.sizeTitle
                    weight: Theme.weightSemiBold
                }
                Row {
                    id: headerRight
                    spacing: Theme.spacingSm
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            ColumnLayout {
                id: body
                Layout.fillWidth: true
                spacing: Theme.spacingSm + Theme.spacingXs / 2
            }
        }
    }
}
