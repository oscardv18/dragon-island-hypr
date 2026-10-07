# Quickshell patterns (0.3.1)

Every type and member used below was checked against `api/`. The snippets are building blocks, not a finished shell: adapt names and wire them to your own singletons. Run with `qs -p <folder>` and read the console for errors.

## 1. Entry point

```qml
// shell.qml
import Quickshell
import QtQuick
import "modules/bar"
import "modules/island"

ShellRoot {
    Variants {
        model: Quickshell.screens
        delegate: Component {
            Bar { property var modelData; screen: modelData }
        }
    }
    Variants {
        model: Quickshell.screens
        delegate: Component {
            IslandWindow { property var modelData; screen: modelData }
        }
    }
}
```

## 2. Global state + IPC (keybinds talk to the shell through this)

```qml
// ShellState.qml
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    // "none" | "dashboard" | "perf" | "wifi" | "bt" | "audio" | "battery" | "notifications" | "calendar" | "launcher" | "power"
    property string openPanel: "none"

    function toggle(name) { openPanel = (openPanel === name) ? "none" : name }
    function close() { openPanel = "none" }

    IpcHandler {
        target: "shell"
        // types MUST be annotated or the function is not registered
        function toggle(name: string): void { root.toggle(name) }
        function close(): void { root.close() }
        function current(): string { return root.openPanel }
    }
}
```

Hyprland side (Lua config): `hl.bind("SUPER + D", hl.dsp.exec_cmd("qs ipc call shell toggle dashboard"))`.

## 3. Floating bar with click-through gaps

The window spans the screen width but only the islands receive clicks; the gaps between them pass clicks to the desktop.

```qml
// modules/bar/Bar.qml
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: bar
    anchors { top: true; left: true; right: true }
    margins { top: 10; left: 14; right: 14 }
    implicitHeight: 40
    exclusiveZone: 46           // reserve space so tiled windows start below the bar
    color: "transparent"
    WlrLayershell.namespace: "dragon-bar"

    mask: Region {
        Region { item: leftIsland }
        Region { item: rightIsland }
    }

    LeftIsland  { id: leftIsland;  anchors.left: parent.left;   anchors.verticalCenter: parent.verticalCenter }
    RightIsland { id: rightIsland; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter }
}
```

## 4. Dynamic Island in its own overlay window

One full-screen transparent overlay per monitor. When closed, the mask is only the pill, so the rest of the screen is click-through. When open, the whole window takes input (scrim closes on click) and keyboard focus (Escape closes).

```qml
// modules/island/IslandWindow.qml
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: win
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "dragon-island"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property bool open: ShellState.openPanel === "dashboard"

    mask: open ? null : pillRegion
    Region { id: pillRegion; item: island }

    // scrim (only visible/clickable while open)
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: win.open ? 0.45 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 220 } }
        MouseArea { anchors.fill: parent; enabled: win.open; onClicked: ShellState.close() }
    }

    Item {
        anchors.fill: parent
        focus: win.open
        Keys.onEscapePressed: ShellState.close()
    }

    Island { id: island; open: win.open; anchors.horizontalCenter: parent.horizontalCenter }
}
```

### Island shape: drop-in + pour-from-the-edge

- Closed: pill 36 px tall, `y` = 10, fully rounded.
- Open: attached to the screen edge (`y` = 0), top corners square, bottom corners 34 px.
- Qt 6.7+ `Rectangle` supports per-corner radii (`topLeftRadius`, …); use them so the open panel looks like it hangs from the edge.

```qml
// modules/island/Island.qml (shape only)
import QtQuick

Rectangle {
    id: shape
    property bool open: false
    color: "#000000"
    border.color: Qt.rgba(0.77, 0.05, 0.82, 0.35)
    border.width: 1

    width:  open ? 860 : pillContent.implicitWidth + 24
    height: open ? dashboard.implicitHeight + 44 : 36
    y:      open ? 0 : 10
    topLeftRadius:     open ? 0 : 18
    topRightRadius:    open ? 0 : 18
    bottomLeftRadius:  open ? 34 : 18
    bottomRightRadius: open ? 34 : 18
    clip: true

    Behavior on width  { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
    Behavior on height { NumberAnimation { duration: 480; easing.type: Easing.OutCubic } }
    Behavior on y      { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    // first appearance: fall from above the screen edge with a small bounce
    Component.onCompleted: dropIn.start()
    SequentialAnimation {
        id: dropIn
        PropertyAction { target: shape; property: "y"; value: -60 }
        NumberAnimation { target: shape; property: "y"; to: 10; duration: 700; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
    }

    // content cross-fade: the dashboard appears after the shape has started growing
    PillContent { id: pillContent; anchors.centerIn: parent; opacity: shape.open ? 0 : 1
                  Behavior on opacity { NumberAnimation { duration: 120 } } }
    Dashboard   { id: dashboard; anchors.top: parent.top; anchors.topMargin: 22
                  anchors.horizontalCenter: parent.horizontalCenter
                  opacity: shape.open ? 1 : 0; visible: opacity > 0
                  Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 160 }
                                                             NumberAnimation { duration: 260 } } } }
}
```

Note: a `Behavior` on `y` will also animate the drop-in; if they fight, disable the Behavior during `dropIn` (`enabled: !dropIn.running`).

### Temporary island states (OSD, notification, workspace)

