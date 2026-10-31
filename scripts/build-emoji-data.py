#!/usr/bin/env python3
"""Rebuild the curated offline set. Own Spanish/English annotations: CC0-1.0.
Unicode character names from Python unicodedata: Unicode-3.0 (see search-data/README.md).
No download, external corpus or runtime dependency.
"""
import json
from pathlib import Path
import unicodedata

# char | Spanish name and keywords | English name and keywords, authored for this project.
SOURCE = '''😀|cara feliz sonrisa alegría|happy face smile joy
😃|sonrisa ojos grandes alegría|smile big eyes happy
😄|risa alegría divertido|laugh smile happy
😁|sonrisa dientes|grin teeth smile
😂|lágrimas de risa gracioso|tears of joy laugh funny
🤣|risa carcajada|rolling laughing
😊|sonrisa tímida sonrojo|smile blush shy
🙂|sonrisa leve|slight smile
😉|guiño complicidad|wink
😍|enamorado ojos corazón|love heart eyes
🥰|cariño amor corazones|love hearts affection
😘|beso amor|kiss love
😎|gafas de sol genial|sunglasses cool
🤓|estudioso gafas|nerd glasses
🤔|pensando duda|thinking question
😴|dormir sueño|sleep tired
😢|triste lágrima|sad tear cry
😭|llorar tristeza|cry sob sad
😡|enfadado ira|angry rage
🤯|sorpresa explosión cabeza|mind blown surprise
🥳|fiesta celebración|party celebration
😱|miedo sorpresa|fear scream
🤖|robot máquina|robot machine
👻|fantasma halloween|ghost halloween
💀|calavera muerte|skull death
👽|alienígena espacio|alien space
💩|caca|poop
👍|pulgar arriba sí bien|thumbs up yes good
👎|pulgar abajo no mal|thumbs down no bad
👏|aplausos bravo|clap applause
🙌|manos celebración|raised hands celebration
🙏|gracias por favor rezar|thanks please pray
👋|hola adiós saludo|hello goodbye wave
👌|bien perfecto|okay perfect
✌|paz victoria|peace victory
💪|fuerza músculo|strength muscle
❤|corazón amor rojo|heart love red
💜|corazón morado amor|purple heart love
💙|corazón azul amor|blue heart love
💚|corazón verde amor|green heart love
💔|corazón roto|broken heart
✨|brillos estrellas|sparkles stars
⭐|estrella favorito|star favorite
🔥|fuego calor|fire hot
💧|gota agua|drop water
🌈|arcoíris colores|rainbow colors
☀|sol día|sun day
🌙|luna noche|moon night
⚡|rayo electricidad|lightning electricity
❄|nieve frío|snow cold
☁|nube clima|cloud weather
🌍|tierra planeta mundo|earth planet world
🚀|cohete espacio lanzamiento|rocket space launch
🐉|dragón fantasía|dragon fantasy
🐈|gato animal|cat animal
🐕|perro animal|dog animal
🦊|zorro animal|fox animal
🦋|mariposa naturaleza|butterfly nature
🌸|flor cerezo|flower cherry blossom
🌱|planta brote|plant seedling
☕|café bebida|coffee drink
🍕|pizza comida|pizza food
🍺|cerveza bebida|beer drink
🎉|celebración fiesta confeti|celebration party confetti
🎂|pastel cumpleaños|cake birthday
🎁|regalo|gift present
🎵|música nota|music note
🎮|juego mando|game controller
💻|ordenador portátil computadora|laptop computer
⌨|teclado|keyboard
🖥|pantalla monitor|screen monitor
📁|carpeta archivos|folder files
📋|portapapeles|clipboard
📌|chincheta fijar|pin
🔒|candado seguridad|lock security
🔑|llave clave|key
🔍|buscar lupa|search magnifier
🔧|herramienta llave|tool wrench
⚙|ajustes engranaje|settings gear
💡|idea bombilla|idea light bulb
📚|libros estudiar|books study
✅|correcto verificado sí|check verified yes
❌|error cerrar no|cross error close no
⚠|aviso advertencia|warning caution
ℹ|información ayuda|information help
❓|pregunta duda|question
→|flecha derecha|arrow right
←|flecha izquierda|arrow left
↑|flecha arriba|arrow up
↓|flecha abajo|arrow down
↔|flecha horizontal ambos|arrow horizontal both
⇒|implica flecha doble derecha|implies double arrow right
⇐|flecha doble izquierda|double arrow left
⇔|equivalente flecha doble|equivalent double arrow
↗|flecha noreste|arrow northeast
↘|flecha sureste|arrow southeast
±|más menos signo|plus minus sign
×|multiplicación por|multiplication times
÷|división entre|division
√|raíz cuadrada|square root
∞|infinito|infinity
≈|aproximadamente igual|approximately equal
≠|distinto diferente no igual|not equal different
≤|menor o igual|less than or equal
≥|mayor o igual|greater than or equal
∑|sumatorio suma|summation sum
∫|integral|integral
∂|derivada parcial|partial derivative
∆|delta incremento|delta increment
∈|pertenece conjunto|element set membership
∅|conjunto vacío|empty set
°|grado temperatura|degree temperature
€|euro moneda|euro currency
£|libra moneda|pound currency
¥|yen yuan moneda|yen yuan currency
$|dólar moneda|dollar currency
₿|bitcoin moneda|bitcoin currency
α|alfa griega|alpha greek
β|beta griega|beta greek
γ|gamma griega|gamma greek
δ|delta griega|delta greek
ε|épsilon griega|epsilon greek
θ|theta teta griega|theta greek
λ|lambda griega|lambda greek
μ|mu micro griega|mu micro greek
π|pi griega|pi greek
σ|sigma griega|sigma greek
φ|fi fi griega|phi greek
ω|omega griega|omega greek
Ω|omega mayúscula ohmio|omega capital ohm
©|derechos autor copyright|copyright
®|marca registrada|registered trademark
™|marca comercial|trademark
•|viñeta punto|bullet dot
…|puntos suspensivos|ellipsis
—|raya guion largo|em dash
✓|marca correcto|check mark'''


def build():
    rows = []
    for line in SOURCE.splitlines():
        char, spanish, english = line.split('|')
        rows.append(dict(id='emoji:' + '-'.join(f'{ord(c):x}' for c in char), char=char,
                         name={'es': spanish, 'en': english},
                         keywords={'es': spanish.split(), 'en': english.split() + [unicodedata.name(char)]}))
    return rows


if __name__ == '__main__':
    path = Path(__file__).resolve().parents[1] / 'dragon-core/search-data/emoji.json'
    path.write_text(json.dumps(build(), ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
