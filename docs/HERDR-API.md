# API de herdr comprobada para el Taller

Inspección local, 2026-10-31: **herdr 0.9.5**, protocolo **22**. Fuentes primarias:
`herdr --help`, `herdr agent --help`, `herdr pane --help`, `herdr api schema --json`
y consultas de lectura al socket real. El esquema está incorporado al binario;
no se deducen comandos a partir de versiones posteriores.

## Transporte

Socket Unix: `HERDR_SOCKET_PATH` o `~/.config/herdr/herdr.sock` (respetando
`XDG_CONFIG_HOME`). Cada petición es una línea JSON UTF-8:

```json
{"id":"dragon","method":"session.snapshot","params":{}}
```

Respuesta: `{"id":"dragon","result":{"type":"session_snapshot","snapshot":{…}}}`
o `{"id":"dragon","error":{"code":"…","message":"…"}}`.
**Una conexión por petición:** en esta versión el servidor cierra después de la
respuesta ordinaria. Una suscripción conserva su conexión y emite JSONL.

## Lo que existe

- `session.snapshot {}`: `version`, `protocol`, `agents`, `panes`, `tabs`,
  `workspaces`, `layouts`, `focused_*`. Verificado contra el servidor real.
- `agent.list {}`: `result.agents`. La CLI es `herdr agent list`, **sin `--json`**.
- Agente: `pane_id`, `agent`, `agent_status` (`blocked|working|done|idle|unknown`),
  `cwd`, `foreground_cwd`, `workspace_id`, `tab_id`, `focused`, `revision`,
  `state_change_seq`, `terminal_title_stripped`, `agent_session` opcional.
- Espacio: `workspace_id`, `label`, `number`, `agent_status`, `pane_count`,
  `tab_count`, `active_tab_id`, `focused`.
- `agent.explain {target}`: `result.explain`; exige destino. Ejecutar solo
  `herdr agent explain` muestra el uso (salida 2), no una descripción global.
- `agent.focus {target}`: cambia el panel del cliente. El puente además enfoca la
  ventana de Hyprland por dirección. En Lua se usa `hl.dsp.focus({window=…})`;
  el antiguo dispatcher `focuswindow` del plan no funciona en configuración Lua.
- `agent.read {target,source:"recent",lines,strip_ansi:true}`: texto del terminal.
  En pantalla alternativa activa, leer 200 líneas recientes devuelve `agent_not_idle`
  (comprobado); el puente usa entonces `visible`, sin desplazar el terminal.
  Fuentes admitidas: `visible`, `recent`, `recent_unwrapped`, `detection`.
- `agent.prompt {target,text}`: entrega y pulsa Intro; **rechaza agentes bloqueados**
  con `agent_blocked`. CLI `herdr agent prompt <target> <text>`; no admite stdin.
  El puente usa el socket para que el prompt nunca figure en argumentos de procesos.
- `pane.send_text {pane_id,text}`: texto literal sin Intro. El puente verifica
  primero que el agente no esté bloqueado, también con `--no-enter`.
- `workspace.create {cwd,label,focus:false}` crea un espacio con su panel inicial.
  `tab.create {workspace_id,cwd,label,focus:false}` crea una pestaña.
- `agent.start {pane_id,kind,name,args:[],timeout_ms}` arranca en un panel con shell
  interactivo. Tipos `claude` y `codex` existen en 0.9.5. No se ejecutó un arranque
  real durante la inspección: podría iniciar un agente del usuario.

## Eventos comprobados

`events.subscribe {subscriptions:[…]}` devuelve `subscription_started` (verificado).
Suscripciones globales: `pane.created`, `pane.closed`, `pane.agent_detected`,
`workspace.created`, `workspace.closed`, `workspace.renamed`, `workspace.updated`.
Para estados: `{"type":"pane.agent_status_changed","pane_id":"wE:p3"}`.
Los eventos tienen `event` y `data`; los nombres del sobre pueden usar guiones
bajos. Se usan como invalidación, con snapshot renovado y suscripción adaptada
al conjunto de paneles. No se suscribe a la salida del terminal.

El observador reconecta con espera 1 → 10 s, emite un latido cada 30 s y termina
con SIGTERM. Con servidor conectado trabaja por eventos, sin sondeo periódico.
Con `--record` registra únicamente comienzo y fin de esperas en SQLite.

## Límites honestos

- **No hay `helper_of`** en el esquema ni en los agentes reales: el puente devuelve
  `null` y anuncia `features.helpers=false`. La UI admite relaciones cuando una
  versión posterior las exponga; no inventa ayudantes a partir del título.
- No hay fecha de transición: `since` significa «observado desde», en segundos
  epoch; se conserva en memoria mientras el estado no cambie.
- La rama se lee del HEAD local; tarjeta y proyecto se cruzan con rutas registradas
  en `dragon-mem`. No se guarda la salida de los paneles ni se llama a modelos.
- El foco se resuelve por clase de ventana (`org.dragonisland.Herdr`, herdr
  nativo) y, si hay varios clientes, por el espacio del título. Si es ambiguo,
  devuelve un error legible sin enfocar una ventana arbitraria.
- No existe comando de aprobación en `dragon-herdr`. El Taller solo navega al panel.
