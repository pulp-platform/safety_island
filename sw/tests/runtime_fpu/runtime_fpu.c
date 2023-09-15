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

int main(void) {

    volatile float op1 = 0.5f;
    volatile float op2 = 5.0f;
    volatile float add, sub, mult, div;

    volatile float add_exp = 5.5f;
    volatile float sub_exp = 4.5f;
    volatile float mult_exp = 2.5f;
    volatile float div_exp = 10.0f;

    add = op1 + op2;
    sub = op2 - op1;
    mult = op1 * op2;
    div = op2 / op1;

    printf("Sum: %f\r\nSub: %f\r\nMult: %f\r\nDiv: %f\r\n", add, sub, mult, div);

    unsigned int errors = 0;

    if (add != add_exp) {
        errors += 1;
    }
    if (sub != sub_exp) {
        errors += 1;
    }

    if (mult != mult_exp) {
        errors += 1;
    }

    if (div != div_exp) {
        errors += 1;
    }

    printf("Errors: %d\r\n", errors);

    return errors;
}
