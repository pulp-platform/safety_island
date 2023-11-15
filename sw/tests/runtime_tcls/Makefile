PULP_APP = runtime_tcls
PULP_APP_FC_SRCS = runtime_tcls.c
PULP_APP_HOST_SRCS = runtime_tcls.c
PULP_APP_ASM_SRCS = handler.S
PULP_CFLAGS = -O3 -g -I. -I../runtime_shared/include

export INJECT_FAULT=$(CURDIR)/fault_injection.tcl

include $(PULP_SDK_HOME)/install/rules/pulp_rt.mk
