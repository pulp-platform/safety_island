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
* Author: Diyou Shen (dishen@student.ethz.ch)
*/

#include "clic.h"
#include "clicint.h"
#include "csr.h"


/* TODO: consider __riscv_32e */

/* Allow recursive (nested) interrupts. Very conservative. Uses regular integer
   abi. */
.section .text.int
.balign 8 /* probably not needed */
.global __handle_isr
.func
__handle_isr:
    /* Here, the only register needs to be saved is the ra for return*
     * address. All other regs have been saved in the general handelr*/
    addi sp, sp, -(4 * 2)
    sw ra, 0(sp)
    csrsi mstatus, MIE /* re-enable global interrupts enable recursion */

    la   t0, clic_isr_2_hook
    lw   t0, 0(t0) /* load function pointer */

    jalr t0 /* vector into hook */

    csrci mstatus, MIE /* disable global interrupts*/
    lw ra, 0(sp)
    addi sp, sp, (4 * 2)
    /* return to address stored in ra if the handler was enterred by *
     * mnxti, which would not be recognized as an exception in the   *
     * core                                                          */
    ret
.endfunc
.endm

.section .text.int
.balign 8 /* probably not needed */
.global __handle_shv
.func
__handle_shv:
    addi sp, sp, -(4 * 18)
    sw ra, 0(sp)
    sw t0, 4(sp)
    sw t1, 8(sp)
    sw t2, 12(sp)
    sw a0, 16(sp)
    sw a1, 20(sp)
    sw a2, 24(sp)
    sw a3, 28(sp)
    sw a4, 32(sp)
    sw a5, 36(sp)
    sw a6, 40(sp)
    sw a7, 44(sp)
    sw t3, 48(sp)
    sw t4, 52(sp)
    sw t5, 56(sp)
    sw t6, 60(sp)
    csrr t0, mcause
    csrr t1, mepc
    sw t0, 64(sp)
    sw t1, 68(sp)
    csrsi mstatus, MIE /* re-enable global interrupts enable recursion */

    la   t0, clic_isr_shv_hook
    lw   t0, 0(t0) /* load function pointer */
    jalr t0 /* vector into hook */

    csrci mstatus, MIE /* disable global interrupts*/
    lw t0, 64(sp)
    lw t1, 68(sp)
    csrw mcause, t0
    csrw mepc, t1
    lw ra, 0(sp)
    lw t0, 4(sp)
    lw t1, 8(sp)
    lw t2, 12(sp)
    lw a0, 16(sp)
    lw a1, 20(sp)
    lw a2, 24(sp)
    lw a3, 28(sp)
    lw a4, 32(sp)
    lw a5, 36(sp)
    lw a6, 40(sp)
    lw a7, 44(sp)
    lw t3, 48(sp)
    lw t4, 52(sp)
    lw t5, 56(sp)
    lw t6, 60(sp)
    addi sp, sp, (4 * 18)
    mret
.endfunc
.endm

/* The SHV mode interrupt handler for OIC */
.section .text.int
.balign 8 /* probably not needed */
.global __handle_oic
.func
__handle_oic:
    addi sp, sp, -(4 * 18)
    sw ra, 0(sp)
    sw t0, 4(sp)
    sw t1, 8(sp)
    sw t2, 12(sp)
    sw a0, 16(sp)
    sw a1, 20(sp)
    sw a2, 24(sp)
    sw a3, 28(sp)
    sw a4, 32(sp)
    sw a5, 36(sp)
    sw a6, 40(sp)
    sw a7, 44(sp)
    sw t3, 48(sp)
    sw t4, 52(sp)
    sw t5, 56(sp)
    sw t6, 60(sp)
    csrr t0, mcause
    csrr t1, mepc
    sw t0, 64(sp)
    sw t1, 68(sp)
    csrsi mstatus, MIE /* re-enable global interrupts enable recursion */

    la   t0, clic_isr_oic_hook
    lw   t0, 0(t0) /* load function pointer */
    jalr t0 /* vector into hook */

    /* Raise the level and priority of irq28(II) to enable it*/
    li    t0, 0x00210000            /* Base address for memory mapped CLIC registers */
    li    t1, 0x1070                /* t1 (Offset) = 0x1000+0x4*28       */
    add   t4, t0, t1                /* clic_base + irq28 offset */
    li    t2, 0x55
    slli  t3, t2, 0x18              /* lvl: 0x55 << 24 (CLICINT_CLICINT_CTL_OFFSET) */
    lw    t5, 0(t4)                 /* load reg */
    li    t1, 0x00ffffff            /* ~mask */
    and   t0, t5, t1                /* reg & ~mask */
    or    t6, t3, t0                /* (reg ~mask) | lvl */
    sw    t6, 0(t4)                 /* set irq28 level and priority       */

    /* Interrupt should happen here and jump to general handler */
    la   t0, clic_delay_hook
    lw   t0, 0(t0) /* load function pointer */
    jalr t0 /* vector into hook */

    csrci mstatus, MIE /* disable global interrupts*/
    lw t0, 64(sp)
    lw t1, 68(sp)
    csrw mcause, t0
    csrw mepc, t1
    lw ra, 0(sp)
    lw t0, 4(sp)
    lw t1, 8(sp)
    lw t2, 12(sp)
    lw a0, 16(sp)
    lw a1, 20(sp)
    lw a2, 24(sp)
    lw a3, 28(sp)
    lw a4, 32(sp)
    lw a5, 36(sp)
    lw a6, 40(sp)
    lw a7, 44(sp)
    lw t3, 48(sp)
    lw t4, 52(sp)
    lw t5, 56(sp)
    lw t6, 60(sp)
    addi sp, sp, (4 * 18)
    mret
