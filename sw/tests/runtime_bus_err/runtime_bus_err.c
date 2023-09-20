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

// CLIC includes
#include "csr.h"
#include "io.h"
#include "clic.h"
#include "clicint.h"

#define ERR_ADDR ARCHI_SAFETY_ISLAND_BASE_ADDR+2*ARCHI_SAFETY_ISLAND_PERIPH_OFFSET
#define INSTR_ERR_IRQ 18
#define DATA_ERR_IRQ 19
#define SHADOW_ERR_IRQ 20


void clic_setup_mtvec(void);
void clic_setup_mtvt(void);

unsigned int bus_err_count;
unsigned int bus_err_addr;

__attribute__((interrupt("machine"))) void bus_err_handler(void) {
    bus_err_count += 1;
    bus_err_addr = data_bus_err_get_addr_32();
    data_bus_err_get_err_and_pop();
}



int main(void) {
    int errors = 0;

    bus_err_count = 0;
    // Probe bus error unit, ensure no errors
    if (data_bus_err_get_err_and_pop()) {
        printf("Bus error Unit has error on startup.\n");
        errors += 1;
    }

    // Read error memory region
    uint32_t test_int = pulp_read32(ERR_ADDR);
    if (test_int != 0xbadcab1e) {
        printf("Error Address not responding with expected 0xbadcab1e.\n");
        errors += 1;
    }

    for (int i = 0; i < 1000; i++) {
        asm volatile ("nop");
    }

    uint32_t test_err_addr = data_bus_err_get_addr_32();
    if (ERR_ADDR != test_err_addr) {
        printf("Error Address does not match bus error unit trigger: 0x%d vs. 0x%d.\n", test_err_addr, ERR_ADDR);
        errors += 1;
    }

    if (0 == data_bus_err_get_err_and_pop()) {
        printf("Bus error Unit did not trigger.\n");
        errors += 1;
    }

    if (0 != data_bus_err_get_err_and_pop()) {
        printf("Bus error Unit did not pop error.\n");
        errors += 1;
    }

    // Ensure interrupt works with handler
    // Other tests confirm CLIC works, here just the UNBENT handler is tested.

    uint32_t mclicbase;
    mclicbase = csr_read(CSR_MCLICBASE);
    // redirect vector table
    clic_setup_mtvec();
    clic_setup_mtvt();

    // Use vector jump, not default handler
    writew((0x1 << CLICINT_CLICINT_ATTR_SHV_BIT) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(DATA_ERR_IRQ)) & ~(0x1 << CLICINT_CLICINT_ATTR_SHV_BIT)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(DATA_ERR_IRQ));


    // set to edge-triggered for DATA_ERR_IRQ
    writew((0x0 << CLICINT_CLICINT_ATTR_TRIG_OFFSET) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(DATA_ERR_IRQ)) &
                ~(CLICINT_CLICINT_ATTR_TRIG_MASK << CLICINT_CLICINT_ATTR_TRIG_OFFSET)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(DATA_ERR_IRQ));

    // Set nlbits, (level/priority global config)
    writew((0x4 << MCLIC_MCLICCFG_MNLBITS_OFFSET), mclicbase + MCLIC_MCLICCFG_REG_OFFSET);

    // set interrupt level and priority for interrupt DATA_ERR_IRQ to 0xaa (because this is the value in other tests)
    writew((0xaa << CLICINT_CLICINT_CTL_OFFSET) | (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(DATA_ERR_IRQ)) &
                                                   ~(CLICINT_CLICINT_CTL_MASK << CLICINT_CLICINT_CTL_OFFSET)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(DATA_ERR_IRQ));

    // enable interrupt DATA_ERR_IRQ on clic
    writew((0x1 << CLICINT_CLICINT_IE_BIT) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(DATA_ERR_IRQ)) & ~(0X1 << CLICINT_CLICINT_IE_BIT)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(DATA_ERR_IRQ));

    // Set interrupt threshold to enable all
    csr_write(CSR_MINTTHRESH, 0); /* 0 < xx */

    uint32_t test_int2 = pulp_read32(ERR_ADDR);

    if (test_int2 != 0xbadcab1e) {
        printf("Error Address not responding with expected 0xbadcab1e.\n");
        errors += 1;
    }

    for (int i = 0; i < 1000; i++) {
        asm volatile ("nop");
    }

    if (bus_err_count != 1) {
        printf("Bus Error count from interrupt handler is not 1: %d\n", bus_err_count);
        errors += 1;
    }

    return errors;
}
