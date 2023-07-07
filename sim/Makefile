# Copyright 2023 ETH Zurich and University of Bologna
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51

SAFED_SIM_DIR ?= .

SIM_TOP ?= tb_safety_island_jtag

include safed_sim.mk

## Compile RTL with Questasim
all: safed_sim_all

opt: safed_sim_opt

build: safed_sim_build

## Remove all compiled RTL
clean: safed_sim_clean

## vsim targets
.PHONY: sim
## Simulate RTL with Questasim (GUI)
sim:
	$(VSIM) -64 -gui vopt_tb \
	-suppress vsim-3009 -suppress vsim-8683 -suppress vsim-8386 \
	+UVM_NO_RELNOTES -stats -t ps \
	-do "set StdArithNoWarnings 1;set NumericStdNoWarnings 1"
