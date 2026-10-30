// Workspace constellation (replaces the workspace pills): five nodes joined by a 1 px lavender line.
//   empty     5 px ring, 1 px, muted
//   occupied  5 px dot, textSoft; a 3 px cyan moon at the top right when the workspace has more than one window
//   active    an 18 px planet (12 in style D): 150° gradient violetBase 34 % → cyan 20 %, 1 px lavender 60 % inner
//             border, a soft 10 px halo and the main app's icon in white; it TRAVELS to the new node (curveOrbita)
//   urgent    the node pulses in warn
// Hover: white dot on a white 8 % disc, and the existing preview (WorkspacePreview, 350 ms) under that node.
// Click = go to the workspace · wheel = previous / next.
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell.Widgets
import "../.."
import "../../services"

Item {
    id: root

    property bool compact: false       // style D
    property real islandX: 0           // screen x of the island's window
    property string screenName: ""

    readonly property real pitch: Theme.barNodePitch     // 20 / 22 / 24 (D: 14 / 16 / 18)
    readonly property real planet: Theme.barPlanet       // 18 / 20 / 22 (D: 12 / 14 / 16)
    readonly property int count: Hypr.workspaceCount
    readonly property int activeIndex: Math.max(0, Math.min(count - 1, Hypr.focusedWorkspaceId - 1))
    readonly property bool activeShown: Hypr.focusedWorkspaceId >= 1 && Hypr.focusedWorkspaceId <= count

    implicitWidth: (count - 1) * pitch + root.planet
    implicitHeight: root.planet
    width: implicitWidth
    height: implicitHeight

    function nodeX(i: int): real { return root.planet / 2 + i * root.pitch; }

    // the line through the nodes: lavender 40 % → 12 %
    Rectangle {
        x: root.nodeX(0)
        width: root.nodeX(root.count - 1) - x
        height: 1
        anchors.verticalCenter: parent.verticalCenter
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Theme.alpha(Theme.lavender, 0.40) }
            GradientStop { position: 1.0; color: Theme.alpha(Theme.lavender, 0.12) }
        }
    }

    Repeater {
        model: root.count
        delegate: Item {
            id: node
            required property int index
            readonly property var ws: Hypr.workspaces[index] ?? null
            readonly property int wsId: index + 1
            readonly property bool occupied: ws?.occupied ?? false
            readonly property bool urgent: ws?.urgent ?? false
            readonly property bool many: (ws?.windows ?? 0) > 1
            readonly property bool hovered: nodeMouse.containsMouse
            readonly property bool isActive: index === root.activeIndex && root.activeShown

            x: root.nodeX(index) - width / 2
            width: root.pitch
            height: root.planet
            anchors.verticalCenter: parent.verticalCenter

            // hover disc, white 8 %
            Rectangle {
                anchors.centerIn: parent
                width: Theme.barNode + 9
                height: width
                radius: width / 2
                color: Theme.hoverOverlay
                opacity: node.hovered && !node.isActive ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.durHover } }
            }

            // empty: ring · occupied: dot
            Rectangle {
                id: dot
                anchors.centerIn: parent
                width: Theme.barNode
                height: Theme.barNode
                radius: width / 2
                color: node.urgent ? Theme.warn : (node.occupied ? (node.hovered ? Theme.text : Theme.textSoft) : Theme.transparent)
                border.width: node.occupied || node.urgent ? 0 : 1
                border.color: node.hovered ? Theme.text : Theme.muted
                Behavior on color { ColorAnimation { duration: Theme.durHover } }
                SequentialAnimation on scale {
                    running: node.urgent && Theme.animationsEnabled
                    loops: Animation.Infinite
                    onStopped: dot.scale = 1
                    NumberAnimation { to: 1.6; duration: Theme.ms(520); easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: Theme.ms(520); easing.type: Easing.InOutSine }
                }
            }

            // moon: more than one window
            Rectangle {
                visible: node.occupied && node.many && !node.isActive
                x: parent.width / 2 + 2
                y: parent.height / 2 - 6
                width: 3
                height: 3
                radius: 1.5
                color: Theme.cyan
            }

            MouseArea {
                id: nodeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Hypr.focusWorkspace(node.wsId)
                onContainsMouseChanged: {
                    if (containsMouse) WorkspacePreview.show(node.wsId, node.mapToItem(null, node.width / 2, 0).x + root.islandX, root.screenName);
                    else WorkspacePreview.hide();
                }
            }
        }
    }

    // ---- the planet: travels between nodes with the Órbita curve ----
    Item {
        id: planetItem
        visible: root.activeShown
        width: root.planet
        height: root.planet
        anchors.verticalCenter: parent.verticalCenter
        x: root.nodeX(root.activeIndex) - width / 2
        Behavior on x {
            enabled: Theme.animationsEnabled
            NumberAnimation { duration: Theme.durOrbit; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveOrbita }
        }

        readonly property var wins: Hypr.windowsOn(Hypr.focusedWorkspaceId)
        readonly property string mainIcon: wins.length > 0 ? (wins.find(w => !w.floating) ?? wins[0]).icon : ""

        // soft 10 px halo
        RectangularShadow {
            anchors.fill: disc
            radius: width / 2
            blur: 10
            color: Theme.alpha(Theme.violetBase, 0.35)
        }

        // 150° gradient: violetBase 34 % → cyan 20 %
        Shape {
            id: disc
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            readonly property real _h: (width * 0.5 + height * 0.866) / 2
            ShapePath {
                strokeWidth: 1
                strokeColor: Theme.alpha(Theme.lavender, 0.6)
                fillGradient: LinearGradient {
                    x1: disc.width / 2 - 0.5 * disc._h
                    y1: disc.height / 2 - 0.866 * disc._h
                    x2: disc.width / 2 + 0.5 * disc._h
                    y2: disc.height / 2 + 0.866 * disc._h
                    GradientStop { position: 0.0; color: Theme.alpha(Theme.violetBase, 0.34) }
                    GradientStop { position: 1.0; color: Theme.alpha(Theme.cyan, 0.20) }
                }
                PathAngleArc {
                    centerX: disc.width / 2
                    centerY: disc.height / 2
                    radiusX: disc.width / 2 - 0.5
                    radiusY: disc.height / 2 - 0.5
                    startAngle: 0
                    sweepAngle: 360
                }
            }
        }

        // the main app of the workspace, in white
        IconImage {
            id: appIcon
            anchors.centerIn: parent
            implicitSize: Theme.barPlanetIcon
            source: planetItem.mainIcon
            asynchronous: true
            visible: false
        }
        MultiEffect {
            anchors.fill: appIcon
            source: appIcon
            visible: planetItem.mainIcon.length > 0
            brightness: 1.0
            colorization: 1.0
            colorizationColor: Theme.text
        }
        Rectangle {   // empty workspace: a small lavender core instead of an icon
            visible: planetItem.mainIcon.length === 0
            anchors.centerIn: parent
            width: 4
            height: 4
            radius: 2
            color: Theme.lavenderInk
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Hypr.focusWorkspace(Hypr.focusedWorkspaceId)
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: e => Hypr.focusRelative(e.angleDelta.y > 0 ? -1 : 1)
    }
}
