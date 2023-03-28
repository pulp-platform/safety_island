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

/* Test basic functionality of the clic (peripheral and core side). Especially
 * check if the interrupt thresholding works. */

#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>

#include "pulp.h"
#include "csr.h"
#include "io.h"

#include "clic.h"

#define assert(expression)                                                     \
	do {                                                                   \
		if (!(expression)) {                                           \
			printf("%s:%d: assert error\n", __FILE__, __LINE__);   \
			exit(1);                                               \
		}                                                              \
	} while (0)

void clic_setup_mtvec(void);
void clic_setup_mtvt(void);

void (*clic_isr_hook[1])(void);

/* need void functions for isr table entries */
void exit_success(void)
{
	exit(0);
}

void exit_fail(void)
{
	exit(1);
}

/* some handlers we use to test */
__attribute__((interrupt("machine"))) void inline_handler(void)
{
	for (volatile int i = 0; i < 10; i++)
		;
}

__attribute__((noinline)) void dummy_loop()
{
	for (volatile int i = 0; i < 10; i++)
		;
}

__attribute__((interrupt("machine"))) void c_handler(void)
{
	dummy_loop();
}

__attribute__((interrupt("machine"))) void check_status_handler(void)
{
	uint32_t mcause = csr_read(CSR_MCAUSE);
	printf("mcause:      %08lx\n", mcause);
	printf("  interrupt: %ld\n", mcause >> 31 & 1);
	printf("  minhv    : %ld\n", mcause >> 30 & 1);
	printf("  mpp      : %ld\n", mcause >> 28 & 3);
	printf("  mpie     : %ld\n", mcause >> 27 & 1);
	printf("  mpil     : %02lx\n", mcause >> 16 & 0xff);
	printf("  excode   : %03lx\n", mcause & 0xfff);
	printf("mintthresh:  %08lx\n", csr_read(CSR_MINTTHRESH));
	printf("mintstatus:  %08lx\n", csr_read(CSR_MINTSTATUS));
}


/* TODO: recursive interrupt */

int main(void)
{

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

	printf("test csr accesses\n");
	uint32_t thresh = 0xffaa;
	uint32_t cmp = 0;
	csr_write(CSR_MINTTHRESH, thresh);
	cmp = csr_read(CSR_MINTTHRESH);
	csr_write(CSR_MINTTHRESH, 0);	/* reset threshold */
	assert(cmp == (thresh & 0xff)); /* only lower 8 bits are writable */


	/* redirect vector table to our custom one */
	printf("set up vector table\n");
	clic_setup_mtvec();
	clic_setup_mtvt();


	/* enable selective hardware vectoring */
	printf("set shv\n");
	writew((0x1 << CLIC_CLICINTATTR_SHV_BIT),
	       mclicbase + CLIC_CLICINTATTR_REG_OFFSET(31));

	/* set trigger type to edge-triggered */
	printf("set trigger type: edge-triggered\n");
	writeb((0x1 << CLIC_CLICINTATTR_TRIG_OFFSET) |
	       readw(mclicbase + CLIC_CLICINTATTR_REG_OFFSET(31)),
	       mclicbase + CLIC_CLICINTATTR_REG_OFFSET(31));

	/* enable irq31 via SW by writing to clicintip31 */
	printf("enable irq31: set clicintip31 bit\n");
	writeb(0x1, mclicbase + CLIC_CLICINTIP_REG_OFFSET(31));

	/* set number of bits for level encoding:
	 * nlbits
	 */
	printf("set nlbits\n");
	writeb((0x4 << CLIC_CLICCFG_NLBITS_OFFSET),
	       mclicbase + CLIC_CLICCFG_REG_OFFSET);

	/* set interrupt level and priority for interrupt 31 */
	printf("set interrupt priority and level\n");
	writew(0xaa, mclicbase + CLIC_CLICINTCTL_REG_OFFSET(31));

	/* raise interrupt threshold to max and check that the interrupt doesn't
	 * fire yet */
	printf("raise interrupt threshold to max (no interrupt should happen)\n");
	csr_write(CSR_MINTTHRESH, 0xff); /* 0xff > 0xaa */
	clic_isr_hook[0] = exit_fail; /* if we take an interrupt then we failed
				       */

	printf("enable interrupt 31\n");
	/* enable interrupt 31 on clic */
	writew(0x1, mclicbase + CLIC_CLICINTIE_REG_OFFSET(31));

	/* no interrupt should happen */
	for (volatile int i = 0; i < 10000; i++)
		;

	printf("lower interrupt threshold (interrupt should happen)\n");
	clic_isr_hook[0] = exit_success;
	csr_write(CSR_MINTTHRESH, 0); /* 0 < 0xaa */

	for (volatile int i = 0; i < 10000; i++)
		;

	printf("Interrupt took too long\n");

	/* TODO: remove */
	clic_isr_hook[0] = inline_handler;
	clic_isr_hook[0] = c_handler;
	return 1;
}
