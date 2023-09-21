PULP_APP = runtime_ecc
PULP_APP_FC_SRCS = runtime_ecc.c
PULP_APP_HOST_SRCS = runtime_ecc.c
PULP_CFLAGS = -O3 -g -I.

export INJECT_FAULT=$(CURDIR)/fault_injection.tcl

include $(PULP_SDK_HOME)/install/rules/pulp_rt.mk
