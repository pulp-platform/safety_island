/*
 * Copyright (C) 2023 ETH Zurich, University of Bologna
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


#ifndef __ARCHI_CHIPS_SAFETY_ISLAND_MEMORY_MAP_H__
#define __ARCHI_CHIPS_SAFETY_ISLAND_MEMORY_MAP_H__

#ifdef CARFIELD
#define ARCHI_SAFETY_ISLAND_BASE_ADDR 0x60000000
#else
#define ARCHI_SAFETY_ISLAND_BASE_ADDR 0x00000000
#endif
#define ARCHI_SAFETY_ISLAND_PERIPH_OFFSET 0x00200000
#define ARCHI_SAFETY_ISLAND_MEM_OFFSET 0x00000000

/*
 * MEMORIES
 */

#define ARCHI_LOCAL_PRIV0_ADDR  ( ARCHI_SAFETY_ISLAND_BASE_ADDR + ARCHI_SAFETY_ISLAND_MEM_OFFSET )
#define ARCHI_LOCAL_PRIV0_SIZE  0x00010000

#define ARCHI_LOCAL_PRIV1_ADDR  ( ARCHI_LOCAL_PRIV0_ADDR + ARCHI_LOCAL_PRIV0_SIZE )
#define ARCHI_LOCAL_PRIV1_SIZE  0x00010000

// L2 alias
#define ARCHI_L2_PRIV0_ADDR  ARCHI_LOCAL_PRIV0_ADDR
#define ARCHI_L2_PRIV0_SIZE  ARCHI_LOCAL_PRIV0_SIZE

#define ARCHI_L2_PRIV1_ADDR  ARCHI_LOCAL_PRIV1_ADDR
#define ARCHI_L2_PRIV1_SIZE  ARCHI_LOCAL_PRIV1_SIZE

// Shared L2
#define ARCHI_L2_SHARED_ADDR 0
#define ARCHI_L2_SHARED_SIZE 0

/*
 * PERIPHERALS
 */

#define ARCHI_SAFETY_ISLAND_PERIPHERALS_ADDR    ( ARCHI_SAFETY_ISLAND_BASE_ADDR + ARCHI_SAFETY_ISLAND_PERIPH_OFFSET )

#define ARCHI_SOC_CTRL_OFFSET       0x00000000
#define ARCHI_BOOT_ROM_OFFSET       0x00001000
#define ARCHI_GLOBAL_PREPEND_OFFSET 0x00002000
#define ARCHI_DEBUG_OFFSET          0x00003000
#define ARCHI_CLIC_OFFSET           0x00010000
#define ARCHI_HMR_OFFSET            0x00005000
#define ARCHI_STDOUT_OFFSET     0x00006000

#define ARCHI_SOC_CTRL_ADDR         ( ARCHI_SAFETY_ISLAND_PERIPHERALS_ADDR + ARCHI_SOC_CTRL_OFFSET )
#define ARCHI_BOOT_ROM_ADDR         ( ARCHI_SAFETY_ISLAND_PERIPHERALS_ADDR + ARCHI_BOOT_ROM_OFFSET )
#define ARCHI_GLOBAL_PREPEND_ADDR   ( ARCHI_SAFETY_ISLAND_PERIPHERALS_ADDR + ARCHI_GLOBAL_PREPEND_OFFSET )
#define ARCHI_DEBUG_ADDR            ( ARCHI_SAFETY_ISLAND_PERIPHERALS_ADDR + ARCHI_DEBUG_OFFSET )
#define ARCHI_CLIC_ADDR             ( ARCHI_SAFETY_ISLAND_PERIPHERALS_ADDR + ARCHI_CLIC_OFFSET )
#define ARCHI_HMR_ADDR              ( ARCHI_SAFETY_ISLAND_PERIPHERALS_ADDR + ARCHI_HMR_OFFSET )
#define ARCHI_STDOUT_ADDR           ( ARCHI_SAFETY_ISLAND_PERIPHERALS_ADDR + ARCHI_STDOUT_OFFSET )

#endif
