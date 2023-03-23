PULP_APP = test
PULP_APP_SRCS = core_list_join.c core_main.c core_matrix.c core_state.c core_util.c pulp/core_portme.c pulp/bench_link.c

PULP_CFLAGS += -Ipulp -I. -O3 -DFLAGS_STR -DITERATIONS=25 -falign-functions=16 -funroll-all-loops

include $(PULP_SDK_HOME)/install/rules/pulp.mk
