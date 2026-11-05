# Handoff — zsh de Dragon en CachyOS (2026-11-05)

Corrección de la terminal tras la instalación real en CachyOS (equipo `dragonOS`): el prompt era el de CachyOS
(Powerlevel10k) en lugar del Starship de Dragon, y no se cargaba ningún plugin, sin ningún aviso.

## Estado inicial (paso 0)

- Repo en `~/.dragon-island-hypr` (oculto), rama `installer`, 3 archivos modificados. Los tres eran **del usuario**, no
  del instalador, así que se confirmaron, no se ignoraron:
  - `packages/user-pacman.txt` y `packages/user-aur.txt`: apps añadidas a mano tras la instalación (commit `354d650`;
    tabla de `pre-instalation.md` regenerada en `e58c5c3`).
  - `config/nvim/lazy-lock.json`: `~/.config/nvim` enlaza al repo y Lazy actualizó 9 plugins desde Neovim (`c0a18f9`).
- En este equipo no había identidad de git: los commits usan la de los anteriores (`oscardv18`) con `git -c`, sin tocar
  la configuración global.
- `~/.zshrc`: el usuario había comentado a mano el instant prompt, `cachyos-config.zsh` y `~/.p10k.zsh`; solo quedaba
  el bloque de Dragon. `~/.zshenv` exporta `DRAGON_ZSH_PLUGINS=~/.local/share/dragon-island/zsh-plugins` (con los tres
  clones hechos a mano). Las dos cosas siguen funcionando con el arreglo y **no se tocaron**.
- Registro (`~/dragon-install.log`): los tres `git clone` fallaron en `/usr/share/oh-my-zsh/custom/plugins` con
  «Permiso denegado» (el oh-my-zsh de CachyOS es de root) y en la segunda ejecución el módulo salió **✔ shell**.
- Diferencias con lo que se creía:
  - `~/.config/dragon-island/zsh` **ya era un enlace simbólico** a `config/zsh` (el registro dice «Ya enlazado»).
    Parecía una copia porque `ls` sigue el enlace del directorio. Punto 5 sin cambios.
  - El código no preguntaba nada antes de escribir la línea en `~/.zshrc` (`marker_set` la escribía directamente).
    Ahora hay una pregunta clara (punto 4).
  - `~/.config/starship.toml` **es** el de Dragon. Es un archivo real y no un enlace **por diseño**: `dragon-palette`
    lo reescribe con el acento (bloque `# >>> dragon-palette`). Si fuera un enlace, la paleta escribiría en el repo.
  - Hay un `starship` 1.27.0 instalado a mano en `/usr/local/bin` que gana en el PATH al paquete (misma versión).
    No molesta; se puede borrar con `sudo rm /usr/local/bin/starship` si se quiere.

## Qué se cambió (paso 1)

| Commit | Qué |
|---|---|
| `afb1404` | `config/zsh/dragon.zsh`: si p10k está cargado, vacía su instant prompt (`_p9k_instant_prompt_cleanup`, que también borra su caché) y lo descarga (`powerlevel10k_plugin_unload`). Los plugins de paquete van primero; la carpeta de oh-my-zsh solo se usa si es escribible; no se carga una segunda copia de lo que CachyOS ya cargó; si falta un plugin, avisa una vez por sesión (`DRAGON_ZSH_WARNED`) con el comando exacto. |
| `98229c1` | `lib/zsh-setup.sh` (reglas compartidas) + `modules/shell.sh`: `zsh-autosuggestions` y `zsh-syntax-highlighting` pasan a paquetes de `extra`; solo se clona fzf-tab; un clon fallido o un plugin ausente = módulo fallido. Preguntas claras con «Sí» por defecto (línea de `~/.zshrc`, chsh), dibujadas en `/dev/tty` aunque el instalador capture la salida; un «no» va a «Queda para ti». Si el `starship.toml` no es el de Dragon, se guarda en `backups/<fecha>/starship-antes-de-dragon/` (ruta propia, para que la copia de `palette_setup` no lo pise) y se pone el de Dragon. |
| `0191f38` | Migración `191-zsh-cachyos.sh`: clona fzf-tab si falta y cambia un `starship.toml` ajeno. Los paquetes los instala `update.sh` en su paso de paquetes. |
| `7c89320` | `doctor.sh`, sección «Terminal (zsh)»: shell por defecto, bloque, `starship.toml`, **prompt activo real** (zsh interactiva en una pty), los tres plugins cargados y arranque sin errores. Cada ✘ trae el comando. |
| `f01de2f` | `tests/zsh/test_zsh_cachyos.py` (11 pruebas) y su paso en `tests/run-all.sh`; `tests/idempotency.sh` crea archivos de plugin para no clonar. |

Decisiones:
- **p10k se descarga desde dragon.zsh**, no se evita que CachyOS lo cargue: el bloque marcado sigue siendo el único
  cambio en `~/.zshrc` y los archivos de CachyOS no se tocan. Coste: CachyOS carga p10k y lo descartamos (unos ms).
- **syntax-highlighting no se vuelve a cargar**: desde la 0.8 dibuja desde `zle-line-pre-redraw` y no envuelve widgets,
  así que cargarlo antes que fzf-tab (como hace CachyOS) no rompe nada. Cargar dos copias distintas sí podría.
- **La sonda de doctor usa `script(1)`** (pty): sin terminal, el plugin `fzf` de oh-my-zsh que activa CachyOS escribe
  «can't change option: zle», que en una terminal real no aparece.

## Verificación

- `tests/zsh` (11 pruebas, HOME temporal con el `~/.zshrc` de CachyOS, un oh-my-zsh de solo lectura simulado, y git,
  chsh, getent y sudo simulados): sin Dragon el prompt es p10k; tras el módulo es Starship, los tres plugins cargan y no
  hay errores; la segunda ejecución es idéntica; un clon fallido = módulo fallido, sin escribir en oh-my-zsh y con un
  único aviso; «no» → «Queda para ti»; `starship.toml` ajeno respaldado sin pisarse; migración 191 (dry-run,
  reparación, idempotencia, salida 10); doctor ✔/✘. Comprueba además que nada escribe en el repo.
- Paso 2, en este equipo: `./install.sh --modules shell --yes --no-sudo --no-update` → `core: ok`, `shell: ok`, doctor
  «Todo en orden». En una pty, `zsh -i` con tu `~/.zshrc` real da: prompt `starship prompt`, 0 hooks de p10k,
  autosuggestions y syntax-highlighting cargados, `^I` = `fzf-tab-complete`, `^R` = `fzf-history-widget`, `z tmp` →
  `/tmp`, stderr vacío. El `~/.zshrc` original de CachyOS (sin comentar) también da Starship, con el instant prompt
  activo o no.

## Pendiente / no verificado

- La pregunta de la línea de `~/.zshrc` y la de chsh solo se han probado sustituyendo `confirm_explicit` (el «no»),
  no pulsando teclas en una instalación real con gum.
- `~/.cache/p10k-instant-prompt-oddv.zsh` sigue en este equipo porque tu `~/.zshrc` actual no carga p10k. Si vuelves a
  descomentar las líneas de CachyOS, la primera terminal la borrará.
- Si quieres recuperar los aliases de CachyOS (`rip`, `jctl`, `cleanup`…), puedes descomentar
  `source /usr/share/cachyos-zsh-config/cachyos-config.zsh` en `~/.zshrc`: Starship seguirá mandando.
