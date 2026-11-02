import os
from pathlib import Path
import shutil
import subprocess
import struct
import tempfile
import unittest

from fixture_shell import ROOT, prepare, environment


class NotificationBell(unittest.TestCase):
    @unittest.skipUnless(shutil.which('qs'), 'Quickshell required')
    def test_real_right_island_states_clicks_and_sizes(self):
        with tempfile.TemporaryDirectory(prefix='dragon-bell-') as directory:
            cfg = prepare(directory)
            result = subprocess.run(['qs', '-p', str(cfg)], env=environment(directory), capture_output=True, text=True, timeout=25)
            log = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, log)
            self.assertIn('BELL_TEST_OK', log, log)
            for error in ('ReferenceError', 'TypeError', 'BELL_TEST:', 'BELL_TEST_TIMEOUT', 'Failed to load', 'Unable to assign'):
                self.assertNotIn(error, log, log)
            for state in ('empty', 'unread', 'dnd', 'dnd-empty', 'overflow'):
                self.assertTrue((Path(directory) / 'out' / (state + '.png')).exists())
            captures = list((Path(directory) / 'out').glob('*.png'))
            self.assertEqual(len(captures), 18)
            for capture in captures:
                self.assertEqual(struct.unpack('>II', capture.read_bytes()[16:24]), (760, 170))

    def test_no_duplicate_clock_markers_or_idle_work(self):
        island = (ROOT / 'config/quickshell/modules/bar/RightIsland.qml').read_text()
        clock = island.split('id: clockCap', 1)[1]
        self.assertNotIn('Notifs.', clock)
        self.assertNotIn('Toggles.dnd', clock)
        bell = (ROOT / 'config/quickshell/modules/bar/NotificationBell.qml').read_text()
        # the only animation is the slot opening/closing with the unread count: no idle or looping animation
        for forbidden in ('Timer {', 'Process', 'execDetached', 'DBus', '#', 'loops:', 'running:', 'SequentialAnimation', 'ParallelAnimation', 'SpringAnimation'):
            self.assertNotIn(forbidden, bell)
        self.assertEqual(bell.count('Animation'), 1)
        self.assertIn('Behavior on width', bell)
        self.assertIn('Toggles.toggleDnd()', bell)
        self.assertIn('island.openPopover("notifications", bell)', bell)
