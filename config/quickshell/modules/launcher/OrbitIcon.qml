// One app icon on the orbital launcher's ring. The ring is drawn by TWO windows: the icons at the back
// (half "back": OrbitBack.qml, mapped BELOW the planet's glass window, so they really pass behind the disc and
// are seen blurred through the glass) and the ones in front (half "front": Launcher.qml, above the planet).
// Both run the same maths from the Launcher's state (`launcher`), and an icon shows in exactly one of them.
import QtQuick
import QtQuick.Effects
import "../.."
import "../../services"
import "../../components"

Item {
    id: icon

    required property var launcher
    required property string half          // "back" | "front"
    required property var modelData
    readonly property int idx: launcher.ringEntries.indexOf(modelData)
    readonly property bool present: idx >= 0 && launcher.shown
    readonly property int ring: idx < Theme.orbitInner ? 1 : 2
    readonly property real j: ring === 1 ? idx : idx - Theme.orbitInner
    readonly property real n: ring === 1 ? launcher.n1 : launcher.n2

    // slot and ring size are animated, so the icons glide to their new places when the results change
    property real aj: j
    property real an: Math.max(1, n)
    Behavior on aj { enabled: icon.present && Theme.animationsEnabled; SpringAnimation { spring: Theme.notchSpring; damping: Theme.notchDamping } }
    Behavior on an { enabled: icon.present && Theme.animationsEnabled; SpringAnimation { spring: Theme.notchSpring; damping: Theme.notchDamping } }

    readonly property real theta: (ring === 1 ? launcher.spin1 : launcher.spin2) + 2 * Math.PI * aj / an
    readonly property real depth: Math.sin(theta)                   // 1 = in front, -1 = behind the planet
    readonly property bool behind: depth < -0.15                    // far enough from the sides to overlap the planet
    readonly property real k: (depth + 1) / 2
    readonly property real outer: ring === 2 ? 1 : 0
    readonly property real rx: Theme.orbitRx * (1 + 0.38 * outer)
    readonly property real ry: Theme.orbitRy * (1 + 0.5 * outer)
    readonly property real tilt: Theme.orbitTilt * Math.PI / 180
    readonly property real px: rx * Math.cos(theta)
    readonly property real py: ry * depth
    readonly property bool isFront: present && idx === launcher.frontIdx
    readonly property bool single: launcher.ringEntries.length === 1
    readonly property real boost: isFront && !launcher.auto ? (single ? 1.55 : 1.3) : 1

    x: (px * Math.cos(tilt) - py * Math.sin(tilt)) * launcher.ringProgress - width / 2
    y: (px * Math.sin(tilt) + py * Math.cos(tilt)) * launcher.ringProgress - height / 2
    width: Theme.orbitIcon
    height: Theme.orbitIcon
    z: depth
    scale: (0.6 + 0.55 * k) * (1 - 0.2 * outer) * boost * Math.min(1, launcher.ringProgress)
    opacity: present ? (0.4 + 0.6 * k) * (1 - 0.4 * outer) * Math.min(1, launcher.ringProgress) : 0
    visible: (present || opacity > 0.01) && behind === (half === "back")

    // accent glow behind the icon that is about to launch
    RectangularShadow {
        anchors.fill: parent
        radius: width / 2
        blur: Theme.glowBlurSmall * 2
        color: Theme.glowStrong
        opacity: icon.isFront && !launcher.auto ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durFade } }
    }

    // a circular glass pill behind the icon (the layer is glassed by alpha: hyprglass gives it the liquid-glass look)
    Rectangle {
        anchors.centerIn: parent
        width: Theme.orbitIcon + 32
        height: width
        radius: width / 2
        color: icon.isFront && !launcher.auto ? Theme.alpha(Theme.accent, 0.35) : Theme.pillBg
        Behavior on color { ColorAnimation { duration: Theme.durFade } }
    }
    Image {
        id: ico
        anchors.fill: parent
        source: icon.present || icon.opacity > 0.01 ? Apps.iconFor(icon.modelData) : ""
        sourceSize: Qt.size(Theme.orbitIcon * 2, Theme.orbitIcon * 2)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        mipmap: true
    }

    // a pinned app has a small accent dot
    Rectangle {
        visible: Apps.isFavorite(icon.modelData)
        width: Theme.pillDot + 1
        height: width
        radius: width / 2
        color: Theme.accent
        anchors.right: parent.right
        anchors.top: parent.top
    }

    // the name sits in a glass pill of its own, under the icon's pill (never over its edge)
    Rectangle {
        visible: icon.isFront
        anchors.top: parent.bottom
        anchors.topMargin: Theme.spacingMd + 12
        anchors.horizontalCenter: parent.horizontalCenter
        height: 28
        width: Math.min(Theme.orbitIcon * 4.5, nameText.implicitWidth + 28)
        radius: height / 2
        color: Theme.popoverBg
        UiText {
            id: nameText
            anchors.centerIn: parent
            width: parent.width - 20
            horizontalAlignment: Text.AlignHCenter
            text: icon.modelData.name
            size: Theme.sizeBody
            weight: Theme.weightSemiBold
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: icon.present && !icon.behind
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: m => {
            if (m.button === Qt.RightButton) Apps.toggleFavorite(icon.modelData);
            else launcher.launch(icon.modelData);
        }
    }
}
