"""Dragon Portal: `org.freedesktop.impl.portal.FileChooser` backed by the Dragon explorer (docs/PORTAL-API.md).

    dragon-portal serve              D-Bus service (activated by the session bus; leaves 60 s after the last request)
    dragon-portal take  <id>         explorer side: fetch the request JSON and mark it taken
    dragon-portal reply <id>         explorer side: JSON answer on stdin → private reply file
    dragon-portal status             what is pending (diagnostics)

Every sub-command prints one JSON line `{"ok": true, …}` or `{"ok": false, "error": {code, message, hint}}` like the other dragon-*.
`serve` is the only part that needs PyGObject (exit 10 when it is missing); the rest runs with `python3 -S`.

The explorer is opened with `$DRAGON_PORTAL_QS open <id>` (default `qs ipc call picker`; `has <id>` and `cancel <id>` follow). If the
explorer does not take the request in DRAGON_PORTAL_ACK seconds, stops answering `has`, or the opener fails, the call is forwarded to
the GTK backend (`org.freedesktop.impl.portal.desktop.gtk`) with the original arguments: the dialog is never lost.
"""
import json
import os
import shlex
import sys
import time

import portal_core as core

GTK_NAME = 'org.freedesktop.impl.portal.desktop.gtk'
OWN_NAME = 'org.freedesktop.impl.portal.desktop.dragon'
PORTAL_PATH = '/org/freedesktop/portal/desktop'
IFACE = 'org.freedesktop.impl.portal.FileChooser'
REQUEST_IFACE = 'org.freedesktop.impl.portal.Request'
INTROSPECTION = '''<node>
<interface name="org.freedesktop.impl.portal.FileChooser">
%s</interface></node>'''
METHOD_XML = ('<method name="%s"><arg type="o" name="handle" direction="in"/><arg type="s" name="app_id" direction="in"/>'
              '<arg type="s" name="parent_window" direction="in"/><arg type="s" name="title" direction="in"/>'
              '<arg type="a{sv}" name="options" direction="in"/><arg type="u" name="response" direction="out"/>'
              '<arg type="a{sv}" name="results" direction="out"/></method>\n')
REQUEST_XML = '<node><interface name="org.freedesktop.impl.portal.Request"><method name="Close"/></interface></node>'
KIND_OF = dict(OpenFile='open', SaveFile='save', SaveFiles='save_files')
MAX_PENDING = 16


def emit(value):
    print(json.dumps(value, ensure_ascii=False, allow_nan=False, separators=(',', ':')), flush=True)


def env_float(name, default):
    try:
        return float(os.environ.get(name, default))
    except ValueError:
        return float(default)


# ------------------------------------------------------------------ CLI (explorer side; no PyGObject)
def cmd_take(request_id):
    core.check_id(request_id)
    req_dir = core.channel('req')
    request = core.read_private_json(req_dir, request_id + '.json')
    if request is None:
        raise core.PortalError('unknown_request', 'No hay ninguna petición con ese identificador',
                               'Ya terminó o la cerró la aplicación.')
    core.write_private_json(req_dir, request_id + '.taken', dict(at=time.time(), pid=os.getpid()))
    return dict(ok=True, request=request)


def cmd_reply(request_id, raw):
    core.check_id(request_id)
    req_dir = core.channel('req')
    if core.read_private_json(req_dir, request_id + '.json') is None:
        raise core.PortalError('unknown_request', 'No hay ninguna petición con ese identificador', 'Ya terminó o la cerró la aplicación.')
    try:
        reply = json.loads(raw.decode('utf-8', 'surrogateescape') if isinstance(raw, bytes) else raw)
    except ValueError:
        raise core.PortalError('invalid_json', 'La respuesta no es JSON válido')
    if not isinstance(reply, dict) or reply.get('response') not in ('accept', 'cancel'):
        raise core.PortalError('invalid_reply', 'La respuesta debe traer response = accept | cancel')
    reply['id'] = request_id
    core.write_private_json(core.channel('rep'), request_id + '.json', reply)
    return dict(ok=True)


