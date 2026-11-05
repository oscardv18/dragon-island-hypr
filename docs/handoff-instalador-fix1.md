# Instalador fix1: proveedores de paquetes y latencia

Fecha: 2026-11-03. Solo rama `installer`, carpeta `../dragon-installer`.
Partida limpia en `10e8c88`; se ejecutó `git pull --rebase origin installer`
antes de editar. Sin otras ramas, worktrees, clones, PR, agentes ni vin.py.
No se editó el escritorio de `~/Devs/dragon-island-hypr`, no se ejecutó una
instalación real, sudo ni recargas. `/status` no está expuesto como herramienta
en esta sesión; se comprobaron directorio, rama y estado de Git.

## Causa confirmada antes de editar

Consultas reales: `pacman -Qi nodejs nodejs-lts-krypton rust rustup` y
`pacman -Si nodejs nodejs-lts-krypton rust rustup`.

| Paquete instalado | Versión | Provides relevante | Conflicts With relevante |
|---|---|---|---|
| nodejs-lts-krypton | 24.22.1-1 | nodejs=24.22.1 | nodejs |
| rustup | 1.29.2-1 | rust, cargo, rustfmt | rust, cargo, rustfmt |

Los repositorios ofrecen `extra/nodejs 26.13.0-1` y
`extra/rust 1:1.99.1-1`. El inventario instalado contiene los nombres reales
de los proveedores, no dos instalaciones adicionales llamadas nodejs y rust.
El preflight comparaba nombres exactos para determinar el estado y luego
enfrentaba los paquetes concretos redundantes con los proveedores instalados.
El motor convertía ese estado en objetivos explícitos de `pacman -S --needed`:
`--needed` no elimina esos objetivos por estar cubiertos por otro proveedor.

En esta versión de pacman, `-Qi nodejs` y `-Qq nodejs` también resuelven el
proveedor; no se atribuye a `-Qq` un fallo de esta máquina. El arreglo unifica
la decisión mediante la prueba de dependencias `pacman -T`.
`pacman -T -- nodejs rust` dio salida 0 sin texto.

## Cambios y contratos

1. `lib/preflight.sh` sigue delegando en el motor Python, sin logs ni estado.
   El motor consulta `pacman -T -- ...` en lote antes de simular la transacción.
   Salida 0 significa satisfecho; 127 con una lista válida identifica lo que
   falta. Errores de consulta o respuestas incoherentes bloquean.
   Los metadatos instalados identifican al proveedor; nunca sustituyen la
   decisión de `-T`. El informe muestra nivel informativo:
   `nodejs: ya satisfecho (lo provee nodejs-lts-krypton).`
2. Los objetivos cubiertos se excluyen de `pacman -Sp` y de la comparación de
   conflictos como paquetes a instalar. Se conserva su fila explicativa.
   Noctalia, conflictos con el proveedor efectivo y paquetes incompatibles
   que sí van a instalarse siguen bloqueando, tanto en texto como en JSON.
3. Se consideran todos los metadatos del plan antes de reducirlo. Si un
   proveedor explícito único cubre otro objetivo, se instala el proveedor y
   se omite el objetivo redundante. No se depende del orden de perfiles ni
   de paquetes. Alternativas ambiguas y proveedores mutuos no se eligen al
   azar: conservan sus conflictos. Las dependencias de perfiles del motor
   se transfieren al proveedor para que no quede diferido al módulo extras.
4. `install_official`, `install_aur`, `ensure_pacman` y `ensure_aur` filtran
   con `pacman -T` antes de llamar a pacman o al ayudante AUR. El motor vuelve
   a consultar después del paso de actualización del sistema. Una lista
   totalmente satisfecha no invoca ningún instalador.
