// Generated register defines for safety_soc_ctrl_icache

// Copyright information found in source file:
// Copyright 2023 ETH Zurich and University of Bologna

// Licensing information found in source file:
// 
// SPDX-License-Identifier: SHL-0.51

#ifndef _SAFETY_SOC_CTRL_ICACHE_REG_DEFS_
#define _SAFETY_SOC_CTRL_ICACHE_REG_DEFS_

#ifdef __cplusplus
extern "C" {
#endif
// Register width
#define SAFETY_SOC_CTRL_ICACHE_PARAM_REG_WIDTH 32

// Core Boot Address
#define SAFETY_SOC_CTRL_ICACHE_BOOTADDR_REG_OFFSET 0x0

// Core Fetch Enable
#define SAFETY_SOC_CTRL_ICACHE_FETCHEN_REG_OFFSET 0x4
#define SAFETY_SOC_CTRL_ICACHE_FETCHEN_FETCHEN_BIT 0

// Core Return Status (return value, EOC)
#define SAFETY_SOC_CTRL_ICACHE_CORESTATUS_REG_OFFSET 0x8

// Core Boot Mode
#define SAFETY_SOC_CTRL_ICACHE_BOOTMODE_REG_OFFSET 0xc
#define SAFETY_SOC_CTRL_ICACHE_BOOTMODE_BOOTMODE_MASK 0x3
#define SAFETY_SOC_CTRL_ICACHE_BOOTMODE_BOOTMODE_OFFSET 0
#define SAFETY_SOC_CTRL_ICACHE_BOOTMODE_BOOTMODE_FIELD \
  ((bitfield_field32_t) { .mask = SAFETY_SOC_CTRL_ICACHE_BOOTMODE_BOOTMODE_MASK, .index = SAFETY_SOC_CTRL_ICACHE_BOOTMODE_BOOTMODE_OFFSET })

// Enable iCache prefetching
#define SAFETY_SOC_CTRL_ICACHE_ICACHE_ENABLE_PREFETCH_REG_OFFSET 0x10
#define SAFETY_SOC_CTRL_ICACHE_ICACHE_ENABLE_PREFETCH_PREFETCH_ENABLE_BIT 0

// Flush iCache
#define SAFETY_SOC_CTRL_ICACHE_ICACHE_FLUSH_REG_OFFSET 0x14
#define SAFETY_SOC_CTRL_ICACHE_ICACHE_FLUSH_FLUSH_BIT 0

// iCache Performance Counter Control
#define SAFETY_SOC_CTRL_ICACHE_ICACHE_PERFCTR_CTRL_REG_OFFSET 0x18
#define SAFETY_SOC_CTRL_ICACHE_ICACHE_PERFCTR_CTRL_ENABLE_BIT 0
#define SAFETY_SOC_CTRL_ICACHE_ICACHE_PERFCTR_CTRL_CLEAR_ALL_BIT 16

// Performance counters (common parameters)
#define SAFETY_SOC_CTRL_ICACHE_COUNTERS_COUNTER_FIELD_WIDTH 32
#define SAFETY_SOC_CTRL_ICACHE_COUNTERS_COUNTER_FIELDS_PER_REG 1
#define SAFETY_SOC_CTRL_ICACHE_COUNTERS_MULTIREG_COUNT 9

// Performance counters
#define SAFETY_SOC_CTRL_ICACHE_COUNTERS_0_REG_OFFSET 0x1c

// Performance counters
#define SAFETY_SOC_CTRL_ICACHE_COUNTERS_1_REG_OFFSET 0x20

// Performance counters
#define SAFETY_SOC_CTRL_ICACHE_COUNTERS_2_REG_OFFSET 0x24

// Performance counters
#define SAFETY_SOC_CTRL_ICACHE_COUNTERS_3_REG_OFFSET 0x28

// Performance counters
#define SAFETY_SOC_CTRL_ICACHE_COUNTERS_4_REG_OFFSET 0x2c

// Performance counters
#define SAFETY_SOC_CTRL_ICACHE_COUNTERS_5_REG_OFFSET 0x30

// Performance counters
#define SAFETY_SOC_CTRL_ICACHE_COUNTERS_6_REG_OFFSET 0x34

// Performance counters
#define SAFETY_SOC_CTRL_ICACHE_COUNTERS_7_REG_OFFSET 0x38

// Performance counters
#define SAFETY_SOC_CTRL_ICACHE_COUNTERS_8_REG_OFFSET 0x3c

#ifdef __cplusplus
}  // extern "C"
#endif
#endif  // _SAFETY_SOC_CTRL_ICACHE_REG_DEFS_
// End generated register defines for safety_soc_ctrl_icache