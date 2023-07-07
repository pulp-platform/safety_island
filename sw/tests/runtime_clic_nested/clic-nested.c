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
 * Author: Alessandro Ottaviano (aottaviano@iis.ee.ethz.ch)
 */

/* Test nested interrupts
 * irq_1: L1, P1, ip1, ie1
 * irq_2: L2, P2, ip2, ie2
 * 1. [thread] Trigger irq_1 (lower level)
 * 2. [isr0] Set irq_1 as happened and trigger irq_2 (higher level)
 * 3. [isr1] Set irq_2 as happened and return
 * 4. [isr0] Validate irq_2 happening and return
 * 5. [thread] Validate irq_1 happening
 */

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

static bool int0_ack = false;
static bool int1_ack = false;

void clic_setup_mtvec(void);
void clic_setup_mtvt(void);

void (*isr0_hook[1])(void);
void (*isr1_hook[1])(void);

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

void isr_1(void) {
    print_clic_csr_state();
    int1_ack = true;
}

void isr_0(void) {
    int0_ack = true;

    // interrupt 2 should happen
    for (volatile int i = 0; i < 1000; i++)
        ;

    print_clic_csr_state();

    assert(int1_ack);
}

int main(void) {

    /*
     * global address map
     * CLIC_START_ADDR      32'h1A20_0000
     * CLIC_CTL_END_ADDR    32'h1A20_FFFF
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

    writew((0x1 << CLICINT_CLICINT_ATTR_SHV_BIT) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(30)) & ~(0x1 << CLICINT_CLICINT_ATTR_SHV_BIT)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(30));

    /* set trigger type to edge-triggered */
    printf("set trigger type irq31: edge-triggered\n");
    writew((0x1 << CLICINT_CLICINT_ATTR_TRIG_OFFSET) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(31)) &
                ~(CLICINT_CLICINT_ATTR_TRIG_MASK << CLICINT_CLICINT_ATTR_TRIG_OFFSET)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(31));

    /* set trigger type to edge-triggered */
    printf("set trigger type irq30: edge-triggered\n");
    writew((0x1 << CLICINT_CLICINT_ATTR_TRIG_OFFSET) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(30)) &
                ~(CLICINT_CLICINT_ATTR_TRIG_MASK << CLICINT_CLICINT_ATTR_TRIG_OFFSET)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(30));

    /* enable irq31 via SW by writing to clicintip31 */
    printf("enable irq31: set clicintip31 bit\n");
    writew((0x1 << CLICINT_CLICINT_IP_BIT) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(31)) & ~(0x1 << CLICINT_CLICINT_IP_BIT)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(31));

    /* enable irq30 via SW by writing to clicintip30 */
    printf("enable irq30: set clicintip30 bit\n");
    writew((0x1 << CLICINT_CLICINT_IP_BIT) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(30)) & ~(0x1 << CLICINT_CLICINT_IP_BIT)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(30));

    /* set number of bits for level encoding: nlbits */
    printf("set nlbits\n");
    writew((0x4 << MCLIC_MCLICCFG_MNLBITS_OFFSET), mclicbase + MCLIC_MCLICCFG_REG_OFFSET);

    /* Currently, once an interrupt is enabled and pending it will be
     * immediately picked if it the highest priority available one. This
     * interrupt will now be sent to the core via a ready/valid handshake.
     * If now the core doesn't accept the handshake for a while (for example
     * because interrupts are disabled), then it could be that a higher
     * level interrupt becomes pending (and enabled) at the CLIC.
     *
     * Unfortunately, ready/valid handshakes can't really be aborted at this
     * moment so the lower priority handshake has to be handed off first
     * before sending out the higher priority one.
     *
     * Ideally, we would add a way to abort the handshake (via an abort
     * ready/valid request) so that the higher priority interrupt can be
     * processed first. */

    /* set interrupt level and priority for interrupt 31 */
    printf("set interrupt priority and level\n");
    writew((0xaa << CLICINT_CLICINT_CTL_OFFSET) | (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(31)) &
                                                   ~(CLICINT_CLICINT_CTL_MASK << CLICINT_CLICINT_CTL_OFFSET)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(31));

    /* set interrupt level and priority for interrupt 30 */
    printf("set interrupt priority and level\n");
    writew((0x88 << CLICINT_CLICINT_CTL_OFFSET) | (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(30)) &
                                                   ~(CLICINT_CLICINT_CTL_MASK << CLICINT_CLICINT_CTL_OFFSET)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(30));

    /* raise interrupt threshold to max and check that the interrupt doesn't
     * fire yet */
    printf("raise interrupt threshold to max (no interrupt should happen)\n");
    csr_write(CSR_MINTTHRESH, 0xff);

    printf("enable interrupt 31\n");
    /* enable interrupt 31 on clic */
    writew((0x1 << CLICINT_CLICINT_IE_BIT) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(31)) & ~(0X1 << CLICINT_CLICINT_IE_BIT)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(31));

    printf("enable interrupt 30\n");
    /* enable interrupt 30 on clic */
    writew((0x1 << CLICINT_CLICINT_IE_BIT) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(30)) & ~(0X1 << CLICINT_CLICINT_IE_BIT)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(30));

    /* no interrupt should happen */
    for (volatile int i = 0; i < 1000; i++)
        ;

    isr0_hook[0] = isr_0;
    isr1_hook[0] = isr_1;

    printf("lower interrupt threshold (interrupt should happen)\n");
    csr_write(CSR_MINTTHRESH, 0); /* 0 < 0xaa */

    /* interrupt should happen */
    for (volatile int i = 0; i < 1000; i++)
        ;

    /* check that handler toggled flag and that we are in a good state */
    assert(int1_ack);

    return 0;
}