5. `--check --profiles editor,mis-apps` y el orden inverso resuelven nodejs
   mediante nodejs-lts-krypton y rust mediante rustup. Para incluir Mis apps
   al aplicar con módulos, se declara `--modules editor,extras --extras myapps`
   (o `DRAGON_EXTRAS=myapps`); el preflight incluye entonces ese perfil.

JSON conserva `schema: 1` y añade estado `satisfied`, `provider` y
`provider_origin` (`installed` o `plan`). Para proveedores del plan,
`required_profiles` indica qué perfiles necesitan instalarlos en la fase
Paquetes. El adaptador TSV conserva sus estados anteriores y añade la
explicación a la fila: «ya satisfecho» o «lo proveerá … (incluido en el plan)».

No se cambiaron listas de paquetes, presentación ni configuración desplegada.
No hay migración nueva: estos helpers se ejecutan desde el repositorio;
no hay archivos instalados por copia que renovar ni estado que transformar.
La 190 queda libre para el siguiente cambio que necesite migración, con
`backup_copy`, idempotencia, `DRY_RUN` y `ASSUME_YES`.

## Criterio de latencia

Se conserva el límite estricto **mediana < 50 ms**, los 6000 registros de
30 días, la consulta de 50 resultados y la medición del CLI completo.
Después del calentamiento se toman siete medidas. Solo si su mediana falla
se permite otra tanda de siete, una única vez. Dos medianas de 50 ms o más
fallan y muestran ambas medianas y las muestras; no se sube el límite,
no se descartan medidas ni se añaden reintentos ilimitados.

Tres pruebas deterministas verifican un valor atípico aislado, una primera
tanda de 57,7 ms seguida de 37,8 ms, y el fallo sostenido a 57,7 o 50 ms.

## Verificado

- Preflight real de editor: salida 0, `blocked: false`; nodejs y rust
  satisfechos por sus proveedores instalados. Informe local:
  `/tmp/dragon-fix1-real-editor.json`.
- 54 pruebas en `tests/preflight/`: proveedores instalados oficiales/AUR,
  las 24 permutaciones de los cuatro objetivos, ambos perfiles reales en
  ambos órdenes, conflictos reales y errores de `-T`.
  Los ejecutables falsos y las capturas en el límite de mutación comprueban
  los argumentos de las cuatro rutas de instalación, sin instalar nada.
- 16 pruebas de actividad en verde. Mediana del bloque específico: 44,4 ms.
- **Una ejecución completa de `tests/run-all.sh`, salida 0,
  `TODO EN VERDE`**. Actividad: mediana 33,9 ms, sin necesitar reintento.
  Incluye shellcheck, sintaxis, 87 migraciones con ambas formas de DRY_RUN,
  servicios, TUI/modos, respaldo, documentación, idempotencia y simulación
  sin cambios en HOME/XDG ni Git. Registro local:
  `/tmp/dragon-installer-fix1-full.log`.
- Durante una prueba específica de modos creé un commit y la comparación
  de Git detectó ese cambio: era ` M tests/activity/test_activity.py`
  frente a árbol limpio. Repetí solo ese caso con Git estable y pasó.
  En la suite completa, sin editar ni hacer commits durante su ejecución,
  ese caso y todos los demás pasaron.

En terminal, `./install.sh --check --profiles editor` debe mostrar las dos
líneas informativas de proveedores y acabar sin esos bloqueos. No se cambió
ni se da por verificada visualmente la sesión gráfica del usuario.

## Pendiente en VM

Aplicar de verdad en CachyOS con proveedores ya instalados, y en una instalación
limpia con editor y Mis apps explícitos. Comprobar que pacman y el ayudante AUR
reciben los objetivos reducidos después de la actualización, conservan los
proveedores y que la segunda ejecución no sustituye herramientas.
Repetir con Noctalia o paquetes incompatibles y verificar que se detiene antes
de aplicar. La instalación real y el arranque de herramientas no se ejecutaron
sobre el escritorio del usuario.

Entrega en `installer`; marca de cierre: `instalador-fix1`.
