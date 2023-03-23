# Copyright 2020 ETH Zurich
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0
# Author: Robert Balas (balasr@iis.ee.ethz.ch)

# -flto, normal			text 4378 rodata 394	4772
# withouth no-jump-tables	text 4144 rodata 562	4706
# with save-restore			text 4156 rodata 546	4702

PYTHON  = python3.6
CTAGS   = ctags

RISCV		?= /usr/pack/riscv-1.0-kgf/pulp-gcc-1.0.16
RISCV_PREFIX	?= $(RISCV)/bin/riscv32-unknown-elf-
CC		= $(RISCV_PREFIX)gcc
OBJCOPY		= $(RISCV_PREFIX)objcopy
OBJDUMP		= $(RISCV_PREFIX)objdump
SIZE		= $(RISCV_PREFIX)size

ARCH = -march=rv32imc -mabi=ilp32

#CFLAGS   = $(ARCH) -Os -g -fno-jump-tables -UARCHI_CORE_HAS_PULPV2 -DRV_ISA_RV32
CFLAGS   = $(ARCH) -Os -g3 -UARCHI_CORE_HAS_PULPV2 -DRV_ISA_RV32
CFLAGS	+= -Wall -Wextra -Wno-unused-parameter -Wno-clobbered
CFLAGS  += -ffunction-sections -fdata-sections -ffreestanding
CFLAGS  += -mno-save-restore

CPPFLAGS  += -DEXIT_REG_ADDR=0x1a1040a0 -DPULP_CHIP_STR=safety-island

CPPFLAGS += -I$(CURDIR) -I$(CURDIR)/include

# CPPFLAGS += -I$(CURDIR) -I$(CURDIR)/include -I$(CURDIR)/include/hal \
#	-I$(CURDIR)/include/archi -I$(CURDIR)/zforth \
#	-I$(CURDIR)/zforth-riscv -I$(CURDIR)/padframe/include

ASFLAGS  = $(CFLAGS) -DLANGUAGE_ASSEMBLY

LDFLAGS  = -Tlink.ld -nostdlib -Wl,--gc-sections -Wl,-Map,boot_code.map $(ARCH)
LDFLAGS  += -Wl,--print-gc-sections
LDLIBS = -lgcc

CFLAGS  += -flto
LDFLAGS += -flto

BOOTCODE = boot_code

OBJS =  boot_code.o crt0.o

all: $(BOOTCODE) boot.rtl boot.gvsoc

# # ASIC bootrom 100 MHz periph freq
# $(BOOTCODE):      CPPFLAGS += -DPERIPH_FREQUENCY=18000000
$(BOOTCODE):      $(OBJS)

# Makefile implicit rules for .o
# %.o: %.c
# COMPILE.c = $(CC) $(CFLAGS) $(CPPFLAGS) $(TARGET_ARCH) -c
# OUTPUT_OPTION = -o $@
# $(COMPILE.c) $(OUTPUT_OPTION) $<

# %.o: %.S
# COMPILE.S = $(CC) $(ASFLAGS) $(CPPFLAGS) $(TARGET_MACH) -c
# $(COMPILE.S) -o $@ $<

# %: %.o
# LINK.o = $(CC) $(LDFLAGS) $(TARGET_ARCH)
# $(LINK.o) $^ $(LOADLIBES) $(LDLIBS) -o $@

# Makefile custom rules for .o.2 (fpga)
%.o.2: %.c
	$(CC) $(CFLAGS) $(CPPFLAGS) $(TARGET_ARCH) -c -o $@ $<

%.o.2: %.S
	$(CC) $(ASFLAGS) $(CPPFLAGS) $(TARGET_MACH) -c -o $@ $<

boot.gvsoc: rom.bin

# gvsoc bootrom
rom.bin: $(BOOTCODE)
	./stim_utils.py  \
		--binary=$(BOOTCODE) \
		--stim-bin=rom.bin \
		--area=0x00201000:0x00202000

# The rtl bootrom is just a verilog dump of the elf file
boot.rtl: boot_code_asic.cde

boot_code_asic.objdump: $(BOOTCODE)
	$(OBJDUMP) -Sr boot_code > $@

boot_code_asic.cde: $(BOOTCODE) boot_code_asic.objdump
	$(OBJCOPY) --srec-len 1 --output-target=srec $(BOOTCODE) $(BOOTCODE).s19
	./s19toboot.py $(BOOTCODE).s19 boot_code_asic.cde pulpissimo
	$(SIZE) -A $(BOOTCODE)

safety_island_bootrom.sv: boot_code_asic.cde
	$(PYTHON) gen_rom.py boot_code_asic.cde $@ --title "ASIC Bootrom for Safety Island"


.PHONY: clean
clean:
	$(RM) $(BOOTCODE) $(OBJS) $(addsuffix .2,$(OBJS)) \
		boot_code.cde boot_code.sv boot_code.s19 rom.bin \
		boot_code_asic.cde \
		boot_code.map safety_island_bootrom.sv \
		boot_code_asic.objdump

.PHONY: TAGS
TAGS:
	$(CTAGS) -R -e .
