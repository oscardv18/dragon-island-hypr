#!/usr/bin/env python3
"""Opt-in integration check: temporary terminals on a hidden Hyprland workspace.

Usage: python3 tests/palette/live-reload.py /path/to/wallpaper.jpg
Never touches the user's configs; probe children exit themselves after the check.
"""
import json
import os
from pathlib import Path
import re
import select
import shlex
import shutil
import subprocess
import sys
import tempfile
import termios
import time
import tty

ROOT = Path(__file__).resolve().parents[2]
CLASSES = {'ghostty': 'org.dragonisland.PaletteCheckGhostty',
           'kitty': 'org.dragonisland.PaletteCheckKitty'}


def probe(directory, app):
    directory = Path(directory)
    with open('/dev/tty', 'r+b', buffering=0) as terminal:
        fd = terminal.fileno()
        saved = termios.tcgetattr(fd)
        try:
            tty.setraw(fd)
            last = None
            deadline = time.monotonic() + 60
            while time.monotonic() < deadline:
                phase = (directory / 'phase').read_text()
                if phase == 'finish':
                    return
                if phase != last:
                    colors = {}
                    for index in (4, 12):
                        os.write(fd, f'\x1b]4;{index};?\x1b\\'.encode())
                        response = b''
                        until = time.monotonic() + 2
                        while time.monotonic() < until:
                            if select.select([fd], [], [], 0.05)[0]:
                                response += os.read(fd, 4096)
                            match = re.search(rb'\x1b\]4;\d+;rgb:([0-9a-fA-F]+)/([0-9a-fA-F]+)/([0-9a-fA-F]+)', response)
                            if match:
                                values = [round(int(v,16)*255/(16**len(v)-1)) for v in match.groups()]
                                colors[str(index)] = '#' + ''.join(f'{v:02X}' for v in values)
                                break
                        if str(index) not in colors:
                            colors[str(index)] = 'no-response'
                    path = directory / f'{app}-{phase}.json'
                    temporary = path.with_suffix('.tmp')
                    temporary.write_text(json.dumps(colors))
                    temporary.replace(path)
                    last = phase
                time.sleep(0.05)
        finally:
            termios.tcsetattr(fd, termios.TCSANOW, saved)


def clients():
    return json.loads(subprocess.check_output(['hyprctl','clients','-j']))


def wait_report(directory, app, phase):
    path = directory / f'{app}-{phase}.json'
    deadline = time.monotonic() + 12
    while time.monotonic() < deadline:
        if path.exists():
            return json.loads(path.read_text())
        time.sleep(0.05)
    raise RuntimeError(f'{app}: no respondió en la fase {phase}')


def main(image):
    for command in ('hyprctl','ghostty','kitty'):
        if not shutil.which(command):
            raise RuntimeError(f'falta {command}')
    if not os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'):
        raise RuntimeError('requiere una sesión Hyprland')
    with tempfile.TemporaryDirectory(prefix='dragon-palette-live-') as temporary:
        directory = Path(temporary)
        env = dict(os.environ, HOME=temporary, XDG_CONFIG_HOME=temporary+'/.config',
                   XDG_DATA_HOME=temporary+'/.local/share', XDG_STATE_HOME=temporary+'/.local/state',
                   XDG_CACHE_HOME=temporary+'/.cache', LINK_MODE='copy', ASSUME_YES='true',
                   NO_SUDO='true', REPO_DIR=str(ROOT))
        env.pop('STARSHIP_CONFIG', None)
        env.pop('KITTY_LISTEN_ON', None)
        for app in CLASSES:
            shutil.copytree(ROOT / 'config' / app, directory / '.config' / app)
        shutil.copy(ROOT / 'config/starship/starship.toml', directory / '.config/starship.toml')
        subprocess.run(['bash',str(ROOT/'migrations/030-palette-templates.sh')], env=env,
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        (directory / 'phase').write_text('before')
        result = {}
        try:
            for app, class_name in CLASSES.items():
                overrides = [f'{key}={env[key]}' for key in ('HOME','XDG_CONFIG_HOME','XDG_DATA_HOME','XDG_STATE_HOME','XDG_CACHE_HOME')]
                args = ['env',*overrides,app]
                if app == 'ghostty':
                    args += ['--gtk-single-instance=false','--class='+class_name,'-e']
                else:
                    args += ['--class',class_name]
                args += [sys.executable, str(Path(__file__).resolve()), '--probe', temporary, app]
                command = shlex.join(args)
                lua = 'hl.dispatch(hl.dsp.exec_cmd(' + json.dumps(command) + ', {workspace="special:dragon-palette-check silent"}))'
                launched = subprocess.run(['hyprctl','eval',lua], capture_output=True, text=True, check=True)
                if launched.stdout.strip() != 'ok':
                    raise RuntimeError(launched.stdout + launched.stderr)
            before = {app: wait_report(directory,app,'before') for app in CLASSES}
            pids = {w['class']:w['pid'] for w in clients() if w['class'] in CLASSES.values()}
            if len(pids) != 2:
                raise RuntimeError(f'faltan ventanas: {pids}')
            command = str(directory / '.local/bin/dragon-palette')
            subprocess.run([command,'generate',str(Path(image).resolve()),'--quiet'], env=env,check=True)
            palette = json.loads((directory / '.local/state/dragon-island/palette.json').read_text())
            for phase, action, expected in (
                ('apply','apply',{'4':palette['accentDeep'],'12':palette['accent']}),
                ('reset','reset',{'4':'#7C3AED','12':'#945DF0'})):
                subprocess.run([command,action,'--quiet'], env=env,check=True)
                time.sleep(0.3)
                (directory/'phase').write_text(phase)
                reports = {app:wait_report(directory,app,phase) for app in CLASSES}
                current = {w['class']:w['pid'] for w in clients() if w['class'] in CLASSES.values()}
                if current != pids:
                    raise RuntimeError(f'los procesos cambiaron: {pids} → {current}')
                for app, colors in reports.items():
                    if colors != expected:
                        raise RuntimeError(f'{app}/{phase}: {colors}, esperado {expected}')
                result[phase] = reports
            print(json.dumps(dict(before=before,**result,pids=pids,windows_survived=True),indent=2))
        finally:
            (directory/'phase').write_text('finish')
            deadline = time.monotonic() + 6
            while time.monotonic() < deadline:
                if not any(w['class'] in CLASSES.values() for w in clients()):
                    break
                time.sleep(0.25)


if __name__ == '__main__':
    if len(sys.argv) == 4 and sys.argv[1] == '--probe':
        probe(sys.argv[2], sys.argv[3])
    elif len(sys.argv) == 2:
        main(sys.argv[1])
    else:
        raise SystemExit(__doc__)
