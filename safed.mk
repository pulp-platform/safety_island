# Copyright 2023 ETH Zurich and University of Bologna
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

BENDER  ?= bender
PYTHON3 ?= python3
REGGEN  ?= $(PYTHON3) $(shell $(BENDER) path register_interface)/vendor/lowrisc_opentitan/util/regtool.py

VLOG_ARGS += -suppress 2583 -suppress 13314 -svinputport=compat

SAFED_ROOT    ?= $(shell $(BENDER) path safety_island)
SAFED_SW_DIR  ?= $(SAFED_ROOT)/sw
SAFED_HW_DIR  ?= $(SAFED_ROOT)/rtl
SAFED_SIM_DIR ?= $(SAFED_ROOT)/sim

################
# Dependencies #
################

# Ensure Bender dependencies are checked out
$(SAFED_ROOT)/.deps:
	$(BENDER) checkout
	@touch $@

# Make sure dependencies are more up-to-date than any targets run
include $(SAFED_ROOT)/.deps

######################
# Nonfree components #
######################

NONFREE_REMOTE ?= git@iis-git.ee.ethz.ch:carfield/safety-island-nonfree.git
NONFREE_COMMIT ?= 4ef4950629df2f683b11db14884d741281f69e48

.PHONY: nonfree-init
## Initialize Safety Island CI repository
nonfree-init:
	git clone $(NONFREE_REMOTE) nonfree
	cd nonfree && git checkout $(NONFREE_COMMIT)

-include nonfree/nonfree.mk


#####################
# Generate Hardware #
#####################
REG_HTML_STRING = "<!DOCTYPE html>\n<html>\n<head>\n<link rel="stylesheet" href="reg_html.css">\n</head>\n"

$(SAFED_HW_DIR)/soc_ctrl/safety_soc_ctrl_reg_pkg.sv $(SAFED_HW_DIR)/soc_ctrl/safety_soc_ctrl_reg_top.sv: $(SAFED_HW_DIR)/soc_ctrl/safety_soc_ctrl_regs.hjson
	$(REGGEN) $< -t $(SAFED_HW_DIR)/soc_ctrl -r
	git apply $(SAFED_HW_DIR)/soc_ctrl/boot_addr.patch
	printf $(REG_HTML_STRING) > $(SAFED_HW_DIR)/soc_ctrl/safety_soc_ctrl.html
	$(REGGEN) $< -d >> $(SAFED_HW_DIR)/soc_ctrl/safety_soc_ctrl.html
	printf "</html>\n" >> $(SAFED_HW_DIR)/soc_ctrl/safety_soc_ctrl.html
	$(REGGEN) $< -D > $(SAFED_HW_DIR)/soc_ctrl/safety_soc_ctrl.h
	cp $(shell $(BENDER) path register_interface)/vendor/lowrisc_opentitan/util/reggen/reg_html.css $(SAFED_HW_DIR)/soc_ctrl

$(SAFED_HW_DIR)/safety_island_bootrom.sv:
	$(MAKE) -C boot clean safety_island_bootrom.sv
	cp boot/safety_island_bootrom.sv rtl/safety_island_bootrom.sv

$(SAFED_HW_DIR)/safety_island_bootrom_carfield.sv:
	$(MAKE) -C boot clean safety_island_bootrom.sv CARFIELD=1
	cp boot/safety_island_bootrom.sv rtl/safety_island_bootrom_carfield.sv

.PHONY: safed-hw-gen safed-bootrom-gen
## Generate Safety Island HW sources
safed-hw-gen: $(SAFED_HW_DIR)/soc_ctrl/safety_soc_ctrl_reg_pkg.sv $(SAFED_HW_DIR)/soc_ctrl/safety_soc_ctrl_reg_top.sv
## Generate Safety Island bootrom
safed-bootrom-gen: $(SAFED_HW_DIR)/safety_island_bootrom.sv $(SAFED_HW_DIR)/safety_island_bootrom_carfield.sv

###########
# Scripts #
###########

# Generate Safety Island Questa Simulation Compile script
$(SAFED_SIM_DIR)/compile.tcl: $(SAFED_ROOT)/.deps
	echo 'set ROOT [file normalize [file dirname [info script]]/..]' > $(SAFED_SIM_DIR)/compile.tcl
	bender script vsim -p safety_island -t test -t rtl -t cv32e40p_use_ff_regfile \
		--vlog-arg="$(VLOG_ARGS)" --vcom-arg="" \
		| grep -v "set ROOT" >> $(SAFED_SIM_DIR)/compile.tcl
	echo 'vlog "$$ROOT/rtl/tb/elfloader.cpp" -ccflags "-std=c++11"' >> $(SAFED_SIM_DIR)/compile.tcl

clean_$(SAFED_SIM_DIR)/compile.tcl:
	rm -rf $(SAFED_SIM_DIR)/compile.tcl

clean: clean_$(SAFED_SIM_DIR)/compile.tcl

##############
# Simulation #
##############

SIM_TOP ?= tb_safety_island_jtag
include sim/safed_sim.mk

##############
## SOFTWARE ##
##############

$(SAFED_SW_DIR)/pulp-runtime:
	git clone https://github.com/pulp-platform/pulp-runtime.git -b safety-island $@

$(SAFED_SW_DIR)/pulp-freertos:
	git clone https://github.com/pulp-platform/pulp-freertos.git $@
	cd $@; \
	git checkout carfield/safety-island; \
	git submodule update --init --recursive

$(SAFED_SW_DIR)/threadx:
	git clone git@github.com:alex96295/threadx.git -b pulp

.PHONY: safed-sw-all
## Generate Safety Island software dependencies
safed-sw-all: $(SAFED_SW_DIR)/pulp-runtime $(SAFED_SW_DIR)/pulp-freertos $(SAFED_SW_DIR)/threadx
