/*
 * Copyright (C) 2021 ETH Zurich and University of Bologna
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

#ifndef __CLIC_H__
#define __CLIC_H__

/* Number of interrupt sources */
/* taken from target configuration */
/* #define CLIC_PARAM_NUM_SRC 256 */

/* Number of interrupt control bits */
/* taken from target configuration */
/* #define CLIC_PARAM_CLIC_INT_CTL_BITS 8 */

/* Register width */
#define CLIC_PARAM_REG_WIDTH 32

/* CLIC Configuration */
#define CLIC_CLICCFG_REG_OFFSET	 0x0
#define CLIC_CLICCFG_NVBITS_BIT	 0
#define CLIC_CLICCFG_NLBITS_MASK 0xf
#define CLIC_CLICCFG_NLBITS_OFFSET 1
#define CLIC_CLICCFG_NMBITS_MASK   0x3
#define CLIC_CLICCFG_NMBITS_OFFSET 5

/* CLIC Information */
#define CLIC_CLICINFO_REG_OFFSET	   0x4
#define CLIC_CLICINFO_NUM_INTERRUPT_MASK   0x1fff
#define CLIC_CLICINFO_NUM_INTERRUPT_OFFSET 0

#define CLIC_CLICINFO_VERSION_MASK   0xff
#define CLIC_CLICINFO_VERSION_OFFSET 13

#define CLIC_CLICINFO_CLICINTCTLBITS_MASK   0xf
#define CLIC_CLICINFO_CLICINTCTLBITS_OFFSET 21

#define CLIC_CLICINFO_NUM_TRIGGER_MASK	 0x3f
#define CLIC_CLICINFO_NUM_TRIGGER_OFFSET 25

/* CLIC enable mnxti irq forwarding logic */
#define CLIC_CLICXNXTICONF_REG_OFFSET 0x8
#define CLIC_CLICXNXTICONF_CLICXNXTICONF_BIT 0

/* CLIC interrupt id pending */
#define CLIC_CLICINTIP_REG_OFFSET(id) (0x1000 + 0x10 * id)
#define CLIC_CLICINTIP_CLICINTIP_BIT  0

/* CLIC interrupt id enable */
#define CLIC_CLICINTIE_REG_OFFSET(id) (0x1004 + 0x10 * id)
#define CLIC_CLICINTIE_CLICINTIE_BIT  0

/* CLIC interrupt id attributes */
#define CLIC_CLICINTATTR_REG_OFFSET(id) (0x1008 + 0x10 * id)
#define CLIC_CLICINTATTR_SHV_BIT	0
#define CLIC_CLICINTATTR_TRIG_MASK	0x3
#define CLIC_CLICINTATTR_TRIG_OFFSET	1
#define CLIC_CLICINTATTR_MODE_MASK	0x3
#define CLIC_CLICINTATTR_MODE_OFFSET	6

#ifndef __ASSEMBLER__
enum clic_trig {
	CLIC_TRIG_LEVEL = 0,
	CLIC_TRIG_EDGE = 1,
	CLIC_TRIG_POSITIVE = 0 << 1,
	CLIC_TRIG_NEGATIVE = 1 << 1
};
#endif

/* CLIC interrupt id control */
#define CLIC_CLICINTCTL_REG_OFFSET(id)	  (0x100c + 0x10 * id)
#define CLIC_CLICINTCTL_CLICINTCTL_MASK	  0xff
#define CLIC_CLICINTCTL_CLICINTCTL_OFFSET 0

#define CSR_MXNTI_ID       0x345
#define MIE                8

#endif /* __CLIC_H__ */
