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

/* quickly scan the given address range with AXI_N_SAMPLES */
#ifndef AXI_N_SAMPLES
#    define AXI_N_SAMPLES 64
#endif

/* we scan 4096 words by default */
#ifndef AXI_SCAN_BLOCKSIZE
#    define AXI_SCAN_BLOCKSIZE 0xfa0
#endif

/* we scan a finite number of blocks between *start and *end addresses to reduce execution time of the test */
#ifndef AXI_SCAN_NUM_BLOCKS
#    define AXI_SCAN_NUM_BLOCKS 10
#endif

/* We scan (read/write) AXI_SCAN_INCREMENT addresses before returning giving a
 * ok/return the result. Since the default axi address space for is rather large
 * (0x40'0000 bytes), per default we just check every 32 * AXI_SCAN_BLOCKSIZE.
 * If you want to run the full test, define AXI_FULL_SCAN. */
#ifndef AXI_SCAN_INCREMENT
#    ifdef AXI_FULL_SCAN
#        define AXI_SCAN_INCREMENT AXI_SCAN_BLOCKSIZE
#    else
#        define AXI_SCAN_INCREMENT (AXI_SCAN_BLOCKSIZE * 32)
#    endif
#endif

#define assert(expression)                                                     \
    do {                                                                       \
        if (!expression) {                                                     \
            printf("%s:%d: assert error\n", __FILE__, __LINE__);               \
            exit(1);                                                           \
        }                                                                      \
    } while (0)

void probe_first_last(volatile uint32_t *from, volatile uint32_t *to);
void probe_range(uintptr_t from, uintptr_t to, int samples);
void scan_range(uintptr_t from, uintptr_t to, uintptr_t increment,
                int blocksize);

int main(void)
{
    volatile uint32_t *ext_base_addr    = (uint32_t *)0x20000000;
    volatile uint32_t *ext_end_addr     = (uint32_t *)0x3fffffff;

    /* axi tests: check if we can access the address space of the axi plug,
     * assuming axi_example.sv is connected to it */
    puts("Testing axi connection by writing patterns to memory and "
         "reading them back\n");

    /* the first thing we do is test the very first and very last address of the
     * axi address space, they might be the most prone to failure */

    probe_first_last(ext_base_addr, ext_end_addr);

    puts("Probe nci_cp_top");
    probe_range((uintptr_t)ext_base_addr, (uintptr_t)ext_end_addr,
                AXI_N_SAMPLES);

    // /* now test the whole address range */
    // scan_range((uintptr_t)ext_base_addr, (uintptr_t)(ext_base_addr + AXI_SCAN_NUM_BLOCKS * AXI_SCAN_BLOCKSIZE),
    //            AXI_SCAN_INCREMENT, AXI_SCAN_BLOCKSIZE);

    printf("done\n");
    return 0;
}

/* check first and last address of given address range */
void probe_first_last(volatile uint32_t *from, volatile uint32_t *to)
{
    assert((uintptr_t)to > (uintptr_t)from);
    puts("checking if the first and last address work\n");
    printf("writing to start addr at %p\n", from);
    *from = 0xcafedead;
    printf("writing to end addr at %p\n", to - 1);
    *(to - 1) = 0xcafedead;
    printf("reading back ... ");
    assert(*from == 0xcafedead);
    assert(*(to - 1) == 0xcafedead);
    puts("ok\n");
}

/* probe address range "samples" time, evenly spaced */
void probe_range(uintptr_t from, uintptr_t to, int samples)
{
    assert(samples > 0);
    assert(to > from);
    puts("probing the address space at evently spaced samples ... ");
    uintptr_t addr = from;
    uintptr_t incr = ((to - from) / samples);

    for (int i = 0; i < samples; i++) {

        printf("writing at %p\n", addr);
        uint32_t expected          = 0xcafedead + 0xab + i;
        *(volatile uint32_t *)addr = expected;

        printf("reading at %p\n", addr);
        uint32_t axi_read = *(volatile uint32_t *)addr;

        assert(expected == axi_read);
        addr += incr;
    }

    puts("ok\n");
}

/* scan the whole address range, evently spaced with the given blocksize */
void scan_range(uintptr_t from, uintptr_t to, uintptr_t increment,
                int blocksize)
{
    for (uintptr_t block_addr = from; block_addr < to;
         block_addr += blocksize) {
        printf("writing %d KiB at %p\n", (blocksize) / 1024 * 4, block_addr);
        for (int i = 0; i < blocksize; i++)
            *(((volatile uint32_t *)block_addr) + i) = 0xcafecafe + i;

        printf("reading back from %p ... ", block_addr);
        for (int i = 0; i < blocksize; i++) {
            uint32_t expected_read = 0xcafecafe + i;
            uint32_t axi_read      = *(((volatile uint32_t *)block_addr) + i);
            assert(expected_read == axi_read);
        }
        puts("ok\n");
    }
  }
