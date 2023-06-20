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
 * Author: Diyou Shen (dishen@student.ethz.ch)
 */

/*
 * Test mnxti CSR functionalities
 * The following interrupts are used:
 * Interrupt Name			ID 		SHV?	LVL/Prio
 * Origin Interrupt (OIC)	irq 27	SHV 	33
 * Initial Interrupt (I)	irq 28 	non		55
 * Interrupt II 			irq 29  non 	66
 * Interrupt III 			irq 30 	non 	44
 * Interrupt IV				irq 31  SHV 	66
 * Interrupt V 				irq 26	non 	33
 *
 * OIC is set at the beginning. I is set inside OIC's handler.
 * II, III and V are set simultaneously when entering general handler
 * IV is set before leaving the general handler.
 *
 * Sequence of expected flow:
 * Normal Code -> VH(OIC 27) -> GH(I 28) -> VH(II 29) -> GH(I 28) ->
 * VH(I 28) -> GH(I 28) -> VH(III 30) -> GH(I 28) -> VH(IV 31) ->
 * GH(I 28) -> VH(OIC 27) -> Normal Code -> GH(V 26) -> VH(V 26) ->
 * GH(V 26) -> Normal Code
 *
 * All interrupts are set pending and enabled at the beginning, but
 * with level lower than the threshold. Their level will be raised
 * to the value described above inside the handler at the correct
 * time. The minimum threshold would be set to 11.
 *
 * All interrupts used are set to edge-triggered
 *
 * To test if the mnxti behaves the same as expected, assertion is used
 * at each vectored handler to check the sequence.
 *
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

static bool int1_ack = false;
static bool int2_ack = false;
static bool int3_ack = false;
static bool int5_ack = false;
static bool intshv_ack = false;
static bool intoic_ack = false;

void clic_setup_mtvec(void);
void clic_setup_mtvt(void);

void (*clic_isr_oic_hook[1])(void);
void (*clic_isr_shv_hook[1])(void);
void (*clic_isr_1_hook[1])(void);
void (*clic_isr_2_hook[1])(void);
void (*clic_isr_3_hook[1])(void);
void (*clic_delay_hook[1])(void);

static void print_clic_csr_state(void) {
    uint32_t mcause = csr_read(CSR_MCAUSE);
    uint32_t mintstatus = csr_read(CSR_MINTSTATUS);
    uint32_t mepc = csr_read(0x341);
    printf("Entering irq%d interrupt handler\n", mcause & 0xfff);
    printf("  mcause     : %08lx\n", mcause);
    printf("  interrupt  : %ld\n", mcause >> 31 & 1);
    printf("  minhv      : %ld\n", mcause >> 30 & 1);
    printf("  mpp        : %ld\n", mcause >> 28 & 3);
    printf("  mpie       : %ld\n", mcause >> 27 & 1);
    printf("  mpil       : %02lx\n", mcause >> 16 & 0xff);
    printf("  excode     : %03lx\n", mcause & 0xfff);
    printf("  mintthresh : %08lx\n", csr_read(CSR_MINTTHRESH));
    printf("  mintstatus : %08lx\n", mintstatus);
    printf("  mil        : %02lx\n", mintstatus >> 24 & 0xff);
    printf("  mepc       : %lx\n", mepc);
    if ((mcause & 0xfff) == 0x01e) { /* irq30 */
        int3_ack = true;
        assert(int1_ack);
    } else if ((mcause & 0xfff) == 0x01d) { /* irq29 */
        int2_ack = true;
        assert(!int1_ack);
        assert(!int3_ack);
    } else if ((mcause & 0xfff) == 0x01c) { /* irq28 */
        int1_ack = true;
        assert(int2_ack);
    } else if ((mcause & 0xfff) == 0x01a) { /* irq26 */
        int5_ack = true;
        assert(intshv_ack);
    }
}

static void print_genint_csr_state(void) {
    uint32_t mcause = csr_read(CSR_MCAUSE);
    printf("Entering irq%d GENERAL int handler\n", mcause & 0xfff);
}

void delay_loop(void) {
    for (volatile int i = 0; i < 5000; i++)
        ;
}

void isr_1(void) {
    print_genint_csr_state();
    assert(intoic_ack);
}

void isr_2(void) { print_clic_csr_state(); }

void isr_3(void) { printf("\n *** Leaving GENERAL handler ***\n\n"); }

void isr_shv(void) {
    intshv_ack = true;
    printf("\n SHV-Selected Interrupt handler \n");
    print_clic_csr_state();
    assert(int3_ack);
}

void isr_oic(void) {
    printf("\n Original Interrupt Context (OIC) handler \n");
    print_clic_csr_state();
    intoic_ack = true;
    assert(!int1_ack);
    assert(!int2_ack);
    assert(!int3_ack);
}

