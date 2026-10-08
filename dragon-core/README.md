# dragon-core — material de trabajo

Material de diseño y pruebas del núcleo neural (lanzador, bloqueo, login). **No se instala**; el código vivo está en
`config/quickshell/`, `sddm/dragon-core/` y `shared/neural-core/`.

- `prompts/`   — los prompts con los que se generó cada entrega (lanzador, bloqueo/login).
- `test/`      — mocks en Python para renderizar fuera de Quickshell (`launcher_mock.py`, `lock_mock.py`, `sddm_mock.py`).
- `reference/` — copia de referencia del lanzador tal como se entregó (el vivo está en `config/quickshell/modules/launcher/`).
