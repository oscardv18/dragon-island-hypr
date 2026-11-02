# Neovim personal en el instalador

Rama `feat/nvim`, worktree `/home/oddv/Devs/dragon-island-nvim`, desde main
`a3cafe7`. Un commit por punto 0–6. Sin vin.py, push, fusión ni sudo ejecutado.
Los cambios previos de las listas personales de paquetes en el worktree principal
quedaron intactos. `~/.config/nvim` permanece como carpeta y no se modificó:
comprobados contenido y mtime de los 15 archivos seleccionados contra el inventario.

## Inventario y copia

LazyVim sobre lazy.nvim; **49 plugins fijados** y 15 extras; Neovim instalado
0.12.6. El mínimo efectivo es **0.12 con LuaJIT**, por los commits fijados de
Treesitter y Rustaceanvim (aunque LazyVim aislado pida 0.11.2). Tema One Dark Pro
Vivid transparente, Snacks Explorer a la derecha, Laravel/Blade, PHP, frontend,
Astro, Rust, Go, Docker, YAML/JSON/TOML, Markdown, pruebas y depuración.
Inventario completo, servidores y herramientas en [NVIM.md](NVIM.md).

Copiados diez Lua (incluido init.lua), lazy-lock.json, lazyvim.json,
.neoconf.json, stylua.toml y LICENSE: 15 archivos de origen. Se conserva el ejemplo
Lua inactivo. La licencia Apache-2.0 de origen viaja con la configuración.
Después se añadió un guard Lua del primer uso (16 archivos finales) y se ajustó
init/bootstrap para consentimiento, tiempo máximo y pin del propio lazy.nvim.
No se reescribieron tus specs, aspecto, idiomas ni atajos.

Excluidos: README de origen (resumido en NVIM.md), su .gitignore (integrado en el
del repo) y nvim.log (estado). No existían after/, ftplugin/, snippets/ ni spell
propio. **No se copió ni inspeccionó para importar** ~/.local/share/nvim: plugins,
shada, swap, undo, cachés, logs e historial quedan fuera del repo.

Seguridad: filtro compartido en todos los archivos seleccionados antes de copiar,
y otra revisión sobre los 16 finales. Revisión manual de credenciales, URLs y
rutas personales: sin hallazgos ni sustituciones de variables necesarias.
`check-nvim-public.py` rechaza secretos sin imprimirlos y añade comprobaciones
de URL privada, email, ruta personal, binario y enlaces. Solo admite config.

## Instalador, migración y retirada

Módulo `editor` predeterminado y separable, con los siete métodos del contrato;
paquetes validados por pacman -Si y tabla generada actualizada. El paquete Rust
puede estar satisfecho por el proveedor rustup ya instalado (comprobado localmente);
no se sustituye. Python ya lo instala core para herramientas compartidas.
Configuración por enlace/copia, backup_copy y manifiesto; retirada con uninstall
restaura la anterior, conserva datos/plugins y es segura al repetirla.

Migración **150**: sin DRAGON_NVIM=1 solo puede adoptar desde una terminal con gum
y confirmación explícita; con --yes/no TTY o en dry-run sin opt-in sale 10.
Con opt-in lista diferencias solo por nombre antes de reemplazar. Si es idéntica
igualmente respalda y crea el enlace. No se aplicó sobre el HOME real.

Primer uso: confirma Sí/No antes de la red (No predeterminado), comprueba GitHub
en 8 s y ejecuta Lazy! restore en un hijo con timeout 180 s + 5 s de cierre.
Sin red/fallo/cancelación/version insuficiente, abre Neovim base. No inicializa
plugins ausentes fuera del hijo confirmado. Marca el hash del lockfile y comprueba
los directorios; una nueva apertura con caché completa no repite la restauración.
LSP/parsers y herramientas Mason no quedan congelados por lazy-lock.json.

## Verificado y pendiente

- Catorce pruebas HOME/XDG temporales en tests/nvim: copia/enlace, idempotencia,
  backup, retirada real/restauración repetida, dry-run 1/true, opt-in y comparación,
  secretos/URL privada/ruta personal, sintaxis Lua, cancelación headless, offline,
  timeout y éxito/marcador simulados. Incluidas en tests/run-all.sh.
- Smoke test del instalador --dry-run incluye editor y pasa sin cambios en
  HOME/XDG ni estado Git. La consulta de versión real se corrigió para usar
  NVIM_LOG_FILE=/dev/null, porque Neovim crea logs incluso con --version.
- Shellcheck/sintaxis Bash de scripts modificados, tabla generada, filtro público
  y diff --check: OK. No se ejecutó la suite completa ajena al cambio.
- **No se sincronizaron plugins reales**, no se instaló ningún paquete y no se
  probó la interfaz con los plugins actuales. Todo ello corresponde a la VM.

Pasos manuales: revisar docs/NVIM.md; en una VM CachyOS con los requisitos previos,
instalar el módulo, abrir nvim, aceptar y verificar :checkhealth/Mason/LSP junto
con proyectos de prueba PHP/Blade, Astro/TS, Rust y Go. Si se usa rustup, preparar
su toolchain/componentes. Los frameworks y Xdebug son configuración de proyecto.
Para adoptar aquí deliberadamente: DRAGON_NVIM=1 bash migrations/150-nvim-opt-in.sh.
Para restaurar plugins más tarde: :DragonNvimRestore. Para retirar el módulo:
./uninstall.sh --modules editor (sin borrar a mano ~/.config/nvim).

El PLAN-INSTALADOR.md solicitado no existía en main ni en el historial local;
se creó desde los módulos existentes tras la confirmación del usuario, con la
fila editor en su sección 1. docs/INSTALL.md está actualizado.

## Resumen (tres líneas)

Tu LazyVim queda versionado y auditado: 49 plugins fijados, sin secretos ni datos de ejecución.
El módulo editor despliega con respaldo; migración 150 opt-in y restauración de plugins confirmada/acotada.
Catorce pruebas aisladas pasan; tu carpeta original está intacta y la sincronización real queda para la VM.
