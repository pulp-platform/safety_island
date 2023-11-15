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

#include "MatrixMul32_stimuli.h"

// CLIC includes
#include "csr.h"
#include "io.h"
#include "clic.h"
#include "clicint.h"

#define TCLS_RESYNCH_IRQ 21

void matrix_init() {
  int i, j;
  // init, copy to TCDM
  for(i = 0; i < SIZE; i++) {
    for(j = 0; j < SIZE; j++) {
      g_mA[i][j] = m_a[i * SIZE + j];
      g_mB[i][j] = m_b[i * SIZE + j];
      g_mC[i][j] = 0;
    }
  }
}

unsigned int matrix_check() {
    int i, j;
  unsigned int errors = 0;
  // check
  for(i = 0; i < SIZE; i++) {
    for(j = 0; j < SIZE; j++) {
      if(g_mC[i][j] != m_exp[i * SIZE + j]) {
        printf("At index %d, %d: %d, %d\n", i, j, g_mC[i][j], m_exp[i * SIZE + j]);
        errors++;
      }
    }
  }

  return errors;
}

int main(void) {
    unsigned int errors = 0;

    // Set up TCLS mode

    printf("TCLS config: %x\n", readw(ARCHI_HMR_ADDR + HMR_TOP_OFFSET + HMR_REGISTERS_AVAIL_CONFIG_REG_OFFSET));


    writew(
        (0 ? 1<<HMR_TMR_REGS_TMR_CONFIG_DELAY_RESYNCH_BIT  : 0) |
        (0 ? 1<<HMR_TMR_REGS_TMR_CONFIG_SETBACK_BIT        : 0) |
        (0 ? 1<<HMR_TMR_REGS_TMR_CONFIG_RELOAD_SETBACK_BIT : 0) |
        (0 ? 1<<HMR_TMR_REGS_TMR_CONFIG_RAPID_RECOVERY_BIT : 0) |
        (0 ? 1<<HMR_TMR_REGS_TMR_CONFIG_SYNCH_REQ_BIT      : 0),
        ARCHI_HMR_ADDR + HMR_TMR_OFFSET + HMR_TMR_REGS_TMR_CONFIG_REG_OFFSET
    );



    // Set up TCLS IRQ & IRQs in general

    uint32_t mclicbase;
    mclicbase = csr_read(CSR_MCLICBASE);
    // redirect vector table
    clic_setup_mtvec();
    clic_setup_mtvt();

    // Use vector jump, not default handler
    writew((0x1 << CLICINT_CLICINT_ATTR_SHV_BIT) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(TCLS_RESYNCH_IRQ)) & ~(0x1 << CLICINT_CLICINT_ATTR_SHV_BIT)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(TCLS_RESYNCH_IRQ));


    // set to edge-sensitive for TCLS_RESYNCH_IRQ
    writew((0x1 << CLICINT_CLICINT_ATTR_TRIG_OFFSET) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(TCLS_RESYNCH_IRQ)) &
                ~(CLICINT_CLICINT_ATTR_TRIG_MASK << CLICINT_CLICINT_ATTR_TRIG_OFFSET)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(TCLS_RESYNCH_IRQ));

    // Set nlbits, (level/priority global config)
    writew((0x4 << MCLIC_MCLICCFG_MNLBITS_OFFSET), mclicbase + MCLIC_MCLICCFG_REG_OFFSET);

    // set interrupt level and priority for interrupt TCLS_RESYNCH_IRQ to 0xaa (because this is the value in other tests)
    writew((0xaa << CLICINT_CLICINT_CTL_OFFSET) | (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(TCLS_RESYNCH_IRQ)) &
                                                   ~(CLICINT_CLICINT_CTL_MASK << CLICINT_CLICINT_CTL_OFFSET)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(TCLS_RESYNCH_IRQ));

    // enable interrupt TCLS_RESYNCH_IRQ on clic
    writew((0x1 << CLICINT_CLICINT_IE_BIT) |
               (readw(mclicbase + CLICINT_CLICINT_REG_OFFSET(TCLS_RESYNCH_IRQ)) & ~(0X1 << CLICINT_CLICINT_IE_BIT)),
           mclicbase + CLICINT_CLICINT_REG_OFFSET(TCLS_RESYNCH_IRQ));

    // Set interrupt threshold to enable all
    csr_write(CSR_MINTTHRESH, 0); /* 0 < xx */

    // Set up MatMul

    matrix_init();

    // nop break to find target section in simulation
    for (int i = 0; i < 10000; i++) {
        asm volatile ("nop");
    }

    // Do MatMul (FI should happen during)

    int i, j, k;

    for(i = 0; i < SIZE; i++) {
        for(j = 0; j < SIZE; j++) {
            g_mC[i][j] = 0;

            for(k = 0; k < SIZE; k++) {
                g_mC[i][j] += g_mA[i][k] * g_mB[k][j];
            }
        }
    }

    // nop break to find target section in simulation
    for (int i = 0; i < 10000; i++) {
        asm volatile ("nop");
    }

    // Check MatMul result

    errors += matrix_check();

    printf("gma: %x\n", g_mA);
    printf("gmb: %x\n", g_mB);
    printf("gmc: %x\n", g_mC);

    printf("ma: %x\n", m_a);
    printf("mb: %x\n", m_b);
    printf("mc: %x\n", m_exp);

    // Check recovery count/error count

    int mismatch_count;

    mismatch_count = readw(ARCHI_HMR_ADDR + HMR_CORE_OFFSET + HMR_CORE_REGS_MISMATCHES_REG_OFFSET);

    printf("Mismatch count: %d\n", mismatch_count);

    if (mismatch_count != 2) {
        errors += 1;
    }











    return errors;
}
