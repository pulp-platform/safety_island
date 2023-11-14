// Copyright 2022 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Nicole Narr <narrn@student.ethz.ch>
// Christopher Reinwardt <creinwar@student.ethz.ch>
// Paul Scheffler <paulsc@iis.ee.ethz.ch>
// Robert Balas <balasr@iis.ee.ethz.ch>
// Alessandro Ottaviano <aottaviano@iis.ee.ethz.ch>
//
// This header provides information defined by hardware parameters, such as
// the address map. In the future, it should be generated automatically as
// part of the SoC generation process.

#ifndef __CAR_MEMORY_MAP_H
#define __CAR_MEMORY_MAP_H

// Base addresses provided at link time
extern void *__base_l2;

// Main Islands and accelerators

// L2 port 0
#define CAR_L2_SPM_PORT0_INTERLEAVED_BASE_ADDR 0x78000000
#define CAR_L2_SPM_PORT0_INTERLEAVED_END_ADDR  0x78100000
#define CAR_L2_SPM_PORT0_CONTIGUOUS_BASE_ADDR  0x78100000
#define CAR_L2_SPM_PORT0_CONTIGUOUS_END_ADDR   0x78200000

// L2 port 1
#define CAR_L2_SPM_PORT1_INTERLEAVED_BASE_ADDR 0x78200000
#define CAR_L2_SPM_PORT1_INTERLEAVED_END_ADDR  0x78300000
#define CAR_L2_SPM_PORT1_CONTIGUOUS_BASE_ADDR  0x78300000
#define CAR_L2_SPM_PORT1_CONTIGUOUS_END_ADDR   0x78400000

// Safety Island
#define CAR_SAFETY_ISLAND_SPM_BASE_ADDR      0x60000000
#define CAR_SAFETY_ISLAND_SPM_END_ADDR       0x60020000
#define CAR_SAFETY_ISLAND_PERIPHERALS_OFFSET 0x00200000
#define CAR_SAFETY_ISLAND_SOC_CTRL_OFFSET    0x00000000
#define CAR_SAFETY_ISLAND_ENTRY_POINT        (CAR_SAFETY_ISLAND_SPM_BASE_ADDR + 0x00010080)
#define CAR_SAFETY_ISLAND_SOC_CTRL_ADDR      (CAR_SAFETY_ISLAND_SPM_BASE_ADDR + CAR_SAFETY_ISLAND_PERIPHERALS_OFFSET + CAR_SAFETY_ISLAND_SOC_CTRL_OFFSET)

#define CAR_SAFETY_ISLAND_BOOTADDR_ADDR      (CAR_SAFETY_ISLAND_SOC_CTRL_ADDR + SAFETY_SOC_CTRL_BOOTADDR_REG_OFFSET)
#define CAR_SAFETY_ISLAND_FETCHEN_ADDR       (CAR_SAFETY_ISLAND_SOC_CTRL_ADDR + SAFETY_SOC_CTRL_FETCHEN_REG_OFFSET)
#define CAR_SAFETY_ISLAND_BOOTMODE_ADDR      (CAR_SAFETY_ISLAND_SOC_CTRL_ADDR + SAFETY_SOC_CTRL_BOOTMODE_REG_OFFSET)
#define CAR_SAFETY_ISLAND_CORESTATUS_ADDR    (CAR_SAFETY_ISLAND_SOC_CTRL_ADDR + SAFETY_SOC_CTRL_CORESTATUS_REG_OFFSET)

#define CAR_SAFETY_ISLAND_PERIPHS_BASE_ADDR 0x60200000
#define CAR_SAFETY_ISLAND_PERIPHS_END_ADDR 0x60300000

// Integer Cluster
#define CAR_INT_CLUSTER_SPM_BASE_ADDR 0x50000000
#define CAR_INT_CLUSTER_SPM_END_ADDR  0x50040000

