#!/usr/bin/env bash
# Installs the dragon-island skill pack into a project (Antigravity and/or Claude Code)
# and fetches the community "hyprland" skill (full official wiki, updated daily).
#
# Usage:
#   ./install-skills.sh <project-dir>            # Antigravity: <project>/.agents/skills
#   ./install-skills.sh <project-dir> --claude   # also Claude Code: <project>/.claude/skills
#   ./install-skills.sh --global                 # Antigravity global: ~/.gemini/config/skills
set -Eeuo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS=(dragon-island quickshell hyprland-plugins arch-tui-installer)
HYPR_SKILL_REPO="https://github.com/marceloeatworld/hyprland-ai-skill"

targets=()
if [[ "${1:-}" == "--global" ]]; then
  targets+=("$HOME/.gemini/config/skills")
else
  proj="${1:?Uso: $0 <carpeta-del-proyecto> [--claude] | --global}"
  targets+=("$proj/.agents/skills")
  [[ "${2:-}" == "--claude" ]] && targets+=("$proj/.claude/skills")
fi

for t in "${targets[@]}"; do
  mkdir -p "$t"
  for s in "${SKILLS[@]}"; do
    rm -rf "${t:?}/$s"
    cp -a "$HERE/.agents/skills/$s" "$t/$s"
    echo "✓ $s → $t/$s"
  done
  if [[ -d "$t/hyprland/.git" ]]; then
    git -C "$t/hyprland" pull --ff-only --quiet && echo "✓ hyprland (actualizado) → $t/hyprland"
  else
    rm -rf "${t:?}/hyprland"
    git clone --depth 1 --quiet "$HYPR_SKILL_REPO" "$t/hyprland" && echo "✓ hyprland → $t/hyprland"
  fi
done

echo
echo "Listo. Reinicia el agente (o abre un chat nuevo) para que detecte las skills."