int main(void) {
    /*
     * global address map
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

    uint32_t mintstatus_before;
    uint32_t mintstatus_after;

    /* redirect vector table to our custom one */
    printf("set up vector table\n");
    clic_setup_mtvec();
    clic_setup_mtvt();

    printf("enable mnxti extension by writing to custom memory-mapped reg\n");
    writew((0x1 << MCLIC_CLICMNXTICONF_CLICMNXTICONF_BIT), mclicbase + MCLIC_CLICMNXTICONF_REG_OFFSET);

    /* disable selective hardware vectoring, mnxti only supports
     * non-vectoring mode
     * irq29 is set as vectored mode, which would skip when read mnxti
     */
    printf("set shv, OIC & IV as SHV; I, II, III as non-SHV\n");
    /* Interrupt IV  */
    writew((0x1 << CLICINT_CLICINT_ATTR_SHV_BIT) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(31)) & ~(0x1 << CLICINT_CLICINT_ATTR_SHV_BIT)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(31));
    /* Interrupt III */
    writew((0x0 << CLICINT_CLICINT_ATTR_SHV_BIT) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(30)) & ~(0x1 << CLICINT_CLICINT_ATTR_SHV_BIT)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(30));
    /* Interrupt II  */
    writew((0x0 << CLICINT_CLICINT_ATTR_SHV_BIT) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(29)) & ~(0x1 << CLICINT_CLICINT_ATTR_SHV_BIT)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(29));
    /* Interrupt I   */
    writew((0x0 << CLICINT_CLICINT_ATTR_SHV_BIT) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(28)) & ~(0x1 << CLICINT_CLICINT_ATTR_SHV_BIT)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(28));
    /* Interrupt OIC */
    writew((0x1 << CLICINT_CLICINT_ATTR_SHV_BIT) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(27)) & ~(0x1 << CLICINT_CLICINT_ATTR_SHV_BIT)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(27));
    /* Interrupt V */
    writew((0x0 << CLICINT_CLICINT_ATTR_SHV_BIT) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(26)) & ~(0x1 << CLICINT_CLICINT_ATTR_SHV_BIT)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(26));

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

    /* set trigger type to edge-triggered */
    printf("set trigger type irq29: edge-triggered\n");
    writew((0x1 << CLICINT_CLICINT_ATTR_TRIG_OFFSET) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(29)) &
                ~(CLICINT_CLICINT_ATTR_TRIG_MASK << CLICINT_CLICINT_ATTR_TRIG_OFFSET)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(29));

    /* set trigger type to edge-triggered */
    printf("set trigger type irq28: edge-triggered\n");
    writew((0x1 << CLICINT_CLICINT_ATTR_TRIG_OFFSET) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(28)) &
                ~(CLICINT_CLICINT_ATTR_TRIG_MASK << CLICINT_CLICINT_ATTR_TRIG_OFFSET)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(28));

    /* set trigger type to edge-triggered */
    printf("set trigger type irq27: edge-triggered\n");
    writew((0x1 << CLICINT_CLICINT_ATTR_TRIG_OFFSET) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(27)) &
                ~(CLICINT_CLICINT_ATTR_TRIG_MASK << CLICINT_CLICINT_ATTR_TRIG_OFFSET)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(27));

    /* set trigger type to edge-triggered */
    printf("set trigger type irq26: edge-triggered\n");
    writew((0x1 << CLICINT_CLICINT_ATTR_TRIG_OFFSET) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(26)) &
                ~(CLICINT_CLICINT_ATTR_TRIG_MASK << CLICINT_CLICINT_ATTR_TRIG_OFFSET)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(26));

    /* enable irq31 via SW by writing to clicintip31 */
    printf("enable irq31: set clicintip31 bit\n");
    writew((0x1 << CLICINT_CLICINT_IP_BIT) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(31)) & ~(0x1 << CLICINT_CLICINT_IP_BIT)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(31));

    /* enable irq31 via SW by writing to clicintip31 */
    printf("enable irq30: set clicintip30 bit\n");
    writew((0x1 << CLICINT_CLICINT_IP_BIT) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(30)) & ~(0x1 << CLICINT_CLICINT_IP_BIT)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(30));

    /* enable irq31 via SW by writing to clicintip31 */
    printf("enable irq29: set clicintip29 bit\n");
    writew((0x1 << CLICINT_CLICINT_IP_BIT) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(29)) & ~(0x1 << CLICINT_CLICINT_IP_BIT)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(29));

    /* enable irq31 via SW by writing to clicintip31 */
    printf("enable irq28: set clicintip28 bit\n");
    writew((0x1 << CLICINT_CLICINT_IP_BIT) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(28)) & ~(0x1 << CLICINT_CLICINT_IP_BIT)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(28));

    /* enable irq31 via SW by writing to clicintip31 */
    printf("enable irq27: set clicintip27 bit\n");
    writew((0x1 << CLICINT_CLICINT_IP_BIT) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(27)) & ~(0x1 << CLICINT_CLICINT_IP_BIT)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(27));

    /* enable irq31 via SW by writing to clicintip31 */
    printf("enable irq26: set clicintip26 bit\n");
    writew((0x1 << CLICINT_CLICINT_IP_BIT) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(26)) & ~(0x1 << CLICINT_CLICINT_IP_BIT)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(26));

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

    /* set interrupt level and priority for interrupt 31 (IV)
     * Here, an initial value smaller than threshold is
     * set to avoid from pre-firing the interrupt
     * In the generic handler */

    /* set interrupt level and priority for interrupt 31 */
    printf("set interrupt 31 (IV) priority and level\n");
    writew((0x11 << CLICINT_CLICINT_CTL_OFFSET) | (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(31)) &
                                                   ~(CLICINT_CLICINT_CTL_MASK << CLICINT_CLICINT_CTL_OFFSET)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(31));

    /* set interrupt level and priority for interrupt 30 */
    printf("set interrupt 30 (III) priority and level\n");
    writew((0x11 << CLICINT_CLICINT_CTL_OFFSET) | (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(30)) &
                                                   ~(CLICINT_CLICINT_CTL_MASK << CLICINT_CLICINT_CTL_OFFSET)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(30));

    /* set interrupt level and priority for interrupt 29 */
    printf("set interrupt 29 (II) priority and level\n");
    writew((0x11 << CLICINT_CLICINT_CTL_OFFSET) | (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(29)) &
                                                   ~(CLICINT_CLICINT_CTL_MASK << CLICINT_CLICINT_CTL_OFFSET)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(29));

    /* set interrupt level and priority for interrupt 28 */
    printf("set interrupt 28 (I) priority and level\n");
    writew((0x33 << CLICINT_CLICINT_CTL_OFFSET) | (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(28)) &
                                                   ~(CLICINT_CLICINT_CTL_MASK << CLICINT_CLICINT_CTL_OFFSET)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(28));

    /* set interrupt level and priority for interrupt 27 */
    printf("set interrupt 27 (0IC) priority and level\n");
    writew((0x33 << CLICINT_CLICINT_CTL_OFFSET) | (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(27)) &
                                                   ~(CLICINT_CLICINT_CTL_MASK << CLICINT_CLICINT_CTL_OFFSET)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(27));

    /* set interrupt level and priority for interrupt 26 */
    printf("set interrupt 26 (V) priority and level\n");
    writew((0x11 << CLICINT_CLICINT_CTL_OFFSET) | (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(26)) &
                                                   ~(CLICINT_CLICINT_CTL_MASK << CLICINT_CLICINT_CTL_OFFSET)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(26));

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
    /* enable interrupt 31 on clic */
    writew((0x1 << CLICINT_CLICINT_IE_BIT) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(30)) & ~(0X1 << CLICINT_CLICINT_IE_BIT)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(30));

    printf("enable interrupt 29\n");
    /* enable interrupt 31 on clic */
    writew((0x1 << CLICINT_CLICINT_IE_BIT) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(29)) & ~(0X1 << CLICINT_CLICINT_IE_BIT)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(29));

    printf("enable interrupt 28\n");
    /* enable interrupt 31 on clic */
    writew((0x1 << CLICINT_CLICINT_IE_BIT) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(28)) & ~(0X1 << CLICINT_CLICINT_IE_BIT)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(28));

    printf("enable interrupt 27\n");
    /* enable interrupt 31 on clic */
    writew((0x1 << CLICINT_CLICINT_IE_BIT) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(27)) & ~(0X1 << CLICINT_CLICINT_IE_BIT)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(27));

    printf("enable interrupt 26\n");
    /* enable interrupt 31 on clic */
    writew((0x1 << CLICINT_CLICINT_IE_BIT) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(26)) & ~(0X1 << CLICINT_CLICINT_IE_BIT)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(26));

    /* no interrupt should happen */
    for (volatile int i = 0; i < 1000; i++)
        ;

    /* Loading all hook functions (for assertion and printing purpose) */
    clic_isr_oic_hook[0] = isr_oic;
    clic_isr_shv_hook[0] = isr_shv;
    clic_isr_1_hook[0] = isr_1;
    clic_isr_2_hook[0] = isr_2;
    clic_isr_3_hook[0] = isr_3;
    clic_delay_hook[0] = delay_loop;

    printf("lower interrupt threshold (interrupt should happen)\n");
    csr_write(CSR_MINTTHRESH, 0x22);

    /* interrupt (OIC) should happen first */
    for (volatile int i = 0; i < 1000; i++)
        ;
    assert(int5_ack);
    return 0;
}
