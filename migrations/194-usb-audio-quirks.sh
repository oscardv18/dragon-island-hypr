#!/usr/bin/env bash
# 194 — arreglos de audio USB en /etc/modprobe.d/dragon-usb-audio.conf: el micrófono de los audífonos USB Jieli
# «UACDemoV1.0» (4c4a:4155) no grababa nada en Linux (cada paquete de captura acababa en -75 EOVERFLOW); el kernel ya
# trae el arreglo para otro chip Jieli y quirk_alias se lo aplica. Paso con sudo, confirmado; sin sudo o si se
# rechaza, sale con 10 y se reintenta en el siguiente update. Idempotente; respeta DRY_RUN y NO_SUDO.
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
# shellcheck source=lib/usb-audio.sh
. "$REPO_DIR/lib/usb-audio.sh"
usb_audio_quirks_setup || exit 10
