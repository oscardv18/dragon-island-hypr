ESTADO: COMPLETO

# Fase 5d · herramientas Codex · 2026-11-01

Rama `feat/fase5d-archivos-codex`, worktree
`/home/oddv/Devs/dragon-5d-archivos-codex`, desde
`feat/fase5d-herramientas` (`0ce93cf`). d1–d3 se revisaron por encima y se
conservaron; las extensiones se implementan en adaptadores separados. No se tocó
`config/quickshell/`. No se ejecutaron vin.py, push, fusiones, sudo ni red real.

## Entrega por punto

| Punto | Commit | Resultado |
|---|---|---|
| d4 | `ff4fe24` | listado, integridad, extracción en staging y creación de comprimidos; migración 071 |
| d5 | `efb8019` | descubrimiento, conexión GVFS, llavero, montajes, recursos y marcadores; 072 |
| d6 | `d17fb72` | Samba usershare con ACL del usuario y restricciones de rutas; 073 y preparación manual |
| d7 | `97bcae5` | `.desktop`, asociación reversible y FileManager1 opcional; 074 |
| d8 | `e98f800` | atajo SUPER+E, 075, espera de la UI, teclado documentado y revisión de seguridad |

**Dependencia de 5c, expresamente fuera de esta entrega por decisión del usuario:** conectar `Files.agentRequested(paths)` al compositor de
5c y activar `Files.composerAvailable`. El contrato de
`docs/handoff-fase-5d-pantallas.md` asigna ese enlace a 5c; ambas propiedades están
en QML, fuera del alcance autorizado de B. El usuario confirmó «Dejar el enlace a 5c pendiente». El alcance acordado de B
queda terminado con esa integración reservada a 5c. No se cambió el diseño ni se habilitó un botón
que no hace nada. El resto del pulido de vistas ya está en la rama de pantallas.

## Contratos

- `dragon-files archive list|test|extract|create`: argumentos del handoff de
  pantallas, JSON de una respuesta o eventos de progreso/conflicto y `done`.
  Los errores conservan `ok:false`, `t:error` y `{code,message,hint}`.
- Contraseñas de extracción: primera línea de stdin. Las siguientes líneas siguen
  disponibles para `{"answer":"skip|overwrite|rename","all":bool}`. Nunca se
  construye una contraseña en argv, entorno, diagnóstico JSON ni fichero.
- Extracción: snapshot privado y acotado dentro de `.dragon-extract-*` en el
  destino, validación de metadatos y lectura completa antes de publicar. Sin
  rutas absolutas/`..`/Windows/controles, sin dispositivos ni enlaces duros.
  Se eliminan setuid/setgid; se comprueba espacio y se exige `--confirm-bomb`
  para tamaño >2 GiB y ratio >200. Tope adicional de 100 000 entradas.
- Los enlaces simbólicos internos se resuelven contra el árbol final previsto,
  incluidos conflictos y enlaces ya existentes. Se rechaza cualquier escape o
  ciclo. No se escriben descendientes de un enlace del comprimido.
- Conflictos de extracción por elemento de primer nivel: sobrescribir una carpeta
  reemplaza esa carpeta completa; no fusiona recursivamente. Las decisiones se
  recogen antes de publicar el primer elemento. SIGTERM y errores limpian staging.
- Lectura con la API de libarchive, disponible con bsdtar. Así los nombres con
  saltos de línea se validan como datos, sin inferirlos de listados de texto.
  Para datos de 7z cifrados se usa `7z x -so` con selección literal por entrada
  validada y contraseña por stdin. Creación: ZIP, 7z, tar.gz, tar.xz y tar.zst.
- `net discover/mounts/saved/shares/connect/unmount/save/forget`: formas del
  handoff. `avahi-browse -artp`, `gio`, `smbclient -g -N` y `secret-tool` son
  opcionales y devuelven error legible al faltar. SMB, SFTP, NFS, FTP, DAV y DAVS
  pasan por el backend GVFS instalado. La UI recibe una ruta FUSE local; sin ella
  se informa `missing_fuse`, aunque el montaje GVFS haya tenido éxito.
- Credenciales de red: solo stdin y llavero con secret-tool. Marcadores guardan
  URI pública, protocolo, usuario y nombre; se rechazan URI con contraseña,
  controles, query o fragmento. No se aceptan automáticamente claves SSH.
- `share status|enable|disable`: usershares, ACL limitada al usuario, invitados
  apagados por defecto (`guest_ok=n`); `--guest` es una petición explícita y la
  configuración manual recomendada la rechaza. Solo subcarpetas propias de HOME,
  sin HOME entero, sistema, SSH, GnuPG, configuración, llaveros ni datos del Taller;
  se resuelven enlaces antes de validar. No se cambia cortafuegos ni servicios.
- `--browse [rutas/URI file…]`: IPC `qs ipc call files open <carpeta>`, sin shell
  ni xdg-open. `--set-default` guarda una sola vez la asociación anterior;
  `--restore-default` la recupera. No elimina ni modifica Dolphin/Nautilus.
- `--filemanager1` opcional: PyGObject, bus de sesión, tres métodos estándar;
  no reemplaza a otro propietario y termina tras 30 s sin peticiones. Sin
  activación D-Bus ni autoinicio. ShowItems/ShowItemProperties abren la carpeta
  contenedora: seleccionar el elemento/abrir sus propiedades exige ampliar el IPC
  de QML, que hoy solo tiene `open(ruta)`.

## Migraciones y coordinación con A

- 070 existente se conserva. 071–074 usan `files_tools_setup` para desplegar
  adaptadores y dependencias tanto por copia como por enlace, con los respaldos
  de `deploy_item`. 073 solo explica la preparación administrativa manual.
