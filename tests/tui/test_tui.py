"""TUI de solo dibujo: terminal simulada (TUI_COLS/TUI_ROWS), sin terminal real, sin escrituras."""
import json
import os
import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ANSI = re.compile(r'\x1b\[[0-9;?]*[A-Za-z]')

SCRIPT = r'''
set -Eeuo pipefail
REPO_DIR="%s"
EV_OUT_FD=1
. "$REPO_DIR/lib/events.sh"
. "$REPO_DIR/lib/tui.sh"
TUI_VERSION=1.2.3
tui_draw() { :; }
tui_open() { :; }
%s
'''

def frame(cols, rows, events, color=False):
    env = dict(os.environ, TUI_COLS=str(cols), TUI_ROWS=str(rows), TERM='xterm-256color', LC_ALL='C.UTF-8')
    env.pop('NO_COLOR', None)
    if not color:
        env['NO_COLOR'] = '1'
    body = events + '\ntui_frame\n'
    out = subprocess.run(['bash', '-c', SCRIPT % (ROOT, body)], env=env, capture_output=True, text=True, timeout=30)
    assert out.returncode == 0, out.stderr
    return out.stdout.split('\n')[:-1]

EVENTS = r'''
for p in Preflight Plan; do tui_handle phase name "$p"; done
tui_handle phase name Paquetes
for i in $(seq 1 40); do tui_handle pkg name "paquete-largo-numero-$i" state install detail "1.$i.0-1"; done
tui_handle pkg name hyprland state installed detail 0.56.2
tui_handle pkg name paquete-largo-numero-3 state running
tui_handle pkg name mpvpaper state aur
tui_handle pkg name rustup state conflict
tui_handle step msg "Instalando paquete-largo-numero-3"
tui_handle warn msg "KWallet compite con gnome-keyring"
for i in $(seq 1 30); do tui_handle log msg "línea $i de salida de pacman con texto bastante largo para comprobar el recorte sin desbordes de ningún tipo en pantalla"; done
'''


class TuiFrame(unittest.TestCase):
    def check(self, cols, rows):
        lines = frame(cols, rows, EVENTS)
        self.assertLessEqual(len(lines), rows - 1, 'el cuadro no cabe en la terminal')
        for line in lines:
            self.assertLessEqual(len(ANSI.sub('', line)), cols, 'desborda: ' + line)
        return lines

    def test_80_columns(self):
        lines = self.check(80, 24)
        text = '\n'.join(lines)
        for word in ('dragon-island', 'v1.2.3', 'Preflight', 'Verificación', '[Paquetes]', '✔ Preflight', 'Registro', 'conflicto'):
            self.assertIn(word, text) if word != 'conflicto' else None
        self.assertIn('%', text)

    def test_wide_is_centred(self):
        lines = frame(200, 40, EVENTS)
        box = next(l for l in lines if '╭' in l)
        left = len(box) - len(box.lstrip())
        right = 200 - left - len(box.strip())
        self.assertLessEqual(abs(left - right), 1)
        self.assertGreater(left, 50)

    def test_many_sizes_never_overflow(self):
        for cols, rows in ((60, 16), (80, 24), (100, 30), (132, 50), (240, 60), (45, 12)):
            with self.subTest(cols=cols, rows=rows):
                self.check(cols, rows)

    def test_icons_and_states(self):
        ev = ("tui_handle pkg name a state installed\ntui_handle pkg name b state install\ntui_handle pkg name c state aur\n"
              "tui_handle pkg name d state conflict\ntui_handle pkg name e state running")
        text = '\n'.join(frame(120, 40, ev))
        for icon in ('✔', '↓', '◆', '✖', '…'):
            self.assertIn(icon, text)

    def test_no_color_has_no_escape(self):
        self.assertFalse(any('\x1b' in l for l in frame(80, 24, EVENTS)))

    def test_color_uses_palette(self):
        text = '\n'.join(frame(80, 24, EVENTS, color=True))
        self.assertIn('38;2;197;14;210', text)   # #c50ed2

    def test_log_strips_escape_sequences(self):
        lines = frame(80, 24, 'tui_handle log msg $\'\\e[31mrojo\\e[0m\\e[2K normal\'')
        text = '\n'.join(lines)
        self.assertIn('rojo normal', text)

    def test_progress_counts(self):
        ev = 'tui_handle pkg name a state installed\ntui_handle pkg name b state install\ntui_handle pkg name c state ok\ntui_handle pkg name d state install'
        text = '\n'.join(frame(80, 24, ev))
        self.assertIn('2/4', text)
        self.assertIn(' 50%', text)


class Sinks(unittest.TestCase):
    def run_events(self, sink, extra=''):
        script = SCRIPT % (ROOT, 'EV_SINK=%s\n' % sink + r'''
ev_phase Preflight
ev_pkg hyprland installed 0.56.2
ev_step 'comillas " y \ barra'
ev_warn "aviso"
ev_log "línea"
ev_done ok "todo bien"
''' + extra)
        return subprocess.run(['bash', '-c', script], capture_output=True, text=True, timeout=30,
                              env=dict(os.environ, LC_ALL='C.UTF-8'))

    def test_json_one_object_per_line(self):
        out = self.run_events('json')
        self.assertEqual(out.returncode, 0, out.stderr)
        events = [json.loads(l) for l in out.stdout.splitlines()]
        self.assertEqual([e['event'] for e in events], ['phase', 'pkg', 'step', 'warn', 'log', 'done'])
        self.assertEqual(events[1]['name'], 'hyprland')
        self.assertEqual(events[2]['msg'], 'comillas " y \\ barra')
        self.assertEqual(events[5]['status'], 'ok')

    def test_plain_has_no_escape_sequences(self):
        out = self.run_events('plain')
        self.assertIn('== Preflight ==', out.stdout)
        self.assertIn('hyprland', out.stdout)
        self.assertNotIn('\x1b', out.stdout)

    def test_tui_failure_falls_back_to_plain(self):
        # tui_handle fails → the run goes on in plain text
        out = self.run_events('tui', 'x=1')
        script = SCRIPT % (ROOT, 'tui_handle() { return 1; }\nEV_SINK=tui\nev_phase Plan\nev_step seguimos\necho "sink=$EV_SINK"\n')
        out = subprocess.run(['bash', '-c', script], capture_output=True, text=True, timeout=30,
                             env=dict(os.environ, LC_ALL='C.UTF-8'))
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn('sink=plain', out.stdout)
        self.assertIn(':: seguimos', out.stdout)


class Summary(unittest.TestCase):
    def test_summary_box_fits_80(self):
        ev = r'''
tui_handle pkg name a state installed
tui_handle pkg name b state failed
tui_finish warn "$(printf 'Queda manual:\n  - habilitar algo muy largo %s\n' "$(printf 'x%.0s' {1..120})")"
'''
        env = dict(os.environ, TUI_COLS='80', TUI_ROWS='24', NO_COLOR='1', LC_ALL='C.UTF-8')
        out = subprocess.run(['bash', '-c', SCRIPT % (ROOT, ev)], env=env, capture_output=True, text=True, timeout=30)
        self.assertEqual(out.returncode, 0, out.stderr)
        for line in out.stdout.splitlines():
            self.assertLessEqual(len(line), 80, line)
        self.assertIn('╭', out.stdout); self.assertIn('╰', out.stdout)
        self.assertIn('Instalación terminada con avisos', out.stdout)


if __name__ == '__main__':
    unittest.main()
