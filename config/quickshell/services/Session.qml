// =============================================================================
// dragon-island — Session.qml
// Service: user / host identity and session actions (lock, suspend, power, logout)
// =============================================================================
/**
 * Properties:
 *   - userName: string [readonly] (first name from GECOS, else $USER)
 *   - login: string [readonly] ($USER)
 *   - hostName: string [readonly]
 *
 * Functions:
 *   - lock(): void        (loginctl lock-session → hypridle runs hyprlock)
 *   - suspend(): void
 *   - hibernate(): void
 *   - reboot(): void
 *   - poweroff(): void
 *   - logout(): void      (exits Hyprland, back to SDDM)
 *   - run(action: string): void ("lock" | "suspend" | "hibernate" | "reboot" | "poweroff" | "logout")
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: root

    readonly property string login: Quickshell.env("USER") ?? ""
    property string userName: login
    property string hostName: ""

    Process {
        running: true
        command: ["sh", "-c", "getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const full = this.text.trim();
                if (full.length > 0) root.userName = full.split(/\s+/)[0];
            }
        }
    }

    FileView {
        id: hostFile
        path: "/etc/hostname"
        printErrors: false
        onLoaded: root.hostName = hostFile.text().trim()
    }

    function lock(): void { Quickshell.execDetached(["loginctl", "lock-session"]); }
    function suspend(): void { Quickshell.execDetached(["systemctl", "suspend"]); }
    function hibernate(): void { Quickshell.execDetached(["systemctl", "hibernate"]); }
    function reboot(): void { Quickshell.execDetached(["systemctl", "reboot"]); }
    function poweroff(): void { Quickshell.execDetached(["systemctl", "poweroff"]); }
    function logout(): void { Hyprland.dispatch(Hyprland.usingLua ? "hl.dsp.exit()" : "exit"); }

    function run(action: string): void {
        switch (action) {
            case "lock":      lock(); break;
            case "suspend":   suspend(); break;
            case "hibernate": hibernate(); break;
            case "reboot":    reboot(); break;
            case "poweroff":  poweroff(); break;
            case "logout":    logout(); break;
        }
    }
}
