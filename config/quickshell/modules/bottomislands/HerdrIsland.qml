// Left bottom island: the state of the AI work in herdr + the code editors that are open.
// Pure visual (replica of the top bar's islands). Data in, signals out; the window owns popups.
//   [ ▣ workspaces ] [ ● working  ● blocked  ● done  ● idle ] [ claude 2 · codex 1 ] [ ⏱ longest ] │ [ editors ]
// Offline: "herdr sin conexión" (dim); the editors capsule still works.
import QtQuick
import "../.."
import "../../components"

Rectangle {
    id: root

    property bool online: false
    property var agents: []
    property var workspaces: []
    property var counts: ({ working: 0, blocked: 0, done: 0, idle: 0, unknown: 0 })
    property string longestText: ""            // "12 min" of the agent that has been working the longest ("" = none / unknown)
    property int editorCount: 0
    property string editorText: ""             // names, for the tooltip-less label (first editor)
    readonly property var states: ["working", "blocked", "done", "idle", "unknown"]
    readonly property var kinds: {                 // agent type → { total, working }
        const m = {}, order = [];
        for (const a of agents) {
            const k = a.agent || a.name || "?";
            if (!m[k]) { m[k] = { name: k, total: 0, working: 0 }; order.push(m[k]); }
            m[k].total++;
            if (a.state === "working") m[k].working++;
        }
        return order;
    }

    // see AppsIsland.pointerOver: hover belongs to the capsules' MouseAreas, not to the zone behind them
    readonly property bool pointerOver: offCap.hovered || aiCap.hovered || edCap.hovered

    signal agentsClicked(Item chip)
    signal editorsClicked(Item chip)

    implicitHeight: Theme.barHeight
    height: Theme.barHeight
    width: Theme.barIslandPadH * 2 + row.implicitWidth
    radius: Theme.barIslandRadius
    color: Theme.glassBg
    border.width: 1
    border.color: Theme.glassBorder

    Row {
        id: row
        x: Theme.barIslandPadH
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.barIslandGap

        // offline
        Capsule {
            id: offCap
            visible: !root.online
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.agentsClicked(offCap)
            UiText { anchors.verticalCenter: parent.verticalCenter; text: "herdr sin conexión"; size: Theme.sizeBar; color: Theme.textDim }
        }

        // online: workspaces + agents by state + types + longest
        Capsule {
            id: aiCap
            visible: root.online
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.agentsClicked(aiCap)

            UiText { anchors.verticalCenter: parent.verticalCenter; text: `${root.workspaces.length} ws`; mono: true; size: Theme.sizeBar; color: Theme.textSoft }
            Repeater {
                model: root.states
                delegate: Row {
                    required property string modelData
                    visible: (root.counts[modelData] ?? 0) > 0
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4; color: Theme.agentColor(modelData) }
                    UiText { anchors.verticalCenter: parent.verticalCenter; text: `${root.counts[modelData] ?? 0}`; mono: true; size: Theme.sizeBar }
                }
            }
            UiText {
                visible: root.agents.length === 0
                anchors.verticalCenter: parent.verticalCenter
                text: "0 agentes"
                size: Theme.sizeBar
                color: Theme.textDim
            }
            UiText {
                visible: root.kinds.length > 0
                anchors.verticalCenter: parent.verticalCenter
                text: root.kinds.map(k => `${k.name} ${k.working}/${k.total}`).join(" · ")
                size: Theme.sizeBar
                color: Theme.textSoft
            }
            UiText {
                visible: root.longestText !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: root.longestText
                mono: true
                size: Theme.sizeBar
                color: Theme.cyan
            }
        }

        // editors
        Capsule {
            id: edCap
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.editorsClicked(edCap)
            UiText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.editorCount === 0 ? "sin editores" : (root.editorCount === 1 ? root.editorText : `${root.editorCount} editores`)
                size: Theme.sizeBar
                color: root.editorCount === 0 ? Theme.textDim : Theme.text
            }
        }
    }
}
