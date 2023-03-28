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

#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include "pulp.h"

int main(void)
{
    volatile int unsigned timer_addr = timer_base_fc(0, 1);
    printf("Timer addr: %x\n\r", timer_addr);

    printf("Reset timer \r\n");
    timer_reset(timer_addr);

    printf("Start timer \r\n");
    timer_start(timer_addr);

    for (volatile int i=0; i< 500; i++)
	;

    timer_conf_set(timer_addr, 0);
    printf("Timer stopped \r\n");

    volatile int time = timer_count_get(timer_addr);
    printf("Free-running timer value: %d\r\n", time);

    return 0;
}
