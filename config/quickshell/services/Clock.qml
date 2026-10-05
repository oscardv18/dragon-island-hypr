// =============================================================================
// dragon-island — Clock.qml
// Service: System Clock, Date Formatting & System Uptime
// =============================================================================
/**
 * Properties:
 *   - time: string [readonly] ("16:23")
 *   - timeWithSeconds: string [readonly] ("16:23:45")
 *   - dateFormatted: string [readonly] ("lun 5 oct")
 *   - fullDate: string [readonly] ("Lunes, 5 de octubre de 2026")
 *   - greeting: string [readonly] ("Buenas tardes")
 *   - uptimeFormatted: string [readonly] ("3h 12m")
 *
 * Functions:
 *   - format(pattern: string): string
 *
 * Signals:
 *   - minuteTicked()
 */
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    SystemClock {
        id: sysClock
        precision: SystemClock.Seconds
        onMinutesChanged: root.minuteTicked()
    }

    readonly property date currentDate: sysClock.date
    readonly property int hours: sysClock.hours
    readonly property int minutes: sysClock.minutes
    readonly property int seconds: sysClock.seconds

    // Time strings
    readonly property string time: Qt.formatDateTime(sysClock.date, "hh:mm")
    readonly property string timeWithSeconds: Qt.formatDateTime(sysClock.date, "hh:mm:ss")

    // Spanish date representations
    readonly property string dateFormatted: {
        const days = ["dom", "lun", "mar", "mié", "jue", "vie", "sáb"];
        const months = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"];
        const d = sysClock.date;
        return `${days[d.getDay()]} ${d.getDate()} ${months[d.getMonth()]}`;
    }

    readonly property string fullDate: {
        const days = ["Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"];
        const months = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"];
        const d = sysClock.date;
        return `${days[d.getDay()]}, ${d.getDate()} de ${months[d.getMonth()]} de ${d.getFullYear()}`;
    }

    // Dynamic greeting based on time of day
    readonly property string greeting: {
        const h = sysClock.hours;
        if (h >= 6 && h < 12) {
            return "Buenos días";
        } else if (h >= 12 && h < 20) {
            return "Buenas tardes";
        } else {
            return "Buenas noches";
        }
    }

    // Uptime monitoring via /proc/uptime
    property string uptimeFormatted: ""

    Process {
        id: uptimeProc
        command: ["sh", "-c", "awk '{print int($1)}' /proc/uptime"]
        stdout: StdioCollector {
            onStreamFinished: {
                const totalSec = parseInt(this.text.trim());
                if (!isNaN(totalSec)) {
                    const days = Math.floor(totalSec / 86400);
                    const hours = Math.floor((totalSec % 86400) / 3600);
                    const mins = Math.floor((totalSec % 3600) / 60);
                    if (days > 0) {
                        root.uptimeFormatted = `${days}d ${hours}h ${mins}m`;
                    } else if (hours > 0) {
                        root.uptimeFormatted = `${hours}h ${mins}m`;
                    } else {
                        root.uptimeFormatted = `${mins}m`;
                    }
                }
            }
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!uptimeProc.running) {
                uptimeProc.running = true;
            }
        }
    }

    function format(pattern: string): string {
        return Qt.formatDateTime(sysClock.date, pattern);
    }

    signal minuteTicked()
}
