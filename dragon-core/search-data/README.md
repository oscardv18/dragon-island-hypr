# Datos locales de símbolos

Conjunto pequeño y curado: emojis, flechas, matemáticas, monedas y letras griegas.
No procede de CLDR, Emojipedia ni de un corpus descargado. Las anotaciones ES/EN
son originales de este proyecto y se ofrecen bajo CC0-1.0 (dedicación al dominio
público, https://creativecommons.org/publicdomain/zero/1.0/).

`scripts/build-emoji-data.py` genera `emoji.json` sin red usando la tabla original
del script y `unicodedata.name` de Python estándar. Los nombres normativos ingleses
son datos de Unicode, bajo Unicode-3.0 (Unicode License v3):
https://www.unicode.org/license.txt (aviso íntegro incluido en `Unicode-3.0.txt`). Python distribuye `unicodedata` con su licencia
PSF y el aviso correspondiente a Unicode. No hay imágenes ni fuentes incrustadas.
Los caracteres seleccionados están asignados desde antes de Unicode 14; la salida
se comprueba idéntica con el generador en las pruebas.
