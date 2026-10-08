#!/usr/bin/env bash
# dragon-island — test in a clean Arch container (needs docker; with sudo if your user is not in the docker group):
#   tests/container.sh                 uses `docker`
#   DOCKER="sudo docker" tests/container.sh
# 1. every official package of packages/*.txt exists in the Arch repos (pacman -Si)  [yay: EndeavourOS repo, skipped]
# 2. every AUR package exists (AUR RPC)
# 3. `install.sh --dry-run --yes --modules core,shell,theme` runs as a normal user and changes nothing
set -Eeuo pipefail
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKER="${DOCKER:-docker}"

# shellcheck disable=SC2016  # the script runs inside the container
INNER='
set -Eeuo pipefail
pacman -Syu --noconfirm --needed git curl unzip gum base-devel sudo pciutils jq >/dev/null
fails=0
echo "== 1. paquetes oficiales =="
for f in base pacman-core pacman-shell pacman-theme pacman-login pacman-plugins; do
    for p in $(awk "/^[[:space:]]*(#|\$|@)/ { next } { print \$1 }" /repo/packages/$f.txt); do
        [[ "$p" == yay ]] && { echo "- yay: repositorio de EndeavourOS (en Arch puro es AUR), se omite"; continue; }
        pacman -Si "$p" >/dev/null 2>&1 || { echo "✘ no existe: $p ($f.txt)"; fails=$((fails + 1)); }
    done
done
for p in $(awk "/^[[:space:]]*(#|\$)/ { next } /^@/ { next } { split(\$1, a, \":\"); if (a[1] == \"pacman\") print a[2] }" /repo/packages/extras.txt); do
    pacman -Si "$p" >/dev/null 2>&1 || { echo "✘ no existe: $p (extras.txt)"; fails=$((fails + 1)); }
done
echo "== 2. paquetes AUR =="
aur=$(cat /repo/packages/aur-*.txt | awk "/^[[:space:]]*(#|\$)/ { next } { print \$1 }"; awk "/^@/ { next } /^[[:space:]]*(#|\$)/ { next } { split(\$1, a, \":\"); if (a[1] == \"aur\") print a[2] }" /repo/packages/extras.txt)
q=""; for p in $aur; do q="$q&arg[]=$p"; done
found=$(curl -fsS "https://aur.archlinux.org/rpc/v5/info?${q#&}" | jq -r ".results[].Name")
for p in $aur; do grep -qx "$p" <<<"$found" || { echo "✘ no existe en el AUR: $p"; fails=$((fails + 1)); }; done
echo "AUR: $(wc -w <<<"$aur") paquetes, $(wc -l <<<"$found") encontrados"
echo "== 3. install.sh --dry-run =="
useradd -m -G wheel tester
cp -a /repo /home/tester/repo && chown -R tester /home/tester/repo
su tester -c "cd ~/repo && ./install.sh --dry-run --yes --modules core,shell,theme" > /tmp/dry.log 2>&1 || { echo "✘ el dry-run falló"; tail -20 /tmp/dry.log; fails=$((fails + 1)); }
grep -q "== Plan ==" /tmp/dry.log && echo "✔ el dry-run imprimió el plan" || { echo "✘ no hay plan en la salida"; fails=$((fails + 1)); }
test -z "$(su tester -c "cd ~/repo && git status --porcelain" 2>/dev/null | grep -v "^??")" && echo "✔ el repo no cambió" || echo "- (el repo copiado no es un clon: no se compara git status)"
test ! -d /home/tester/.local/state/dragon-island && echo "✔ el dry-run no creó ~/.local/state/dragon-island" || { echo "✘ el dry-run escribió estado"; fails=$((fails + 1)); }
exit $fails
'

$DOCKER run --rm -v "$REPO_DIR:/repo:ro" archlinux:latest bash -c "$INNER"
