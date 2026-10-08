// =============================================================================
// dragon-island — Vpn.qml
// Service: is a VPN up? Looks for Proton VPN's network interface (proton0, tun*, wg*, ipv6leakintrf0)
// =============================================================================
/**
 * Functions:
 *   - openApp(): void (Proton VPN's window, if installed)
 *
 * Properties:
 *   - active: bool [readonly]
 *   - iface: string [readonly] (first matching interface, "" when none)
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property string iface: ""
    readonly property bool active: iface.length > 0

    function openApp(): void {
        Quickshell.execDetached(["sh", "-c", "command -v protonvpn-app >/dev/null && exec protonvpn-app"]);
    }

    Process {
        id: probe
        command: ["sh", "-c", "ls /sys/class/net"]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = this.text.split(/\s+/).filter(n => n.length > 0);
                // the tunnel first: ipv6leakintrf0 (the kill-switch dummy) only counts when nothing else is up
                root.iface = names.find(n => /^(proton|tun\d|wg\d)/.test(n)) ?? names.find(n => /^ipv6leakintrf/.test(n)) ?? "";
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!probe.running) probe.running = true
    }
}
