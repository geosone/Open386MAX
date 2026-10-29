# Open 386MAX
# Copyright: Open 386MAX contributors 2026.
# GNU General Public License version 3; see LICENSE.
# SPDX-License-Identifier: GPL-3.0-only
#
# MAXPROBE:  the graphics card probe tools (flat .COM files, jwasm -bin)
# -> build/MAXPROBE.  The bootable images:  linux/mkprobe.sh.
ROOT := $(abspath ..)
OUT  := $(ROOT)/build/MAXPROBE
PROGS := PCILIST.COM VBELIST.COM REGDUMP.COM VGATEST.COM

all: $(addprefix $(OUT)/,$(PROGS))

$(OUT)/%.COM: %.ASM
	mkdir -p $(OUT)
	$(ROOT)/linux/bin/jwasm -q -bin -Fo=$@ $<

clean:
	rm -rf $(OUT)

.PHONY: all clean
