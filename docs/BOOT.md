# Tema de arranque de Dragon OS (módulo `boot`)

Limine primero; GRUB como alternativa. Todo lo marcado **(verificado)** se comprobó en esta máquina el 2026-11-02; **(fuente)** viene de los
documentos del paquete exacto que se descargó y se abrió (no se ejecutó ningún binario descargado); **(no verificado)** queda para la máquina virtual.

## 0. Descubrimiento

### Esta máquina no usa Limine (verificado)

| Qué | Resultado |
|---|---|
| Sistema | EndeavourOS (no CachyOS), `bootctl status`: «Current Boot Loader: **GRUB 2.16**», Secure Boot desactivado |
| `/boot` | `efi/`, `grub/`, `memtest86+/`, kernels (`vmlinuz-linux`, `initramfs-*`); `/boot/efi` (la ESP) **solo lo lee root** |
| Limine | `pacman -Q limine` → no instalado; no hay `limine`, `limine-entry-tool`, `/etc/default/limine` ni `limine.conf` |
| GRUB | `/etc/default/grub` con `GRUB_BACKGROUND='/usr/share/endeavouros/splash.png'`, `GRUB_TIMEOUT='5'`, `GRUB_DISTRIBUTOR='EndeavourOS'`; ya existe `/boot/grub/themes/starfield` |
| VM | `qemu-system-x86_64` y OVMF (`/usr/share/edk2/x64/OVMF_CODE.4m.fd`, `OVMF_VARS.4m.fd`) instalados |

Por tanto **nada sobre Limine/CachyOS se pudo comprobar «en la máquina»**. Se verificó contra los paquetes reales descargados (sin instalarlos):
`extra/limine 12.9.6-1` (Arch, `https://geo.mirror.pkgbuild.com/extra/os/x86_64/`) y, del repositorio de CachyOS
(`https://mirror.cachyos.org/repo/x86_64/cachyos/`), `limine-entry-tool 1.40.0-1` y `limine-mkinitcpio-hook 1.40.0-1`. Cuando instales CachyOS comprueba con
`pacman -Q limine limine-entry-tool` que las versiones no son muy distintas; `dragon-boot detect` y `verify` lo diagnostican.

### Dónde lee Limine su configuración (fuente: `CONFIG.md` 12.9.6)

En el volumen del disco de arranque; en EFI primero el de `limine_x64.efi`. En cada volumen, por este orden:
`<carpeta del .efi>/limine.conf` (con `limine-entry-tool` el `.efi` queda en `/EFI/limine/` y el config que escribe es `$ESP/limine.conf`; si existiera además un `/EFI/limine/limine.conf`, **taparía** al otro), si no `/EFI/BOOT/limine.conf`, y luego `/boot/limine/limine.conf`,
`/boot/limine.conf`, `/limine/limine.conf`, `/limine.conf`. **Se usa solo el primero que exista; los demás se ignoran.** `dragon-boot` calcula ese orden,
edita el que Limine leerá y avisa (`shadowed_by`) de los otros. `boot():/ruta` es la partición que contiene el config, así que el papel tapiz va en
`<ESP>/dragon-os/wallpaper.jpg` y se referencia como `boot():/dragon-os/wallpaper.jpg`.

### CachyOS y la regeneración (fuente: `limine-entry-tool` 1.40.0)

- `limine-entry-tool` (y `limine-update`, `limine-mkinitcpio` por los hooks de pacman) genera y **modifica `$ESP_PATH/limine.conf`**; `ESP_PATH` se busca en `/efi`, `/boot`, `/boot/efi`, `/limine`
  o se fija en `/etc/default/limine` (`/etc/limine-entry-tool.conf` es solo la plantilla: «copia a `/etc/default/limine`»). El README advierte de que **solo escribe en `$ESP_PATH/limine.conf`** y
  de que otro config en una ubicación anterior lo tapa.
- El archivo se **parsea a un árbol** («Parsing of limine.conf», «Preserve old comments», copia `limine.conf.old` si pasaron `CONFIG_BACKUP_THRESHOLD` horas, 6 por defecto); la plantilla con
  `timeout: 3` / `default_entry: 2` solo se usa cuando no existe el archivo. **No pude comprobar ejecutando la herramienta si conserva las opciones globales propias** (el binario es un ejecutable
  nativo descargado y no lo ejecuté) → el diseño **no depende de ello**:
