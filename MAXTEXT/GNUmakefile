# Open 386MAX
# Copyright: Open 386MAX contributors 2026.
# GNU General Public License version 3; see LICENSE.
# SPDX-License-Identifier: GPL-3.0-only
#
# MAXTEXT uses the same assembler/linker rules as the other DOS components.
PROJ := MAXTEXT
ROOT := $(abspath ..)
SRCDIRS := .
ASMINC := . ../INC
PROGS := MAXTEXT.SYS MAXTEXT.COM
MAXTEXT.SYS_OBJS := MAXTEXT.OBJ
MAXTEXT.SYS_BIN := 1
MAXTEXT.COM_OBJS := MTEXTCOM.OBJ
include $(ROOT)/linux/mk/dos.mk
