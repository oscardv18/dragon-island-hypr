# Plan del instalador modular

Este documento se reconstruyó a partir del instalador existente porque no estaba
presente en main. Describe el contrato actual; no introduce una fase nueva.
Fuentes: `install.sh`, `uninstall.sh`, `lib/common.sh`, `modules/` y `docs/INSTALL.md`.

## 1. Módulos

Todos implementan `_desc`, `_plan`, `_sudo`, `_packages`, `_apply`, `_check` y
`_revert`. `core` siempre se incluye; `--modules` permite separar el resto.

| Módulo | Por defecto | Responsabilidad | Retirada |
|---|---|---|---|
| `core` | Sí, obligatorio | Hyprland/Quickshell, terminales, servicios y herramientas compartidas | Retira despliegues y restaura sus respaldos |
| `shell` | Sí | zsh, Starship, herramientas de terminal e inclusiones marcadas | Retira inclusiones y despliegues propios |
| `editor` | Sí | Neovim ≥ 0.12, configuración personal, herramientas de PHP/JS/Rust/Go; plugins en primer uso con confirmación y timeout | Restaura el Neovim anterior; conserva plugins y datos |
| `theme` | Sí | Fuentes, iconos, ajustes Qt/GTK y fondos | Retira ajustes propios, conserva paquetes |
| `plugins` | Sí | Plugins del compositor, compilación en sesión válida | Deshabilita plugins gestionados |
| `keyboard` | Sí | Distribuciones de teclado en override local; localectl opcional | Retira su bloque marcado |
| `login` | No | Tema SDDM opt-in y guía para otros gestores | Reversión del instalador del tema |
| `keyring` | No | Integración de Secret Service y PAM opt-in | Restaura respaldos de cambios gestionados |
| `extras` | No | Apps, herdr y listas personales seleccionadas | Retira configuración; paquetes solo si se pide |

## 2. Flujo y garantías

1. Detectar Arch/EndeavourOS/CachyOS y comprobar requisitos de `pre-instalation.md`.
2. Elegir módulos y modo enlace/copia; mostrar paquetes, cambios y pasos sudo.
3. Confirmar los pasos privilegiados; actualizar con pacman -Syu antes de añadir
   paquetes, para evitar una actualización parcial.
4. Aplicar módulos con helpers comunes y respaldos en el estado del proyecto.
5. Registrar módulos, LINK_MODE y despliegues en el manifiesto. Uninstall recorre
   módulos en orden inverso; no desinstala paquetes sin petición explícita.
6. Ejecutar doctor y mostrar el resultado y pendientes.

`DRY_RUN` no escribe en HOME/XDG ni pide sudo. Las listas de paquetes se validan
contra pacman y alimentan la tabla generada de `pre-instalation.md`.
`backup_copy` conserva archivos antes del reemplazo; el manifiesto permite
restaurarlos. `deploy_item` respeta LINK_MODE y no repite un despliegue idéntico.
Los cambios en instalaciones existentes llevan migración idempotente.

Neovim tiene una protección adicional: migración 150 **opt-in**, aun con --yes.
El primer uso de una configuración nueva pide otra confirmación para la red;
solo restaura los commits del lockfile y no instala frameworks en proyectos.
Sin red o con fallo/timeout abre el editor base; la VM valida la restauración real.
