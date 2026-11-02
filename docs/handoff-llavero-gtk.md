# Handoff llavero y selector GTK

Rama `feat/llavero-portal-gtk`, worktree `/home/oddv/Devs/dragon-island-llavero-gtk`, desde `main` (`053d774`).
Sin sudo, vin.py, push ni fusión. El worktree original tenía cambios en listas de paquetes; quedaron intactos.

## A — Llavero

`login.Locked = false`. SDDM ya integra GNOME Keyring en auth/password/session;
`kwallet-pam` también está instalado y habilitado por PAM, sin prueba de que cause
el aviso. Claude Desktop 4.4212.0-1 viene del paquete `claude-desktop`, usa un wrapper
que admite flags y se lanzaba sin selección de almacén. Su código usa safeStorage
y rechaza `basic_text`: el registro `main.log` del 2026-11-02 10:30:03 confirma `backend=basic_text`.
Se extrajeron solo fecha y enum: la causa es la selección automática bajo Hyprland,
no un llavero bloqueado. No se probaron credenciales.
Migración 120: fuerza libsecret en su archivo de flags con backup, idempotencia y DRY_RUN.
`docs/KEYRING.md` explica la evidencia, las líneas PAM ya presentes y la retirada
manual opcional de kwallet-pam. No se reinicia Claude: falta confirmar el aviso tras
cerrar y abrir la app desde su menú. Prueba automatizada: HOME/XDG temporales,
conservación de opciones/comentarios, reemplazo de almacén, backup, repetición y DRY_RUN.

## Resumen (tres líneas)

A: llavero abierto; backend basic_text de Electron confirmado, flags libsecret preparados.
B: pendiente de completar en el segundo commit.
Manual: reiniciar Claude voluntariamente y comprobar el aviso; PAM/KWallet documentados, sin sudo ejecutado.
