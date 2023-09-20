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

#include "ECC.h"

#define BITFLIPADDR ARCHI_SAFETY_ISLAND_BASE_ADDR+0x2000
#define ARRAY_SIZE 0x8000

int main(void) {
    unsigned int errors = 0;
    unsigned int test_value = 0;

    // Get large enough memory space (that isn't used for other stuff)
    unsigned int *mem_array = pi_l2_malloc(ARRAY_SIZE);
    printf("Allocated memory at %p\r\n", mem_array, mem_array+ARRAY_SIZE);
    if (BITFLIPADDR < mem_array || BITFLIPADDR > mem_array+ARRAY_SIZE) {
        printf("BITFLIPADDR not in allocated memory\r\n");
        return 1;
    }

    // Fill SRAM region
    for (int i = 0; i < ARRAY_SIZE>>2; i++) {
        pulp_write32(&(mem_array[i]), i);
    }
    test_value = pulp_read32(BITFLIPADDR);

    // wait for bit flip (external script!)
    for (int i = 0; i < 10000; i++) {
        asm volatile ("nop");
    }

    // read flipped bit -> check corrected
    if (test_value != pulp_read32(BITFLIPADDR)) {
        printf("Test Value no longer matches after flip!");
        errors += 1;
    }
    // Check flip count status register
    unsigned int ecc_errors = pulp_read32(ARCHI_ECC_MGR_ADDR+ECC_MANAGER_MISMATCH_COUNT_REG_OFFSET); // + (0x20*BankId)
    if (ecc_errors != 1) {
        printf("ECC error count not correct!\r\n");
        errors += 1;
    }

    // enable scrubber
    pulp_write32(ARCHI_ECC_MGR_ADDR+ECC_MANAGER_SCRUB_INTERVAL_REG_OFFSET, 2);

    // wait for scrubber (2*bank_size+margin cycles)
    for (int i = 0; i < 40000; i++) {
        asm volatile ("nop");
    }

    // check scrubber fixed (scrub corrected count, read value and ensure not correction not needed)
    unsigned int scrub_fix_count = pulp_read32(ARCHI_ECC_MGR_ADDR+ECC_MANAGER_SCRUB_FIX_COUNT_REG_OFFSET);
    if (scrub_fix_count != 1) {
        printf("Scrub fix count not correct: %d\r\n", scrub_fix_count);
        errors += 1;
    }

    // disable scrubber
    pulp_write32(ARCHI_ECC_MGR_ADDR+ECC_MANAGER_SCRUB_INTERVAL_REG_OFFSET, 0);

    // wait for double bit flip (external script!)
    for (int i = 0; i < 10000; i++) {
        asm volatile ("nop");
    }

    // read word, ensure bus_err_unit triggers
    unsigned int bad_read = pulp_read32(BITFLIPADDR);

    uint32_t test_err_addr = data_bus_err_get_addr_32();
    if (BITFLIPADDR != test_err_addr) {
        printf("Error Address does not match bus error unit trigger: 0x%d vs. 0x%d.\n", test_err_addr, BITFLIPADDR);
        errors += 1;
    }

    if (0 == data_bus_err_get_err_and_pop()) {
        printf("Bus error Unit did not trigger.\n");
        errors += 1;
    }

    if (0 != data_bus_err_get_err_and_pop()) {
        printf("No additional errors read.\n");
        errors += 1;
    }

    pi_l2_free(mem_array, ARRAY_SIZE);
    printf("Errors: %d\r\n", errors);

    return errors;
}
