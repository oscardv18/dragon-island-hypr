#!/usr/bin/env python3
"""Runs INSIDE `dbus-run-session`: starts the real xdg-desktop-portal (with the Dragon + fake GTK backends registered through
XDG_DESKTOP_PORTAL_DIR), calls the PUBLIC org.freedesktop.portal.FileChooser like an application would and prints one JSON result.

argv[1] = JSON file {cases: [{name, method, title, options: {key: [type, value]}, group, close_after, wait}], timeout}
Cases of the same `group` run at the same time; groups run one after another.
"""
import json
import os
import subprocess
import sys
import time

from gi.repository import Gio, GLib

spec = json.load(open(sys.argv[1]))
bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
unique = bus.get_unique_name().lstrip(':').replace('.', '_')
loop = GLib.MainLoop()
xdp = subprocess.Popen(['/usr/lib/xdg-desktop-portal', '-r'], stdout=subprocess.DEVNULL, stderr=open(os.environ['FAKE_EXPLORER_DIR'] + '/xdp.log', 'w'))


def wait_for(name, seconds=15):
    end = time.time() + seconds
    while time.time() < end:
        if bus.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus', 'NameHasOwner',
                         GLib.Variant('(s)', (name,)), None, 0, -1, None).unpack()[0]:
            return True
        time.sleep(0.1)
    return False


def unpack(value):
    return value.unpack() if isinstance(value, GLib.Variant) else value


def run_group(cases):
    pending, results = {}, {}
    for case in cases:
        token = 'tok' + case['name'].replace('-', '_')
        path = '/org/freedesktop/portal/desktop/request/%s/%s' % (unique, token)
        options = {k: GLib.Variant(t, v) for k, (t, v) in case.get('options', {}).items()}
        options['handle_token'] = GLib.Variant('s', token)
        started = time.time()
        entry = dict(name=case['name'], path=path, started=started)
        results[case['name']] = entry
        pending[path] = case

        def on_signal(conn, sender, obj, iface, signal, params, _case=case, _entry=entry):
            response, res = params.unpack()
            _entry.update(response=response, results=res, elapsed=time.time() - _entry['started'])
            pending.pop(obj, None)
            if not pending:
                loop.quit()
        bus.signal_subscribe('org.freedesktop.portal.Desktop', 'org.freedesktop.portal.Request', 'Response', path, None,
                             Gio.DBusSignalFlags.NONE, on_signal)
        try:
            bus.call_sync('org.freedesktop.portal.Desktop', '/org/freedesktop/portal/desktop', 'org.freedesktop.portal.FileChooser',
                          case['method'], GLib.Variant('(ssa{sv})', ('', case.get('title', case['name']), options)), None, 0, -1, None)
        except GLib.Error as exc:
            entry.update(call_error=str(exc))
            pending.pop(path, None)
        if case.get('close_after') is not None:
            def close(_path=path, _entry=entry):
                try:
                    bus.call_sync('org.freedesktop.portal.Desktop', _path, 'org.freedesktop.portal.Request', 'Close', None, None, 0, -1, None)
                    _entry['closed'] = True
                except GLib.Error as exc:
                    _entry['close_error'] = str(exc)
                pending.pop(_path, None)
                if not pending:
                    loop.quit()
                return GLib.SOURCE_REMOVE
            GLib.timeout_add(int(case['close_after'] * 1000), close)
    if pending:
        def timeout():
            for case in pending.values():
                results[case['name']]['timeout'] = True
            pending.clear()
            loop.quit()
            return GLib.SOURCE_REMOVE
        GLib.timeout_add(int(spec.get('timeout', 20) * 1000), timeout)
        loop.run()
    return list(results.values())


out = dict(ready=wait_for('org.freedesktop.portal.Desktop'), cases=[])
if out['ready']:
    groups = {}
    for case in spec['cases']:
        groups.setdefault(case.get('group', case['name']), []).append(case)
    for cases in groups.values():
        out['cases'] += run_group(cases)
    time.sleep(spec.get('settle', 0.3))
xdp.terminate()
print(json.dumps(out, default=lambda o: o.decode('utf-8', 'replace') if isinstance(o, bytes) else str(o)))
