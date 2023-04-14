/*
 * Copyright 2021 ETH Zurich
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by apclicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 * Author: Robert Balas (balasr@iis.ee.ethz.ch)
 */

/* Test if mintstatus is correctly preserved accross an interrupt */

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "csr.h"
#include "io.h"
#include "pulp.h"

#include "clic.h"
#include "clicint.h"

#define assert(expression) \
    do { \
        if (!(expression)) { \
            printf("%s:%d: assert error\n", __FILE__, __LINE__); \
            exit(1); \
        } \
    } while (0)

void clic_setup_mtvec(void);
void clic_setup_mtvt(void);

static bool interrupt_happened = false;

static void print_clic_csr_state(void) {
    uint32_t mcause = csr_read(CSR_MCAUSE);
    uint32_t mintstatus = csr_read(CSR_MINTSTATUS);
    printf("mcause:      %08lx\n", mcause);
    printf("  interrupt: %ld\n", mcause >> 31 & 1);
    printf("  minhv    : %ld\n", mcause >> 30 & 1);
    printf("  mpp      : %ld\n", mcause >> 28 & 3);
    printf("  mpie     : %ld\n", mcause >> 27 & 1);
    printf("  mpil     : %02lx\n", mcause >> 16 & 0xff);
    printf("  excode   : %03lx\n", mcause & 0xfff);
    printf("mintthresh:  %08lx\n", csr_read(CSR_MINTTHRESH));
    printf("mintstatus:  %08lx\n", mintstatus);
    printf("  mil      : %02lx\n", mintstatus >> 24 & 0xff);
}

__attribute__((interrupt("machine"))) void check_status_handler(void) {
    printf("CLIC CSR STATE DURING INTERRUPT\n");
    print_clic_csr_state();
    interrupt_happened = true;
    /* check that this is interrupt 31 */
    assert((csr_read(CSR_MCAUSE) & 0x3ff) == 31);
    /* maximize interrupt threshold to prevent further recursive interrupts
     * since our interrupt line 31 is level sensitive and premanently
     * asserted */
    csr_write(CSR_MINTTHRESH, 0xff); /* 0xff > 0xaa */
}

int main(void) {

    /*
     * global address map
     * CLIC_START_ADDR      32'h1A20_0000
     * CLIC_CTRL_END_ADDR   32'h1A20_FFFF
     * See clic.h for register map
     */

    /* This tests works with edge triggered interrupts as default.
     * It uses clicintip[i] CLIC register to assert pending interrupt via
     * SW, even though the corresponding lines are not asserted in HW.
     *
     * If the trigger is switched to level-sensitive mode,
     * pending interrupts must be excited by asserting the corresponding
     * line in HW.
     */

    uint32_t mclicbase;
    mclicbase = csr_read(CSR_MCLICBASE);
    printf("the readed CSR value is: %lx\n", mclicbase);

    /* TODO: hook illegal insn handler to exit(1) */

    uint32_t mintstatus_before;
    uint32_t mintstatus_after;

    /* redirect vector table to our custom one */
    printf("set up vector table\n");
    clic_setup_mtvec();
    clic_setup_mtvt();

    /* enable selective hardware vectoring */
    printf("set shv\n");
    writew((0x1 << CLICINT_CLICINT_ATTR_SHV_BIT) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(31)) & ~(0x1 << CLICINT_CLICINT_ATTR_SHV_BIT)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(31));

    /* set trigger type to edge-triggered */
    printf("set trigger type: edge-triggered\n");
    writew((0x1 << CLICINT_CLICINT_ATTR_TRIG_OFFSET) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(31)) &
                ~(CLICINT_CLICINT_ATTR_TRIG_MASK << CLICINT_CLICINT_ATTR_TRIG_OFFSET)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(31));

    /* enable irq31 via SW by writing to clicintip31 */
    printf("enable irq31: set clicintip31 bit\n");
    writew((0x1 << CLICINT_CLICINT_IP_BIT) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(31)) & ~(0x1 << CLICINT_CLICINT_IP_BIT)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(31));

    /* set number of bits for level encoding:
     * nlbits
     */

    printf("set nlbits\n");
    writew((0x4 << MCLIC_MCLICCFG_MNLBITS_OFFSET), mclicbase + MCLIC_MCLICCFG_REG_OFFSET);

    /* set interrupt level and priority for interrupt 31 */
    printf("set interrupt priority and level\n");
    writew((0xaa << CLICINT_CLICINT_CTL_OFFSET) | (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(31)) &
                                                   ~(CLICINT_CLICINT_CTL_MASK << CLICINT_CLICINT_CTL_OFFSET)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(31));

    printf("set interrupt threshold \n");
    csr_write(CSR_MINTTHRESH, 0xb); /* 0xb < 0xaa */

    printf("CLIC CSR STATE BEFORE INTERRUPT\n");
    print_clic_csr_state();
    mintstatus_before = csr_read(CSR_MINTSTATUS);

    printf("enable interrupt 31\n");
    /* enable interrupt 31 on clic */
    writew((0x1 << CLICINT_CLICINT_IE_BIT) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(31)) & ~(0X1 << CLICINT_CLICINT_IE_BIT)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(31));

    /* give the interrupt some room to fire */
    for (volatile int i = 0; i < 16; i++)
        ;

    /* check that handler toggled flag and that we are in a good state */
    assert(interrupt_happened);

    printf("CLIC CSR STATE AFTER INTERRUPT\n");
    print_clic_csr_state();

    /* check that we preserved state */
    mintstatus_after = csr_read(CSR_MINTSTATUS);
    assert(mintstatus_before == mintstatus_after);

    return 0;
}
