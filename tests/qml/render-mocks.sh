#!/usr/bin/env bash
# Renders the pure views of the bottom islands offscreen with simulated data (no Quickshell, no services).
# usage: tests/qml/render-mocks.sh <out dir>      → apps-0/3/12.png (right island), herdr-*.png (left island, when it exists)
# Quickshell's QML plugin cannot be loaded by the plain `qml6` runner, so the script renders a patched COPY of the
# project's Theme (root type Singleton → QtObject); nothing in the repo is modified.
set -Eeuo pipefail
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${1:?usage: render-mocks.sh <out dir>}"
mkdir -p "$OUT"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/config" "$WORK/tests/qml"
cp -r "$REPO_DIR/config/quickshell" "$WORK/config/quickshell"
cp "$REPO_DIR"/tests/qml/*_mock.qml "$WORK/tests/qml/"
for f in Theme Icons; do
    sed -i -e '/^import Quickshell$/d' -e 's/^Singleton {/QtObject {/' "$WORK/config/quickshell/$f.qml"
done
printf 'singleton Theme 1.0 Theme.qml\nsingleton Icons 1.0 Icons.qml\n' > "$WORK/config/quickshell/qmldir"
for m in "$WORK"/tests/qml/*_mock.qml; do
    QT_QPA_PLATFORM=offscreen timeout 90 qml6 "$m" -- "$OUT"
done
ls "$OUT"
