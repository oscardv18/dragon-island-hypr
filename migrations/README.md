# Migraciones

`update.sh` ejecuta, **una sola vez**, cada `NNN-nombre.sh` de esta carpeta (en orden) y apunta las aplicadas
en `~/.local/state/dragon-island/migrations.done`.

**Regla:** todo cambio que afecte a sistemas ya instalados viene con su migración.

Cada migración:
- es idempotente (ejecutarla dos veces no cambia nada) y hace copia de seguridad (`backup_copy`, `deploy_item`) antes de tocar nada;
- respeta `DRY_RUN` (usa `run` para todo lo que escriba) y `ASSUME_YES` (`confirm`);
- sale con `0` si quedó aplicada, `10` si se omite a propósito (se reintentará la próxima vez) y otro código si falla;
- usa las ayudas de `lib/common.sh` (`run`, `log_info`, `confirm`, `deploy_item`, `backup_copy`, `need_relogin`, `add_component`).

Plantilla:

```bash
#!/usr/bin/env bash
# NNN — qué hace y por qué
set -Eeuo pipefail
REPO_DIR="${REPO_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/migration-env.sh
. "$REPO_DIR/lib/migration-env.sh"
...
```
