# Copyright 2023 ETH Zurich and University of Bologna
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

ifneq (,$(wildcard /etc/iis.version))
	QUESTA          ?= questa-2022.3
	VSIM            ?= $(QUESTA) vsim
	VLOG            ?= $(QUESTA) vlog
	VOPT            ?= $(QUESTA) vopt
	VLIB            ?= $(QUESTA) vlib
	VMAP            ?= $(QUESTA) vmap
else
	VSIM            ?= vsim
	VLOG            ?= vlog
	VOPT            ?= vopt
	VLIB            ?= vlib
	VMAP            ?= vmap
endif

VSIM_SUPPRESS   += -suppress vsim-3009 -suppress vsim-8683 -suppress vsim-8386
VLOG_FLAGS      +=
VOPT_FLAGS      += +acc

.PHONY: safed_sim_all
safed_sim_all: safed_sim_build safed_sim_opt

.PHONY: safed_sim_build
safed_sim_build:
	cd $(SAFED_SIM_DIR) && $(VSIM) -c -do 'source compile.tcl; quit'

.PHONY: safed_sim_opt
safed_sim_opt:
	cd $(SAFED_SIM_DIR) && $(VOPT) $(VOPT_FLAGS) -o vopt_tb $(SIM_TOP) -work work

.PHONY: safed_sim_clean
safed_sim_clean:
	$(RM) -r $(SAFED_SIM_DIR)/work 
	$(RM) $(SAFED_SIM_DIR)/modelsim.ini
	$(RM) $(SAFED_SIM_DIR)/transcript
	$(RM) $(SAFED_SIM_DIR)/vsim.wlf