#define CAR_INT_CLUSTER_PERIPH_OFFS           0x00200000
#define CAR_INT_CLUSTER_CTRL_UNIT_OFFS        0x00000000
#define CAR_INT_CLUSTER_CTRL_UNIT_RETURN_OFFS 0x100
#define CAR_INT_CLUSTER_RETURN_ADDR (CAR_INT_CLUSTER_SPM_BASE_ADDR + CAR_INT_CLUSTER_PERIPH_OFFS + CAR_INT_CLUSTER_CTRL_UNIT_OFFS + CAR_INT_CLUSTER_CTRL_UNIT_RETURN_OFFS)

#define CAR_INT_CLUSTER_BOOT_ADDR_OFFS 0x40
#define CAR_INT_CLUSTER_BOOT_ADDR_REG (CAR_INT_CLUSTER_SPM_BASE_ADDR + CAR_INT_CLUSTER_PERIPH_OFFS + CAR_INT_CLUSTER_CTRL_UNIT_OFFS + CAR_INT_CLUSTER_BOOT_ADDR_OFFS)

// Floating Point Spatz Cluster
#define CAR_FP_CLUSTER_SPM_BASE_ADDR 0x51000000
#define CAR_FP_CLUSTER_SPM_END_ADDR  0x51020000

#define CAR_FP_CLUSTER_PERIPHS_BASE_ADDR 0x51020000
// #define CAR_FP_CLUSTER_PERIPHS_END_ADDR  unknown

// HyperRAM
#define CAR_HYPERRAM_BASE_ADDR 0x80400000
#define CAR_HYPERRAM_END_ADDR  0x80800000

// Peripheral devices
// from cheshire
#define CAR_BOOTROM_BASE_ADDR        0x000002000000
#define CAR_CLINT_BASE_ADDR          0x000002040000 // for both cores
#define CAR_IRQ_ROUTER_BASE_ADDR     0x000002080000
#define CAR_IRQ_AXI_REALM_BASE_ADDR  0x0000020c0000
#define CAR_CHESHIRE_CFG_BASE_ADDR   0x000003000000
#define CAR_LLC_CFG_BASE_ADDR        0x000003001000
#define CAR_CLIC_CFG_BASE_ADDR(id)   0x000008000000

// from carfield proper
#define CAR_PERIPHS_BASE_ADDR        0x20000000

#define CAR_ETHERNET_OFFSET          0x0000
#define CAR_CAN_OFFSET               0x1000
#define CAR_SYSTEM_TIMER_OFFSET      0x4000
#define CAR_ADVANCED_TIMER_OFFSET    0x5000
#define CAR_WATCHDOG_TIMER_OFFSET    0x7000
#define CAR_HYPERBUS_CFG_OFFSET      0x9000
#define CAR_PAD_CFG_OFFSET           0xa000
#define CAR_SOC_CTRL_OFFSET          0x10000

#define CAR_ETHERNET_BASE_ADDR       (CAR_PERIPHS_BASE_ADDR + CAR_ETHERNET_OFFSET)
#define CAR_CAN_BASE_ADDR            (CAR_PERIPHS_BASE_ADDR + CAR_CAN_OFFSET)
#define CAR_SYSTEM_TIMER_BASE_ADDR   (CAR_PERIPHS_BASE_ADDR + CAR_SYSTEM_TIMER_OFFSET)
#define CAR_ADVANCED_TIMER_BASE_ADDR (CAR_PERIPHS_BASE_ADDR + CAR_ADVANCED_TIMER_OFFSET)
#define CAR_WATCHDOG_TIMER_BASE_ADDR (CAR_PERIPHS_BASE_ADDR + CAR_WATCHDOG_TIMER_OFFSET)
#define CAR_HYPERBUS_CFG_BASE_ADDR   (CAR_PERIPHS_BASE_ADDR + CAR_HYPERBUS_CFG_OFFSET)
#define CAR_PAD_CFG_BASE_ADDR        (CAR_PERIPHS_BASE_ADDR + CAR_PAD_CFG_OFFSET)
#define CAR_SOC_CTRL_BASE_ADDR       (CAR_PERIPHS_BASE_ADDR + CAR_SOC_CTRL_OFFSET)

