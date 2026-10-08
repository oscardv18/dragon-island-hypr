"""Render LauncherView.qml offscreen: usage python3 -I launcher_mock.py <LauncherView.qml> <fonts_dir> <out_dir>"""
import os, sys
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
from PySide6.QtCore import QUrl, QTimer, QEventLoop, QObject, QMetaObject, Qt
from PySide6.QtGui import QGuiApplication, QFontDatabase, QKeyEvent
from PySide6.QtQuick import QQuickView
from PySide6.QtCore import QCoreApplication, QEvent
qml, fonts, out = sys.argv[1:4]
os.makedirs(out, exist_ok=True)
app = QGuiApplication(sys.argv)
for f in os.listdir(fonts): QFontDatabase.addApplicationFont(os.path.join(fonts, f))
v = QQuickView(); warns = []
v.engine().warnings.connect(lambda ws: warns.extend(w.toString() for w in ws))
from PySide6.QtGui import QColor
v.setColor(QColor("#05060c"))
v.setResizeMode(QQuickView.SizeRootObjectToView); v.resize(1366, 768)
v.setSource(QUrl.fromLocalFile(qml))
if v.status() == QQuickView.Error:
    [print("ERROR", e.toString()) for e in v.errors()]; sys.exit(1)
v.show(); r = v.rootObject()
names = [("Brave","Navegador web"),("Ghostty","Terminal"),("Dolphin","Archivos"),("Spotify","Música"),("Discord","Chat"),("Visual Studio Code","Editor"),
         ("Steam","Juegos"),("OBS Studio","Grabación"),("Proton VPN","VPN"),("Kate","Editor de texto"),("GIMP","Imágenes"),("Blender","3D"),
         ("Firefox","Navegador web"),("Telegram","Chat"),("Krita","Dibujo"),("LibreOffice Writer","Documentos"),("mpv","Video"),("Okular","Documentos")]
r.setProperty("apps", [{"id": f"app{i}", "name": n, "subtitle": g, "icon": ""} for i, (n, g) in enumerate(names)])
activated = []
r.activated.connect(lambda i: activated.append(i))
def wait(ms): l = QEventLoop(); QTimer.singleShot(ms, l.quit); l.exec()
def key(k, text=""):
    for t in (QEvent.KeyPress, QEvent.KeyRelease):
        QCoreApplication.sendEvent(v, QKeyEvent(t, k, Qt.NoModifier, text))
q = r.findChild(QObject, "q")
wait(1400); v.grabWindow().save(f"{out}/launcher-idle.png")
key(Qt.Key_Right); key(Qt.Key_Right); wait(1500); v.grabWindow().save(f"{out}/launcher-sel.png")
q.setProperty("text", "co"); wait(800); v.grabWindow().save(f"{out}/launcher-query.png")
print("filtered(co):", r.property("filtered").toVariant() and [a["name"] for a in r.property("filtered").toVariant()])
q.setProperty("text", "zzzz"); wait(900); v.grabWindow().save(f"{out}/launcher-nomatch.png")
q.setProperty("text", "dis"); wait(500)
key(Qt.Key_Return, "\r"); wait(250); v.grabWindow().save(f"{out}/launcher-launch.png"); wait(600)
print("activated:", activated)
r.setProperty("open", False); wait(900); print("settled after close:", r.property("settled"))
print("warnings:", len(warns)); [print(w) for w in warns]