.endfunc
.endm

/* The general interrupt handler for non-SHV interrupts (enter due to I) */
.section .text.int
.balign 1024 /* probably not needed */
# .macro recursive_clic_int int_hook:req
.global __clic_gen_handler
.func
__clic_gen_handler:
    addi sp, sp, -(4 * 20)
    sw ra, 0(sp)
    sw t0, 4(sp)
    sw t1, 8(sp)
    sw t2, 12(sp)
    sw a0, 16(sp)
    sw a1, 20(sp)
    sw a2, 24(sp)
    sw a3, 28(sp)
    sw a4, 32(sp)
    sw a5, 36(sp)
    sw a6, 40(sp)
    sw a7, 44(sp)
    sw t3, 48(sp)
    sw t4, 52(sp)
    sw t5, 56(sp)
    sw t6, 60(sp)
    csrr  t0, mcause
    csrr  t1, mepc
    sw    t0, 64(sp)
    sw    t1, 68(sp)

    li    t0, 0x00210000            /* Base address for memory mapped CLIC registers */

    /* Raise the level and priority of irq29 to enable it*/
    li    t0, 0x00210000            /* Base address for memory mapped CLIC registers */
    li    t1, 0x1074                /* t1 (Offset) = 0x1000+0x4*29       */
    add   t4, t0, t1                /* clic_base + irq29 offset */
    li    t2, 0x66
    slli  t3, t2, 0x18              /* lvl: 0x66 << 24 (CLICINT_CLICINT_CTL_OFFSET) */
    lw    t5, 0(t4)                 /* load reg */
    li    t1, 0x00ffffff            /* ~mask */
    and   t0, t5, t1                /* reg & ~mask */
    or    t6, t3, t0                /* (reg ~mask) | lvl */
    sw    t6, 0(t4)                 /* set irq29 level and priority       */

    /* Raise the level and priority of irq30 to enable it*/
    li    t0, 0x00210000            /* Base address for memory mapped CLIC registers */
    li    t1, 0x1078                /* t1 (Offset) = 0x1000+0x4*30       */
    add   t4, t0, t1                /* clic_base + irq30 offset */
    li    t2, 0x44
    slli  t3, t2, 0x18              /* lvl: 0x44 << 24 (CLICINT_CLICINT_CTL_OFFSET) */
    lw    t5, 0(t4)                 /* load reg */
    li    t1, 0x00ffffff            /* ~mask */
    and   t0, t5, t1                /* reg & ~mask */
    or    t6, t3, t0                /* (reg ~mask) | lvl */
    sw    t6, 0(t4)                 /* set irq30 level and priority       */

    /* Raise the level and priority of irq26 to enable it*/
    li    t0, 0x00210000            /* Base address for memory mapped CLIC registers */
    li    t1, 0x1068                /* t1 (Offset) = 0x1000+0x4*26       */
    add   t4, t0, t1                /* clic_base + irq28 offset */
    li    t2, 0x33
    slli  t3, t2, 0x18              /* lvl: 0x33 << 24 (CLICINT_CLICINT_CTL_OFFSET) */
    lw    t5, 0(t4)                 /* load reg */
    li    t1, 0x00ffffff            /* ~mask */
    and   t0, t5, t1                /* reg & ~mask */
    or    t6, t3, t0                /* (reg ~mask) | lvl */
    sw    t6, 0(t4)                 /* set irq26 level and priority       */

    /* Print when enter general interrupt handler */
    la    t0, clic_isr_1_hook
    lw    t0, 0(t0)                 /* load function pointer */
    jalr  t0                        /* vector into hook */

    csrrsi  a0, CSR_MNXTI, MIE   /* Get highest current interrupt and enable interrupts *
				     * Will return original interrupt if no others appear  *
				     * CSR ADDR: mnxti: 0x345                              */

    /* If the original interrupt pending disappears, leaving the handler *
     * If not, jump to original interrupt's vectored interrupt handler   */
    beqz    a0, cont
    service_loop:
    csrrsi  t0, mstatus, MIE        /* Make sure interrupt is globally enabaled            */
    jalr    a0
    csrrsi  a0, CSR_MNXTI, MIE   /* CSR ADDR: mnxti: 0x345                              */
    bnez    a0, service_loop

    cont:
    /* Raise the level and priority of irq31 to enable it*/
    li    t0, 0x00210000            /* Base address for memory mapped CLIC registers */
    li    t1, 0x107c                /* t1 (Offset) = 0x1000+0x4*31       */
    add   t4, t0, t1                /* clic_base + irq28(II) offset */
    li    t2, 0x66
    slli  t3, t2, 0x18              /* lvl: 0x55 << 24 (CLICINT_CLICINT_CTL_OFFSET) */
    lw    t5, 0(t4)                 /* load reg */
    li    t1, 0x00ffffff            /* ~mask */
    and   t0, t5, t1                /* reg & ~mask */
    or    t6, t3, t0                /* (reg ~mask) | lvl */
    sw    t6, 0(t4)                 /* set irq31 level and priority       */

    csrrsi  t0, mstatus, MIE        /* Make sure interrupt is globally enabaled            */

    csrci mstatus, MIE              /* disable global interrupts*/
    lw t0, 64(sp)
    lw t1, 68(sp)
    csrw mcause, t0
    csrw mepc, t1

    csrrci  a0, CSR_MNXTI, MIE   /* CSR ADDR: mnxti: 0x345                              */
    bnez    a0, service_loop

    /* Print when leaving general interrupt handler */
    la    t0, clic_isr_3_hook
    lw    t0, 0(t0)                 /* load function pointer */
    jalr  t0                        /* vector into hook */

    lw ra, 0(sp)
    lw t0, 4(sp)
    lw t1, 8(sp)
    lw t2, 12(sp)
    lw a0, 16(sp)
    lw a1, 20(sp)
    lw a2, 24(sp)
    lw a3, 28(sp)
    lw a4, 32(sp)
    lw a5, 36(sp)
    lw a6, 40(sp)
    lw a7, 44(sp)
    lw t3, 48(sp)
    lw t4, 52(sp)
    lw t5, 56(sp)
    lw t6, 60(sp)
    addi sp, sp, (4 * 20)
    mret