// Mailbox
#define CAR_NUM_MAILBOXES            25
#define CAR_MBOX_BASE_ADDR           0x40000000

#define MBOX_INT_SND_STAT_OFFSET     0x00
#define MBOX_INT_SND_SET_OFFSET      0x04
#define MBOX_INT_SND_CLR_OFFSET      0x08
#define MBOX_INT_SND_EN_OFFSET       0x0C
#define MBOX_INT_RCV_STAT_OFFSET     0x40
#define MBOX_INT_RCV_SET_OFFSET      0x44
#define MBOX_INT_RCV_CLR_OFFSET      0x48
#define MBOX_INT_RCV_EN_OFFSET       0x4C
#define MBOX_LETTER0_OFFSET          0x80
#define MBOX_LETTER1_OFFSET          0x84

#define MBOX_CAR_INT_SND_STAT(id)		  (CAR_MBOX_BASE_ADDR + MBOX_INT_SND_STAT_OFFSET + (id*0x100))
#define MBOX_CAR_INT_SND_SET(id)          (CAR_MBOX_BASE_ADDR + MBOX_INT_SND_SET_OFFSET  + (id*0x100))
#define MBOX_CAR_INT_SND_CLR(id)          (CAR_MBOX_BASE_ADDR + MBOX_INT_SND_CLR_OFFSET  + (id*0x100))
#define MBOX_CAR_INT_SND_EN(id)           (CAR_MBOX_BASE_ADDR + MBOX_INT_SND_EN_OFFSET   + (id*0x100))
#define MBOX_CAR_INT_RCV_STAT(id)         (CAR_MBOX_BASE_ADDR + MBOX_INT_RCV_STAT_OFFSET + (id*0x100))
#define MBOX_CAR_INT_RCV_SET(id)          (CAR_MBOX_BASE_ADDR + MBOX_INT_RCV_SET_OFFSET  + (id*0x100))
#define MBOX_CAR_INT_RCV_CLR(id)          (CAR_MBOX_BASE_ADDR + MBOX_INT_RCV_CLR_OFFSET  + (id*0x100))
#define MBOX_CAR_INT_RCV_EN(id)           (CAR_MBOX_BASE_ADDR + MBOX_INT_RCV_EN_OFFSET   + (id*0x100))
#define MBOX_CAR_LETTER0(id)              (CAR_MBOX_BASE_ADDR + MBOX_LETTER0_OFFSET      + (id*0x100))
#define MBOX_CAR_LETTER1(id)              (CAR_MBOX_BASE_ADDR + MBOX_LETTER1_OFFSET      + (id*0x100))


// PLL
#define CAR_PLL_BASE_ADDRESS         0x20020000
#define PLL_ADDR_SPACE               0x200
#define PLL_BASE_ADDRESS(id)         (CAR_PLL_BASE_ADDRESS + (id+1)*PLL_ADDR_SPACE)

// Error codes
#define EHOSTDEXEC 1 // Execution error host domain
#define ESAFEDEXEC 2 // Execution error safe domain
#define EINTCLEXEC 3 // Execution error integer cluster
#define EFPCLEXEC  4 // Execution error floating point cluster

// Memory-mapped registers
#define CAR_INT_CLUSTER_FETCHEN_ADDR (CAR_SOC_CTRL_BASE_ADDR + CARFIELD_PULP_CLUSTER_FETCH_ENABLE_REG_OFFSET)
#define CAR_INT_CLUSTER_BOOTEN_ADDR  (CAR_SOC_CTRL_BASE_ADDR + CARFIELD_PULP_CLUSTER_BOOT_ENABLE_REG_OFFSET)
#define CAR_INT_CLUSTER_BUSY_ADDR    (CAR_SOC_CTRL_BASE_ADDR + CARFIELD_PULP_CLUSTER_BUSY_REG_OFFSET)
#define CAR_INT_CLUSTER_EOC_ADDR     (CAR_SOC_CTRL_BASE_ADDR + CARFIELD_PULP_CLUSTER_EOC_REG_OFFSET)

#endif /* __CAR_MEMORY_MAP_H */
