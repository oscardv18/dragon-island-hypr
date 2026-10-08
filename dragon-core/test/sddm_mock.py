"""Render the dragon-core SDDM theme offscreen with a mocked greeter API.

usage: python3 -I sddm_mock.py <theme_dir> <out_dir> [WxH]
Produces calm.png, typing.png, alert.png, ok.png and prints QML warnings.
"""
import os, sys
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software") if os.environ.get("SW") else None

from PySide6.QtCore import (QObject, Property, Signal, Slot, QUrl, QTimer, QAbstractListModel,
                            Qt, QModelIndex, QByteArray, QEventLoop)
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlPropertyMap
from PySide6.QtQuick import QQuickView

theme, out = sys.argv[1], sys.argv[2]
W, H = (int(v) for v in (sys.argv[3] if len(sys.argv) > 3 else "1366x768").split("x"))
os.makedirs(out, exist_ok=True)


class ListModel(QAbstractListModel):
    def __init__(self, roles, rows, last):
        super().__init__()
        self._roles = roles; self._rows = rows; self._last = last
    def rowCount(self, parent=QModelIndex()): return len(self._rows)
    def roleNames(self): return {Qt.UserRole + i + 1: QByteArray(r.encode()) for i, r in enumerate(self._roles)}
    def data(self, idx, role):
        k = role - Qt.UserRole - 1
        if 0 <= k < len(self._roles): return self._rows[idx.row()][self._roles[k]]
        return None
    countChanged = Signal()
    @Property(int, notify=countChanged)
    def count(self): return len(self._rows)
    @Property(int, constant=True)
    def lastIndex(self): return self._last
    @Property(str, constant=True)
    def lastUser(self): return self._rows[self._last]["name"]


class Layout(QObject):
    def __init__(self, s, l): super().__init__(); self._s, self._l = s, l
    @Property(str, constant=True)
    def shortName(self): return self._s
    @Property(str, constant=True)
    def longName(self): return self._l


class Keyboard(QObject):
    changed = Signal()
    def __init__(self):
        super().__init__()
        self._layouts = [Layout("us", "English (US)"), Layout("latam", "Spanish (Latin American)")]
        self._cur = 1   # start on latam to prove the theme forces index 0
        self._caps = False
    @Property(list, notify=changed)
    def layouts(self): return self._layouts
    def _gc(self): return self._cur
    def _sc(self, v): self._cur = v; self.changed.emit()
    currentLayout = Property(int, _gc, _sc, notify=changed)
    @Property(bool, notify=changed)
    def capsLock(self): return self._caps
    @Property(bool, notify=changed)
    def numLock(self): return True


class Sddm(QObject):
    loginSucceeded = Signal()
    loginFailed = Signal()
    informationMessage = Signal(str)
    @Property(str, constant=True)
    def hostName(self): return "darkdev"
    @Property(bool, constant=True)
    def canPowerOff(self): return True
    @Property(bool, constant=True)
    def canReboot(self): return True
    @Property(bool, constant=True)
    def canSuspend(self): return True
    @Slot(str, str, int)
    def login(self, user, pw, session):
        print(f"login(user={user!r}, len(pw)={len(pw)}, session={session})")
        QTimer.singleShot(250, self.loginSucceeded.emit if pw == "dragon" else self.loginFailed.emit)
    @Slot()
    def powerOff(self): print("powerOff")
    @Slot()
    def reboot(self): print("reboot")
    @Slot()
    def suspend(self): print("suspend")


app = QGuiApplication(sys.argv)
view = QQuickView()
warnings = []
view.engine().warnings.connect(lambda ws: warnings.extend(w.toString() for w in ws))
ctx = view.rootContext()
sddm = Sddm(); kb = Keyboard()
users = ListModel(["name", "realName", "homeDir", "icon", "needsPassword"],
                  [{"name": os.environ.get("USER", "user"), "realName": "", "homeDir": os.path.expanduser("~"), "icon": os.environ.get('FACE',''), "needsPassword": True}], 0)
sessions = ListModel(["name", "file", "type", "exec", "comment"],
                     [{"name": "Hyprland", "file": "hyprland.desktop", "type": 0, "exec": "", "comment": ""},
                      {"name": "Plasma (Wayland)", "file": "plasma.desktop", "type": 0, "exec": "", "comment": ""},
                      {"name": "Plasma (X11)", "file": "plasmax11.desktop", "type": 0, "exec": "", "comment": ""}], 0)
cfg = QQmlPropertyMap()
for k, v in {"pointCount": "240", "defaultLayoutIndex": "0", "locale": "es_VE", "reducedMotion": "false",
             "backgroundOpacity": "0.22", "background": ""}.items():
    cfg.insert(k, v)
for name, obj in {"sddm": sddm, "keyboard": kb, "userModel": users, "sessionModel": sessions, "config": cfg}.items():
    ctx.setContextProperty(name, obj)

view.setResizeMode(QQuickView.SizeRootObjectToView)
view.resize(W, H)
view.setSource(QUrl.fromLocalFile(os.path.join(theme, "Main.qml")))
if view.status() == QQuickView.Error:
    for e in view.errors(): print("ERROR", e.toString())
    sys.exit(1)
view.show()
root = view.rootObject()


def wait(ms):
    loop = QEventLoop(); QTimer.singleShot(ms, loop.quit); loop.exec()


def shot(name):
    view.grabWindow().save(os.path.join(out, name)); print("saved", name)


def find(oid):
    return root.findChild(QObject, oid)


wait(1500); shot("calm.png")
print("layout after start:", kb.currentLayout, "(expect 0)")
from PySide6.QtCore import QMetaObject
from PySide6.QtQml import QQmlProperty
pwItem = find("pw"); core = find("core")
pwItem.setProperty("text", "drago")
QQmlProperty.write(core, "_kick", 1.0)
wait(400); shot("typing.png")
QMetaObject.invokeMethod(root, "doLogin")
wait(900); shot("alert.png")
wait(1600)
pwItem.setProperty("text", "dragon")
QMetaObject.invokeMethod(root, "doLogin")
wait(1300); shot("ok.png")

print("--- QML warnings ---")
for w in warnings: print(w)
print("count:", len(warnings))