- 074 propone la asociación XDG, guarda el gestor anterior y respeta DRY_RUN.
  Avisa que la asociación afecta también a Plasma. ASSUME_YES acepta la propuesta.
- 075 renueva `binds.lua` copiado con `backup_copy`: SUPER+E → `files open`.
- 074 y 075 devuelven 10 si no existe `services/Files.qml` instalado. Al quedar
  pendientes se reintentan en la siguiente actualización; no activan un atajo o
  una asociación hacia una UI inexistente.
- A está en `feat/fase5d-migracion` (`b8a134b`, desde `e6bf0d6`), worktree
  `/home/oddv/Devs/dragon-5d-migracion`: 080 despliega los QML nuevos, servicios,
  registros, tokens, shell.qml y reglas Lua (flotante, centrada, sin decoración,
  1226×612, blur nativo). Tiene su prueba aislada y diario.
- Integrar ambas ramas corresponde al usuario/coordinador. No se fusionó nada.
  Resolver la entrada compartida de `docs/noche/codex.md` conservando ambas notas.
  Si 074/075 se omitieron antes de 080, volver a ejecutar las migraciones pendientes
  en una actualización posterior, sin modificar a mano migrations.done.

## Verificado

- **52 pruebas** en `tests/files/`, una sola ejecución agregada final: d1–d3,
  comprimidos maliciosos, creación/extracción en cinco formatos, ZIP y 7z cifrados,
  cancelación, corrupción sin salida parcial, escapes por enlaces existentes,
  red/Samba/xdg-mime/qs falsos y migraciones con HOME/XDG temporales.
- Cada regla de d4 tiene su fixture malicioso generado localmente. La bomba usa
  1 MiB de ceros con ratio real >200 y umbral absoluto reducido solo en la prueba.
- FileManager1: bus privado con dbus-run-session, las tres llamadas con gdbus,
  qs falso y segundo propietario rechazado. Ningún bus ni ventana de la sesión
  real se usó en esa prueba.
- `tests/files/bench.py`: siete arranques fríos, mediana **112,5 ms** para 1000
  entradas, dentro del objetivo de 150 ms.
- `tests/migrations-dry-run.sh`: **62 migraciones**, DRY_RUN=1 y true, y tres
  estados del actualizador sin modificar HOME ni ejecutar comandos reales de
  sesión, sudo o red. Pasó también el control de estado Git.
- `shellcheck -x` en launcher, helper y migraciones 070–075; `luac -p` en binds;
  `git diff --check`. A: dos pruebas de 080, shellcheck y sintaxis Lua.
- No se ejecutó `tests/run-all.sh`. Solo se repitieron pruebas focalizadas por
  fallos concretos o nuevos casos; no se repitió la suite agregada de archivos.

## Riesgos y comprobaciones pendientes

- No hay validación visual ni prueba del shell contra estos comandos en una
  sesión real. Las capturas de pantallas usan su simulador. Al integrar debe verse
  la ventana de Archivos de 1226×612, flotante, sin barra del compositor y con un
  solo blur, además de Red, Extraer y Compartir según las maquetas.
- Los formatos dependen de libarchive/7z instalados. No se verificaron RAR, ISO,
  DEB, RPM, CAB, AppImage ni archivos con **cabeceras cifradas**. Estos últimos
  pueden no ser legibles con libarchive aunque la contraseña sea válida; se devuelve
  error y se limpia staging. No se promete compatibilidad universal por extensión.
- La publicación mueve elementos de primer nivel al terminar la validación;
  no es una transacción global con rollback ante fallo de disco durante los movimientos.
  No protege frente a otro proceso del mismo usuario cambiando el destino a la vez.
- La conexión GVFS depende de sus backends, GVFS-FUSE y la sesión de llavero.
  No se probó ningún servidor real, descubrimiento real, USB ni contraseña de red.
  Si falta soporte de un protocolo, se informa el fallo; no se hace un montaje sudo.
- El diálogo CLI de gio se reconoce en LC_ALL=C y se acota por tiempo; probarlo
  con las versiones instaladas antes de dar por validada la autenticación real.
- D7 conserva el propietario inicial de FileManager1 y no registra autoinicio;
  probar «Mostrar en carpeta» con el navegador cuando se arranque explícitamente.
- No se cambió docs/HANDOFF.md: el plan reserva su consolidación al coordinador.

## Pasos manuales

1. Integrar A+B; el enlace del compositor queda pendiente de 5c por decisión del
   usuario. Resolver los bloques
   compartidos como indique el coordinador. Reiniciar Quickshell por los tipos QML
   nuevos y recargar Hyprland cuando el usuario decida aplicar los cambios.
2. Reintentar 074/075 si quedaron pendientes antes de 080. Revisar la asociación
   de inode/directory; restaurarla con `dragon-files --restore-default` si procede.
3. Si se desea compartir, seguir **docs/FILES-SAMBA.md**: paquete, grupo,
   directorio usershare, respaldo de smb.conf, testparm, contraseña Samba y servicio.
   Todos los comandos que requieren sudo están allí; no se ejecutaron.
4. Abrir puertos solo para una LAN verificada, si hace falta. La documentación da
   el comando UFW y una subred de ejemplo; nunca se abrió el cortafuegos.
5. FileManager1 opcional: instalar python-gobject si falta y arrancar explícitamente
   `dragon-files --filemanager1`; ver **docs/FILES-DESKTOP.md** para las limitaciones.
6. Verificar con ventanas reales los criterios visuales del handoff de pantallas,
   una extracción ZIP/7z/tar.zst, cancelación, un recurso SMB y el botón Compartir.
