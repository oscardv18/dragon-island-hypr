// Selector with a sliding pill (docs/design/28-emergentes.png: Ahorro · Equilibrado · Rendimiento): the same control
// for every choice of the shell (power profile, bar size, glass style, …). model = [{ key, label, icon?, available }].
// The pill slides to the chosen option (estandar curve); the chosen label is bright, the rest dim.
import QtQuick
import ".."

Rectangle {
    id: root
    property var model: []
    property string current: ""
    signal selected(string key)

    implicitHeight: Theme.capsuleHeight + Theme.spacingSm
    implicitWidth: Theme.popoverWidthSm
    radius: height / 2
    color: Theme.hudRowFill
    border.width: 1
    border.color: Theme.hudCardEdge

    readonly property int _n: Math.max(1, model.length)
    readonly property int _idx: Math.max(0, model.findIndex(m => m.key === root.current))
    readonly property real _segW: (width - Theme.spacingXs * 2) / _n

    // the sliding pill
    Rectangle {
        visible: root.model.findIndex(m => m.key === root.current) >= 0
        x: Theme.spacingXs + root._idx * root._segW
        y: Theme.spacingXs
        width: root._segW
        height: root.height - Theme.spacingXs * 2
        radius: height / 2
        color: Theme.alpha(Theme.cyan, 0.12)
        border.width: 1
        border.color: Theme.alpha(Theme.cyan, 0.45)
        Behavior on x { NumberAnimation { duration: Theme.durStd; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.curveEstandar } }
    }

    Row {
        x: Theme.spacingXs
        anchors.verticalCenter: parent.verticalCenter
        Repeater {
            model: root.model
            delegate: Item {
                id: seg
                required property var modelData
                readonly property bool isCurrent: modelData.key === root.current
                width: root._segW
                height: root.height - Theme.spacingXs * 2
                enabled: modelData.available !== false
                opacity: enabled ? 1 : 0.4

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    visible: !seg.isCurrent && segMouse.containsMouse
                    color: Theme.hoverOverlay
                }
                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spacingXs
                    Glyph {
                        visible: (seg.modelData.icon ?? "").length > 0
                        icon: seg.modelData.icon ?? ""
                        size: Theme.iconSm
                        color: seg.isCurrent ? Theme.text : Theme.textDim
                    }
                    UiText {
                        text: seg.modelData.label
                        size: Theme.sizeCaption + 1
                        weight: seg.isCurrent ? Theme.weightSemiBold : Theme.weightRegular
                        color: seg.isCurrent ? Theme.text : Theme.textDim
                        Behavior on color { ColorAnimation { duration: Theme.durStd } }
                    }
                }
                MouseArea {
                    id: segMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selected(seg.modelData.key)
                }
            }
        }
    }
}
