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

#define ERR_ADDR ARCHI_SAFETY_ISLAND_BASE_ADDR+2*ARCHI_SAFETY_ISLAND_PERIPH_OFFSET

unsigned int bus_err_count;
unsigned int bus_err_addr;

__attribute__((interrupt("machine"))) void bus_err_handler(void) {
    bus_err_count += 1;
    bus_err_addr = data_bus_err_get_addr_32();
    data_bus_err_get_err_and_pop();
}



int main(void) {
    bus_err_count = 0;

    // Set up CLIC interrupt for Bus Error Unit
    // @Ale how?
    

    // Probe bus error unit, ensure no errors
    if (data_bus_err_get_err_and_pop()) printf("init: got an error?\n");

    // Read error memory region
    uint32_t test_int = pulp_read32(ERR_ADDR);
    if (test_int != 0xbadcab1e) return 1;

    // while(1) {
    //     if (bus_err_count > 0) break;
    // }
    // Ensure interrupt is handled correctly

    for (int i = 0; i < 1000; i++) {asm volatile ("nop");}

    printf("Testing err addr 0x%x\n", data_bus_err_get_addr_32());
    printf("Testing err code 0x%x\n", data_bus_err_get_err_and_pop());

    printf("Testing popped? 0x%x\n", data_bus_err_get_err_and_pop());

    return 0;
}
