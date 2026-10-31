// The isla de mando (docs/design/31-isla-mando.png / 31-isla-mando-busqueda.png): the expanded notch.
//   header  the command line (34 px, chips = > ? @ IA; the SAME services/Search.qml as the launcher) and the compact
//           tabs Mando · Apps · IA on the right
//   body    Mando: priority stack · core · music · 6 h time strip · five toggles (CommandTab) — typing replaces it with up
//           to 4 results (↑ ↓ Enter, Esc goes back); Apps and IA keep their content (AppsTab, AiTab)
// Width = the notch body (shape minus ears); the height is fixed by the shape (Theme.notchExpandedHeight).
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../services"
import "../../components"

Item {
    id: root

    property string screenName: ""
    property string tab: ShellState.nookTab   // "nook" (Mando) | "apps" | "ia" (SUPER + ALT + A opens it on "ia")
    readonly property bool searching: line.active

    implicitWidth: Theme.notchExpandedWidth

    // ---- header: command line + tabs ----
    RowLayout {
        id: top
        x: Theme.notchPad
        y: Theme.spacingMd
        width: root.width - Theme.notchPad * 2
        height: Theme.cmdField
        spacing: Theme.spacingSm

        CommandLine {
            id: line
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.cmdField
            screenName: root.screenName
        }

        Repeater {
            model: [{ key: "nook", label: "Mando" }, { key: "apps", label: "Apps" }, { key: "ia", label: "IA" }]
            delegate: Item {
                id: tabItem
                required property var modelData
                readonly property bool current: root.tab === modelData.key && !root.searching
                Layout.preferredWidth: label.implicitWidth + Theme.spacingMd * 2
                Layout.preferredHeight: Theme.cmdTab
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: tabItem.current ? Theme.alpha(Theme.text, 0.10) : (tabMouse.containsMouse ? Theme.hudRowHover : Theme.transparent)
                    Behavior on color { ColorAnimation { duration: Theme.durHover } }
                }
                UiText {
                    id: label
                    anchors.centerIn: parent
                    text: tabItem.modelData.label
                    size: Theme.sizeCaption + 1.5
                    weight: tabItem.current ? Theme.weightSemiBold : Theme.weightRegular
                    color: tabItem.current ? Theme.text : Theme.textDim
                }
                MouseArea {
                    id: tabMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { line.clear(); root.tab = tabItem.modelData.key; }
                }
            }
        }
    }

    // ---- body ----
    Item {
        id: body
        x: Theme.notchPad
        y: top.y + top.height + Theme.spacingMd
        width: root.width - Theme.notchPad * 2
        height: Theme.notchExpandedHeight - y - Theme.spacingMd

        Loader {
            anchors.fill: parent
            sourceComponent: root.searching ? resultsView : (root.tab === "apps" ? appsTab : (root.tab === "ia" ? aiTab : mandoTab))
        }
    }

    Component { id: mandoTab; CommandTab { screenName: root.screenName; onAskAi: line.setMode("ia"); onGoTab: t => root.tab = t } }
    Component { id: appsTab; AppsTab {} }
    Component { id: aiTab; AiTab {} }
    Component { id: resultsView; CommandResults { cmd: line } }
}
