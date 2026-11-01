// =============================================================================
// dragon-island — Priority.qml
// Service: the priority stack of the isla de mando (docs/design/31-isla-mando.png). It orders itself:
//   1 blocked or completed-unseen agent · Ir al panel / Ignorar 10 min
//   2 meeting in less than 15 min     Unirse (a Meet / Zoom / Teams link in the location or description) · Posponer 5 min
//   3 focus block running             Pausar / Reanudar · Terminar
//   4 long command finished < 5 min   Abrir terminal (in its folder)
//   5 pending updates                 Actualizar
// The view shows the first as a big card and the next two as thin rows; a click on a row raises it.
// =============================================================================
/**
 * Properties:
 *   - cards: list<var> [readonly] ({ key, kind: "agent"|"meeting"|"focus"|"command"|"updates", label (caption),
 *       title, sub, when ("hace 1 min" / "en 18 min" / ""), tone (color), payload (the agent / event / command) })
 *
 * Functions:
 *   - snooze(key: string, minutes: int): void (hides a meeting card for that long)
 *   - meetingLink(event): string ("" when there is none)
 *   - join(event): void (opens the link)   openTerminal(cmd): void (Ghostty in the command's folder)
 */
pragma Singleton
import Quickshell
import QtQuick
import ".."

Singleton {
    id: root

    property real _now: Date.now()
    Timer { interval: 30000; running: true; repeat: true; onTriggered: root._now = Date.now() }
    property var _snoozed: ({})     // key → until (ms)

    function snooze(key: string, minutes: int): void {
        const s = Object.assign({}, root._snoozed);
        s[key] = Date.now() + minutes * 60000;
        root._snoozed = s;
        root._now = Date.now();
    }

    function ago(ms: real): string {
        const m = Math.max(0, Math.round((root._now - ms) / 60000));
        return m < 1 ? "ahora" : `hace ${m} min`;
    }

    function meetingLink(ev): string {
        const text = `${ev?.location ?? ""} ${ev?.description ?? ""}`;
        const m = /(https?:\/\/(?:meet\.google\.com|[\w.-]*zoom\.us|teams\.microsoft\.com|teams\.live\.com)\/[^\s"'<>]+)/i.exec(text);
        return m ? m[1] : "";
    }
    function join(ev): void { const l = root.meetingLink(ev); if (l) Quickshell.execDetached(["xdg-open", l]); }
    function openTerminal(cmd): void {
        Quickshell.execDetached(["ghostty", `--working-directory=${cmd?.cwd || Quickshell.env("HOME")}`]);
    }

    readonly property var cards: {
        const now = root._now, out = [];
        void Clock.minutes;
        // 1 · blocked first, then completed and unseen. Snoozes/seen state live only in Herdr memory.
        for (const a of Herdr.attentionAgents)
            out.push({ key: `agent:${a.pane}`, kind: "agent", label: a.state === "blocked" ? "Agente · bloqueado" : "Agente · listo sin ver",
                       title: `${a.agent} ${a.state === "blocked" ? "espera tu respuesta" : "terminó"}`, sub: [a.workspace,a.card,a.note].filter(x => x).join(" · "),
                       when: root.ago(a.since), tone: a.state === "blocked" ? Theme.warn : Theme.ok, payload: a });
        // 2 · meetings starting within 15 min (or started less than 5 min ago)
        for (const ev of Clock.eventsBetween(new Date(now - 300000), new Date(now + 900000))) {
            const key = `meeting:${ev.startMs}:${ev.title}`;
            if ((root._snoozed[key] ?? 0) > now || ev.startMs < now - 300000) continue;
            const mins = Math.round((ev.startMs - now) / 60000);
            out.push({ key: key, kind: "meeting", label: "Reunión", title: ev.title, sub: [ev.time, ev.calendar].filter(x => x).join(" · "),
                       when: mins > 0 ? `en ${mins} min` : "ahora", tone: Theme.lavender, payload: ev });
        }
        // 3 · focus
        if (Focus.active)
            out.push({ key: "focus", kind: "focus", label: "Enfoque", title: `${Focus.paused ? "En pausa" : "Enfoque"} · ${String(Math.floor(Focus.remaining / 60)).padStart(2, "0")}:${String(Focus.remaining % 60).padStart(2, "0")}`,
                       sub: Focus.summary, when: "", tone: Theme.focusTeal, payload: null });
        // 4 · long command finished in the last 5 min
        const cmd = Commands.recent.find(c => now - c.at < 300000);
        if (cmd)
            out.push({ key: `command:${cmd.id}:${cmd.at}`, kind: "command", label: "Comando", title: `${cmd.command.split(/\s+/).slice(0, 2).join(" ")} ${cmd.code === 0 ? "terminó ✓" : `falló (${cmd.code})`}`,
                       sub: `${Commands.formatDuration(cmd.seconds)} · ${(cmd.cwd || "").split("/").filter(p => p).pop() ?? ""}`, when: root.ago(cmd.at),
                       tone: cmd.code === 0 ? Theme.ok : Theme.error, payload: cmd });
        // 5 · updates
        if (Updates.count > 0)
            out.push({ key: "updates", kind: "updates", label: "Sistema", title: Updates.count === 1 ? "1 actualización pendiente" : `${Updates.count} actualizaciones pendientes`,
                       sub: `${Updates.repoCount} repositorios · ${Updates.aurCount} AUR`, when: "", tone: Theme.cyan, payload: null });
        return out;
    }
}
