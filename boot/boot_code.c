/*
 * Copyright (C) 2023 ETH Zurich, University of Bologna and GreenWaves
 * Technologies
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
 */
#include "config.h"
#include "archi/pulp.h"
#include "stdint.h"

static inline void __attribute__((noreturn))
jump_to_address(unsigned int address)
{
    goto *(uint32_t *)address;

    for (;;)
        ;
}

// static inline void __attribute__((noreturn))
// jump_to_entry(flash_v2_header_t *header)
// {

//     apb_soc_bootaddr_set(header->bootaddr);
//     jump_to_address(header->entry);

//     for (;;)
//         ;
// }

void __attribute__((noreturn)) main(void)
{
  for (;;)
    ;
}