# Fase 5a · Base del Taller

Rama `feat/fase5a-base`, desde `main`; inicio 2026-10-31. En curso.

## 1. Entorno comprobado

| Herramienta | Versión |
|---|---|
| Hyprland | 0.57.0, commit `0aa6745f705f2c4b0a5004eb019ef76e5bbdb426` |
| Quickshell | 0.3.2 (Arch) |
| herdr | 0.9.5, protocolo 22 |
| Docker CLI | 29.9.2 |
| Git | 2.56.0 |

`hyprctl configerrors` vacío. La terminal heredaba una firma antigua; se recuperó
la sesión de `wayland-1` con `lib/hyprland-session.sh`, sin cambiar configuraciones.
El socket de herdr responde a `api snapshot`; el sandbox requiere permiso para acceder.
No se probó aún el daemon Docker (fuera del alcance de 5a).

Herramientas opcionales de §5.7 presentes: `gio`, `udisksctl`, `lsblk`, `7z`,
`bsdtar`, `unrar`, `avahi-browse`, `smbclient`, `net`, `secret-tool`,
`vipsthumbnail`, `magick`, `ffmpegthumbnailer`, `wl-copy`, `xdg-open`.
Ausente: `inotifywait`.

## Decisiones

- El usuario confirma mover Dwindle/Scrolling a `SUPER + CTRL + T`; `SUPER + T`
  queda para el Taller.
- Las maquetas requeridas están en `docs/design/`; `FrameDecor` ya está en `main`.
- No hay ramas locales sin fusionar. El árbol inicial está limpio; `main` tiene
  tres commits por delante de `origin/main` que se conservan.

## 2–3. Filtro y memoria

Filtro único en `dragon-core/secret_filter.py`, compatible con portapapeles,
búsqueda y actividad. 4 pruebas nuevas + 40 de motores + 13 de actividad pasan.
Migración 043 despliega también el filtro en instalaciones por copia.

`dragon-mem`: esquema de §4, WAL, claves concurrentes, WIP, FTS transaccional,
criterios, notas, plantillas, revisión por contenido, comentarios, esperas,
métricas, exportación <4 KB, registro del sistema y 7 respaldos SQLite coherentes.
Migración 044 e instalación nueva comparten `lib/mem.sh`; una base previa se
respalda antes de ampliar el esquema. 13 pruebas con HOME/XDG temporales y
shellcheck en verde. Lectura fría (mediana de 7): 87,7 ms (<150 ms).

## 4. Puente de herdr

`docs/HERDR-API.md` se escribió a partir de las ayudas, el esquema incorporado y
el socket real antes de implementar el adaptador. `dragon-herdr` ofrece probe,
snapshot, watch --record, focus, read, prompt por stdin y start; conserva su
lanzador sin argumentos. Migración 045, instalación base y extra herdr incluyen
las librerías necesarias también en modo copia.

7 pruebas con servidor falso: eventos <2 s, desconexión y reconexión, SIGTERM,
esperas sin duplicados, foco con hyprctl simulado, tachado antes de recortar,
prompts bloqueados rechazados y cruce con worktrees. Snapshot y probe reales
responden; no se enviaron prompts ni se arrancaron agentes reales.

Límites: herdr 0.9.5 no publica relaciones de ayudantes ni timestamps;
`helper_of=null`, `features.helpers=false`, `since` es tiempo observado.
