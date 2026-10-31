// =============================================================================
// dragon-island — GravityModes.qml: the «MODOS» panel of the Gravity launcher while searching (03-busqueda.png)
// One row per prefix (= > ? : @ /) with its coloured chip; the active mode is lit. In the calculator a card under
// the list shows the operation and its result (the first result of dragon-search calc).
// =============================================================================
import QtQuick
import "../.."
import "../../services"
import "../../components"

Rectangle {
    id: root

    property real gs: 1

    width: Theme.gravityModesWidth * gs
    height: col.implicitHeight + Theme.gravityPanelPad * gs * 2
    radius: Theme.gravityPanelRadius * gs
    color: Theme.gravityPanel
    border.width: 1
    border.color: Theme.gravityTileEdge

    readonly property var calc: Search.mode === "calc" && Search.results.length > 0 && Search.results[0].kind === "calc" ? Search.results[0] : null

    Column {
        id: col
        x: Theme.gravityPanelPad * root.gs
        y: Theme.gravityPanelPad * root.gs
        width: parent.width - x * 2
        spacing: Theme.spacingXs * root.gs

        UiText {
            text: "MODOS"
            mono: true
            size: Theme.sizeCaption * Math.max(1, root.gs)
            color: Theme.textDim
            font.letterSpacing: 2.4 * root.gs
            bottomPadding: Theme.spacingXs * root.gs
        }

        Repeater {
            model: Search.modes
            delegate: Rectangle {
                id: row
                required property var modelData
                readonly property bool current: Search.prefix === modelData.prefix
                readonly property color tint: Theme.searchModeColors[modelData.prefix]
                width: parent.width
                height: Theme.gravityModeRow * root.gs
                radius: Theme.gravityRowRadius * root.gs
                color: current ? Theme.alpha(tint, 0.10) : Theme.transparent
                border.width: current ? 1 : 0
                border.color: Theme.alpha(tint, 0.45)

                Rectangle {
                    id: chip
                    x: Theme.spacingXs * root.gs
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.gravityChip * 1.4 * root.gs
                    height: width
                    radius: Theme.keyCapRadius * root.gs
                    color: Theme.alpha(row.tint, 0.12)
                    border.width: 1
                    border.color: Theme.alpha(row.tint, 0.45)
                    UiText {
                        anchors.centerIn: parent
                        text: row.modelData.prefix
                        mono: true
                        size: Theme.sizeBodyLg * Math.max(1, root.gs)
                        weight: Theme.weightSemiBold
                        color: row.tint
                    }
                }
                UiText {
                    anchors { left: chip.right; leftMargin: Theme.spacingMd * root.gs; verticalCenter: parent.verticalCenter; right: parent.right }
                    text: row.modelData.label
                    size: Theme.sizeBodyLg * Math.max(1, root.gs)
                    color: row.current ? Theme.text : Theme.textSoft
                }
            }
        }

        // calculator: the operation and its result
        Item { width: 1; height: Theme.spacingSm * root.gs; visible: root.calc !== null }
        Rectangle {
            visible: root.calc !== null
            width: parent.width
            height: calcCol.implicitHeight + Theme.spacingMd * root.gs * 2
            radius: Theme.gravityRowRadius * root.gs
            color: Theme.alpha(Theme.warn, 0.08)
            border.width: 1
            border.color: Theme.alpha(Theme.warn, 0.45)
            Column {
                id: calcCol
                x: Theme.spacingLg * root.gs
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x * 2
                UiText {
                    width: parent.width
                    text: `= ${root.calc?.sub ?? Search.query}`
                    mono: true
                    size: Theme.sizeBody * Math.max(1, root.gs)
                    color: Theme.warn
                }
                UiText {
                    width: parent.width
                    text: root.calc?.title ?? ""
                    mono: true
                    size: Theme.sizeGreeting * Math.max(1, root.gs)
                    weight: Theme.weightSemiBold
                    color: Theme.text
                }
            }
        }
    }
}
