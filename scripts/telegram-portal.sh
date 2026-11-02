#!/usr/bin/env bash
# Telegram's QFileDialog must use the themed portal in Hyprland.
# Other desktop sessions inherit their normal Qt integration.
set -Eeuo pipefail
case ":${XDG_CURRENT_DESKTOP:-}:" in
    *:Hyprland:*|*:hyprland:*) export QT_QPA_PLATFORMTHEME=xdgdesktopportal ;;
esac
exec Telegram "$@"