def cmd_status():
    try:
        import gi  # noqa: F401
        gio = True
    except Exception:
        gio = False
    pending = sorted(n[:-5] for n in os.listdir(core.channel('req')) if n.endswith('.json') and not n.startswith('.'))
    return dict(ok=True, gio=gio, channel=core.runtime_dir(), pending=pending)


def run_cli(argv):
    args = [a for a in argv if a != '--json']
    try:
        if not args or args[0] in ('-h', '--help'):
            print(__doc__)
            return 0
        if args[0] == 'serve':
            return serve()
        if args[0] == 'take' and len(args) == 2:
            emit(cmd_take(args[1]))
        elif args[0] == 'reply' and len(args) == 2:
            emit(cmd_reply(args[1], sys.stdin.buffer.read(core.MAX_JSON + 1)))
        elif args[0] == 'status' and len(args) == 1:
            emit(cmd_status())
        else:
            emit(core.error('invalid_usage', 'Argumentos no válidos', 'Consulta dragon-portal --help.'))
            return 2
        return 0
    except core.PortalError as exc:
        emit(core.error(exc.code, exc.message, exc.hint))
        return 1
    except OSError as exc:
        emit(core.error('io_error', exc.strerror or str(exc), 'Revisa XDG_RUNTIME_DIR.'))
        return 1


# ------------------------------------------------------------------ service
def serve():
    try:
        from gi.repository import Gio, GLib
    except ImportError:
        print('Dragon Portal: instala python-gobject (PyGObject) para el servicio.', file=sys.stderr)
        return 10
    return Service(Gio, GLib).run()


class Pending:
    def __init__(self, method, handle, params, invocation, request):
        self.method, self.handle, self.params, self.invocation, self.request = method, handle, params, invocation, request
        self.id = request['id']
        self.created = time.monotonic()
        self.taken_at = None
        self.registration = None
        self.done = False
        self.fallback = False
        self.opener_failed = False
        self.probing = False
        self.probe_failures = 0
        self.next_probe = 0.0


