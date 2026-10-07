// =============================================================================
// dragon-island — Updates.qml
// Service: pending package updates (checkupdates from pacman-contrib + AUR helper), every 30 minutes
// =============================================================================
/**
 * Properties:
 *   - count: int [readonly] (repository + AUR updates)
 *   - repoCount / aurCount: int [readonly]
 *   - checking: bool [readonly]
 *
 * Functions:
 *   - refresh(): void
 *   - run(): void  (opens Ghostty with the update: AUR helper if there is one, else pacman -Syu)
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property int repoCount: 0
    property int aurCount: 0
    readonly property int count: repoCount + aurCount
    readonly property bool checking: checker.running

    function refresh(): void { if (!checker.running) checker.running = true; }

    function run(): void {
        Quickshell.execDetached(["ghostty", "-e", "sh", "-c",
            "h=$(command -v paru || command -v yay); if [ -n \"$h\" ]; then \"$h\" -Syu; else sudo pacman -Syu; fi; printf '\\nPulsa Enter para cerrar... '; read _"]);
        // look again a little later: the list changes once the update ran
        recheck.restart();
    }

    Process {
        id: checker
        command: ["sh", "-c", "n=$(checkupdates 2>/dev/null | wc -l); a=0; for h in paru yay; do if command -v $h >/dev/null 2>&1; then a=$($h -Qua 2>/dev/null | wc -l); break; fi; done; echo \"$n $a\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = this.text.trim().split(/\s+/).map(Number);
                root.repoCount = f[0] || 0;
                root.aurCount = f[1] || 0;
            }
        }
    }

    Timer { interval: 1800000; running: true; repeat: true; onTriggered: root.refresh() }
    Timer { running: true; interval: 15000; onTriggered: root.refresh() }       // first check shortly after login
    Timer { id: recheck; interval: 120000; onTriggered: root.refresh() }
}
