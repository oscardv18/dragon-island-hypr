"""A pty runner that types answers when a prompt appears (the sudo password, a confirmation)."""
import fcntl
import os
import pty
import select
import struct
import termios
import time

from tests.tui.test_install_modes import ROOT


def run_interactive(args, env, cols=80, rows=30, answers=(), timeout=240):
    """answers: iterable of (text-to-wait-for, text-to-type). Returns (raw output, exit code)."""
    pid, fd = pty.fork()
    if pid == 0:
        os.chdir(ROOT)
        os.execve(str(ROOT/'install.sh'), [str(ROOT/'install.sh'), *args], dict(env, TERM='xterm-256color'))
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack('HHHH', rows, cols, 0, 0))
    pending, chunks, seen, deadline = list(answers), [], b'', time.time() + timeout
    while time.time() < deadline:
        ready, _, _ = select.select([fd], [], [], 1)
        if ready:
            try:
                data = os.read(fd, 65536)
            except OSError:
                break
            if not data:
                break
            chunks.append(data); seen += data
            while pending and pending[0][0].encode() in seen:
                needle, typed = pending.pop(0)
                seen = seen.split(needle.encode(), 1)[1]
                os.write(fd, typed.encode())
        elif os.waitpid(pid, os.WNOHANG)[0]:
            break
    else:
        os.kill(pid, 9)
    try:
        _, status = os.waitpid(pid, 0)
    except ChildProcessError:
        status = 0
    return b''.join(chunks).decode('utf-8', 'replace'), os.waitstatus_to_exitcode(status)