class Service:
    def __init__(self, Gio, GLib):
        self.Gio, self.GLib = Gio, GLib
        self.loop = GLib.MainLoop()
        self.pending = {}
        self.connection = None
        self.exit_code = 0
        self.ack = env_float('DRAGON_PORTAL_ACK', 10)
        self.idle = env_float('DRAGON_PORTAL_IDLE', 60)
        self.probe_every = env_float('DRAGON_PORTAL_PROBE', 5)
        self.qs = shlex.split(os.environ.get('DRAGON_PORTAL_QS', 'qs ipc call picker'))
        self.home = os.path.expanduser('~') or '/'
        self.tick_id = None
        self.idle_id = None
        self.request_node = Gio.DBusNodeInfo.new_for_xml(REQUEST_XML)

    # -- lifecycle
    def run(self):
        Gio, GLib = self.Gio, self.GLib
        try:
            core.sweep()
        except (core.PortalError, OSError) as exc:
            print('Dragon Portal: canal no disponible:', exc, file=sys.stderr)
            return 1
        xml = INTROSPECTION % ''.join(METHOD_XML % m for m in KIND_OF)
        node = Gio.DBusNodeInfo.new_for_xml(xml)

        def acquired(conn, name):
            self.connection = conn
            conn.register_object(PORTAL_PATH, node.interfaces[0], self.on_call, None, None)
            self.arm_idle()

        def lost(conn, name):
            self.exit_code = 10
            self.loop.quit()

        owner = Gio.bus_own_name(Gio.BusType.SESSION, OWN_NAME, Gio.BusNameOwnerFlags.DO_NOT_QUEUE, acquired, None, lost)
        try:
            self.loop.run()
        finally:
            Gio.bus_unown_name(owner)
        return self.exit_code

    def arm_idle(self):
        GLib = self.GLib
        if self.idle_id is not None:
            GLib.source_remove(self.idle_id)
            self.idle_id = None
        if not self.pending:
            self.idle_id = GLib.timeout_add(int(self.idle * 1000), self.on_idle)

    def on_idle(self):
        self.idle_id = None
        if not self.pending:
            self.loop.quit()
        return self.GLib.SOURCE_REMOVE

    # -- D-Bus entry
    def on_call(self, conn, sender, path, interface, method, params, invocation):
        try:
            handle, app_id, parent, title, options = params.unpack()
            kind = KIND_OF[method]
            if len(self.pending) >= MAX_PENDING:
                raise core.PortalError('busy', 'Demasiadas peticiones a la vez')
            request = core.build_request(kind, app_id, title, options, self.home)
            pending = Pending(method, handle, params, invocation, request)
        except Exception as exc:                                    # malformed call: answer, never hang
            self.forward_or_fail(invocation, method, params, 'entrada no válida: %s' % exc)
            return
        try:
            self.start(pending)
        except Exception as exc:
            self.fallback(pending, 'no se pudo preparar la petición: %s' % exc)

    def forward_or_fail(self, invocation, method, params, why):
        print('Dragon Portal:', why, file=sys.stderr)
        self.call_gtk(method, params, lambda ok, value: self.reply_invocation(invocation, value if ok else (2, {})))

    def reply_invocation(self, invocation, value):
        """`value` is a ready `(ua{sv})` Variant (from GTK) or a (response, results) pair."""
        GLib = self.GLib
        if not isinstance(value, GLib.Variant):
            value = GLib.Variant('(ua{sv})', (value[0], value[1]))
        invocation.return_value(value)

    def start(self, p):
        GLib = self.GLib
        self.pending[p.id] = p
        self.arm_idle()
        core.write_private_json(core.channel('req'), p.id + '.json', p.request)
        p.registration = self.connection.register_object(p.handle, self.request_node.interfaces[0],
                                                         lambda *a: self.on_close(p, a[-1]), None, None)
        self.spawn(self.qs + ['open', p.id], lambda ok, out: self.on_opened(p, ok))
        if self.tick_id is None:
            self.tick_id = GLib.timeout_add(150, self.tick)

    def on_opened(self, p, ok):
        if not ok:
            p.opener_failed = True

    def on_close(self, p, invocation):
        invocation.return_value(None)
        if p.fallback:
            self.connection.call(GTK_NAME, p.handle, REQUEST_IFACE, 'Close', None, None, self.Gio.DBusCallFlags.NONE, 5000, None, None, None)
        else:
            self.finish(p, 1, {}, tell_explorer=True)

    # -- polling: reply file, acknowledgement, opener failure, explorer health
    def tick(self):
        now = time.monotonic()
        for p in list(self.pending.values()):
            if p.done or p.fallback:
                continue
            try:
                self.check(p, now)
            except Exception as exc:
                self.fallback(p, 'error interno: %s' % exc)
        if not self.pending:
            self.tick_id = None
            return self.GLib.SOURCE_REMOVE
        return self.GLib.SOURCE_CONTINUE

    def check(self, p, now):
        reply = None
        try:
            reply = core.read_private_json(core.channel('rep'), p.id + '.json')
        except core.PortalError as exc:
            self.finish(p, 2, {}, why=exc.message)
            return
        if reply is not None:
            try:
                response, results = core.reply_to_results(p.request, reply)
            except core.PortalError as exc:
                self.finish(p, 2, {}, why=exc.message, tell_explorer=True)
                return
            self.finish(p, response, self.results_variant(p, response, results))
            return
        if p.taken_at is None and os.path.exists(os.path.join(core.channel('req'), p.id + '.taken')):
            p.taken_at = now
            p.next_probe = now + self.probe_every
        if p.opener_failed:
            self.fallback(p, 'no se pudo abrir el explorador')
        elif p.taken_at is None and now - p.created > self.ack:
            self.fallback(p, 'el explorador no respondió en %.0f s' % self.ack)
        elif p.taken_at is not None and now >= p.next_probe and not p.probing:
            self.probe(p)

    def probe(self, p):
        p.probing = True

        def done(ok, out):
            p.probing = False
            p.next_probe = time.monotonic() + self.probe_every
            if p.done or p.fallback:
                return
            alive = ok and out.strip() == 'true'
            p.probe_failures = 0 if alive else p.probe_failures + 1
            if p.probe_failures >= 2:
                self.fallback(p, 'el explorador dejó de responder')
        self.spawn(self.qs + ['has', p.id], done, timeout=4)

    # -- answers
    def results_variant(self, p, response, results):
        GLib = self.GLib
        if response != 0:
            return {}
        out = {'uris': GLib.Variant('as', results['uris'])}
        if results['choices']:
            out['choices'] = GLib.Variant('a(ss)', results['choices'])
        index = results['filter_index']
        if index is not None and p.request['kind'] != 'save_files':
            f = p.request['filters'][index]
            out['current_filter'] = GLib.Variant('(sa(us))', (f['name'], [(0 if r['type'] == 'glob' else 1, r['value']) for r in f['patterns']]))
        return out

    def finish(self, p, response, results, why='', tell_explorer=False):
        if p.done:
            return
        p.done = True
        if why:
            print('Dragon Portal:', why, file=sys.stderr)
        if tell_explorer:
            self.spawn(self.qs + ['cancel', p.id], lambda ok, out: None, timeout=4)
        if p.registration is not None:
            self.connection.unregister_object(p.registration)
            p.registration = None
        for kind, suffix in (('req', '.json'), ('req', '.taken'), ('rep', '.json')):
            try:
                core.remove_quiet(core.channel(kind), p.id + suffix)
            except (core.PortalError, OSError):
                pass
        self.pending.pop(p.id, None)
        self.arm_idle()
        try:
            self.reply_invocation(p.invocation, (response, results))
        except Exception as exc:
            print('Dragon Portal: no se pudo responder:', exc, file=sys.stderr)

    def fallback(self, p, why):
        if p.done or p.fallback:
            return
        p.fallback = True
        print('Dragon Portal: usando el portal de GTK (%s)' % why, file=sys.stderr)
        self.spawn(self.qs + ['cancel', p.id], lambda ok, out: None, timeout=4)
        for kind, suffix in (('req', '.json'), ('req', '.taken'), ('rep', '.json')):
            try:
                core.remove_quiet(core.channel(kind), p.id + suffix)
            except (core.PortalError, OSError):
                pass

        def got(ok, value):
            if p.done:
                return
            p.done = True
            if p.registration is not None:
                self.connection.unregister_object(p.registration)
                p.registration = None
            self.pending.pop(p.id, None)
            self.arm_idle()
            self.reply_invocation(p.invocation, value if ok else (2, {}))
        self.call_gtk(p.method, p.params, got)

    def call_gtk(self, method, params, callback):
        """Same call to the GTK backend (no timeout: the user may keep the dialog open for minutes)."""
        Gio, GLib = self.Gio, self.GLib

        def finished(conn, result, _data):
            try:
                callback(True, conn.call_finish(result))
            except Exception as exc:
                print('Dragon Portal: el portal de GTK falló:', exc, file=sys.stderr)
                callback(False, None)
        try:
            self.connection.call(GTK_NAME, PORTAL_PATH, IFACE, method, params, GLib.VariantType('(ua{sv})'),
                                 Gio.DBusCallFlags.NONE, 2147483647, None, finished, None)
        except Exception as exc:
            print('Dragon Portal: no se pudo llamar a GTK:', exc, file=sys.stderr)
            callback(False, None)

    # -- subprocess helper (argv list, never a shell)
    def spawn(self, argv, callback, timeout=None):
        Gio, GLib = self.Gio, self.GLib
        try:
            proc = Gio.Subprocess.new(argv, Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_SILENCE)
        except GLib.Error:
            callback(False, '')
            return
        timer = []
        if timeout:
            def expire():
                timer.clear()
                proc.force_exit()
                return GLib.SOURCE_REMOVE
            timer.append(GLib.timeout_add(int(timeout * 1000), expire))

        def finished(source, result, _data):
            if timer:
                GLib.source_remove(timer.pop())
            try:
                _ok, out, _err = source.communicate_utf8_finish(result)
                callback(source.get_if_exited() and source.get_exit_status() == 0, out or '')
            except GLib.Error:
                callback(False, '')
        proc.communicate_utf8_async(None, None, finished, None)


if __name__ == '__main__':
    raise SystemExit(run_cli(sys.argv[1:]))
