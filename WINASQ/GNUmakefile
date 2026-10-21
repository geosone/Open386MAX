# WINASQ.EXE, ASQ for Windows (GNU make, see linux/mk/win.mk):  shows
# the reports of an ASQ snapshot (.ASQ) with the ASQ engine for Windows
# (ASQENG/asqwin.mk, LENGINEW.LIB).
PROJ     := WINASQ
ROOT     := $(abspath ..)
CMODEL   := l
MSCOMPAT := 1
CDEFS    := DOS_VERSION OWC_MSC
SRCDIRS  := . ../QUILIB
INCDIRS  := . ../INCLUDE ../INC ../ASQENG
PROGS    := WINASQ.EXE

WINASQ.EXE_OBJS := WINASQ.OBJ WINSTUBS.OBJ WINGLOB.OBJ BCD_NUM.OBJ DATESTR.OBJ TRNBLN.OBJ POS_TEST.OBJ
WINASQ.EXE_RC   := WINASQ.RC
WINASQ.EXE_DEF  := WINASQ.DEF
WINASQ.EXE_LIBS := commdlg $(ROOT)/build/ASQENG-W/LENGINEW.LIB \
	$(ROOT)/build/QUILIB-W/LQUILIBW.LIB

include $(ROOT)/linux/mk/win.mk

all: engine
engine:
	$(MAKE) -f asqwin.mk -C ../ASQENG
$(OUT)/WINASQ.EXE: engine
.PHONY: engine
