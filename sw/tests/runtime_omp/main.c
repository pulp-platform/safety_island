#include "pulp.h"

////////////////////////////
// from offload-manager.c //
////////////////////////////

#define DEBUG_LEVEL_OFFLOAD_MANAGER 10

/*
 * Copyright (C) 2018 ETH Zurich and University of Bologna
 *
 * Authors:
 *    Alessandro Capotondi, UNIBO, (alessandro.capotondi@unibo.it)
 */

/* Copyright (C) 2005-2014 Free Software Foundation, Inc.
 *
 * This file is part of the GNU OpenMP Library (libgomp).
 *
 * Libgomp is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3, or (at your option)
 * any later version.
 *
 * Libgomp is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 *
 * Under Section 7 of GPL version 3, you are granted additional
 * permissions described in the GCC Runtime Library Exception, version
 * 3.1, as published by the Free Software Foundation.
 *
 * You should have received a copy of the GNU General Public License and
 * a copy of the GCC Runtime Library Exception along with this program;
 * see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see
 * <http://www.gnu.org/licenses/>.
 */

#include "sw_mailbox.h"

#include "archi/pulp.h"
#include "hal/pulp.h"

#include <stdio.h>
#include <stdint.h>

// #include "hero/offload-manager.h"

// FIXME consider to move these variables to L1 (vars it is ususally Empty when
// OpenMP4 Offload is used)
void **offload_func_table;
uint32_t nb_offload_funcs;
void **offload_var_table;
uint32_t nb_offload_vars;

int gomp_offload_manager() {
    // Init the manager (handshake btw host and accelerator is here)
    // gomp_init_offload_manager();

    // FIXME For the momenent we are not using the cmd sended as trigger.
    // It should be used to perform the deactivation of the accelerator,
    // as well as other operations, like local data allocation or movement.
    // FIXME Note that the offload at the moment use several time the mailbox.
    // We should compact the offload descriptor and just sent a pointer to
    // that descriptor.
    uint32_t cmd = (uint32_t)NULL;

    // Offloaded function pointer and arguments
    void (*offloadFn)(uint64_t) = NULL;
    uint64_t offloadArgs = 0x0;
    int nbOffloadRabMissHandlers = 0x0;

    int cycles = 0;

    g_a2h_mbox = *((struct ring_buf **)0x3000004);
    g_h2a_mbox = *((struct ring_buf **)0x3000000);

    // Print the addresses of the mboxes for debug purpose
    // Note this printf is uper minimal, we need to wait to avoid
    // loosing chars when the UART is busy
    csleep(1024 * 1024 * 100);
    printf("[device g_a2h_mbox]\n\r");
    csleep(1024 * 1024 * 10);
    printf("%x\n\r", g_a2h_mbox);
    csleep(1024 * 1024 * 10);
    printf("%x\n\r", g_h2a_mbox);
    csleep(1024 * 1024 * 10);
    printf("done\n\r");

    while (1) {
        if (DEBUG_LEVEL_OFFLOAD_MANAGER > 0)
            printf("Waiting for command...\n\r");

        // (1) Wait for the offload trigger.
        mailbox_read((uint32_t *)&cmd, 1);

        if (MBOX_DEVICE_STOP == cmd) {
            if (DEBUG_LEVEL_OFFLOAD_MANAGER > 0)
                printf("Got PULP_STOP from host, stopping execution now.\n");
            break;
        }

        // (2) The host sends through the mailbox the pointer to the function
        // that should be
        // executed on the accelerator.
        mailbox_read((uint32_t *)&offloadFn, 1);

        if (DEBUG_LEVEL_OFFLOAD_MANAGER > 0)
            printf("tgt_fn @ 0x%x\n", (uint32_t)offloadFn);

        // (3) The host sends through the mailbox the pointer to the arguments
        // that should
        // be used.
        mailbox_read((uint32_t *)&offloadArgs, 1);

        if (DEBUG_LEVEL_OFFLOAD_MANAGER > 0)
            printf("tgt_vars @ 0x%x\n", (uint32_t)offloadArgs);

        // (3b) The host sends through the mailbox the number of rab misses
        // handlers threads
        mailbox_read((uint32_t *)&nbOffloadRabMissHandlers, 1);

        if (DEBUG_LEVEL_OFFLOAD_MANAGER > 0)
            printf("nbOffloadRabMissHandlers %d\n", nbOffloadRabMissHandlers);

        // (3c) Spawning nbOffloadRabMissHandlers
        // Not implemented

        // (4) Ensure access to offloadArgs. It might be in SVM.
        // Not implemented

        // (5) Execute the offloaded function.
        if (DEBUG_LEVEL_OFFLOAD_MANAGER > 0)
            printf("begin offloading\n");
        reset_timer();
        start_timer();
        offloadFn(offloadArgs);
        stop_timer();
        if (DEBUG_LEVEL_OFFLOAD_MANAGER > 0)
            printf("end offloading\n");
        cycles = get_time();

        mailbox_write(MBOX_DEVICE_DONE);
        mailbox_write(cycles);

        if (DEBUG_LEVEL_OFFLOAD_MANAGER > 0)
            printf("Kernel execution time [PULP cycles] = %d\n", cycles);

        if (nbOffloadRabMissHandlers) {
        }
    }

    return 0;
}

////////////////////////////

int done = 0;
int iters = 0;

__attribute__((weak)) int main(int argc, char **argv, char **envp) {
    // FIXME: handle multi-cluster properly
    gomp_offload_manager();
    return 0;
}
