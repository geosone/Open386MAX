#!/usr/bin/env python3
"""Keyword tests: boot 386MAX once per line of TESTS/KEYWORDS.LST and check
what MAXPROBE reports.

    linux/test/kwtest.py [-d msdos622] [-j 6] [-k NAME ...] [--check] [--update]

A line of KEYWORDS.LST:

    NAME  [@mem=MB] [@cpu=MODEL] [@cfg=LINE] KEYWORD;KEYWORD... | EXPECT ...

The keywords (; separated, - for none) become C:\\MAX\\386MAX.PRO, loaded
with DEVICE=C:\\MAX\\386MAX.SYS PRO=C:\\MAX\\386MAX.PRO (no DOS=HIGH, so the
HMA can be checked; DOS=UMB).  AUTOEXEC.BAT runs MAXPROBE (TESTS/MAX) and
ends QEMU.  An expectation compares a value of MAXPROBE (hex):

    NAME=v  NAME!=v  NAME<v  NAME>v  NAME<=v  NAME>=v
    %OK        no Unknown keyword/Invalid/error on the screen, MAXPROBE ran,
               XMS 3.50 (386MAX's)
    SCR~text   the screen after booting contains text (_ = blank)
    SCR!~text  ... doesn't
    ROM~seg    an option ROM starts at seg (hex)
    ROM!~seg   ... doesn't

Results:  build/kwtest/<dos>/result.txt (PASS / FAIL with the failed
expectations / NOPROBE when MAXPROBE didn't run:  hang, crash, a key
press that didn't help).  --check compares with TESTS/BASELINE/kw-<dos>.TXT
(exit 1 on regressions), --update stores the results there.

Environment:  ACCEL (default -accel tcg), MAXBIN (other 386MAX.SYS).
Warnings that wait for a key get Enter every 20 seconds.
"""
import argparse
import concurrent.futures
import os
import shutil
import socket
import subprocess
import sys
import time

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
TESTS = os.path.join(ROOT, 'TESTS')
BUILD = os.path.join(ROOT, 'build')
ENV = dict(os.environ, MTOOLS_SKIP_CHECK='1', MTOOLS_NO_VFAT='1')
ACCEL = os.environ.get('ACCEL', '-accel tcg')
QEXIT = bytes.fromhex('ba0105b000eeb8004ccd21')  # out 501h,0; int 21h 4C00h
SHELLS = {'svardos': 'SHELL=C:\\COMMAND.COM /P'}
SHELL = 'SHELL=C:\\COMMAND.COM C:\\ /E:1024 /P'
TIMEOUT = 420 if 'tcg' in ACCEL else 120
# %OK in an expectation list:  the keyword is accepted and the system boots
OKSET = ['SCR!~Unknown_keyword', 'SCR!~Invalid', 'SCR!~error', 'DOSVER>0', 'XMS=350']


def sh(*cmd, **kw):
    return subprocess.run(cmd, env=ENV, check=True, **kw)


class Line:
    def __init__(self, text):
        left, _, right = text.partition('|')
        w = left.split()
        self.name, self.mem, self.cpu, self.cfg, kw = w[0], '64', None, [], []
        for x in w[1:]:
            if x.startswith('@mem='):
                self.mem = x[5:]
            elif x.startswith('@cpu='):
                self.cpu = x[5:]
            elif x.startswith('@cfg='):
                self.cfg.append(x[5:].replace('_', ' '))
            else:
                kw.append(x)
        kw = ' '.join(kw)
        self.keywords = [] if kw.strip() == '-' else [k.strip() for k in kw.split(';') if k.strip()]
        self.expect = []
        for e in right.split():
            self.expect += OKSET if e == '%OK' else [e]


def write_dos(p, name, lines, tmpdir):
    tmp = os.path.join(tmpdir, os.path.basename(name))
    with open(tmp, 'w', newline='') as f:
        f.write('\r\n'.join(lines) + '\r\n')
    sh('mcopy', '-o', '-i', p, tmp, '::/' + name)
    os.remove(tmp)


def maxfile(f):
    g = os.path.join(os.environ.get('MAXBIN', ''), f)
    return g if os.environ.get('MAXBIN') and os.path.exists(g) else os.path.join(BUILD, 'bin', f)


def monitor(sock, cmd):
    try:
        s = socket.socket(socket.AF_UNIX)
        s.settimeout(5)
        s.connect(sock)
        s.recv(4096)
        s.sendall((cmd + '\n').encode())
        time.sleep(0.3)
        s.close()
    except OSError:
        pass


