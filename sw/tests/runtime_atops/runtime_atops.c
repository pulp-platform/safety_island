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

//===============================================================
// RISC-V atomic instruction wrappers
//===============================================================

static inline uint32_t lr_w(volatile uint32_t* addr) {
    uint32_t data = 0;
    asm volatile("lr.w %[data], (%[addr])"
                 : [ data ] "+r"(data)
                 : [ addr ] "r"(addr)
                 : "memory");
    return data;
}

static inline uint32_t sc_w(volatile uint32_t* addr, uint32_t data) {
    uint32_t err = 0;
    asm volatile("sc.w %[err], %[data], (%[addr])"
                 : [ err ] "+r"(err)
                 : [ addr ] "r"(addr), [ data ] "r"(data)
                 : "memory");
    return err;
}

static inline uint32_t atomic_maxu_fetch(volatile uint32_t* addr,
                                         uint32_t data) {
    uint32_t prev = 0;
    asm volatile("amomaxu.w %[prev], %[data], (%[addr])"
                 : [ prev ] "+r"(prev)
                 : [ addr ] "r"(addr), [ data ] "r"(data)
                 : "memory");
    return prev;
}

static inline uint32_t atomic_minu_fetch(volatile uint32_t* addr,
                                         uint32_t data) {
    uint32_t prev = 0;
    asm volatile("amominu.w %[prev], %[data], (%[addr])"
                 : [ prev ] "+r"(prev)
                 : [ addr ] "r"(addr), [ data ] "r"(data)
                 : "memory");
    return prev;
}

//===============================================================
// Test all atomics on a given memory location (single core)
//===============================================================

uint32_t test_atomics(volatile uint32_t* atomic_var) {
    uint32_t tmp = 0;
    uint32_t nerrors = 0;
    uint32_t dummy_val = 42;
    uint32_t amo_operand;
    uint32_t expected_val;

    /******************************************************
     * Initialize
     ******************************************************/
    *atomic_var = 0;

    /******************************************************
     * Test 0: SC without previously acquiring lock
     *
     * We expect the SC to return an error and the lock
     * to not be overwritten.
     ******************************************************/
    amo_operand = dummy_val;
    expected_val = *atomic_var;
    tmp = sc_w(atomic_var, amo_operand);
    if (!tmp) nerrors++;
    if (*atomic_var != expected_val) nerrors++;

    /******************************************************
     * Test 1: LR/SC sequence
     *
     * We expect the LR to return zero. That is the
     * initial value of lock. We expect the SC not to fail
     * and lock to be updated to the stored value.
     ******************************************************/
    expected_val = *atomic_var;
    tmp = lr_w(atomic_var);
    if (tmp != expected_val) nerrors++;

    amo_operand = dummy_val;
    expected_val = amo_operand;
    tmp = sc_w(atomic_var, amo_operand);
    if (tmp) nerrors++;
    if (*atomic_var != expected_val) nerrors++;

    /******************************************************
     * Test 2: AMOADD
     ******************************************************/
    amo_operand = 1;
    expected_val += amo_operand;
    __atomic_add_fetch(atomic_var, amo_operand, __ATOMIC_RELAXED);
    if (*atomic_var != expected_val) nerrors++;

    /******************************************************
     * Test 3: AMOSUB
     ******************************************************/
    amo_operand = 1;
    expected_val -= amo_operand;
    __atomic_sub_fetch(atomic_var, amo_operand, __ATOMIC_RELAXED);
    if (*atomic_var != expected_val) nerrors++;

    /******************************************************
     * Test 4: AMOAND
     *
     * Clear the second least-significant bit.
     ******************************************************/
    amo_operand = ~(1 << 1);
    expected_val &= amo_operand;
    __atomic_and_fetch(atomic_var, amo_operand, __ATOMIC_RELAXED);
    if (*atomic_var != expected_val) nerrors++;

    /******************************************************
     * Test 5: AMOOR
     *
     * Assert the second least-significant bit.
     ******************************************************/
    amo_operand = 1 << 1;
    expected_val |= amo_operand;
    __atomic_or_fetch(atomic_var, amo_operand, __ATOMIC_RELAXED);
    if (*atomic_var != expected_val) nerrors++;

    /******************************************************
     * Test 6: AMOXOR
     *
     * Toggle the second least-significant bit.
     ******************************************************/
    amo_operand = 1 << 1;
    expected_val ^= amo_operand;
    __atomic_xor_fetch(atomic_var, amo_operand, __ATOMIC_RELAXED);
    if (*atomic_var != expected_val) nerrors++;

    /******************************************************
     * Test 7: AMOMAXU
     *
     * Max between lock and the incremented value.
     * Expects incremented value to be stored.
     ******************************************************/
    amo_operand = expected_val + 1;
    expected_val = expected_val > amo_operand ? expected_val : amo_operand;
    atomic_maxu_fetch(atomic_var, amo_operand);
    if (*atomic_var != expected_val) nerrors++;

    /******************************************************
     * Test 8: AMOMINU
     *
     * Max between lock and the decremented value.
     * Expects decremented value to be stored.
     ******************************************************/
    amo_operand = expected_val - 1;
    expected_val = expected_val < amo_operand ? expected_val : amo_operand;
    atomic_minu_fetch(atomic_var, amo_operand);
    if (*atomic_var != expected_val) nerrors++;

    /******************************************************
     * Test 9: AMOSWAP
     ******************************************************/
    amo_operand = dummy_val;
    expected_val = dummy_val;
    __atomic_exchange_n(atomic_var, amo_operand, __ATOMIC_RELAXED);
    if (*atomic_var != expected_val) nerrors++;

    return nerrors;
}

int main(void) {
    unsigned int nerrors = 0;

    volatile uint32_t* local = pi_l2_malloc(sizeof(uint32_t));

    printf("Testing atomics at 0x%x\n", local);

    nerrors += test_atomics(&local);

    volatile uint32_t* ext = pi_l2_shared_malloc(sizeof(uint32_t));

    printf("Testing atomics at 0x%x\n", ext);

    nerrors += test_atomics(&ext);

    return 0;
}
