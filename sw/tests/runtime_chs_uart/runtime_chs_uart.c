// Copyright 2023 ETH Zurich and University of Bologna.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Nicole Narr <narrn@student.ethz.ch>
// Christopher Reinwardt <creinwar@student.ethz.ch>
//
// Simple payload to test bootmodes

#include "uart.h"

// void *__base_uart = (void*)0x03002000;

int main(void) {

    // // Init the HW
    // car_init_start();

    char str[] = "Hello World!\r\n";
    // uint32_t rtc_freq = *reg32(&__base_regs, CHESHIRE_RTC_FREQ_REG_OFFSET);
    // uint64_t reset_freq = clint_get_core_freq(rtc_freq, 2500);
    uint64_t reset_freq = 100000000; // 100MHz
    // uint64_t reset_freq = 4000000; // 4MHz
    uart_init(0x03002000, reset_freq, 115200);
    uart_write_str(0x03002000, str, sizeof(str));
    uart_write_flush(0x03002000);
    return 0;
}
