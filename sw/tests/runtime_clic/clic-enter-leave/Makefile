PULP_APP = clic-enter-leave
PULP_APP_FC_SRCS = clic-enter-leave.c
PULP_APP_HOST_SRCS = clic-enter-leave.c
PULP_APP_ASM_SRCS = handler.S
PULP_CFLAGS = -Os -g3 -Wall -Wextra -I../../runtime_shared/include \
	-Wno-unused-parameter -Wno-unused-function -Wno-unused-variable \
	-Wnull-dereference -Wformat=2

VERBOSE=1
include $(PULP_SDK_HOME)/install/rules/pulp_rt.mk


.PHONY: pulptrace
pulptrace: traced.log

traced.log: build/trace_core_000003e0.log build/clic-enter-leave/clic-enter-leave
	pulptrace2 build/trace_core_000003e0.log build/clic-enter-leave/clic-enter-leave > $@