def boot(line, dos, out):
    os.makedirs(out, exist_ok=True)
    base = dos if os.path.isfile(dos) else os.path.join(BUILD, 'dosdisk', dos + '.img')
    img = os.path.join(out, 'test.img')
    shutil.copy(base, img)
    p = img + '@@32256'
    subprocess.run(['mmd', '-i', p, '::/MAX'], env=ENV, capture_output=True)
    for f in ['386MAX.SYS', '386MAX.VXD', '386LOAD.SYS', '386LOAD.COM', '386UTIL.COM', 'XLAT.COM']:
        if os.path.exists(maxfile(f)):
            sh('mcopy', '-o', '-i', p, maxfile(f), '::/MAX/')
    sh('mcopy', '-o', '-i', p, os.path.join(BUILD, 'TESTS', 'MAXPROBE.EXE'), '::/MAX/')
    q = os.path.join(out, 'QEXIT.COM')
    open(q, 'wb').write(QEXIT)
    sh('mcopy', '-o', '-i', p, q, '::/QEXIT.COM')
    subprocess.run(['mdel', '-i', p, '::/PROBE.TXT'], env=ENV, capture_output=True)
    write_dos(p, 'MAX/386MAX.PRO', line.keywords or ['; none'], out)
    name = os.path.basename(base).lower()
    shell = next((v for k, v in SHELLS.items() if k in name), SHELL)
    write_dos(p, 'CONFIG.SYS', ['DEVICE=C:\\MAX\\386MAX.SYS PRO=C:\\MAX\\386MAX.PRO']
              + line.cfg + ['DOS=UMB', 'FILES=40', 'BUFFERS=20', shell], out)
    write_dos(p, 'AUTOEXEC.BAT', ['@ECHO OFF', 'C:\\MAX\\MAXPROBE.EXE > C:\\PROBE.TXT',
                                  'C:\\QEXIT.COM'], out)
    sock = os.path.join(out, 'm.sock')
    cmd = (['qemu-system-i386', '-machine', 'pc'] + ACCEL.split()
           + (['-cpu', line.cpu] if line.cpu else [])
           + ['-m', line.mem, '-display', 'none', '-vga', 'std', '-no-reboot',
              '-monitor', 'unix:%s,server,nowait' % sock,
              '-drive', 'if=ide,index=0,format=raw,file=' + img, '-boot', 'c', '-nic', 'none',
              '-device', 'isa-debug-exit,iobase=0x501,iosize=0x02'])
    qemu = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    t0 = time.time()
    while qemu.poll() is None and time.time() - t0 < TIMEOUT:
        time.sleep(2)
        if int(time.time() - t0) % 20 < 2 and time.time() - t0 > 30:
            monitor(sock, 'sendkey ret')
    if qemu.poll() is None:
        qemu.kill()
        qemu.wait()
    r = subprocess.run(['mtype', '-i', p, '::/PROBE.TXT'], env=ENV, capture_output=True)
    text = r.stdout.decode('cp437', 'replace').replace('\r', '') if r.returncode == 0 else ''
    open(os.path.join(out, 'probe.txt'), 'w').write(text)
    os.remove(img)
    return text


def parse(text):
    vals, scr, roms = {}, [], set()
    for l in text.split('\n'):
        if l.startswith('SCR:'):
            scr.append(l[4:])
        elif l.startswith('ROM='):
            roms.add(int(l[4:].split(',')[0], 16))
        elif '=' in l:
            k, _, v = l.partition('=')
            try:
                vals[k.strip()] = int(v.strip(), 16)
            except ValueError:
                pass
    return vals, '\n'.join(scr), roms


def check(line, text):
    if 'DOSVER=' not in text:
        return 'NOPROBE', []
    vals, scr, roms = parse(text)
    bad = []
    for e in line.expect:
        for op in ('!~', '~', '<=', '>=', '!=', '=', '<', '>'):
            if op in e:
                k, _, v = e.partition(op)
                break
        else:
            bad.append(e + '?')
            continue
        if k == 'SCR':
            has = v.replace('_', ' ').lower() in scr.lower()
            ok = has if op == '~' else not has
        elif k == 'ROM':
            has = int(v, 16) in roms
            ok = has if op == '~' else not has
        elif k not in vals:
            ok = False
        else:
            a, b = vals[k], int(v, 16)
            ok = {'=': a == b, '!=': a != b, '<': a < b, '>': a > b,
                  '<=': a <= b, '>=': a >= b}[op]
        if not ok:
            bad.append('%s (%s)' % (e, ('%X' % vals[k]) if k in vals else '-'))
    return ('FAIL' if bad else 'PASS'), bad


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('-d', '--dos', default='msdos622')
    ap.add_argument('-j', '--jobs', type=int, default=6)
    ap.add_argument('-k', '--keyword', action='append', default=[], help='only these lines (NAME)')
    ap.add_argument('--check', action='store_true')
    ap.add_argument('--update', action='store_true')
    a = ap.parse_args()
    subprocess.run(['make', '-s', '-C', TESTS], check=True)
    lines = [Line(l.strip()) for l in open(os.path.join(TESTS, 'KEYWORDS.LST'))
             if l.strip() and not l.startswith('#')]
    if a.keyword:
        want = set(k.upper() for k in a.keyword)
        lines = [l for l in lines if l.name.upper() in want]
    tag = os.path.basename(a.dos).replace('.img', '')
    top = os.path.join(BUILD, 'kwtest', tag)
    os.makedirs(top, exist_ok=True)
    res = {}

    def one(l):
        st, bad = check(l, boot(l, a.dos, os.path.join(top, l.name)))
        print('%-16s %-7s %s' % (l.name, st, ' '.join(bad)), flush=True)
        return l.name, st, bad

    with concurrent.futures.ThreadPoolExecutor(a.jobs) as ex:
        for name, st, bad in ex.map(one, lines):
            res[name] = (st, bad)
    with open(os.path.join(top, 'result.txt'), 'w') as f:
        for n in sorted(res):
            f.write('%-16s %s %s\n' % (n, res[n][0], ' '.join(res[n][1])))
    base = os.path.join(TESTS, 'BASELINE', 'kw-%s.TXT' % tag)
    old = {}
    if os.path.exists(base):
        for l in open(base):
            w = l.split()
            if len(w) >= 2:
                old[w[0]] = w[1]
    rc = 0
    if a.check:
        for n, (st, _) in sorted(res.items()):
            if old.get(n) == 'PASS' and st != 'PASS':
                print('REGRESSION kw-%s %s: PASS -> %s' % (tag, n, st))
                rc = 1
            elif n not in old:
                print('new kw-%s %s: %s' % (tag, n, st))
    if a.update:
        old.update({n: st for n, (st, _) in res.items()})
        os.makedirs(os.path.dirname(base), exist_ok=True)
        with open(base, 'w') as f:
            for n in sorted(old):
                f.write('%-16s %s\n' % (n, old[n]))
    return rc


if __name__ == '__main__':
    sys.exit(main())
