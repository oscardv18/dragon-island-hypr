# Handoff instalador: rc2

Fecha: 2026-11-04. Rama `installer`, etiqueta `instalador-rc2` (rc1 ya estaba subido). Continúa `handoff-instalador-rc1.md`.
Pruebas con `hyprctl`, `hyprpm`, `kreadconfig6`/`kwriteconfig6` y `notify-send` falsos. Nada se ejecutó contra una instalación real salvo lo indicado en A.

## A) Sintaxis de `hyprctl dispatch` en Hyprland 0.57 (Lua)
- **Comprobado en el Hyprland 0.57.0 de esta máquina** (el WebFetch al wiki dio 404 en las tres URL probadas, así que no pude citar el wiki): `hyprctl dispatch 'hl.dsp.exec_cmd("true")'` → `ok`;
  `hyprctl dispatch exec true` → `')' expected near 'true'` (el mismo error que viste). Los nombres de las funciones salen de los stubs que instala Hyprland
  (`/usr/share/hypr/stubs/hl.meta.lua`): `hl.dsp.exec_cmd`, `.focus`, `.exit`, `.dpms`, `.layout`, `.send_shortcut`, `.window.{close,float,fullscreen,move,pin,resize,set_prop,drag}`, `.workspace.toggle_special`.
- Revisión de todo el repositorio (binds, Quickshell, `bin/*`, hypridle, dragon-herdr, doctor, instalador, pruebas): **el código ya usaba la sintaxis nueva**; la única llamada antigua era
  `docs/TROUBLESHOOTING.md:84` (`hyprctl dispatch exec hyprlock`), corregida a `hyprctl dispatch 'hl.dsp.exec_cmd("hyprlock")'`. Las referencias de terceros (`.agents/`, `quickshell/`, `docs/design/`) no se tocan.
- `tests/installer_ux/test_rc2.py`: `HyprctlSyntax` falla si aparece `hyprctl dispatch <sintaxis antigua>`, `Hyprland.dispatch("…")` sin `hl.` fuera de un `usingLua ? … : …`, o `['dispatch','…']` sin `hl.`;
  y comprueba que cada `hl.dsp.*` usado existe en la API instalada.

## B) Versión fijada de Hyprland
`packages/pins.json` (`hyprland: "0.57"`) + `lib/pins.sh`. `doctor.sh`: «Versión de Hyprland = fijada» o ✘ con qué hacer (`git pull && ./update.sh`; si ya estás al día, alinear Hyprland). El primer arranque
(`plugins-foreground.sh`) lo valida **antes** de `hyprpm update`: si la serie no coincide no compila, muestra los pasos y avisa «Plugins con error» (queda pendiente). `plugins.lua` ya no dice «0.56.x».
Migración `190-plugins-pins.sh`: copia el script y los pines a `~/.local/state/dragon-island` si el módulo plugins ya estaba (idempotente, `deploy_item`/respaldo, `DRY_RUN`).
**Pendiente conocido:** el pin de `hyprglass` quedó en `null` (la 0.9.1 era la de 0.56; no inventé la de 0.57). Tras el primer arranque en la VM, mira `hyprctl plugin list` y fíjala en `pins.json`.

## C) KWallet
`keyring_kwallet_offer` (módulo keyring, fase «Llavero y grupos»): si `kwallet` o `kwallet-pam` están instalados, AVISA y ofrece —solo con un «sí» explícito, por defecto No, `--yes` nunca lo da—
poner `apiEnabled=false` en la sección `org.freedesktop.secrets` de `kwalletrc` (respaldo antes; `kreadconfig6` evita repetirlo). No desinstala nada. Si dices que no, queda en «Queda para ti» con el comando. `kwallet-pam` sigue siendo solo aviso.
`has_gum` respeta `DRAGON_NO_GUM=1` (preguntas `[S/n]` sencillas; lo usan las pruebas).

## D) Documentación
`docs/VIRTUALBOX.md` (enlazado desde `docs/INSTALL.md`): SUPER interceptado por el host, submapa passthrough en el host (`hl.define_submap`; firma comprobada en los stubs, **no probado** en un host real),
`MAIN_MOD=ALT` en `local.conf` solo para pruebas (nuevo en `config/hypr/binds.lua`, solo SUPER/ALT/CTRL) y cómo abrir una terminal con `hyprctl` en la sintaxis 0.57.

## Probar en la VM
`git pull`, `./install.sh`, reinicia y entra en Hyprland: `./doctor.sh` debe mostrar «Versión de Hyprland = fijada»; si hay KWallet, el instalador pregunta una vez.
