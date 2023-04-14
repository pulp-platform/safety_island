/*
 * Copyright 2021 ETH Zurich
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by apclicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 * Author: Robert Balas (balasr@iis.ee.ethz.ch)
 */

/* Test whether we can access CLIC specific CSRs */

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "csr.h"
#include "io.h"
#include "pulp.h"

#include "clic.h"

#define assert(expression) \
    do { \
        if (!(expression)) { \
            printf("%s:%d: assert error\n", __FILE__, __LINE__); \
            exit(1); \
        } \
    } while (0)

int main(void) {
    uint32_t mintstatus;
    uint32_t mcause;

    printf("test CSR_MINTTHRESH\n");
    uint32_t thresh = 0xffaa;
    uint32_t cmp = 0;
    csr_write(CSR_MINTTHRESH, thresh);
    cmp = csr_read(CSR_MINTTHRESH);
    csr_write(CSR_MINTTHRESH, 0);   /* reset threshold */
    assert(cmp == (thresh & 0xff)); /* only lower 8 bits are writable */

    printf("test CSR_MINTSTATUS\n");
    mintstatus = csr_read(CSR_MINTSTATUS); /* should be readable */
    /* should be ready only */
    csr_write(CSR_MINTSTATUS, 0xffffffff);
    assert(mintstatus == csr_read(CSR_MINTSTATUS));

    printf("test shared CSR_MCAUSE and CSR_MSTATUS\n");
    uint32_t mpp = 0x3;
    uint32_t mpie = 1;

    /* mstatus and mcause should have shared mpp and mpie fields */
    csr_read_set(CSR_MSTATUS, (mpp << 11) | (mpie << 7));
    mcause = csr_read(CSR_MCAUSE);
    assert((mcause >> 28 & 3) == mpp);
    assert((mcause >> 27 & 1) == mpie);

    csr_read_clear(CSR_MSTATUS, (mpp << 11) | (mpie << 7));
    mcause = csr_read(CSR_MCAUSE);
    /* we only have M mode so we can't force this to any other value */
    assert((mcause >> 28 & 3) == mpp);
    assert((mcause >> 27 & 1) == 0);

    return 0;
}
