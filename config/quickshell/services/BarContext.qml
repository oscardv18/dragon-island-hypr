// =============================================================================
// dragon-island — BarContext.qml
// Service: the contextual capsules of the right island — shown only while they are relevant
// =============================================================================
/**
 * Each entry: { key, prio, icon, color, text, est, pulse }
 *   prio: lower = more important. prio <= 2 (privacy, recording) is never grouped into "+N".
 *   est:  estimated width in px (the bar decides what fits before the chips are measured)
 *
 * Properties:
 *   - slots: list<string> [readonly] (every possible key, in priority order: fixed delegates animate in and out)
 *   - items: list<var> [readonly] (the active ones, sorted by priority)
 *   - byKey: var [readonly] (key → entry)
 *   - netThreshold: real (bytes/s above which the network speed capsule appears, default 500 KB/s)
 */
pragma Singleton
import Quickshell
import QtQuick
import ".."

Singleton {
    id: root

    property real netThreshold: 512000

    readonly property var slots: ["privacy", "rec", "vpn", "headset", "caffeine", "dnd", "updates", "net"]

    function _mmss(s: int): string {
        return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
    }

    readonly property var items: {
        const l = [];
        if (Privacy.active) {
            l.push({ key: "privacy", prio: 1, icon: Privacy.screen ? Icons.screenShare : (Privacy.camera ? Icons.webcam : Icons.microphone),
                     color: Privacy.color, text: "", est: 30, pulse: false });
        }
        if (Toggles.isRecording) {
            l.push({ key: "rec", prio: 2, icon: Icons.record, color: Theme.error, text: root._mmss(Toggles.recordingSeconds), est: 68, pulse: true });
        }
        if (Vpn.active) {
            l.push({ key: "vpn", prio: 3, icon: Icons.shield, color: Theme.ok, text: "", est: 30, pulse: false });
        }
        if (Bluetooth.hasBattery && Bluetooth.connectedDevices.length > 0) {
            const pct = Bluetooth.connectedBatteryPct;
            l.push({ key: "headset", prio: 4, icon: Icons.headphones, color: pct <= 20 ? Theme.warn : Theme.textSoft,
                     text: `${pct}%`, est: 66, pulse: false });
        }
        if (Caffeine.enabled) {
            l.push({ key: "caffeine", prio: 5, icon: Icons.coffee, color: Theme.warn, text: "", est: 30, pulse: false });
        }
        if (Notifs.dnd) {
            l.push({ key: "dnd", prio: 6, icon: Icons.bellOff, color: Theme.textDim, text: "", est: 30, pulse: false });
        }
        if (Updates.count > 0) {
            l.push({ key: "updates", prio: 7, icon: Icons.update, color: Theme.cyan, text: `${Updates.count}`, est: 30 + 9 * `${Updates.count}`.length + 8, pulse: false });
        }
        const top = Math.max(SysStats.rxRate, SysStats.txRate);
        if (top > root.netThreshold) {
            l.push({ key: "net", prio: 8, icon: SysStats.rxRate >= SysStats.txRate ? Icons.arrowDown : Icons.arrowUp,
                     color: Theme.textSoft, text: SysStats.formatRate(top), est: 104, pulse: false });
        }
        return l;
    }

    readonly property var byKey: {
        const m = {};
        for (const i of root.items) m[i.key] = i;
        return m;
    }
}
