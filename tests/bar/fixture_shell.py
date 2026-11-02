"""Create an isolated Quickshell using real UI/ShellState and inert fixture services."""
import json
import os
from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parents[2]


def prepare(work):
    work = Path(work)
    cfg = work / 'shell'
    shutil.copytree(ROOT / 'config/quickshell', cfg)
    fixture = json.loads((ROOT / 'tests/qml/fixtures/right-island.json').read_text())
    services = cfg / 'services'
    shutil.rmtree(services)
    services.mkdir()
    functions = {
        'Audio': 'function setVolume(v) {} function toggleMute() {}',
        'Brightness': 'function levelFor(s) { return 0.7; } function setLevelFor(s, v) {}',
        'Caffeine': 'function toggle() {}', 'Keyboard': 'function next() {}',
        'SysStats': 'function formatRate(v) { return "200 K/s"; }',
        'Tiling': 'function toggle() {}', 'Vpn': 'function openApp() {}',
    }
    for name, values in fixture['services'].items():
        properties = '\n'.join('property var ' + key + ': ' + json.dumps(value) for key, value in values.items())
        (services / (name + '.qml')).write_text('pragma Singleton\nimport QtQuick\nimport Quickshell\nSingleton {\n' + properties + '\n' + functions.get(name, '') + '\n}\n')
    (services / 'Toggles.qml').write_text('pragma Singleton\nimport QtQuick\nimport Quickshell\nSingleton { readonly property bool dnd: Notifs.dnd; function toggleDnd() { Notifs.dnd = !Notifs.dnd; } function toggleRecording() {} }\n')
    (services / 'qmldir').write_text(''.join(f'singleton {name} 1.0 {name}.qml\n' for name in list(fixture['services']) + ['Toggles']))
    (cfg / 'fixtures').mkdir()
    shutil.copy(ROOT / 'tests/qml/fixtures/right-island.json', cfg / 'fixtures')
    source = (ROOT / 'tests/qml/notification_bell_mock.qml').read_text()
    # Exercise the actual mapping logic without loading Bar's system services or
    # layer surfaces in the user's desktop. The RightIsland itself is unmodified.
    bar_source = (ROOT / 'config/quickshell/modules/bar/Bar.qml').read_text()
    methods = '\n'.join(re.search(r'    function ' + name + r'\([^\n]*\n.*?\n    }', bar_source, re.S).group(0) for name in ('openFrom', 'isOpen'))
    source = source.replace('QtObject { id: bar; property string screenName: "FIXTURE-1" }',
                            'QtObject { id: bar; property string screenName: "FIXTURE-1"\n' + methods + '\n}')
    (cfg / 'shell.qml').write_text(source)
    (work / 'out').mkdir()
    return cfg


def environment(work, offscreen=True):
    work = Path(work)
    env = dict(os.environ, HOME=str(work), PYTHONDONTWRITEBYTECODE='1', QML_XHR_ALLOW_FILE_READ='1',
               BELL_OUTPUT=str(work / 'out'), QT_FORCE_STDERR_LOGGING='1')
    env.pop('QT_QPA_PLATFORMTHEME', None)
    for kind in ('CONFIG', 'DATA', 'STATE', 'CACHE'):
        env['XDG_' + kind + '_HOME'] = str(work / kind.lower())
    if offscreen:
        runtime = work / 'runtime'
        runtime.mkdir(mode=0o700)
        env.update(XDG_RUNTIME_DIR=str(runtime), QT_QPA_PLATFORM='offscreen')
    return env
