PULP_APP = omptarget_runtime
PULP_APP_FC_SRCS = sw_mailbox.c main.c
PULP_CFLAGS = -O3 -g

include $(PULP_SDK_HOME)/install/rules/pulp_rt.mk

archive_app: $(PULP_APP_OBJS_omptarget_runtime)
	$(PULP_AR) rcs build/lib$(PULP_APP).a $(PULP_APP_OBJS_omptarget_runtime)
