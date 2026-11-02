"""Optional D-Bus FileManager1, explicitly started; quits after 30 seconds idle.

PyGObject is deliberately optional and this module is launched without -S.
It never replaces the current owner of org.freedesktop.FileManager1.
"""
import sys
try:
    from gi.repository import Gio, GLib
except ImportError:
    print('FileManager1 opcional: instala python-gobject para habilitarlo.',file=sys.stderr)
    raise SystemExit(10)

from files_desktop import browse

XML = '''<node><interface name="org.freedesktop.FileManager1">
<method name="ShowItems"><arg type="as" direction="in"/><arg type="s" direction="in"/></method>
<method name="ShowFolders"><arg type="as" direction="in"/><arg type="s" direction="in"/></method>
<method name="ShowItemProperties"><arg type="as" direction="in"/><arg type="s" direction="in"/></method>
</interface></node>'''


def serve():
    loop=GLib.MainLoop()
    node=Gio.DBusNodeInfo.new_for_xml(XML)
    connection=None
    registration=None
    timer=None
    failed=False

    def idle():
        loop.quit()
        return GLib.SOURCE_REMOVE

    def reset_idle():
        nonlocal timer
        if timer is not None: GLib.source_remove(timer)
        timer=GLib.timeout_add_seconds(30,idle)

    def call(conn,sender,path,interface,method,parameters,invocation):
        try:
            uris,startup_id=parameters.unpack()
            browse(uris,show_items=method in ('ShowItems','ShowItemProperties'))
            invocation.return_value(GLib.Variant('()',()))
        except Exception:
            invocation.return_dbus_error('org.freedesktop.FileManager1.Error','No se pudo abrir la ruta en Archivos.')
        reset_idle()

    def acquired(conn,name):
        nonlocal connection,registration
        connection=conn
        registration=conn.register_object('/org/freedesktop/FileManager1',node.interfaces[0],call,None,None)
        reset_idle()

    def lost(conn,name):
        nonlocal failed
        failed=True
        loop.quit()

    owner=Gio.bus_own_name(Gio.BusType.SESSION,'org.freedesktop.FileManager1',
                           Gio.BusNameOwnerFlags.DO_NOT_QUEUE,acquired,None,lost)
    try: loop.run()
    finally:
        if timer is not None:
            try: GLib.source_remove(timer)
            except Exception: pass
        if connection and registration: connection.unregister_object(registration)
        Gio.bus_unown_name(owner)
    return 10 if failed else 0

if __name__=='__main__': raise SystemExit(serve())
