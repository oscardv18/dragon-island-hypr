.pragma library
// Synthetic data for the 5c Taller mocks (Kanban, Revisión, compositor). No user data; mirrors the 32-taller-* mockups.

function project() {
    return { slug: "arxnet-erp", name: "arxnet-erp", path: "/synthetic/arxnet-erp", branch: "feat/facturas-filtros", key_prefix: "AX", wip_limit: 3, test_cmd: "npm test" };
}

function cards(now) {
    const d = 86400, s = Math.floor(now / 1000);
    const c = (key, title, kind, col, age, extra) => Object.assign({ key: key, title: title, kind: kind, col: col, project: "arxnet-erp",
        created_at: s - age, started_at: col === "doing" || col === "review" || col === "done" ? s - age : null, body: "" }, extra ?? {});
    return [
        c("AX-150", "Paginación en el listado de clientes", "feat", "backlog", 5 * d, { criteria_total: 4, criteria_done: 0 }),
        c("AX-151", "Error 500 al exportar sin filas", "fix", "backlog", 3 * d, { criteria_total: 3, criteria_done: 0 }),
        c("AX-152", "Actualizar dependencias de pruebas", "chore", "backlog", 1 * d, { criteria_total: 2, criteria_done: 0 }),
        c("AX-148", "Vista de detalle de factura", "feat", "ready", 2 * d, { criteria_total: 4, criteria_done: 0 }),
        c("AX-146", "Plantilla de correo de cobro", "feat", "ready", 2 * d, { criteria_total: 3, criteria_done: 0 }),
        c("AX-142", "Filtros de facturas por estado y fecha", "feat", "doing", 2 * d, { criteria_total: 5, criteria_done: 3, branch: "feat/facturas-filtros", worktree: "/synthetic/arxnet-ax142", agent_ref: "p-claude" }),
        c("AX-139", "Exportar CSV respetando filtros", "fix", "doing", 14 * 60, { criteria_total: 5, criteria_done: 2, branch: "fix/export-csv", worktree: "/synthetic/arxnet-ax139", agent_ref: "p-codex" }),
        c("AX-137", "Índice parcial en estado de factura", "chore", "review", 1 * d, { criteria_total: 3, criteria_done: 3, agent_ref: "p-claude-2" }),
        c("AX-131", "Login con enlace mágico", "feat", "done", 4 * d, { criteria_total: 4, criteria_done: 4 }),
        c("AX-129", "Corregir zona horaria en reportes", "fix", "done", 5 * d, { criteria_total: 3, criteria_done: 3 }),
        c("AX-127", "Documentar variables de entorno", "chore", "done", 6 * d, { criteria_total: 2, criteria_done: 2 })
    ];
}

function details() {
    return {
        "AX-142": { criteria: [
            { id: 1, text: "Filtra por estado", done: 1 }, { id: 2, text: "Filtra por rango de fechas", done: 1 },
            { id: 3, text: "Conserva los filtros en la URL", done: 1 }, { id: 4, text: "Exporta solo lo filtrado", done: 0 },
            { id: 5, text: "Pruebas para cada filtro", done: 0 }], events: [{ kind: "gate", data: { exit: 0, seconds: 42 } }] }
    };
}

function stats() {
    return { lead_time_median_h: 50.4, cycle_time_median_h: 31.2, rework_pct: 12, throughput_7d: 5, approval_wait_median_h: 3.4 };
}

function gates() {
    return { "AX-142": { tests: { state: "ok", label: "42 OK" }, seen: { seen: 4, total: 7, changed: 1, state: "pending" }, conflicts: { state: "ok", label: "OK" }, ready: false, needsConfirm: false },
             "AX-137": { tests: { state: "none", label: "SIN EJECUTAR" }, seen: { seen: 3, total: 3, changed: 0, state: "ok" }, conflicts: { state: "ok", label: "OK" }, ready: false, needsConfirm: false } };
}

function agents(now) {
    return [
        { id: "p-claude", pane: "p-claude", kind: "claude", agent: "claude", state: "blocked", card: "AX-142", space: "arxnet-erp", branch: "feat/facturas-filtros", since: now - 120000 },
        { id: "p-codex", pane: "p-codex", kind: "codex", agent: "codex", state: "working", card: "AX-139", space: "arxnet-erp", branch: "fix/export-csv", since: now - 840000 },
        { id: "p-claude-2", pane: "p-claude-2", kind: "claude", agent: "claude", state: "done", card: "AX-137", space: "arxnet-erp", branch: "chore/indice", since: now - 3600000 }
    ];
}

function templates() {
    return [{ id: "implementar-tarjeta", name: "Implementar tarjeta" }, { id: "error-de-contenedor", name: "Error de contenedor" }, { id: "revisar-cambios", name: "Revisión" }];
}

function reviewPrompt() {
    return { tokens: 242, warnings: [], text: "", blocks: [
        { id: "comments-0", type: "comments", label: "Comentarios (2)", tokens: 88, enabled: true, redactions: 0,
          text: "Comentarios de revisión:\n- 0042_idx_estado.sql L4: ¿por qué no un índice parcial?\n- api/facturas.ts L18: falta validar el rango de fechas." },
        { id: "diff-1", type: "diff", label: "Diff · 0042 (9 l.)", tokens: 104, enabled: true, redactions: 0, text: "Diff relevante: migrations/0042_idx_estado.sql (+9)" },
        { id: "paths-2", type: "paths", label: "Rutas (2)", tokens: 30, enabled: true, redactions: 0, text: "Archivos: migrations/0042_idx_estado.sql,\nsrc/api/facturas.ts" },
        { id: "text-3", type: "text", label: "Texto libre", tokens: 20, enabled: true, redactions: 0, text: "Responde con los cambios propuestos." }] };
}

function reviewFiles() {
    return [
        { path: "src/facturas/filtros.ts", status: "M", add: 48, del: 6, seen: true },
        { path: "src/facturas/filtros.test.ts", status: "A", add: 72, del: 0, seen: true },
        { path: "src/facturas/lista.tsx", status: "M", add: 12, del: 3, seen: true },
        { path: "migrations/0042_idx_estado.sql", status: "A", add: 9, del: 0, seen: false },
        { path: "src/api/facturas.ts", status: "M", add: 31, del: 4, seen: false, changed: true }
    ];
}

function reviewDiff() {
    return { path: "migrations/0042_idx_estado.sql", add: 9, del: 0, hunks: [{ header: "@@ -0,0 +1,9 @@", lines: [
        { o: null, n: 1, t: "add", text: "-- índice para filtrar facturas por estado" },
        { o: null, n: 2, t: "add", text: "CREATE INDEX CONCURRENTLY idx_facturas_estado" },
        { o: null, n: 3, t: "add", text: "  ON facturas (estado, fecha);" },
        { o: null, n: 4, t: "add", text: "-- TODO: valorar índice parcial" },
        { o: null, n: 5, t: "add", text: "" },
        { o: null, n: 6, t: "add", text: "ANALYZE facturas;" }] }] };
}

function comments() {
    return [
        { id: 1, path: "migrations/0042_idx_estado.sql", line: 4, text: "¿Por qué no un índice parcial?", sent: 0 },
        { id: 2, path: "src/api/facturas.ts", line: 18, text: "Falta validar el rango de fechas.", sent: 0 }
    ];
}
