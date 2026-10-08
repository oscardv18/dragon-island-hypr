"""Render LockView.qml offscreen. usage: python3 -I lock_mock.py <LockView.qml> <fonts_dir> <out_dir>"""
import os, sys
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
from PySide6.QtCore import QUrl, QTimer, QEventLoop, QObject, QMetaObject, Q_ARG
from PySide6.QtGui import QGuiApplication, QFontDatabase
from PySide6.QtQuick import QQuickView
qml, fonts, out = sys.argv[1:4]
os.makedirs(out, exist_ok=True)
app = QGuiApplication(sys.argv)
for f in os.listdir(fonts): QFontDatabase.addApplicationFont(os.path.join(fonts, f))
v = QQuickView(); warns = []
v.engine().warnings.connect(lambda ws: warns.extend(w.toString() for w in ws))
v.setResizeMode(QQuickView.SizeRootObjectToView); v.resize(1366, 768)
v.setSource(QUrl.fromLocalFile(qml))
if v.status() == QQuickView.Error:
    [print("ERROR", e.toString()) for e in v.errors()]; sys.exit(1)
v.show(); r = v.rootObject()
def wait(ms): l = QEventLoop(); QTimer.singleShot(ms, l.quit); l.exec()
for k, val in dict(userName=os.environ.get("USER", "user"), hostName=os.uname().nodename, layoutLabel="US", monoFont="JetBrains Mono",
                   hasMedia=True, mediaTitle="Lo-fi para concentrarse", mediaArtist="Chillhop", mediaPlaying=True,
                   notifCount=3, batteryPct=86.0).items():
    r.setProperty(k, val)
wait(1200); v.grabWindow().save(f"{out}/lock-calm.png")
r.findChild(QObject, "pw").setProperty("text", "secreto")
r.setProperty("mood", "alert"); r.setProperty("stateText", "acceso denegado")
r.setProperty("hint", "Contraseña incorrecta. Revisa la distribución de teclado (US)."); r.setProperty("hintError", True)
r.setProperty("capsLock", True)
QMetaObject.invokeMethod(r, "shake")
wait(700); v.grabWindow().save(f"{out}/lock-alert.png")
print("warnings:", len(warns)); [print(w) for w in warns]
