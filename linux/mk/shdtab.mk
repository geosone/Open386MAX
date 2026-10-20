# SHDTAB.INC and SHDTAB.H, the host bridge tables of 386MAX/SHADOWRAM.TXT
# (linux/tools/shdtab.py), for the objects in SHDTAB_USERS; included
# after dos.mk.
$(OUT)/SHDTAB.INC: $(ROOT)/386MAX/SHADOWRAM.TXT $(LX)/tools/shdtab.py | $(OUT)
	$(PYTHON) $(LX)/tools/shdtab.py $< $@ $(OUT)/SHDTAB.H
$(OUT)/SHDTAB.H: $(OUT)/SHDTAB.INC
$(addprefix $(OUT)/,$(SHDTAB_USERS)): $(OUT)/SHDTAB.INC $(OUT)/SHDTAB.H
