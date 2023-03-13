# Copyright 2021 ETH Zurich and University of Bologna.
# Copyright and related rights are licensed under the Solderpad Hardware
# License, Version 0.51 (the "License"); you may not use this file except in
# compliance with the License.  You may obtain a copy of the License at
# http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
# or agreed to in writing, software, hardware and materials distributed under
# this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
# CONDITIONS OF ANY KIND, either express or implied. See the License for the
# specific language governing permissions and limitations under the License.

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


