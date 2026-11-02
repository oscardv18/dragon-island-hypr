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
