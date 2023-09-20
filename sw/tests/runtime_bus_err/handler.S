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
* Author: Robert Balas (balasr@iis.ee.ethz.ch)
*/

#include "clic.h"

.section .text.int
.global clic_setup_mtvec
.type clic_setup_mtvec,@function
clic_setup_mtvec:
	la t0, __clic_vector_table
	or t0, t0, 1 /* enable vectored mode */
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
	j external_handler
__no_irq_handler:
	j __no_irq_handler

.section .text.vectors
.option norvc
.balign 1024
.global __clic_vector_table
__clic_vector_table:
	j default_exception_handler /*  0 */
	j __no_irq_handler          /*  1 */
	j __no_irq_handler          /*  2 */
	j software_handler          /*  3, msip */
	j __no_irq_handler          /*  4 */
	j __no_irq_handler          /*  5 */
	j __no_irq_handler          /*  6 */
	j timer_handler             /*  7, timer[0] */
	j __no_irq_handler          /*  8 */
	j __no_irq_handler          /*  9, seip */
	j __no_irq_handler          /* 10 */
	j external_handler          /* 11, meip */
	j __no_irq_handler          /* 12 */
	j __no_irq_handler          /* 13 */
	j __no_irq_handler          /* 14 */
	j __no_irq_handler          /* 15 */
	j __no_irq_handler          /* 16, timer[0] */
	j __no_irq_handler          /* 17, timer[1] */
	j __no_irq_handler          /* 18, bus_err instr */
	j bus_err_handler           /* 19, bus_err data */
	j __no_irq_handler          /* 20, bus_err shadow */
	j __no_irq_handler          /* 21, TCLS resynch */
	j __no_irq_handler          /* 22 */
	j __no_irq_handler          /* 23 */
	j __no_irq_handler          /* 24 */
	j __no_irq_handler          /* 25 */
	j __no_irq_handler          /* 26 */
	j __no_irq_handler          /* 27 */
	j __no_irq_handler          /* 28 */
	j __no_irq_handler          /* 29 */
	j __no_irq_handler          /* 30 */
	j __no_irq_handler          /* 31 */
