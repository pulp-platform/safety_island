/*
 * Copyright 2021 ETH Zurich
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include "pulp.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include "car_memory_map.h"
#include "io.h"

#define N_SAMPLES 64
#define DEFAULT_SEED 0xdeadbeef
#define FEEDBACK 0x7f000032

uint32_t *lfsr_byte_feedback;

/* probe address range "samples" time, evenly spaced */
int probe_range_direct(volatile uintptr_t from, volatile uintptr_t to, int samples) {
    // check whether arguments passed make sense
    if ((samples < 0) && (to < from))
        return 2;

    uintptr_t addr = from;
    uintptr_t incr = ((to - from) / samples);

    for (int i = 0; i < samples; i++) {
        // write
        uint32_t expected = 0xcafedead + 0xab + i;
        writed(expected, addr);
        // read
        if (expected != readd(addr))
            return 1;
        // increment
        addr += incr;
    }
    return 0;
}

uint32_t lfsr_iter_bit(uint32_t lfsr) { return (lfsr & 1) ? ((lfsr >> 1) ^ FEEDBACK) : (lfsr >> 1); }

uint32_t lfsr_iter_byte(uint32_t lfsr, uint32_t *lfsr_byte_feedback) {
    uint32_t l = lfsr;
    for (int i = 0; i < 8; i++)
        l = lfsr_iter_bit(l);
    return l;
}

uint32_t lfsr_iter_word(uint32_t lfsr, uint32_t *lfsr_byte_feedback) {
    uint32_t l = lfsr_iter_byte(lfsr, lfsr_byte_feedback);
    l = lfsr_iter_byte(l, lfsr_byte_feedback);
    l = lfsr_iter_byte(l, lfsr_byte_feedback);
    return lfsr_iter_byte(l, lfsr_byte_feedback);
}

int probe_range_lfsr_wrwr(volatile uintptr_t from, volatile uintptr_t to, int samples) {
    // check whether arguments passed make sense
    if ((samples < 0) && (to < from))
        return 2;

    uintptr_t addr = from;
    uintptr_t incr = ((to - from) / samples);

    uint32_t lfsr = DEFAULT_SEED;
    for (int i = 0; i < samples; i++) {
        // write
        lfsr = lfsr_iter_word(lfsr, lfsr_byte_feedback);
        writew(lfsr, addr);
        fence();
        // read
        if (lfsr != readw(addr))
            return 1;
        // increment
        addr += incr;
    }
    return 0;
}

int probe_range_lfsr_wwrr(volatile uintptr_t from, volatile uintptr_t to, int samples) {
    // check whether arguments passed make sense
    if ((samples < 0) && (to < from))
        return 2;

    uintptr_t addr = from;
    uintptr_t incr = ((to - from) / samples);

    // write
    uint32_t lfsr = DEFAULT_SEED;
    for (int i = 0; i < samples; i++) {
        lfsr = lfsr_iter_word(lfsr, lfsr_byte_feedback);
        // write
        writew(lfsr, addr);
        // increment
        addr += incr;
    }

    fence();

    // read
    addr = from;
    lfsr = DEFAULT_SEED;
    for (int i = 0; i < samples; i++) {
        lfsr = lfsr_iter_word(lfsr, lfsr_byte_feedback);
        // read
        if (lfsr != readw(addr))
            return 1;
        // increment
        addr += incr;
    }

    return 0;
}

int main(void)
{

    int errors = 0;

    // Probe an address range with pseudo-random values and read after each write
    // (wrwr)

    // L2 shared memory
    errors += probe_range_lfsr_wrwr((uint32_t *)CAR_L2_SPM_PORT1_INTERLEAVED_BASE_ADDR,
                                    (uint32_t *)CAR_L2_SPM_PORT1_INTERLEAVED_END_ADDR,
                                    N_SAMPLES);
    if (errors) {
        char str[] = "1\n";
        printf(str, sizeof(str));
    }

    errors += probe_range_lfsr_wrwr((uint32_t *)CAR_L2_SPM_PORT1_CONTIGUOUS_BASE_ADDR,
                                    (uint32_t *)CAR_L2_SPM_PORT1_CONTIGUOUS_END_ADDR,
                                    N_SAMPLES);
    if (errors) {
        char str[] = "2\n";
        printf(str, sizeof(str));
    }

    // Integer Cluster
    errors += probe_range_lfsr_wrwr((uint32_t *)CAR_INT_CLUSTER_SPM_BASE_ADDR,
                                    (uint32_t *)CAR_INT_CLUSTER_SPM_END_ADDR,
                                    N_SAMPLES);
    if (errors) {
        char str[] = "4\n";
        printf(str, sizeof(str));
    }
    // HyperRAM
    errors += probe_range_lfsr_wrwr((uint32_t *)CAR_HYPERRAM_BASE_ADDR,
                                    (uint32_t *)CAR_HYPERRAM_END_ADDR,
                                    N_SAMPLES);
    if (errors) {
        char str[] = "5\n";
        printf(str, sizeof(str));
    }
    // FP Cluster
    errors += probe_range_lfsr_wrwr((uint32_t *)CAR_FP_CLUSTER_SPM_BASE_ADDR,
                                    (uint32_t *)CAR_FP_CLUSTER_SPM_END_ADDR,
                                    N_SAMPLES);
    if (errors) {
        char str[] = "6\n";
        printf(str, sizeof(str));
    }
    // TODO Mailboxes

    // Probe an address space with pseudo-random values and read all after
    // writing (wwrr)

    // L2 shared memory
    errors += probe_range_lfsr_wwrr((uint32_t *)CAR_L2_SPM_PORT1_INTERLEAVED_BASE_ADDR,
                                    (uint32_t *)CAR_L2_SPM_PORT1_INTERLEAVED_END_ADDR,
                                    N_SAMPLES);
    if (errors) {
        char str[] = "7\n";
        printf(str, sizeof(str));
    }
    errors += probe_range_lfsr_wwrr((uint32_t *)CAR_L2_SPM_PORT1_CONTIGUOUS_BASE_ADDR,
                                    (uint32_t *)CAR_L2_SPM_PORT1_CONTIGUOUS_END_ADDR,
                                    N_SAMPLES);
    if (errors) {
        char str[] = "8\n";
        printf(str, sizeof(str));
    }

    // Integer Cluster
    errors += probe_range_lfsr_wwrr((uint32_t *)CAR_INT_CLUSTER_SPM_BASE_ADDR,
                                    (uint32_t *)CAR_INT_CLUSTER_SPM_END_ADDR,
                                    N_SAMPLES);
    if (errors) {
        char str[] = "a\n";
        printf(str, sizeof(str));
    }
    // HyperRAM
    errors += probe_range_lfsr_wwrr((uint32_t *)CAR_HYPERRAM_BASE_ADDR,
                                    (uint32_t *)CAR_HYPERRAM_END_ADDR,
                                    N_SAMPLES);
    if (errors) {
        char str[] = "b\n";
        printf(str, sizeof(str));
    }
    // FP Cluster
    errors += probe_range_lfsr_wrwr((uint32_t *)CAR_FP_CLUSTER_SPM_BASE_ADDR,
                                    (uint32_t *)CAR_FP_CLUSTER_SPM_END_ADDR,
                                    N_SAMPLES);
    if (errors) {
        char str[] = "c\n";
        printf(str, sizeof(str));
    }
    // TODO Mailboxes

    return errors;

}
