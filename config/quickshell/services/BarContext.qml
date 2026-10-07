// =============================================================================
// dragon-island — BarContext.qml
// Service: the contextual capsules of the right island — shown only while they are relevant
// =============================================================================
/**
 * (Microphone use is a dot on the volume capsule; No molestar, unread notifications and updates are markers on
 * the clock capsule and live in its popover.)
 *
 * Each entry: { key, prio, icon, color, text, est, pulse }
 *   prio: lower = more important. prio <= 2 (privacy, recording, agents) is never grouped into "+N".
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

    readonly property var slots: ["privacy", "rec", "agents", "vpn", "headset", "caffeine", "net"]

    function _mmss(s: int): string {
        return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
    }

    readonly property var items: {
        const l = [];
        // the microphone is a dot on the volume capsule (details in the Sonido popover); camera and screen
        // sharing get a capsule of their own
        if (Privacy.camera || Privacy.screen) {
            l.push({ key: "privacy", prio: 1, icon: Privacy.screen ? Icons.screenShare : Icons.webcam,
                     color: Privacy.camera && !Privacy.screen ? Theme.ok : Theme.warn, text: "", est: 30, pulse: false });
        }
        if (Toggles.isRecording) {
            l.push({ key: "rec", prio: 2, icon: Icons.record, color: Theme.error, text: root._mmss(Toggles.recordingSeconds), est: 68, pulse: true });
        }
        if (Herdr.active) {
            // one part per state present, each in its palette colour: working = cyan, blocked = amber (pulses), done = green
            const c = Herdr.counts;
            const parts = [];
            if (c.blocked > 0) parts.push({ icon: Icons.bellRing, color: Theme.warn, text: `${c.blocked}`, pulse: true });
            if (c.working > 0) parts.push({ icon: Icons.bolt, color: Theme.cyan, text: `${c.working}`, breathe: true });
            if (c.done > 0)    parts.push({ icon: Icons.check, color: Theme.ok, text: `${c.done}` });
            if (c.idle > 0 && parts.length === 0) parts.push({ icon: Icons.dots, color: Theme.textSoft, text: `${c.idle}` });
            l.push({ key: "agents", prio: 2, icon: Icons.robot, color: Theme.textSoft, text: "", parts: parts,
                     est: 36 + 34 * parts.length, pulse: false });
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