- **Gancho posterior propio**: la herramienta ejecuta `/etc/boot/hooks/post.d/*` **después** de actualizar `limine.conf` (en orden léxico; código de salida `0` ok, `1–99` error no fatal, `≥100` fatal).
  `modules/boot.sh` instala `90-dragon-boot-theme`, que ejecuta `dragon-boot reapply`: si el bloque del tema sigue ahí no hace nada; si una regeneración lo quitó, lo vuelve a poner **sin tocar las entradas nuevas**.
  Nunca devuelve ≥ 100 (no puede impedir una actualización de kernel). Como `90-dragon…` < `90-limine-enroll-config`, corre antes de que se enrole el hash.
- **Dónde van los ajustes propios para que no se pisen**: dentro del bloque marcado del propio `limine.conf` (`# >>> dragon-boot … >>>` … `# <<< dragon-boot <<<`), al **final de la parte global** (antes de la primera `/Entrada`),
  más la copia de root en `/usr/local/lib/dragon-os-boot/{dragon_boot.py,settings.json,wallpaper-src.*}`. Tus propias opciones globales que choquen con las del tema (`timeout`, `wallpaper`, `term_*`…) se
  **comentan** (`# dragon-boot desactivó: …`), no se borran, y `revert` las restaura. Opciones tuyas que el tema no usa (`default_entry`, `remember_last_entry`, `editor_enabled`…) no se tocan.
- **Peligro (fuente)**: con `ENABLE_ENROLL_LIMINE_CONFIG=yes` el hash del config va dentro del binario de Limine y **cualquier edición impide arrancar** hasta volver a enrolar. `dragon-boot` lo lee de
  `/etc/limine-entry-tool.conf` y `/etc/default/limine` y **se niega** (`enrolled_config`).

### Opciones de tema de Limine 12.9.6 (fuente: `CONFIG.md`)

Globales usadas: `timeout` (decimales admitidos, `0` = sin menú), `interface_branding` + `interface_branding_colour` (RRGGBB), `interface_help_colour`, `interface_help_colour_bright`,
`wallpaper` (BMP, PNG, JPEG, QOI; varios = al azar), `wallpaper_style` (`tiled|centered|stretched`, por defecto `stretched`), `backdrop` (RRGGBB, lo que rodea a una imagen `centered`),
`term_palette` y `term_palette_bright` (8 colores RRGGBB cada una, separados por `;`, orden negro-rojo-verde-marrón-azul-magenta-cian-gris / gris oscuro-…-blanco), `term_background`
(**TTRRGGBB**, TT = transparencia: `00` opaco, `ff` transparente; por defecto `80` con papel tapiz), `term_foreground`, `term_background_bright`, `term_foreground_bright`, `term_margin` (px; 64 con papel tapiz),
`term_margin_gradient`. Resolución: `interface_resolution: ANCHOxALTO` (solo la interfaz de Limine; si no existe elige otra). Otras que **no** se usan: `term_font*` (fuente propia: opcional, sin hash en Secure Boot se omite),
`interface_help_hidden`, `graphics`, `editor_*`. Con Secure Boot + hash enrolado, papel tapiz y fuentes se omiten en silencio si no coinciden (el menú sale sin imagen, no deja de arrancar).

**Resolución y sin deformar**: Limine estira (`stretched`) por defecto. Se usa `centered` + `backdrop` con la imagen ya recortada («cover») a la resolución elegida (1920×1080 por defecto; `--resolution`):
en una pantalla de otra proporción se ve centrada sobre el color de fondo, nunca deformada. JPEG de línea base (sin progresivo; el soporte de JPEG progresivo no está documentado), calidad 90.

### GRUB (verificado en esta máquina)

`grub-mkfont`, `grub-mkconfig`, `grub-script-check` existen (2.16). El tema completo (`theme.txt`, `background.png`, 9 piezas `select_*.png`, barra de cuenta atrás, fuentes `.pf2` de Outfit con `grub-mkfont -n "Dragon UI"` →
«Dragon UI Regular 20/26/44») va en `/boot/grub/themes/dragon-os/`; `/etc/default/grub` recibe un bloque marcado (`GRUB_THEME`, `GRUB_TIMEOUT`, `GRUB_TIMEOUT_STYLE`, `GRUB_GFXMODE`) y las líneas tuyas
con esas claves (y `GRUB_BACKGROUND`, que EndeavourOS fija) se comentan. `GRUB_DISTRIBUTOR` **no** se cambia (los nombres de las entradas siguen siendo los de siempre; «Dragon OS» sale como rótulo del tema).
`grub-mkconfig` se escribe en un archivo temporal, se pasa `grub-script-check` y solo entonces se reemplaza `grub.cfg` (con copia con fecha). Las entradas de Windows las genera `os-prober` como siempre.

## 1. Uso

