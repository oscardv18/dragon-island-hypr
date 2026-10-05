// =============================================================================
// dragon-island — Clock.qml
// Service: clock, Spanish date strings, calendar grid and uptime
// =============================================================================
/**
 * Properties:
 *   - currentDate: date [readonly]   hours / minutes / seconds: int [readonly]
 *   - time: string [readonly] ("16:23")         timeWithSeconds: string [readonly] ("16:23:45")
 *   - dateFormatted: string [readonly] ("lun 5 oct")
 *   - barText: string [readonly] ("lun 5 oct  16:23", bar clock capsule)
 *   - fullDate: string [readonly] ("Lunes, 5 de octubre de 2026")
 *   - shortDate: string [readonly] ("lunes 5 de octubre")
 *   - greeting: string [readonly] ("Buenos días" | "Buenas tardes" | "Buenas noches")
 *   - uptimeFormatted: string [readonly] ("3 h 12 min")
 *   - weekdayLetters: list<string> [readonly] (["L","M","X","J","V","S","D"], Monday first)
 *   - hasEventSource: bool [readonly] (false: no calendar backend yet → no event rings / agenda)
 *
 * Functions:
 *   - format(pattern: string): string
 *   - monthName(month: int): string   (0-based, "octubre")
 *   - monthGrid(year: int, month: int): list<var>
 *       42 cells, Monday first: { day, month, year, inMonth, isToday, hasEvents }
 *   - eventsFor(date): list<var>      (always [] until a calendar source exists)
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

    readonly property var days: ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"]
    readonly property var daysShort: ["dom", "lun", "mar", "mié", "jue", "vie", "sáb"]
    readonly property var months: ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
    readonly property var monthsShort: ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]
    readonly property var weekdayLetters: ["L", "M", "X", "J", "V", "S", "D"]

    readonly property date currentDate: sysClock.date
    readonly property int hours: sysClock.hours
    readonly property int minutes: sysClock.minutes
    readonly property int seconds: sysClock.seconds

    readonly property string time: Qt.formatDateTime(sysClock.date, "hh:mm")
    readonly property string timeWithSeconds: Qt.formatDateTime(sysClock.date, "hh:mm:ss")

    readonly property string dateFormatted: {
        const d = sysClock.date;
        return `${daysShort[d.getDay()]} ${d.getDate()} ${monthsShort[d.getMonth()]}`;
    }
    readonly property string barText: `${dateFormatted}  ${time}`

    readonly property string fullDate: {
        const d = sysClock.date;
        const day = days[d.getDay()];
        return `${day.charAt(0).toUpperCase()}${day.slice(1)}, ${d.getDate()} de ${months[d.getMonth()]} de ${d.getFullYear()}`;
    }
    readonly property string shortDate: {
        const d = sysClock.date;
        return `${days[d.getDay()]} ${d.getDate()} de ${months[d.getMonth()]}`;
    }

    readonly property string greeting: {
        const h = sysClock.hours;
        if (h >= 6 && h < 12) return "Buenos días";
        if (h >= 12 && h < 20) return "Buenas tardes";
        return "Buenas noches";
    }

    readonly property bool hasEventSource: false

    // ---- Uptime ----
    property string uptimeFormatted: ""

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        printErrors: false
        onLoaded: {
            const total = Math.floor(parseFloat(uptimeFile.text()));
            if (isNaN(total)) return;
            const d = Math.floor(total / 86400);
            const h = Math.floor((total % 86400) / 3600);
            const m = Math.floor((total % 3600) / 60);
            root.uptimeFormatted = d > 0 ? `${d} d ${h} h` : (h > 0 ? `${h} h ${m} min` : `${m} min`);
        }
    }

    onMinutesChanged: uptimeFile.reload()

    function format(pattern: string): string {
        return Qt.formatDateTime(sysClock.date, pattern);
    }

    function monthName(month: int): string {
        return months[((month % 12) + 12) % 12];
    }

    function monthGrid(year: int, month: int): var {
        const first = new Date(year, month, 1);
        const offset = (first.getDay() + 6) % 7;          // Monday = 0
        const start = new Date(year, month, 1 - offset);
        const today = sysClock.date;
        const cells = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i);
            cells.push({
                day: d.getDate(),
                month: d.getMonth(),
                year: d.getFullYear(),
                inMonth: d.getMonth() === month,
                isToday: d.toDateString() === today.toDateString(),
                hasEvents: eventsFor(d).length > 0
            });
        }
        return cells;
    }

    // TODO(calendar): wire a source (e.g. khal/ical file via FileView) when one is chosen.
    function eventsFor(date): var { return []; }

    signal minuteTicked()
}
