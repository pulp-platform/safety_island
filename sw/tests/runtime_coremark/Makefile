PULP_APP = runtime_coremark
PULP_APP_SRCS = core_list_join.c core_main.c core_matrix.c core_state.c core_util.c pulp/core_portme.c pulp/bench_link.c

PULP_CFLAGS += -Ipulp -I. -O3 -DFLAGS_STR -falign-functions=16 -funroll-all-loops

# As this test is currently only used in the CI and performance is not evaluated, we only run 2 iterations and hack the timing to avoid errors
PULP_CFLAGS += -DITERATIONS=2 

include $(PULP_SDK_HOME)/install/rules/pulp.mk
