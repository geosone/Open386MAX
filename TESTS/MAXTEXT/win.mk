# Copyright (C) 2026 Open386MAX contributors. SPDX-License-Identifier: GPL-3.0-only
PROJ := TESTS/MAXTEXT/WIN
ROOT := $(abspath ../..)
CMODEL := s
PROGS := MTWIN.EXE
MTWIN.EXE_OBJS := MTWIN.OBJ
MTWIN.EXE_DEF := MTWIN.DEF
include $(ROOT)/linux/mk/win.mk
