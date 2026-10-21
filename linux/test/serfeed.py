#!/usr/bin/env python3
"""The caller side of a serial line for multitasking tests:  connects to
QEMU's COM1 (-serial unix:SOCKET,server,nowait), waits until the DOS
side (TESTS/SCENARIO/SERECHO) sends "R", then sends COUNT bytes at RATE
bytes a second and checks that every byte comes back (echo).

    serfeed.py SOCKET [--count N] [--rate B] [--wait S] [--out FILE]

--wait:  seconds to wait for the socket and the "R" (default 600).
Prints (and writes to --out) "sent N echoed M ok|bad"; exit code 0 when
all bytes came back unchanged and in order.
"""
import argparse
import os
import select
import socket
import sys
import time


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('socket')
    ap.add_argument('--count', type=int, default=3000)
    ap.add_argument('--rate', type=int, default=50)
    ap.add_argument('--wait', type=int, default=600)
    ap.add_argument('--out')
    a = ap.parse_args()

    end = time.time() + a.wait
    s = None
    while time.time() < end:
        if os.path.exists(a.socket):
            try:
                s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                s.connect(a.socket)
                break
            except OSError:
                s = None
        time.sleep(1)
    if not s:
        return report(a, 0, b'', b'', 'no socket')
    s.setblocking(False)

    # wait for "R" (anything before it is the DOS side's earlier output)
    got = b''
    while time.time() < end and b'R' not in got:
        r, _, _ = select.select([s], [], [], 1)
        if r:
            d = s.recv(4096)
            if not d:
                return report(a, 0, b'', b'', 'closed')
            got += d
    if b'R' not in got:
        return report(a, 0, b'', b'', 'no R')

    data = bytes(0x30 + i % 43 for i in range(a.count))   # '0'..'Z'
    echo = b''
    sent = 0
    step = max(1, a.rate // 10)
    t = time.time()
    while sent < a.count:
        s.sendall(data[sent:sent + step])
        sent += min(step, a.count - sent)
        t += 0.1
        while True:
            left = t - time.time()
            if left <= 0:
                break
            r, _, _ = select.select([s], [], [], left)
            if r:
                echo += s.recv(4096)
    # the rest of the echo
    last = time.time() + 15
    while time.time() < last and len(echo) < a.count:
        r, _, _ = select.select([s], [], [], 1)
        if r:
            echo += s.recv(4096)
    return report(a, sent, data, echo, '')


def report(a, sent, data, echo, why):
    ok = not why and echo == data
    line = 'sent %d echoed %d %s%s' % (sent, len(echo), 'ok' if ok else 'bad',
                                       (' (%s)' % why) if why else '')
    if not ok and not why:
        n = next((i for i in range(min(len(echo), len(data)))
                  if echo[i] != data[i]), min(len(echo), len(data)))
        line += ' (first difference at byte %d)' % n
    print(line)
    if a.out:
        with open(a.out, 'w') as f:
            f.write(line + '\n')
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