```sh
dragon-boot preview --out /tmp/arranque.png                 # lo que verás, sin tocar nada (--bootloader grub para GRUB; --resolution 1366x768)
dragon-boot detect                                          # qué gestor está en uso, dónde está su config, si hay Windows, si hay que tener cuidado
./install.sh --dry-run --modules boot                       # el plan y la DIFERENCIA exacta (sin sudo ni escrituras)
./install.sh --modules boot                                 # Limine o GRUB, el que se detecte
./install.sh --modules boot --bootloader grub               # forzar uno
./install.sh --revert-boot                                  # quitar el tema
```

Cada paso con sudo se muestra con su comando y se pregunta **también con `--yes`**; sin terminal no se hace nada. Orden: (1) motor y gancho en `/usr/local/lib/dragon-os-boot` y `/etc/boot/hooks/post.d`
(no toca `/boot`), (2) simulación de solo lectura con el diff, (3) aplicar, (4) `dragon-boot verify`.

La **vista previa** dibuja con el papel tapiz, la paleta y los textos reales; la **disposición** del menú es una aproximación (no es una captura de Limine/GRUB: eso es la prueba de la VM, §3).
Paleta (de `Theme.qml`, una sola fuente): `#c50ed2` (marca), `#00c1e4` (cian), `#7c3aed` (violeta), `#06c993` (verde) + `bg #07060d`, `text #edebf5`, etc.; el instalador congela la paleta en `settings.json`.

## 2. Seguridad

- **Respaldo con fecha**: `limine.conf.bak-dragon-AAAAMMDD-HHMMSS` (o `grub.bak-…`, `grub.cfg.bak-…`) junto al original; nunca se sobreescribe ni se borra uno (`-2`, `-3` si hay colisión).
- **`--dry-run`** (`dragon-boot apply --dry-run`, `./install.sh --dry-run`): muestra el diff unificado y las acciones; no escribe nada.
- **Nunca** se toca una entrada EFI: la herramienta no llama a `efibootmgr`, `bootctl` ni escribe variables (una prueba lo comprueba con binarios falsos y revisando el código), ni `limine-install`/`grub-install`.
- **Nunca** se borra ni edita una entrada de arranque: solo cambia la parte global; una comprobación exige que las líneas desde la primera `/Entrada` sean idénticas byte a byte antes de escribir.
  **Windows** (`/Windows` con `protocol: efi` + `bootmgfw.efi`, o `menuentry` de os-prober) se conserva intacto; `detect` lo lista.
- **Comprobación de sintaxis antes de aplicar**: el nuevo `limine.conf` debe pasar el validador (opciones `clave: valor` antes de la primera entrada, colores RRGGBB/TTRRGGBB, paleta de 8, `wallpaper_style` válido, bloque bien cerrado, entradas con nombre);
  si el archivo **actual** ya está roto no se toca. (No es el validador oficial de Limine: no está instalado aquí; la prueba real es la VM.) En GRUB: validación de `/etc/default/grub` y `grub-script-check` del `grub.cfg` generado.
- Escritura **atómica** (archivo temporal en el mismo directorio + `rename`), y la copia de root del motor se instala con `install` (root:root, 0644).
- Si hay `ENABLE_ENROLL_LIMINE_CONFIG=yes`, se niega (ver arriba). Si hay otro `limine.conf` que tapa al editado, avisa.

### Volver atrás

Normal: `./install.sh --revert-boot` (o `sudo python3 /usr/local/lib/dragon-os-boot/dragon_boot.py revert --bootloader limine --esp /boot`): quita el bloque, descomenta tus opciones, borra `dragon-os/` y el gancho.

**Si el equipo no arranca (desde un USB)** — arranca un USB vivo de Arch/EndeavourOS/CachyOS:

```sh
lsblk -f                                   # localiza la ESP (FAT32, ~512 MB–1 GB) y /boot si es otra partición
sudo mount /dev/nvme0n1p1 /mnt             # ← tu ESP (nvme0n1p1 es un ejemplo)
ls /mnt/limine.conf.bak-dragon-*           # (o /mnt/boot/limine.conf.bak-…, /mnt/EFI/limine/…)
sudo cp /mnt/limine.conf.bak-dragon-AAAAMMDD-HHMMSS /mnt/limine.conf     # el archivo que Limine lee; el respaldo con la fecha anterior a tu cambio
sudo rm -r /mnt/dragon-os                  # opcional: el papel tapiz
sudo umount /mnt && reboot
```

