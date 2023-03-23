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

# Description: Makefile to build the blinky and other demo applications. Note
# that it supports the usual GNU Make implicit variables e.g. CC, CFLAGS,
# CPPFLAGS etc. Consult the GNU Make manual for move information about these.

# Notes:
# Useful targets
# make all      Compile and link
# make run      Simulate SoC
# make backup   Record your simulation run
# make analyze  Run analysis scripts on the simulation result

# Important Variables
# PROG       Needs to be set to your executables name
# USER_SRCS  Add your source files here (use +=)
# CPPFLAGS   Add your include search paths and macro definitions (use +=)

# For compile options check the README.md

# good defaults for many environment variables
include $(FREERTOS_PROJ_ROOT)/default_flags.mk

# manually set CFLAGS to disable some warnings (-Wconversion)
CFLAGS = \
	-march=rv32imac -mabi=ilp32 -msmall-data-limit=8 -mno-save-restore \
	-fsigned-char -ffunction-sections -fdata-sections \
	-std=gnu11 \
	-Wall -Wextra -Wshadow -Wformat=2 -Wundef \
	-Wno-unused-parameter -Wno-unused-variable \
	-Og -g3 \
	-DFEATURE_CLUSTER=0 -D__PULP__=1 -DDEBUG \
        -Wstack-usage=1024

CONFIG_CLUSTER=n
# rtos, pulp and pmsis sources
include $(FREERTOS_PROJ_ROOT)/default_srcs.mk

# application name
PROG = freertos_uart

# application/user specific code
USER_SRCS = freertos_uart.c

# FreeRTOS.h
CPPFLAGS += $(addprefix -I$(USER_DIR)/, ".")

CPPFLAGS += -DportasmHANDLE_INTERRUPT=vSystemIrqHandler
CPPFLAGS += -DUSE_STDIO
## number of error check polls before the tests is conclueded as being successful
CPPFLAGS += -DSTREAM_CHECK_ITERATIONS=2

# Uncomment to disable Additional reigsters (HW Loops)
#CPPFLAGS += -DportasmSKIP_ADDITIONAL_REGISTERS

# compile, simulation and analysis targets
include $(FREERTOS_PROJ_ROOT)/default_targets.mk
