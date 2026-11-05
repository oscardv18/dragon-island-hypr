#!/usr/bin/env bash
# 193 — la app de escritorio de Herdr con el aspecto de Ghostty: tema dragon-ghostty (colores de Ghostty) y la fuente
# CaskaydiaCove NF SemiBold 14 en ~/.config/herdr-app. De settings.json solo se añaden las claves que faltan (nunca se
# pisa el zoom, los sonidos ni una fuente elegida). La transparencia y el blur los pone Hyprland (opacity-herdr-app en
# config/hypr/rules.lua), que llega con el enlace o con la sincronización de configuraciones.
# Sin ~/.config/herdr-app (la app nunca se abrió) sale con 10 y se reintenta en el siguiente update.
# Idempotente; copia de seguridad con deploy_item / backup_copy. Respeta DRY_RUN.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
# shellcheck source=lib/herdr.sh
. "$REPO_DIR/lib/herdr.sh"
herdr_app_setup