.endfunc
.endm

.section .text.int
.global clic_setup_mtvec
.type clic_setup_mtvec,@function
clic_setup_mtvec:
    la   t0,  __clic_gen_handler
    or   t0,  t0, 1 /* enable clic mode TODO: change to 11 for clic mode */
    csrw mtvec, t0
    ret

.section .text.int
.global clic_setup_mtvt
.type clic_setup_mtvt,@function
clic_setup_mtvt:
	la t0, __clic_vector_table
	or t0, t0, 1 /* enable vectored mode TODO: should be clic mode */
	csrw 0x307, t0 /* mtvt=0x307 */
	ret

.section .text.vectors
default_exception_handler:
    j default_exception_handler
software_handler:
    j software_handler
timer_handler:
    j timer_handler
external_handler:
__no_irq_handler:
    j __no_irq_handler

.section .text.vectors
.option norvc
.balign 1024
.global __clic_vector_table
__clic_vector_table:
    j default_exception_handler
    j __no_irq_handler
    j __no_irq_handler
    j software_handler
    j __no_irq_handler
    j __no_irq_handler
    j __no_irq_handler
    j timer_handler
    j __no_irq_handler
    j __no_irq_handler
    j __no_irq_handler
    j external_handler
    j __no_irq_handler
    j __no_irq_handler
    j __no_irq_handler
    j __no_irq_handler
    j __no_irq_handler
    j __no_irq_handler
    j __no_irq_handler
    j __no_irq_handler
    j __no_irq_handler
    j __no_irq_handler
    j __no_irq_handler
    j __no_irq_handler
    j __no_irq_handler
    j __no_irq_handler
    j __handle_isr          /* irq26 (V)    */
    j __handle_oic          /* irq27 (OIC)  */
    j __handle_isr          /* irq28 (I)    */
    j __handle_isr          /* irq29 (II)   */
    j __handle_isr          /* irq30 (III)  */
    j __handle_shv          /* irq31 (IV)   */
