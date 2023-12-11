# Safety Island

This IP contains a safety island, designed for the [Carfield](https://github.com/pulp-platform/carfield) project. It consists of
a Triple-Core Lockstep (TCLS) core and two memory banks. To interface with the
rest of the SoC, it has both an AXI input and an AXI output port.

The safety island, as well as [Carfield](https://github.com/pulp-platform/carfield), is developed as part of the PULP project, a joint effort between ETH Zurich and the University of Bologna.

## Getting started

Download the software stack
```
make pulp-runtime
make pulp-freertos
```

Set up environment variables

```
source env/env.sh
```

Make sure the PULP RISC-V toolchain is in your `PATH`. If not:

```
export PATH=/usr/pack/riscv-1.0-kgf/pulp-gcc-2.6.0:$PATH
```

Get the hardware dependencies

```
make checkout
```

Compile the top with `jtag` or `preloaded` testbenches using Questasim

```
make build SIM_TOP=tb_safety_island_jtag
# or
make build SIM_TOP=tb_safety_island_preloaded
```

* JTAG bootmode: the debug module will handle the boot through the jtag interface
* Preloaded bootmode: it expectes an external master to handle the bootflow
  through the AXI slave (fot the safety_island) interface

Compile and execute a test with `pulp-runtime` or `pulp-freertos`

```
cd sw/tests/{freertos, runtime}_<test_name>
make clean all run
```

This will start a simulation in Questasim. To activate GUI mode, add `gui=1` to
the end of the last command.

## License
Unless specified otherwise in the respective file headers, all code checked into this repository is made available under a permissive license. All hardware sources and tool scripts are licensed under the Solderpad Hardware License 0.51 (see `LICENSE.md`). All software sources are licensed under Apache 2.0.
