# Startup files of the DOS versions

SETUPDOS, MAXIMIZE, STRIPMGR and ASQ edit or show the CONFIG.SYS and the
startup batch file the running DOS really reads, not always
C:\CONFIG.SYS and C:\AUTOEXEC.BAT.  Both come from QUILIB/MBPARSE.C:

- `dos_cfgname()`:  the configuration file, by the running kernel
  (FreeDOS = INT 21h 3000h OEM FDh, DR DOS = INT 21h 4452h).
- `fnShell()` with `shell_kind()`:  the startup batch file from the
  SHELL= line, by the kind of COMMAND.COM it names (found by its
  contents:  "FreeCOM", "Caldera"/"DR-DOS"/"Novell", UPX packed =
  SvarCOM on the EDR-DOS kernel, FreeCOM on the FreeDOS kernel, else
  MS-DOS/PC DOS).  4DOS/NDOS:  4DOS.INI AutoExecPath, /K.

| DOS | configuration file | startup batch file |
|---|---|---|
| MS-DOS, PC DOS | CONFIG.SYS | AUTOEXEC.BAT; `/K file` runs file instead |
| FreeDOS (kernel, FreeCOM) | FDCONFIG.SYS before CONFIG.SYS (CONFIG= of the kernel command line first) | `/P=file` or `/P:file` (FDAUTO.BAT); `/K file` runs after AUTOEXEC.BAT |
| DR DOS, EDR-DOS | DCONFIG.SYS before CONFIG.SYS (CHAIN= continues in another file) | `/P:file`, at most 12 characters (AUTODOS7.BAT); `/P=file` is ignored |
| SvarDOS (EDR-DOS kernel, SvarCOM) | DCONFIG.SYS before CONFIG.SYS | always AUTOEXEC.BAT (`/P=`, `/P:`, `/K` ignored) |

Sources:  the FreeDOS kernel (kernel/config.c) and EDR-DOS
(drbio/genercfg.asm, command/com.c); FreeCOM and SvarCOM tried in QEMU
(build/dosdisk images of linux/test/mkdosdisk.sh).  Not handled:  CONFIG=
on the FreeDOS kernel command line, CHAIN=.

Test:  linux/test/maxnames.sh, unattended SETUPDOS and MAXIMIZE with
FDCONFIG.SYS + FDAUTO.BAT (FreeDOS), DCONFIG.SYS + AUTODOS7.BAT
(EDR-DOS), DCONFIG.SYS + AUTOEXEC.BAT (SvarDOS, also with a /P= SvarCOM
ignores) and /K MSAUTO.BAT (MS-DOS 6.22), each with a CONFIG.SYS and
AUTOEXEC.BAT beside them that must stay unchanged.