- Si no hay respaldo: un `limine.conf` mínimo en ese mismo sitio basta (`timeout: 5` y una entrada `/Arch` con `protocol: linux`, `path: boot():/…/vmlinuz-linux`, `module_path: boot():/…/initramfs-linux.img`, `cmdline: root=UUID=… rw`).
- GRUB: monta `/` y `/boot`, `sudo arch-chroot /mnt`, restaura `/etc/default/grub.bak-dragon-…`, `grub-mkconfig -o /boot/grub/grub.cfg`; si `grub.cfg` estaba mal, existe `grub.cfg.bak-dragon-…`.
- Si Limine panica por un hash: es `ENABLE_ENROLL_LIMINE_CONFIG` (el tema se niega a editar en ese caso, así que solo ocurriría por una edición a mano). Se resuelve ejecutando `limine-enroll-config` **(no verificado)**.
- El menú de arranque de la placa (F12/Esc) sigue ahí: las entradas EFI no se tocan.

## 3. Prueba real en la máquina virtual con UEFI (pendiente: es tuya)

Nada de esto se ejecutó. **Antes de tocar el equipo real**, hazlo en una VM con la misma disposición (CachyOS con Limine).

**A. Solo el menú (sin instalar nada, sin root)**

```sh
mkdir -p /tmp/vm/esp/EFI/BOOT && cd /tmp/vm
cp /usr/share/limine/BOOTX64.EFI esp/EFI/BOOT/BOOTX64.EFI          # paquete `limine` (pacman -S limine en el anfitrión o extraído)
cat > esp/limine.conf <<'EOC'
timeout: 10
/Dragon OS
    protocol: linux
    path: boot():/no-existe/vmlinuz
/Windows
    protocol: efi
    path: boot():/EFI/Microsoft/Boot/bootmgfw.efi
EOC
~/Devs/dragon-island-hypr/bin/dragon-boot apply --bootloader limine --esp /tmp/vm/esp          # usuario normal: el ESP falso es tuyo
cp /usr/share/edk2/x64/OVMF_VARS.4m.fd vars.fd
qemu-system-x86_64 -machine q35 -m 1G -vga std \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,file=vars.fd \
  -drive file=fat:rw:esp,format=raw
```

Esperado: fondo morado oscuro con las ondas del papel tapiz, «Dragon OS» en magenta arriba a la izquierda, lista con la selección violeta, cuenta atrás de 3 s con el menú visible al pulsar una tecla. Captura sin interfaz:
añade `-display none -monitor stdio` y en el monitor `screendump /tmp/vm/menu.ppm`. Compáralo con `dragon-boot preview`. Las entradas no arrancan (no hay kernel): es solo el menú.
**Anota** si el texto se lee sobre el fondo (si no: sube `term_background` a `00`) y si el papel tapiz aparece centrado o recortado.

**B. Instalación completa (la prueba que importa)**

1. En la VM (OVMF, disco ≥ 40 GB), instala CachyOS con **Limine** como gestor; `pacman -Q limine limine-entry-tool` y apunta las versiones.
2. Haz una **instantánea** (`qemu-img snapshot -c antes-boot disco.qcow2`, o la de virt-manager) y copia `/boot/limine.conf` (o la ruta que muestre `dragon-boot detect`) a un sitio seguro.
3. Clona dragon-island, `./install.sh --dry-run --modules boot` → lee el diff. `./install.sh --modules boot` y contesta a cada sudo.
4. `dragon-boot verify --bootloader limine --esp <ESP>` → `ok: true, themed: true`. Reinicia: se ve el menú del paso A con tus entradas reales; arranca el sistema.
5. **Regeneración**: `sudo pacman -S linux-cachyos` (reinstalar) o `sudo limine-update`; reinicia: el tema sigue (y `journalctl -b | grep dragon-boot` sin errores). Prueba también quitando el bloque a mano y ejecutando `limine-update`: el gancho lo repone.
6. **Windows** (opcional): segunda partición con Windows o una entrada falsa `protocol: efi` a un `.efi` de prueba: sigue en el menú y arranca igual que antes.
7. **Volver atrás**: `./install.sh --revert-boot`, reinicia (Limine con el aspecto de antes). Luego estropea `limine.conf` a propósito, arranca el ISO vivo y sigue «Volver atrás desde un USB».
8. Repite 1–4 con GRUB (instalación con GRUB) y `--bootloader grub`: el tema de GRUB (menú centrado, caja violeta con borde cian, barra de cuenta atrás) y `Windows` generado por os-prober.

**Criterio de «bien»**: arranca, el tema se ve, sobrevive a un kernel nuevo, y `--revert-boot` deja el aspecto anterior. Cualquier otra cosa: instantánea, no el equipo real.
