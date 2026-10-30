// =============================================================================
// dragon-island — Keyboard.qml
// Service: active keyboard layout (kb_layout "us,latam" in config/hypr/input.lua)
// =============================================================================
/**
 * Properties:
 *   - layoutName: string [readonly] (xkb description, e.g. "English (US)", "Spanish (Latin American)")
 *   - code: string [readonly] ("US" | "LA", otherwise the first two letters of the name; "" until known)
 *   - capsLock: bool [readonly] (any keyboard's Caps Lock LED is on: /sys/class/leds/*::capslock/brightness, read
 *       every 250 ms only while such a LED exists — sysfs has no change events; same idea as Brightness)
 *
 * Signals:
 *   - layoutSwitched(from: string, to: string) (codes, after the initial value is known)
 *
 * Functions:
 *   - next(): void   (hyprctl switchxkblayout all next)
 *
 * Follows Hyprland's `activelayout` event (data: "<keyboard>,<layout name>"); the initial value
 * comes from the main keyboard in `hyprctl -j devices`.
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: root

    property string layoutName: ""
    property string _lastCode: ""
    onCodeChanged: {
        if (root._lastCode.length > 0 && root.code.length > 0 && root.code !== root._lastCode) root.layoutSwitched(root._lastCode, root.code);
        root._lastCode = root.code;
    }
    signal layoutSwitched(from: string, to: string)

    // ---- Caps Lock: the LEDs of every keyboard (laptop + USB) ----
    property var _capsPaths: []
    property var _capsOn: ({})
    readonly property bool capsLock: Object.keys(root._capsOn).some(k => root._capsOn[k])

    Process {
        running: true
        command: ["sh", "-c", "for d in /sys/class/leds/*::capslock; do [ -r \"$d/brightness\" ] && echo \"$d/brightness\"; done"]
        stdout: StdioCollector { onStreamFinished: root._capsPaths = this.text.split("\n").filter(l => l.length > 0) }
    }
    Instantiator {
        id: capsFiles
        model: root._capsPaths
        delegate: FileView {
            required property string modelData
            path: modelData
            printErrors: false
            onLoaded: {
                const on = parseInt(text()) > 0;
                if (!!root._capsOn[modelData] === on) return;
                const c = Object.assign({}, root._capsOn);
                c[modelData] = on;
                root._capsOn = c;
            }
        }
    }
    Timer {
        interval: 250
        repeat: true
        running: root._capsPaths.length > 0
        onTriggered: { for (let i = 0; i < capsFiles.count; i++) capsFiles.objectAt(i)?.reload(); }
    }

    readonly property string code: {
        const n = root.layoutName.toLowerCase();
        if (n.length === 0) return "";
        if (n.includes("latin")) return "LA";
        if (n.includes("(us)")) return "US";
        return root.layoutName.slice(0, 2).toUpperCase();
    }

    function next(): void {
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]);
    }

    Process {
        running: true
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kbs = JSON.parse(this.text).keyboards ?? [];
                    const main = kbs.find(k => k.main) ?? kbs[0];
                    if (main && root.layoutName.length === 0) root.layoutName = main.active_keymap ?? "";
                } catch (e) {
                    console.warn(`Keyboard: could not read hyprctl devices: ${e}`);
                }
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activelayout") return;
            // "<keyboard name>,<layout name>": the layout name may itself contain commas
            const at = event.data.indexOf(",");
            if (at >= 0) root.layoutName = event.data.slice(at + 1);
        }
    }
}
