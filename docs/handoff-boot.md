# Handoff · tema de arranque (rama `feat/boot-tema`, worktree `../dragon-boot-tema`)

Sin `vin.py`, sin push, sin fusionar. Migraciones 160 y 161. Detalle técnico y pruebas reales pendientes: `docs/BOOT.md`.

## Hecho (un commit por punto)

| Punto | Qué |
|---|---|
| 0 Descubrimiento | `docs/BOOT.md` §0: lo verificado en tu máquina, lo leído en los paquetes reales de Limine 12.9.6 y limine-entry-tool 1.40.0, y lo que no se pudo comprobar |
| 1 Tema Limine | `dragon-core/dragon_boot.py` + `bin/dragon-boot`: papel tapiz de `assets/wallpapers` recortado («cover») a la resolución (1920×1080 por defecto) en JPEG de línea base, paleta de `Theme.qml`, marca «Dragon OS», `timeout: 3`; `dragon-boot preview` |
| 2 GRUB | tema completo (imágenes 9-slice, fuentes `.pf2`, barra de cuenta atrás), `--bootloader grub|limine|auto` en `install.sh` y en `dragon-boot`, detección automática |
| 3 Seguridad | respaldos con fecha, `--dry-run` con diff, validación de sintaxis, entradas/Windows byte a byte, sin EFI, negativa con `ENABLE_ENROLL_LIMINE_CONFIG=yes`, vuelta atrás (también desde USB) |
| 4 Pruebas | `tests/boot/` (38 pruebas) en una ESP y una raíz falsas |
| Instalador | `modules/boot.sh` + `lib/boot-tools.sh` (opt-in), gancho `config/boot/90-dragon-boot-theme`, `./install.sh --revert-boot`, migraciones `160-boot-tools`, `161-boot-refresh` |

## Lo que debes saber antes de usarlo

1. **Esta máquina usa GRUB (EndeavourOS), no Limine** y Limine no está instalado: la parte Limine se verificó contra los paquetes descargados (documentación y archivos), **sin ejecutar ningún binario descargado**
   (se bloqueó al intentarlo y lo respeté). Si el equipo de Limine es otro (CachyOS), allí hay que pasar la prueba de la VM.
2. **No pude comprobar si `limine-entry-tool` conserva las opciones globales al regenerar.** El diseño no depende de ello: el gancho `post.d` repone el tema si falta (probado con una regeneración simulada que las conserva y otra que las descarta).
3. **Toca `/boot` con sudo.** Cada paso se pregunta aunque uses `--yes`, y sin terminal no hace nada. Los respaldos con fecha quedan junto a cada archivo.
4. Con `ENABLE_ENROLL_LIMINE_CONFIG=yes` se niega a editar (editar impediría arrancar).
5. La vista previa (`dragon-boot preview`) usa el papel tapiz y los colores reales, pero la **disposición** del menú de Limine es una aproximación mía: la imagen exacta solo sale de la VM.

## Pasos manuales

1. `dragon-boot preview --out /tmp/arranque.png` (y `--bootloader grub`) y mírala.
2. **VM con OVMF** (`docs/BOOT.md` §3, A y B): primero solo el menú, luego CachyOS completo con instantánea.
3. Recién entonces, en el equipo real: `./install.sh --dry-run --modules boot` → `./install.sh --modules boot`.
4. Si algo falla: `./install.sh --revert-boot`, o USB vivo (`docs/BOOT.md` «Volver atrás»).

## Verificado

- `tests/boot/` (38): Limine en ESP falsa — bloque válido con los 4 colores, entradas y Windows idénticos byte a byte, opciones propias comentadas (no borradas), respaldo con fecha, idempotencia (sin 2.º respaldo ni reescritura),
  dry-run sin cambios, ninguna llamada a `efibootmgr`/`bootctl` (binarios falsos + revisión del código), config roto o con hash enrolado → se niega, papel tapiz recortado sin deformar y JPEG de línea base, config que tapa a otro, revert;
  regeneración simulada (conserva / descarta globales → gancho) y gancho nunca fatal; GRUB en raíz falsa — tema completo, bloque en `/etc/default/grub`, idempotencia, revert, `grub.cfg` intacto; módulo con `BOOT_SUDO=""` (se niega sin terminal incluso con `--yes`); migraciones 160/161 con `DRY_RUN=1` y `true`.
- `shellcheck -x` limpio, `tests/check-docs.sh` en verde, bloque nuevo en `tests/run-all.sh`.
- Vista previa renderizada y revisada a mano (Limine y GRUB, 1920×1080).

## No verificado

Arranque real (Limine y GRUB) en VM o hardware; `limine-entry-tool` ejecutándose; `grub-mkconfig`/`grub-script-check` reales sobre `/boot` (el código existe, las pruebas usan `--no-regen`); fuentes `.pf2` en un GRUB real
(nombre «Dragon UI Regular N»); JPEG baseline en Limine; legibilidad de `term_background 50`; varios discos/ESP; Secure Boot.

**Resumen:** el módulo `boot` tematiza Limine (y GRUB) con la paleta, el papel tapiz y la marca de Dragon OS; solo reescribe la parte global del config, con respaldo con fecha, diff previo y sin tocar entradas EFI ni Windows.
Esta máquina usa GRUB y no tiene Limine, así que lo de Limine se validó contra los paquetes reales y 38 pruebas en una ESP falsa, no arrancando.
Antes del equipo real queda la prueba en la VM con OVMF (pasos en `docs/BOOT.md` §3).
