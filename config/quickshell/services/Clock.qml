// =============================================================================
// dragon-island — Clock.qml
// Service: clock, Spanish date strings, calendar grid, khal events and uptime
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
 *   - todayKey: string [readonly] ("2026-10-05", changes once a day: use it to refresh day-based UI)
 *   - hasEventSource: bool [readonly] (khal installed and its date format understood)
 *   - eventsError: string [readonly] (why events are unavailable, "" when fine)
 *   - eventsLoading: bool [readonly]
 *
 * Functions:
 *   - format(pattern: string): string
 *   - monthName(month: int): string   (0-based, "octubre")
 *   - monthGrid(year: int, month: int): list<var>
 *       42 cells, Monday first: { day, month, year, inMonth, isToday, hasEvents }
 *   - eventsFor(date): list<var>      ({ title, time, location, calendar, allDay }, all-day first)
 *   - requestMonth(year: int, month: int): void (load khal events for that month's 6-week grid)
 *   - refreshEvents(): void
 *
 * Signals:
 *   - minuteTicked()
 *
 * Events come from khal (`khal list`); calendars are synced with vdirsyncer as usual.
 * khal reads and prints dates in the user's configured format, so it is learned from
 * `khal printformats` (which renders 2013-12-21 in that format).
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

    readonly property string todayKey: Qt.formatDate(sysClock.date, "yyyy-MM-dd")

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

    function dayKey(d): string {
        return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
    }

    function monthGrid(year: int, month: int): var {
        const first = new Date(year, month, 1);
        const offset = (first.getDay() + 6) % 7;          // Monday = 0
        const start = new Date(year, month, 1 - offset);
        void root.todayKey;              // depend on the day, not on every second
        const today = dayKey(new Date());
        const cells = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i);
            cells.push({
                day: d.getDate(),
                month: d.getMonth(),
                year: d.getFullYear(),
                inMonth: d.getMonth() === month,
                isToday: dayKey(d) === today,
                hasEvents: eventsFor(d).length > 0
            });
        }
        return cells;
    }

    // =========================================================================
    // Calendar events (khal)
    // =========================================================================
    readonly property string _mark: String.fromCharCode(1)   // placeholder prefix (never part of a date)

    property bool khalFound: false
    property string _dateTemplate: ""  // e.g. "<mark>D.<mark>M.<mark>Y"
    property var _datePattern: null    // { re: RegExp, order: ["D", "M", "Y"] }
    property var _events: ({})         // "yyyy-MM-dd" → [event]
    property string _rangeStart: ""    // khal-formatted first day of the loaded 6-week grid
    property bool eventsLoading: false
    property string eventsError: ""
    readonly property bool hasEventSource: khalFound && _datePattern !== null

    Process {
        id: khalFormats
        running: true
        command: ["sh", "-c", "command -v khal >/dev/null || exit 3; exec khal printformats"]
        stdout: StdioCollector {
            onStreamFinished: root._learnFormat(this.text)
        }
        onExited: (code, status) => {
            if (code === 3) root.eventsError = "khal no está instalado";
            else if (code !== 0) root.eventsError = "khal no está configurado (ejecuta «khal configure»)";
        }
    }

    function _learnFormat(text: string): void {
        const line = text.split("\n").find(l => l.trim().startsWith("longdateformat:"));
        if (!line) return;
        const example = line.substring(line.indexOf(":") + 1).trim();
        const M = root._mark;
        // 2013-12-21 in the user's format → placeholders. "2013" first, then day 21, month 12, then a 2-digit year.
        const t = example.replace("2013", M + "Y").replace("21", M + "D").replace("12", M + "M").replace("13", M + "y");
        if (t.indexOf(M + "D") < 0 || t.indexOf(M + "M") < 0) {
            root.eventsError = `Formato de fecha de khal no soportado: ${example}`;
            return;
        }
        const order = [];
        const parts = t.split(new RegExp(`(${M}[YyDM])`));
        const source = parts.map(part => {
            if (part === M + "Y") { order.push("Y"); return "(\\d{4})"; }
            if (part === M + "y") { order.push("y"); return "(\\d{2})"; }
            if (part === M + "D") { order.push("D"); return "(\\d{1,2})"; }
            if (part === M + "M") { order.push("M"); return "(\\d{1,2})"; }
            return part.replace(/[.*+?^${}()|[\]\\\/]/g, "\\$&");
        }).join("");
        root._dateTemplate = t;
        root._datePattern = { re: new RegExp(source), order: order };
        root.khalFound = true;
        root.eventsError = "";
        root.requestMonth(sysClock.date.getFullYear(), sysClock.date.getMonth());
    }

    function _toKhal(d): string {
        const M = root._mark;
        const pad = n => String(n).padStart(2, "0");
        return root._dateTemplate
            .replace(M + "Y", `${d.getFullYear()}`)
            .replace(M + "y", pad(d.getFullYear() % 100))
            .replace(M + "D", pad(d.getDate()))
            .replace(M + "M", pad(d.getMonth() + 1));
    }

    function _parseKhalDate(s: string): string {
        const m = root._datePattern ? root._datePattern.re.exec(s) : null;
        if (!m) return "";
        let y = 0, mo = 0, d = 0;
        root._datePattern.order.forEach((k, i) => {
            const v = parseInt(m[i + 1], 10);
            if (k === "Y") y = v;
            else if (k === "y") y = 2000 + v;
            else if (k === "M") mo = v;
            else d = v;
        });
        return dayKey(new Date(y, mo - 1, d));
    }

    function _parseList(text: string): void {
        const events = {};
        let day = "";
        for (const raw of text.split("\n")) {
            const line = raw.replace(/\x1b\[[0-9;]*m/g, "");
            if (line.startsWith("@@")) {
                day = _parseKhalDate(line.substring(2).trim());
                continue;
            }
            if (!day || line.trim().length === 0) continue;
            const f = line.split("\t");
            const start = (f[0] || "").trim();
            const end = (f[1] || "").trim();
            const ev = {
                title: (f[2] || "").trim() || "(sin título)",
                location: (f[3] || "").trim(),
                calendar: (f[4] || "").trim(),
                allDay: start.length === 0,
                time: start.length === 0 ? "Todo el día" : (end.length > 0 ? `${start}–${end}` : start)
            };
            (events[day] = events[day] || []).push(ev);
        }
        for (const k in events) events[k].sort((a, b) => (b.allDay - a.allDay) || a.time.localeCompare(b.time));
        root._events = events;
    }

    Process {
        id: khalList
        stdout: StdioCollector {
            onStreamFinished: {
                root._parseList(this.text);
                root.eventsLoading = false;
            }
        }
        onExited: (code, status) => {
            root.eventsLoading = false;
            if (code !== 0) root.eventsError = "khal list falló (revisa ~/.config/khal/config)";
        }
    }

    function requestMonth(year: int, month: int): void {
        if (!root.hasEventSource) return;
        const first = new Date(year, month, 1);
        const start = new Date(year, month, 1 - (first.getDay() + 6) % 7);
        const key = _toKhal(start);
        if (key === root._rangeStart && !root.eventsLoading) return;
        root._rangeStart = key;
        refreshEvents();
    }

    function refreshEvents(): void {
        if (!root.hasEventSource || root._rangeStart.length === 0) return;
        root.eventsLoading = true;
        khalList.exec(["khal", "list",
                       "--day-format", "@@{date-long}",
                       "--format", "{start-time}\t{end-time}\t{title}\t{location}\t{calendar}",
                       root._rangeStart, "42d"]);
    }

    onTodayKeyChanged: requestMonth(sysClock.date.getFullYear(), sysClock.date.getMonth())

    // calendars change in the background (vdirsyncer): refresh the loaded range
    Timer {
        interval: 600000
        repeat: true
        running: root.hasEventSource
        onTriggered: root.refreshEvents()
    }

    function eventsFor(date): var {
        if (!date) return [];
        return root._events[dayKey(date)] ?? [];
    }

    signal minuteTicked()
}
