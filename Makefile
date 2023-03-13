# Copyright 2023 ETH Zurich and University of Bologna
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

VLOG_ARGS += -suppress 2583 -suppress 13314 \"+incdir+\$$ROOT/rtl/includes\"

BENDER_SIM_BUILD_DIR = sim

.PHONY: checkout
## Checkout/update dependencies using Bender
checkout:
	bender checkout
	touch Bender.lock
	$(MAKE) scripts

Bender.lock:
	bender checkout
	touch Bender.lock

.PHONY: scripts
## Generate scripts for all tools
scripts: scripts-bender-vsim 

scripts-bender-vsim: | Bender.lock
	echo 'set ROOT [file normalize [file dirname [info script]]/..]' > $(BENDER_SIM_BUILD_DIR)/compile.tcl
	bender script vsim -t test -t rtl \
		--vlog-arg="$(VLOG_ARGS)" --vcom-arg="" \
		| grep -v "set ROOT" >> $(BENDER_SIM_BUILD_DIR)/compile.tcl


.PHONY: build
## Build the RTL model for vsim
build: $(BENDER_SIM_BUILD_DIR)/compile.tcl
	@test -f Bender.lock || { echo "ERROR: Bender.lock file does not exist. Did you run make checkout in bender mode?"; exit 1; }
	@test -f $(BENDER_SIM_BUILD_DIR)/compile.tcl || { echo "ERROR: sim/compile.tcl file does not exist. Did you run make scripts in bender mode?"; exit 1; }
	cd sim && $(MAKE) all

.PHONY: clean
## Remove the RTL model files
clean:
	$(MAKE) -C sim clean


REG_PATH = $(shell bender path register_interface)
REG_TOOL = $(REG_PATH)/vendor/lowrisc_opentitan/util/regtool.py

HJSON = rtl/soc_ctrl/safety_soc_ctrl_regs.hjson
TARGET_DIR = rtl/soc_ctrl
REG_HTML_STRING = "<!DOCTYPE html>\n<html>\n<head>\n<link rel="stylesheet" href="reg_html.css">\n</head>\n"

gen_soc_ctrl_regs:
	python $(REG_TOOL) $(HJSON) -t $(TARGET_DIR) -r
	printf $(REG_HTML_STRING) > $(TARGET_DIR)/safety_soc_ctrl.html
	python $(REG_TOOL) $(HJSON) -d >> $(TARGET_DIR)/safety_soc_ctrl.html
	printf "</html>\n" >> $(TARGET_DIR)/safety_soc_ctrl.html
	python $(REG_TOOL) $(HJSON) -D > $(TARGET_DIR)/safety_soc_ctrl.h
	cp $(REG_PATH)/vendor/lowrisc_opentitan/util/reggen/reg_html.css $(TARGET_DIR)


