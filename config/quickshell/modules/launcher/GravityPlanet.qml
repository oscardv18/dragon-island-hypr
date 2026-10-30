// =============================================================================
// dragon-island — GravityPlanet.qml: one app on a ring of the Gravity launcher (docs/design/02-launcher.png)
// Everything it needs comes from the view (GravityView): ring geometry, the ring's turn, the hover / selection and
// the search pull. Size = base of its ring × frecency (0.85–1.25) × depth; the back half is smaller, dimmer, blurred
// and sits under the core (negative z). Moons = its open windows (3 at most, then «+N»).
// =============================================================================
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import "../.."
import "../../components"

Item {
    id: planet

    required property var host            // GravityView
    required property var app             // { id, name, icon, frec, windows }
    required property int ring
    required property int slot
    required property int count            // planets on this ring

    readonly property real gs: host.gs
    readonly property real rx: Theme.gravityRingRx[ring] * gs * host.reveal
    readonly property real ry: Theme.gravityRingRy[ring] * gs * host.reveal
    readonly property real theta: 2 * Math.PI * slot / Math.max(1, count) + host.ringAngle(ring)
    readonly property real depth: Math.sin(theta)                  // +1 front (bottom of the ellipse), −1 back
    readonly property real front: (depth + 1) / 2

    readonly property bool hovered: host.hoverKey === app.id
    readonly property bool selected: host.selKey === app.id
    // search: 1 = pulled next to the core (a match), −1 = pushed out as a ghost, 0 = on its orbit
    readonly property real pull: host.pullOf(app.id)
    readonly property real attract: Math.max(0, pull)
    readonly property real ghost: Math.max(0, -pull)

    readonly property real orbitX: host.cx + Math.cos(theta) * rx
    readonly property real orbitY: host.cy + Math.sin(theta) * ry
    readonly property point dock: host.dockPoint(app.id)          // where a match sits while searching

    readonly property real useScale: Theme.gravityUseMin + (Theme.gravityUseMax - Theme.gravityUseMin) * (app.frec || 0)
    readonly property real depthScale: Theme.gravityBackScale + (1 - Theme.gravityBackScale) * front
    readonly property real size: Theme.gravityPlanet[ring] * gs * useScale
        * (attract > 0 ? 1 + attract * (host.dockSize(app.id) - 1) : depthScale)
        * (hovered ? Theme.gravityHoverScale : 1)

    readonly property real cxp: orbitX + (dock.x - orbitX) * attract
    readonly property real cyp: orbitY + (dock.y - orbitY) * attract

    width: size
    height: size
    x: cxp - width / 2
    y: cyp - height / 2
    z: hovered || attract > 0.5 ? 30 : (depth >= 0 ? 5 + depth : -3 + depth)
    visible: host.reveal > 0.01 && ghost < 0.99
    opacity: (attract > 0 ? 1 : Theme.gravityBackOpacity + (1 - Theme.gravityBackOpacity) * front) * host.reveal * (1 - ghost)

    readonly property real blurAmount: attract > 0 || hovered ? 0 : Theme.gravityBackBlur * Math.max(0, -depth)

    // cyan halo: hovered / selected
    Rectangle {
        visible: planet.hovered || planet.selected
        anchors.centerIn: parent
        width: parent.width + Theme.gravityHalo * planet.gs
        height: width
        radius: width * 0.3
        color: Theme.transparent
        border.width: 1.5
        border.color: planet.hovered ? Theme.cyan : Theme.gravitySelectionEdge
        antialiasing: true
    }

    // the icon (the theme's rounded square is the planet)
    Item {
        id: body
        anchors.fill: parent
        layer.enabled: planet.blurAmount > 0.06
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: planet.blurAmount
            blurMax: 12
        }

        Rectangle {
            anchors.fill: parent
            visible: img.status !== Image.Ready
            radius: width * 0.28
            color: Theme.gravityTile
            border.width: 1
            border.color: Theme.gravityTileEdge
            UiText {
                anchors.centerIn: parent
                text: (planet.app.name || "?").charAt(0).toUpperCase()
                size: parent.width * 0.42
                weight: Theme.weightSemiBold
                color: Theme.textSoft
            }
        }
        Image {
            id: img
            anchors.fill: parent
            source: planet.app.icon || ""
            sourceSize: Qt.size(128, 128)      // one high-res decode, crisp at every depth (cached by the engine)
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            asynchronous: true
            cache: true
        }
    }

    // moons: one per open window, on a dashed orbit around the planet
    readonly property int moons: (app.windows || []).length
    readonly property real moonOrbit: width + Theme.gravityMoonOrbit * gs
    Shape {
        visible: planet.moons > 0 && planet.ghost === 0
        anchors.centerIn: parent
        width: planet.moonOrbit
        height: width
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Theme.alpha(Theme.cyan, 0.35)
            strokeWidth: 1
            strokeStyle: ShapePath.DashLine
            dashPattern: [2, 3]
            fillColor: Theme.transparent
            PathAngleArc { centerX: planet.moonOrbit / 2; centerY: planet.moonOrbit / 2; radiusX: planet.moonOrbit / 2; radiusY: planet.moonOrbit / 2; startAngle: 0; sweepAngle: 360 }
        }
    }
    Repeater {
        model: planet.ghost === 0 ? Math.min(planet.moons, Theme.gravityMaxMoons) : 0
        delegate: Rectangle {
            required property int index
            readonly property real a: host.moonAngle + index * 2 * Math.PI / Math.min(planet.moons, Theme.gravityMaxMoons) + planet.slot
            width: Theme.gravityMoon * planet.gs * (0.8 + 0.2 * planet.front)
            height: width
            radius: width / 2
            color: Theme.cyan
            x: planet.width / 2 + Math.cos(a) * planet.moonOrbit / 2 - width / 2
            y: planet.height / 2 + Math.sin(a) * planet.moonOrbit / 2 - height / 2
        }
    }
    UiText {
        visible: planet.moons > Theme.gravityMaxMoons && planet.ghost === 0
        anchors { left: parent.right; bottom: parent.top; leftMargin: -2; bottomMargin: -6 }
        text: `+${planet.moons - Theme.gravityMaxMoons}`
        mono: true
        size: Theme.sizeCaption
        color: Theme.cyan
    }

    // name under a match while searching
    UiText {
        visible: planet.attract > 0.6
        opacity: planet.attract
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.bottom; topMargin: Theme.spacingSm * planet.gs }
        text: planet.app.name || ""
        size: (planet.selected ? Theme.sizeTitle + 2 : Theme.sizeBody) * Math.max(1, planet.gs)
        weight: planet.selected ? Theme.weightSemiBold : Theme.weightRegular
        color: planet.selected ? Theme.text : Theme.textSoft
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onEntered: planet.host.hoverKey = planet.app.id
        onExited: if (planet.host.hoverKey === planet.app.id) planet.host.hoverKey = ""
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) planet.host.closeRequested();
            else planet.host.launch(planet.app.id);
        }
        onWheel: wheel => planet.host.wheel(planet.ring, wheel.angleDelta.y)
    }
}