Keep a `transient` property in a singleton (`IslandState.mode`, `IslandState.payload`) and a `Timer` that resets it after ~2 s. The pill content switches with `Loader { sourceComponent: ... }` or `StackLayout`; width changes animate through the same Behaviors.

## 5. Popover under a bar capsule

Option A (simplest, consistent look): draw popovers inside the island overlay window, positioned under the capsule using coordinates mapped from the bar.

Option B: `PopupWindow` anchored to the capsule + `HyprlandFocusGrab` so clicking elsewhere closes it.

```qml
import Quickshell
import Quickshell.Hyprland
import QtQuick

PopupWindow {
    id: pop
    required property Item capsule
    required property string panelName
    anchor.item: capsule
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.margins.top: 8
    visible: ShellState.openPanel === panelName
    color: "transparent"
    implicitWidth: 360
    implicitHeight: content.implicitHeight

    HyprlandFocusGrab {
        windows: [ pop ]
        active: pop.visible
        onCleared: ShellState.close()
    }

    PopoverCard { id: content; anchors.fill: parent }
}
```

## 6. Services (singletons with no visuals)

### Audio (PipeWire) — nodes must be bound to read volume

```qml
// services/Audio.qml
pragma Singleton
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

Singleton {
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false

    function setVolume(v) { if (sink?.audio) sink.audio.volume = Math.max(0, Math.min(1, v)) }
    function toggleMute() { if (sink?.audio) sink.audio.muted = !sink.audio.muted }

    PwObjectTracker { objects: [ Pipewire.defaultAudioSink, Pipewire.defaultAudioSource ] }
}
```

Per-app mixer: filter `Pipewire.nodes.values` with `isStream && isSink === false && audio !== null` (check direction for your setup) and add them to a `PwObjectTracker`.

### Media (MPRIS)

```qml
pragma Singleton
import Quickshell
import Quickshell.Services.Mpris
import QtQuick

Singleton {
    // prefer a playing player, else the first one
    readonly property MprisPlayer player: {
        const ps = Mpris.players.values
        return ps.find(p => p.isPlaying) ?? ps[0] ?? null
    }
    readonly property string title: player?.trackTitle ?? ""
    readonly property string artist: player?.trackArtist ?? ""
    readonly property string art: player?.trackArtUrl ?? ""
    readonly property string app: player?.identity ?? ""
}
```
`position` is not continuously updated; refresh it with a `Timer` while playing if you draw a progress bar.

### Notifications daemon

```qml
pragma Singleton
import Quickshell
import Quickshell.Services.Notifications
import QtQuick

Singleton {
    id: root
    property bool dnd: false
    readonly property var list: server.trackedNotifications.values
    signal arrived(Notification n)

    NotificationServer {
        id: server
        actionsSupported: true
        imageSupported: true
        bodyMarkupSupported: false
        keepOnReload: true
        onNotification: n => { n.tracked = true; if (!root.dnd) root.arrived(n) }
    }
    function clearAll() { for (const n of server.trackedNotifications.values.slice()) n.dismiss() }
}
```
Only one notification daemon can own the D-Bus name. Do not run mako/dunst/swaync in the same session.

### Battery and power profile

```qml
import Quickshell.Services.UPower
// UPower.displayDevice.percentage is 0.0–1.0 (the docs say "percentage", the code divides by 100)
readonly property int batteryPct: Math.round((UPower.displayDevice?.percentage ?? 0) * 100)
// PowerProfiles.profile = PowerProfile.PowerSaver | Balanced | Performance (needs power-profiles-daemon)
```

### Polling a CLI / file

```qml
Process {
    id: proc
    command: ["sh", "-c", "free -b | awk '/Mem:/ {print $3, $2}'"]
    stdout: StdioCollector { onStreamFinished: { const [u, t] = this.text.trim().split(" "); root.memUsed = +u; root.memTotal = +t } }
}
Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: proc.running = true }
```

For `/proc` files you can use `FileView { id: stat; path: "/proc/stat" }` and call `stat.reload()` in the timer, then parse `stat.text()`.

### App launcher data

`DesktopEntries.applications.values` gives `DesktopEntry` objects (`name`, `genericName`, `icon`, `keywords`, `execute()`). Use `Quickshell.iconPath(entry.icon)` for the image source.

## 7. Hyprland data

```qml
import Quickshell.Hyprland
// workspaces 1..5 with occupancy
Repeater {
    model: 5
    delegate: WorkspacePill {
        required property int index
        readonly property int wsId: index + 1
        readonly property var ws: Hyprland.workspaces.values.find(w => w.id === wsId) ?? null
        active: Hyprland.focusedWorkspace?.id === wsId
        occupied: ws !== null
        onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = "${wsId}" })`)  // Lua-mode dispatcher
    }
}
```
Check `Hyprland.usingLua`; with a hyprlang config the dispatcher string format is different.

## 8. Blur behind shell windows

```qml
import Quickshell.Wayland
PanelWindow {
    id: w
    color: "transparent"
    BackgroundEffect.blurRegion: Region { item: card; radius: 22 }
    Rectangle { id: card; color: "#b3161925"; radius: 22 /* … */ }
}
```
Alternatively a Hyprland layer rule on the window's namespace (`hl.layer_rule({ match = { namespace = "dragon-bar" }, blur = true })`). Use one method, not both.
