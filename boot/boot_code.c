/*
 * Copyright (C) 2021 ETH Zurich, University of Bologna and GreenWaves
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

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "config.h"
#include "archi/pulp.h"

static inline void __attribute__((noreturn))
jump_to_address(unsigned int address)
{
    goto *(uint32_t *)address;

    for (;;)
        ;
}

void __attribute__((noreturn)) boot_preloaded(void)
{
    /* load bootaddr and jump there */
    uint32_t *bootaddr = (uint32_t *)((ARCHI_READ(ARCHI_SOC_CTRL_ADDR, SAFETY_SOC_CTRL_BOOTMODE_REG_OFFSET)));
    goto *bootaddr; /* gcc extension */
}

void __attribute__((noreturn)) boot_jtag_openocd(void)
{
    /* wait for openocd to take over */
    /* TODO: do we need this hal_itc_enable_value_set(0); */

    for (;;)
        asm volatile("wfi");
}

/* TODO: some default */
#define BOOT_MODE_DEFAULT 0
/* trigger fetch enable, busy loop. OpenOCD can take over the hart safely */
#define BOOT_MODE_JTAG_OPENOCD 1
/* preload the memory with binary, write entry point to BOOTADDR register,
 * trigger fetch enable register through write or signal */
#define BOOT_MODE_PRELOADED 2

void __attribute__((noreturn)) main(void)
{
    /*
     *  Current boot modes:
     *  bootsel     meaning
     *  2'b0        default boot (to be determined)
     *  2'b1        jtag boot for openocd (busy loop)
     *  2'b2        preloaded boot (jump to address in bootaddr register)
     */

    switch (ARCHI_READ(ARCHI_SOC_CTRL_ADDR, SAFETY_SOC_CTRL_BOOTMODE_REG_OFFSET)) {
    case BOOT_MODE_DEFAULT:
        break;
    case BOOT_MODE_JTAG_OPENOCD:
        boot_jtag_openocd();
        break;
    case BOOT_MODE_PRELOADED:
        boot_preloaded();
        break;
    default: /* not possible */
        break;
    }

    /* TODO: determine fallback boot mode */
    for (;;)
        ;
}
