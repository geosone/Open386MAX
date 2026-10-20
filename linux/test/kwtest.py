#!/usr/bin/env python3
"""Keyword tests: boot 386MAX once per line of TESTS/KEYWORDS.LST and check
what MAXPROBE reports.

    linux/test/kwtest.py [-d msdos622] [-j 6] [-k NAME ...] [--check] [--update]

A line of KEYWORDS.LST:

    NAME  [@mem=MB] [@cpu=MODEL] [@cfg=LINE] [@noumb] [@run=TEST]
          KEYWORD;KEYWORD... | EXPECT ...

The keywords (; separated, - for none) become C:\\MAX\\386MAX.PRO, loaded
with DEVICE=C:\\MAX\\386MAX.SYS PRO=C:\\MAX\\386MAX.PRO (no DOS=HIGH, so the
HMA can be checked; DOS=UMB unless @noumb).  AUTOEXEC.BAT runs MAXPROBE
(TESTS/MAX), then the test program TEST (build/TESTS/TEST.EXE, output in
run.txt; expected:  errorlevel 0) and ends QEMU.  An expectation compares
a value of MAXPROBE (hex):

    NAME=v  NAME!=v  NAME<v  NAME>v  NAME<=v  NAME>=v
    %OK        no Unknown keyword/Invalid/error on the screen, MAXPROBE ran,
               XMS 3.51 (386MAX's)
    SCR~text   the screen after booting contains text (_ = blank)
    SCR!~text  ... doesn't
    ROM~seg    an option ROM starts at seg (hex)
    ROM!~seg   ... doesn't

Results:  build/kwtest/<dos>/result.txt (PASS / FAIL with the failed
expectations / NOPROBE when MAXPROBE didn't run:  hang, crash, a key
press that didn't help).  --check compares with TESTS/BASELINE/kw-<dos>.TXT
(exit 1 on regressions), --update stores the results there.

-m MANAGER (not max) boots another memory manager for comparison with the
lines of TESTS/KWMGR.LST whose first word is that manager:  the words
before | are its command line options (- for none).  MANAGERS below lists
the CONFIG.SYS lines; files from REFDIR (default ~/mars/scratch-386max/ref)
go to C:\\REF.  Results build/kwtest/<manager>-<dos>, baseline
kw-<manager>-<dos>.TXT; compare.md in build/kwtest lists the MAXPROBE
values of a line name for all managers run so far.

Environment:  ACCEL (default -accel tcg), MAXBIN (other 386MAX.SYS),
REFDIR.
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
OKSET = ['SCR!~Unknown_keyword', 'SCR!~Invalid', 'SCR!~error', 'DOSVER>0', 'XMS=351']
# other managers:  {} = the options of the line; (CONFIG.SYS, REFDIR files)
MANAGERS = {
    'himem':   (['DEVICE=C:\\DOS\\HIMEM.SYS {}'], []),
    'emm386':  (['DEVICE=C:\\DOS\\HIMEM.SYS', 'DEVICE=C:\\DOS\\EMM386.EXE {}'], []),
    'himemx':  (['DEVICE=C:\\REF\\HIMEMX.EXE {}'], ['HIMEMX.EXE']),
    'himemsx': (['DEVICE=C:\\REF\\HIMEMSX.EXE {}'], ['HIMEMSX.EXE']),
    'jemm386': (['DEVICE=C:\\REF\\HIMEMX.EXE', 'DEVICE=C:\\REF\\JEMM386.EXE {}'],
                ['HIMEMX.EXE', 'JEMM386.EXE']),
    'jemmsx':  (['DEVICE=C:\\REF\\HIMEMSX.EXE', 'DEVICE=C:\\REF\\JEMM386.EXE {}'],
                ['HIMEMSX.EXE', 'JEMM386.EXE']),
    'jemmex':  (['DEVICE=C:\\REF\\JEMMEX.EXE {}'], ['JEMMEX.EXE']),
    # needs the qemm622 image (QEMM in C:\\QEMM, the user's own copy)
    'qemm':    (['DEVICE=C:\\QEMM\\QEMM386.SYS {}'], []),
}
OKMGR = ['SCR!~Unknown', 'SCR!~Invalid', 'SCR!~error', 'DOSVER>0', 'XMS>0']
REFDIR = os.environ.get('REFDIR', os.path.expanduser('~/mars/scratch-386max/ref'))


def sh(*cmd, **kw):
    return subprocess.run(cmd, env=ENV, check=True, **kw)


class Line:
    def __init__(self, text, mgr='max'):
        left, _, right = text.partition('|')
        w = left.split()
        if mgr != 'max':
            w = w[1:]
        self.name, self.mem, self.cpu, self.cfg, kw = w[0], '64', None, [], []
        self.umb, self.run = True, None
        for x in w[1:]:
            if x == '@noumb':
                self.umb = False
            elif x.startswith('@run='):
                self.run = x[5:].upper()
            elif x.startswith('@mem='):
                self.mem = x[5:]
            elif x.startswith('@cpu='):
                self.cpu = x[5:]
            elif x.startswith('@cfg='):
                self.cfg.append(x[5:].replace('_', ' '))
            else:
                kw.append(x)
        kw = ' '.join(kw)
        self.keywords = [] if kw.strip() == '-' else [k.strip() for k in kw.split(';') if k.strip()]
        if mgr != 'max' and kw.strip() != '-':
            self.keywords = kw.split()
        self.expect = []
        for e in right.split():
            self.expect += (OKSET if mgr == 'max' else OKMGR) if e == '%OK' else [e]
        if self.run:
            self.expect.append('RUNOK=1')


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


def boot(line, dos, out, mgr='max'):
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
    if line.run:
        sh('mcopy', '-o', '-i', p, os.path.join(BUILD, 'TESTS', line.run + '.EXE'), '::/MAX/')
    q = os.path.join(out, 'QEXIT.COM')
    open(q, 'wb').write(QEXIT)
    sh('mcopy', '-o', '-i', p, q, '::/QEXIT.COM')
    for f in ('PROBE.TXT', 'RUN.TXT'):
        subprocess.run(['mdel', '-i', p, '::/' + f], env=ENV, capture_output=True)
    if mgr == 'max':
        write_dos(p, 'MAX/386MAX.PRO', line.keywords or ['; none'], out)
        dev = ['DEVICE=C:\\MAX\\386MAX.SYS PRO=C:\\MAX\\386MAX.PRO']
    else:
        cfg, files = MANAGERS[mgr]
        subprocess.run(['mmd', '-i', p, '::/REF'], env=ENV, capture_output=True)
        have = {g.upper(): g for g in os.listdir(REFDIR)}
        for f in files:
            sh('mcopy', '-o', '-i', p, os.path.join(REFDIR, have[f]), '::/REF/' + f)
        opt = ' '.join(line.keywords)
        dev = [c.replace('{}', opt).rstrip() for c in cfg]
    name = os.path.basename(base).lower()
    shell = next((v for k, v in SHELLS.items() if k in name), SHELL)
    write_dos(p, 'CONFIG.SYS', dev
              + line.cfg + (['DOS=UMB'] if line.umb else []) + ['FILES=40', 'BUFFERS=20', shell], out)
    run = ['C:\\MAX\\%s.EXE > C:\\RUN.TXT' % line.run, 'IF ERRORLEVEL 1 GOTO X',
           'ECHO RUNOK=1>> C:\\PROBE.TXT', ':X'] if line.run else []
    write_dos(p, 'AUTOEXEC.BAT', ['@ECHO OFF', 'C:\\MAX\\MAXPROBE.EXE > C:\\PROBE.TXT']
              + run + ['C:\\QEXIT.COM'], out)
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
    if line.run:
        r = subprocess.run(['mtype', '-i', p, '::/RUN.TXT'], env=ENV, capture_output=True)
        open(os.path.join(out, 'run.txt'), 'w').write(r.stdout.decode('cp437', 'replace').replace('\r', ''))
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


# MAXPROBE values compared across the managers (build/kwtest/compare.md)
CMPKEYS = ['CONVKB', 'XMS', 'XMSFREE', 'XMSTOTAL', 'HMA', 'XMSHANDLES', 'XMSUMB', 'SXFREE',
           'EMS', 'EMSFRAME', 'EMSPAGES', 'EMSFREE', 'EMSHANDLES', 'VCPI', 'DPMI', 'VDS',
           'QPI', 'I1588', 'I15E801', 'I15E801HI', 'I15E820', 'I15E820HI', 'UMBFREEKB']


def compare():
    top = os.path.join(BUILD, 'kwtest')
    runs = {}   # line name -> {run dir: values}
    for d in sorted(os.listdir(top)):
        if not os.path.isdir(os.path.join(top, d)):
            continue
        for n in sorted(os.listdir(os.path.join(top, d))):
            f = os.path.join(top, d, n, 'probe.txt')
            if os.path.exists(f):
                runs.setdefault(n, {})[d] = parse(open(f).read())[0]
    with open(os.path.join(top, 'compare.md'), 'w') as f:
        f.write('# MAXPROBE values (hex) per manager\n')
        for n in sorted(runs):
            if len(runs[n]) < 2:
                continue
            cols = sorted(runs[n])
            f.write('\n## %s\n\n| value | %s |\n|---|%s\n' % (n, ' | '.join(cols), '---|' * len(cols)))
            for k in CMPKEYS:
                v = ['%X' % runs[n][c][k] if k in runs[n][c] else '-' for c in cols]
                if any(x != '-' for x in v):
                    f.write('| %s | %s |\n' % (k, ' | '.join(v)))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('-d', '--dos', default='msdos622')
    ap.add_argument('-j', '--jobs', type=int, default=6)
    ap.add_argument('-k', '--keyword', action='append', default=[], help='only these lines (NAME)')
    ap.add_argument('--check', action='store_true')
    ap.add_argument('--update', action='store_true')
    ap.add_argument('-m', '--manager', default='max', choices=['max'] + sorted(MANAGERS))
    a = ap.parse_args()
    subprocess.run(['make', '-s', '-C', TESTS], check=True)
    if a.manager == 'max':
        lines = [Line(l.strip()) for l in open(os.path.join(TESTS, 'KEYWORDS.LST'))
                 if l.strip() and not l.startswith('#')]
    else:
        lines = [Line(l.strip(), a.manager) for l in open(os.path.join(TESTS, 'KWMGR.LST'))
                 if l.strip() and not l.startswith('#') and l.split()[0] == a.manager]
    if a.keyword:
        want = set(k.upper() for k in a.keyword)
        lines = [l for l in lines if l.name.upper() in want]
    tag = os.path.basename(a.dos).replace('.img', '')
    if a.manager != 'max':
        tag = a.manager + '-' + tag
    top = os.path.join(BUILD, 'kwtest', tag)
    os.makedirs(top, exist_ok=True)
    res = {}

    def one(l):
        st, bad = check(l, boot(l, a.dos, os.path.join(top, l.name), a.manager))
        print('%-16s %-7s %s' % (l.name, st, ' '.join(bad)), flush=True)
        return l.name, st, bad

    with concurrent.futures.ThreadPoolExecutor(a.jobs) as ex:
        for name, st, bad in ex.map(one, lines):
            res[name] = (st, bad)
    with open(os.path.join(top, 'result.txt'), 'w') as f:
        for n in sorted(res):
            f.write('%-16s %s %s\n' % (n, res[n][0], ' '.join(res[n][1])))
    compare()
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
