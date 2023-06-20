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
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j __no_irq_handler
	j check_status_handler
