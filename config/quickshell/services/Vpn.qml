// =============================================================================
// dragon-island — Vpn.qml
// Service: is a VPN up? Looks for Proton VPN's network interface (proton0, tun*, wg*, ipv6leakintrf0)
// =============================================================================
/**
 * Functions:
 *   - openApp(): void (Proton VPN's window, if installed)
 *
 *   - connectLast(): void (`nmcli connection up` of the last used VPN / WireGuard connection; none → openApp())
 *   - disconnect(): void (`nmcli connection down` of the active one)
 *
 * Properties:
 *   - active: bool [readonly]
 *   - iface: string [readonly] (first matching interface, "" when none)
 *   - provider: string [readonly] ("Proton" when the connection name says so, else "")
 *   - activeName / lastName: string [readonly] (NetworkManager connection names; Proton names them «ProtonVPN ES#12»)
 *   - server: string [readonly] (the server part of the active or last connection: «ES#12»)
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property string iface: ""
    readonly property bool active: iface.length > 0

    property string activeName: ""
    property string lastName: ""
    readonly property string provider: /proton/i.test(activeName || lastName) ? "Proton" : ""
    readonly property string server: (activeName || lastName).replace(/^ProtonVPN\s*/i, "")

    // VPN / WireGuard connections of NetworkManager, most recently used first (TIMESTAMP = last activation)
    Process {
        id: conns
        command: ["nmcli", "-t", "-f", "NAME,TYPE,TIMESTAMP,ACTIVE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = [];
                for (const raw of this.text.split("\n")) {
                    const f = raw.split(":");
                    if (f.length < 4) continue;
                    const type = f[f.length - 3];
                    if (type !== "wireguard" && type !== "vpn") continue;
                    rows.push({ name: f.slice(0, f.length - 3).join(":").replace(/\\/g, ""), ts: Number(f[f.length - 2]), active: f[f.length - 1] === "yes" });
                }
                rows.sort((a, b) => b.ts - a.ts);
                root.activeName = rows.find(r => r.active)?.name ?? "";
                root.lastName = rows[0]?.name ?? "";
            }
        }
    }
    Process { id: nmAction; onExited: conns.running = true }
    function connectLast(): void {
        if (root.lastName) nmAction.exec(["nmcli", "connection", "up", root.lastName]);
        else root.openApp();
    }
    function disconnect(): void { if (root.activeName) nmAction.exec(["nmcli", "connection", "down", root.activeName]); }
    onActiveChanged: if (!conns.running) conns.running = true

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
        onTriggered: { if (!probe.running) probe.running = true; if (!conns.running && !root.lastName) conns.running = true; }
    }
}
