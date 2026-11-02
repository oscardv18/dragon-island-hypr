# Neovim del usuario

## 0. Inventario de origen (solo lectura, 2026-11-02)

Origen: `~/.config/nvim`, 108 KiB contando documentación y un log, sin enlaces
simbólicos. Neovim instalado: 0.12.6 con LuaJIT. No se ejecutó esta configuración
ni se modificó/borró su directorio durante el inventario.

Gestor: **lazy.nvim**, sobre **LazyVim**. `init.lua` carga `config.lazy`, que
importa `lazyvim.plugins` y `plugins`. El bootstrap original clona `stable`;
`lazy-lock.json` fija **49 plugins por commit**. `lazyvim.json` guarda 15 extras,
`.neoconf.json` configura neodev/neoconf y `stylua.toml` el estilo de Lua.

**Mínimo efectivo: Neovim 0.12.0 con LuaJIT.** Requisitos comprobados en los
README de los commits del lockfile, no deducidos del LazyVim actual:

| Componente fijado | Mínimo |
|---|---|
| [lazy.nvim](https://github.com/folke/lazy.nvim/blob/85c7ff3711b730b4030d03144f6db6375044ae82/README.md) | Neovim 0.8; Git 2.19 |
| [LazyVim](https://github.com/LazyVim/LazyVim/blob/999700997f72227187d49d8b92667183dc7fc809/README.md) | Neovim 0.11.2; Git 2.19 |
| [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig/blob/ac062d0d01c019c0dbdb798968f3e5d8b35c3853/README.md) | Neovim 0.11.3 |
| [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter/blob/ca581c3436fc2b236847f5b739ebc263739e5ca6/README.md) | Neovim 0.12; tree-sitter-cli 0.26.1; compilador C |
| [rustaceanvim](https://github.com/mrcjkb/rustaceanvim/blob/a968f5133b8b24f481de12f08cd79420d1ace559/README.md) | Neovim 0.12 |

### Ajustes propios y extras

- One Dark Pro Vivid con paleta viva y transparencia; Snacks Explorer a la derecha.
- Intelephense para PHP/Blade y vtsls para TypeScript. ESLint aporta diagnósticos
  y acciones; Prettier formatea el frontend.
- Extras dap.core, test.core; PHP, TypeScript, Astro, Docker, Rust, Go, YAML,
  JSON, TOML, Markdown, Tailwind; Prettier y ESLint.
- Laravel/Blade con `adalessa/laravel.nvim`, pickers Snacks y atajos de Artisan,
  rutas, generadores, recursos, acciones y entorno. Detecta el proyecto por su raíz.
- `lua/plugins/example.lua` retorna `{}` antes de sus ejemplos: Pyright,
  Telescope, flake8 y demás referencias de ese archivo **no están activas**.

### LSP, formateadores y herramientas

| Área | Configuración activa y herramientas heredadas de los extras fijados |
|---|---|
| Lua (base) | lua_ls, lazydev, StyLua |
| PHP / Laravel / Blade | intelephense; Pint o php_cs_fixer según proyecto; phpcs; blade-formatter; php-debug-adapter/Xdebug 9003 |
| TypeScript / JavaScript / React | vtsls, ESLint, Prettier |
| Astro / web | astro, html, cssls, tailwindcss; Prettier y prettier-plugin-astro del proyecto |
| Rust | rust-analyzer por rustaceanvim, rustfmt del toolchain; CodeLLDB, crates.nvim |
| Go | gopls, goimports, gofumpt; golangci-lint y Delve según extras |
| Docker / Compose | dockerls, docker_compose_language_service, Hadolint |
| YAML / JSON / TOML | yamlls, jsonls, taplo; SchemaStore, Prettier según tipo |
| Shell | bashls, ShellCheck; shfmt cuando lo seleccionan los defaults |
| Markdown | marksman, Prettier, markdownlint-cli2, markdown-toc, markdown-preview |

La lista propia `mason.ensure_installed` contiene exactamente `blade-formatter`,
`pint`, `rust-analyzer`, `shellcheck` y `php-debug-adapter`. LazyVim/Mason LSP y
los extras añaden sus herramientas. Los nombres LSP no son paquetes pacman.
El lockfile fija plugins, **no** versiones de herramientas Mason ni parsers.

Parsers propios: bash, blade, css, html, php_only y toml, combinados con base/extras.
Los frameworks y dependencias npm/composer se instalan dentro de cada proyecto;
no se copian ni instalan globalmente. No hace falta el motor Docker para editar
Dockerfile/Compose. Python/Pyright no se requieren por los ejemplos inactivos.

### Portabilidad y selección

No se encontraron rutas `/home/oddv…` ni repositorios privados en la configuración.
Ya usa `stdpath("data")` y `vim.fs.root`. Antes de publicar se revisan todos los
archivos seleccionados con el filtro compartido y una revisión manual.

Selección: `init.lua`, todo `lua/`, `lazy-lock.json`, `lazyvim.json`, `.neoconf.json`,
`stylua.toml` y LICENSE (licencia Apache-2.0 de origen). No existen after/,
ftplugin/, snippets/ ni diccionarios spell propios. El README original se resume
aquí y su `.gitignore` se integra con las exclusiones del repo.

Exclusiones: `nvim.log`, logs, swap, undo, shada, cachés, historial y **todo**
`~/.local/share/nvim`, incluidos los plugins. Son estado, no configuración.

### Plugins fijados (49)

- `blink.cmp`
- `bufferline.nvim`
- `catppuccin`
- `conform.nvim`
- `crates.nvim`
- `flash.nvim`
- `friendly-snippets`
- `gitsigns.nvim`
- `grug-far.nvim`
- `laravel.nvim`
- `lazy.nvim`
- `lazydev.nvim`
- `LazyVim`
- `lualine.nvim`
- `markdown-preview.nvim`
- `mason-lspconfig.nvim`
- `mason-nvim-dap.nvim`
- `mason.nvim`
- `mini.ai`
- `mini.icons`
- `mini.pairs`
- `neotest`
- `neotest-golang`
- `neotest-pest`
- `neotest-phpunit`
- `noice.nvim`
- `nui.nvim`
- `nvim-dap`
- `nvim-dap-go`
- `nvim-dap-ui`
- `nvim-dap-virtual-text`
- `nvim-lint`
- `nvim-lspconfig`
- `nvim-nio`
- `nvim-treesitter`
- `nvim-treesitter-textobjects`
- `nvim-ts-autotag`
- `onedarkpro.nvim`
- `persistence.nvim`
- `plenary.nvim`
- `render-markdown.nvim`
- `rustaceanvim`
- `SchemaStore.nvim`
- `snacks.nvim`
- `todo-comments.nvim`
- `tokyonight.nvim`
- `trouble.nvim`
- `ts-comments.nvim`
- `which-key.nvim`

## 1. Revisión de publicación

Los 15 archivos seleccionados pasaron `scripts/check-nvim-public.py` **antes de
copiarlos**. Usa `dragon-core/secret_filter.py` en su modo de detecciones tipadas
(el mismo de `redact`): no interpreta los hashes públicos del lockfile como tokens.
También rechaza rutas personales, emails, enlaces simbólicos y URLs cuyo host no
esté revisado. No imprime los valores detectados. Se repite sobre `config/nvim`
antes del despliegue y en las pruebas.

La revisión manual cubrió todos los Lua activos, el ejemplo inactivo, JSON,
configuración de StyLua y licencia: sin claves API, tokens, URLs privadas ni datos
personales que eliminar. No hubo sustituciones por variables de entorno porque
no se encontraron secretos. Las únicas URLs son documentación pública y GitHub.
El código no intenta anonimizar ni copiar logs.

## 2. Copia versionada

Se copiaron los 15 archivos seleccionados a `config/nvim`, byte por byte tras la
revisión, sin seguir enlaces ni leer directorios de plugins. El lockfile conserva
los 49 commits originales. El ejemplo Lua se conserva como parte de tu carpeta,
pero sigue desactivado. Las exclusiones de estado se añadieron al `.gitignore`.
Los ajustes del primer arranque se añaden en el punto del módulo, sin modificar
ningún archivo del origen instalado.

## 3. Módulo editor y primer uso

`editor` estará activo por defecto y puede excluirse con `--modules`. Despliega
según LINK_MODE, conserva un `backup_copy` del destino y lo registra para la
retirada. Uninstall restaura el respaldo sin borrar plugins ni datos de usuario;
una segunda retirada no elimina la configuración restaurada.

Paquetes validados con `pacman -Si` (2026-11-02): neovim, git, ripgrep, fd, gcc,
tree-sitter-cli, nodejs, npm, lazygit, go, rust, php, composer, curl, unzip y
wl-clipboard. No se ejecutó ninguna instalación de paquetes en esta máquina.
Rust incluye Cargo/rustfmt/Clippy; pacman reconoce el proveedor rustup existente
sin sustituirlo. Con rustup ya instalado, el toolchain y sus componentes siguen
siendo responsabilidad del usuario. No se cambian dependencias de proyectos.

El aspecto y los specs personales se conservan. Solo se añade una barrera en
`init.lua` y `lua/config/dragon_first_use.lua`, más estos ajustes de bootstrap:
se fija lazy.nvim al commit de su lockfile y la instalación de plugins ausentes
solo está habilitada en el hijo confirmado. El primer uso pide Sí/No (No por
defecto), prueba GitHub con un máximo de 8 s y ejecuta, como usuario:

```sh
nvim --headless '+Lazy! restore' +qa
```

La implementación usa `timeout --kill-after=5s 180s`, hereda el config/XDG del
usuario y añade `DRAGON_NVIM_RESTORE=1` **solo al hijo** para evitar recursión.
No muestra la salida de red ni credenciales en errores. Sin red, sin consentimiento,
con versión insuficiente o con fallo/timeout, avisa y abre el editor base.
`:DragonNvimRestore` vuelve a ofrecer la confirmación. Para automatizar en la VM:
`DRAGON_NVIM_SYNC=1 nvim` autoriza expresamente la misma restauración acotada.

El estado de éxito queda en `stdpath("state")/dragon-plugins-restored`, asociado
al hash del lockfile; se comprueba además la presencia de los 49 directorios.
No se persiste en la configuración ni se copia desde esta máquina. Los LSP,
formateadores y parsers se gestionan por Mason/Treesitter al usarlos; no quedan
congelados por el lock de plugins.

**La sincronización real no se ejecuta en las pruebas ni en esta máquina.** Se
hará en la VM CachyOS limpia, con red y confirmación, seguida de `:checkhealth`,
`:checkhealth mason` y `:checkhealth vim.lsp`. Allí hay que probar un proyecto
Laravel/Blade, Astro/TypeScript, Rust y Go con sus dependencias locales; Xdebug,
Composer/npm y Rustup requieren su configuración de proyecto/toolchain habitual.

## 4. Esta máquina: adopción opt-in

La migración 150 **no se ejecutó sobre tu configuración real**. `--yes` y un
terminal no interactivo no autorizan reemplazar Neovim: sale 10 y lo deja intacto.
Para adoptarla deliberadamente después de revisar el repo:

```sh
DRAGON_NVIM=1 bash migrations/150-nvim-opt-in.sh
```

La variable autoriza el reemplazo. Antes de tocar nada se compara la carpeta y
se listan únicamente los archivos diferentes o exclusivos, nunca su contenido.
También puedes ejecutar sin variable desde una terminal con gum: presenta esa
comparación y pide confirmación explícita. Si es idéntica igualmente se respalda
con `backup_copy` antes del enlace. El resultado de esta migración es un symlink;
la instalación nueva permite `--copy`. Las diferencias actuales esperables son
el guard del primer uso, los ajustes de bootstrap y el log excluido del repo.
No borres tu carpeta a mano para instalar. Si no optas por adoptarla, mantienes
tu configuración actual y la migración queda pendiente.

## 5. Pruebas sin tocar el HOME real

`python3 -m unittest discover -s tests/nvim -v`: catorce casos, con HOME y todas las
raíces XDG temporales. Cubren enlaces/copias, doble despliegue sin cambios,
backup (también de enlaces y copias idénticas), rechazo seguro de backup fallido, dry-run (1/true), retirada real por uninstall y segunda retirada segura,
opt-in obligatorio aun con --yes, comparación antes de reemplazar, igualdad con
respaldo, filtro de secretos/URL privada/ruta personal, sintaxis Lua, inicio sin
consentimiento, offline y timeout simulados, y marcador de restauración simulada
que evita repetir la red. No hay sincronización real ni pruebas sobre tus plugins.
La consulta de versión usa `NVIM_LOG_FILE=/dev/null`: incluso `nvim --version`
podría crear un log, y no debe hacerlo durante dry-run.

El grupo está incluido en `tests/run-all.sh`; el smoke test de dry-run del
instalador incluye ahora `editor`. La validación real de los plugins y la
apariencia de Neovim queda para la máquina virtual, como se indica arriba.
