#!/usr/bin/env bash
# shellcheck disable=SC2034
# =============================================================================
# module taller — Docker + Compose + Buildx, LazyGit y LazyDocker (perfil taller).
# Los paquetes los instala la fase «Paquetes»; este módulo prepara el servicio en la fase «Servicios»:
#   · habilita docker (sudo, confirmado)
#   · el grupo docker EQUIVALE A ROOT: añadir al usuario solo con confirmación explícita (nunca con --yes solo)
# herdr (instalador oficial) sigue siendo opt-in en extras.
# =============================================================================
taller_desc() { echo "Docker, Compose, Buildx, LazyGit y LazyDocker (el grupo docker solo con tu confirmación)"; }
taller_sudo() { echo "pacman -S (paquetes), systemctl enable --now docker, y usermod -aG docker solo si lo confirmas"; }
taller_packages() { pkg_list "$REPO_DIR/packages/pacman-taller.txt"; }
taller_check() { command -v docker >/dev/null 2>&1 && systemctl is-enabled docker.service >/dev/null 2>&1; }
taller_plan() {
    echo "  · paquetes: $(taller_packages | tr '\n' ' ')"
    echo "  · servicios: docker.service se habilita (sudo, con confirmación)"
    echo "  · grupo docker: NO se añade solo. Equivale a root; se pide confirmación explícita (--docker-group la da de antemano)"
}

taller_apply() {
    ensure_via pacman taller_packages || log_warn "Paquetes de Taller pendientes."
    return 0
}

# group_member <user> <group>
taller_in_group() { id -nG "$1" 2>/dev/null | tr ' ' '\n' | grep -qx "$2"; }

# docker_group_consent → 0 only with an explicit yes: --docker-group, or «sí» to a prompt that defaults to NO
docker_group_consent() {
    $DOCKER_GROUP_FLAG && return 0
    $ASSUME_YES && return 1
    has_gum || return 1
    CONFIRM_DETAIL=$'El grupo «docker» equivale a root: quien lo tenga puede montar / en un contenedor y leer o cambiar cualquier archivo.\nSin el grupo, usa «sudo docker» o docker rootless.' \
        confirm_default_no "¿Añadir a $USER al grupo docker?"
}

taller_services() {
    if ! pkg_installed docker && ! $DRY_RUN; then log_warn "docker no está instalado: se omite el servicio."; return 0; fi
    confirm_sudo "Habilitar y arrancar docker.service (daemon de contenedores)" systemctl enable --now docker.service || true
    if taller_in_group "$USER" docker; then
        log_info "$USER ya está en el grupo docker."
    elif docker_group_consent; then
        confirm_sudo "Añadir a $USER al grupo docker (equivale a root; efectivo al reiniciar la sesión)" usermod -aG docker "$USER" || true
        need_relogin "docker: cierra sesión y vuelve a entrar para que el grupo docker se aplique"
    else
        log_warn "No se añade $USER al grupo docker (equivale a root). Si lo quieres: sudo usermod -aG docker $USER"
        MANUAL_ITEMS+=("Docker sin grupo: usa «sudo docker», o decide añadirte con: sudo usermod -aG docker \$USER (equivale a root)")
    fi
    return 0
}

taller_revert() {
    log_info "taller: los paquetes y el grupo docker no se quitan solos. Para desactivar el servicio: sudo systemctl disable --now docker"
}
