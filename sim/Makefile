# Copyright 2021 ETH Zurich and University of Bologna.
# Copyright and related rights are licensed under the Solderpad Hardware
# License, Version 0.51 (the "License"); you may not use this file except in
# compliance with the License.  You may obtain a copy of the License at
# http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
# or agreed to in writing, software, hardware and materials distributed under
# this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
# CONDITIONS OF ANY KIND, either express or implied. See the License for the
# specific language governing permissions and limitations under the License.


VSIM            ?= vsim
VSIM_SUPPRESS   = -suppress vsim-3009 -suppress vsim-8683 -suppress vsim-8386

VLOG            ?= vlog
VLOG_FLAGS      =

VOPT            ?= vopt
VOPT_FLAGS      ?= +acc

VLIB            ?= vlib
VMAP            ?= vmap

SIM_TOP = safety_island_top

## Compile RTL with Questasim
all: build opt

.PHONY: opt
opt:
	$(VOPT) $(VOPT_FLAGS) -o vopt_tb $(SIM_TOP) -work work

.PHONY: build
build:
	$(VSIM) -c -do 'source compile.tcl; quit'

.PHONY: clean
## Remove all compiled RTL
clean:
	$(RM) -r work 
	$(RM) modelsim.ini
	$(RM) transcript
	$(RM) vsim.wlf

## vsim targets
.PHONY: sim
## Simulate RTL with Questasim (GUI)
sim:
	$(VSIM) -64 -gui vopt_tb \
	-suppress vsim-3009 -suppress vsim-8683 -suppress vsim-8386 \
	+UVM_NO_RELNOTES -stats -t ps \
	-do "set StdArithNoWarnings 1;set NumericStdNoWarnings 1"
