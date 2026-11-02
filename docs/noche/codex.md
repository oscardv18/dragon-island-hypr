# Diario Codex · 2026-11-01

- Inicio: main a7b0b69 limpio; /status no está disponible como herramienta en la sesión.
- Sin vin.py, push, merge, sudo ni red real. Worktrees propios para A y B.
- A terminado en feat/fase5d-migracion (443550d), pruebas focalizadas; sin suite completa.
- B desde feat/fase5d-herramientas (0ce93cf), sin reescribir d1–d3 ni tocar config/quickshell/.
- Revisados listados, operaciones, dispositivos, limpieza SIGTERM y el contrato de pantallas.
- d4: libarchive con lectura acotada por entrada; staging, snapshot privado, validación previa y publicación posterior.
- d4: 17 pruebas de archivos maliciosos/formatos (falló la salida .7z de creación; corregida y repetida solo esa prueba). d1–d3: 16 pruebas pasan.
- Lectura con API libarchive en lugar de parsear listados de texto: conserva nombres con controles y contraseña por stdin sin pasarla a argv. Formatos dependientes de la libarchive instalada; cifrado 7z requiere verificar soporte, error legible si falta.
- d5: descubrimiento avahi, GVFS con diálogo acotado, montajes/rutas FUSE, recursos SMB, marcadores públicos y credenciales con secret-tool. Seis pruebas con ejecutables falsos; ninguna conexión real.
- d6: usershares con ACL del usuario, invitados apagados por defecto, rutas sensibles y alias rechazados. Cuatro pruebas contra net falso (corregida la invocación del caso --name=-bad para que llegue a la validación). Preparación privilegiada documentada en FILES-SAMBA.md; la migración 073 solo despliega herramientas.
- d7: .desktop sin recursión, asociación reversible y FileManager1 opcional sin sustituir propietarios ni autoinicio; cuatro pruebas con qs/xdg-mime falsos. Propiedades/selección por IPC no están en el contrato actual.
