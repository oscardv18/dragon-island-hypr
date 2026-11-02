#!/usr/bin/env python3
"""Stand-in for xdg-desktop-portal-gtk's FileChooser (tests only): answers with a fixed URI, logs every call and every Close."""
import json
import os
import sys
from pathlib import Path

from gi.repository import Gio, GLib

D = Path(os.environ['FAKE_EXPLORER_DIR'])
XML = '''<node><interface name="org.freedesktop.impl.portal.FileChooser">%s</interface></node>''' % ''.join(
    '<method name="%s"><arg type="o" direction="in"/><arg type="s" direction="in"/><arg type="s" direction="in"/>'
    '<arg type="s" direction="in"/><arg type="a{sv}" direction="in"/><arg type="u" direction="out"/>'
    '<arg type="a{sv}" direction="out"/></method>' % m for m in ('OpenFile', 'SaveFile', 'SaveFiles'))
REQ = '<node><interface name="org.freedesktop.impl.portal.Request"><method name="Close"/></interface></node>'
loop = GLib.MainLoop()


def log(entry):
    with open(D / 'gtk.log', 'a') as handle:
        handle.write(json.dumps(entry) + '\n')


def on_call(conn, sender, path, iface, method, params, inv):
    handle, app_id, parent, title, options = params.unpack()
    log(dict(method=method, handle=handle, title=title, options=sorted(options)))
    registration = conn.register_object(handle, Gio.DBusNodeInfo.new_for_xml(REQ).interfaces[0],
                                        lambda c, s, p, i, m, pa, invocation: (log(dict(close=p)), invocation.return_value(None)), None, None)

    def answer():
        conn.unregister_object(registration)
        inv.return_value(GLib.Variant('(ua{sv})', (0, {'uris': GLib.Variant('as', ['file:///gtk/fallback'])})))
        return GLib.SOURCE_REMOVE
    delay = float(os.environ.get('FAKE_GTK_DELAY', '0'))
    GLib.timeout_add(int(delay * 1000), answer)


def acquired(conn, name):
    conn.register_object('/org/freedesktop/portal/desktop', Gio.DBusNodeInfo.new_for_xml(XML).interfaces[0], on_call, None, None)


Gio.bus_own_name(Gio.BusType.SESSION, 'org.freedesktop.impl.portal.desktop.gtk', 0, acquired, None, lambda *a: loop.quit())
loop.run()
