# Safety Island

This IP contains a safety island, designed for the [Carfield](https://github.com/pulp-platform/carfield) project. It consists of a Triple-Core Lockstep (TCLS)  CV32RT core and two memory banks. To interface with the rest of the SoC, it has both an AXI input and an AXI output port, as well as an optional wrapper with CDCs and synchronizers for all relevant nets.

The safety island, as well as [Carfield](https://github.com/pulp-platform/carfield), is developed as part of the PULP project, a joint effort between ETH Zurich and the University of Bologna.

## Architecture

![Block Diagram](doc/carfield_safety_ss.drawio.svg)

## Configuration

The safety island offers several configuration options for integration into an SoC.

Many configurations are in the configuration object:

| Parameter           | Default          | Function                                              |
|---------------------|------------------|-------------------------------------------------------|
| `HartId`            | `8`              | Core's Hart ID                                        |
| `BankNumBytes`      | `32'h0001_0000`  | Number of bytes in a memory bank                      |
| `NumBanks`          | `2`              | Number of memory banks in the island                  |
| `PulpJtagIdCode`    | `32'h1_0000_db3` | Debug module ID code                                  |
| `NumTimers`         | `1`              | CV32RT: Number of Timers (currently only 1 supported) |
| `UseClic`           | `1`              | Use CLIC of legacy CLINT                              |
| `ClicIntCtlBits`    | `8`              | Number of bits for level-priority encoding in CLIC    |
| `UseSSClic`         | `0`              | Enable Supervisor mode for CLIC                       |
| `UseUSClic`         | `0`              | Enable User mode for CLIC                             |
| `UseVSClic`         | `0`              | Enable Virtual Supervisor mode for CLIC               |
| `NVsCtxts`          | `0`              | CLIC: Number of virtual contexts supported            |
| `UseVSPrio`         | `0`              | CLIC: Enable virtual supervisor prioritization        |
| `UseFastIrq`        | `1`              | Use CV32RT with fast interrupt extension              |
| `UseFpu`            | `1`              | Enable FPU                                            |
| `UseIntegerCluster` | `0`              | Make CV32 aware of an external integer cluster        |
| `UseXPulp`          | `1`              | CV32: Enable PULP extensions                          |
| `UseZfinx`          | `1`              | CV32: Use ZFinX extension                             |
| `UseTCLS`           | `1`              | Enable Triple-Core LockStep                           |
| `NumInterrupts`     | `64`             | Number of input interrupts to the safety island       |
| `NumMhpmCounters`   | `1`              | CV32: Number of performance counters                  |

Some configurations are in the top-level module:

| Parameter           | Function                                                                 |
|---------------------|--------------------------------------------------------------------------|
| `GlobalAddrWidth`   | Global address width of SoC                                              |
| `BaseAddr`          | Base address of the safety island                                        |
| `AddrRange`         | Address range of the safety island                                       |
| `MemOffset`         | Address offset of the memory in the island                               |
| `PeriphOffset`      | Address offset of the peripherals in the island                          |
| `NumDebug`          | Number of external debug lines from safety island debug module           |
| `SelectableHarts`   | Selectable modules for external debug                                    |
| `HartInfo`          | Hart information about external debug                                    |
| `AxiUserAtop`       | Enable AXI ATOP to use User bits for ID                                  |
| `AxiUserAtopMsb`    | MSB of AXI ATOP User ID                                                  |
| `AxiUserAtopLsb`    | LSB of AXI ATOP User ID                                                  |
| `AxiUserEccErr`     | Enable AXI ECC error signal on user bits                                 |
| `AxiUserEccErrBit`  | Bit for AXI ECC error                                                    |
| `AxiDataWidth`      | Data width for AXI bus (in and out)                                      |
| `AxiAddrWidth`      | AXI address width                                                        |
| `AxiInputIdWidth`   | AXI ID width for input connection                                        |
| `AxiUserWidth`      | AXI User width                                                           |
| `axi_input_req_t`   | AXI input request type                                                   |
| `axi_input_resp_t`  | AXI input response type                                                  |
| `AxiOutputIdWidth`  | AXI ID width for output                                                  |
| `DefaultUser`       | Default User bits for output                                             |
| `axi_output_req_t`  | AXI output request type                                                  |
| `axi_output_resp_t` | AXI output response type                                                 |


## Bootmodes

| Bootmode  | Configuration |
|-----------|---------------|
| JTAG      | `00`          |
| Preloaded | `01`          |

## Memory Map

To simplify, we assume following configurations for address parameters. The address spaces below will all be moved when changing the `BaseAddr`, the memory banks will be moved further by `MemOffset`, and the Peripherals will be moved further by `PeriphOffset`. Note that the parameters can be set to collide, but this will not work in the device, so take care when configuring.

| Parameter      | Config          |
|----------------|-----------------|
| `BaseAddr`     | `32'h6000_0000` |
| `AddrRange`    | `32'h0080_0000` |
| `MemOffset`    | `32'h0000_0000` |
| `PeriphOffset` | `32'h0020_0000` |
| `BankNumBytes` | `32'h0001_0000` |
| `NumBanks`     | `2`             |

| Start Address   | Stop Address    | Description                                |
|-----------------|-----------------|--------------------------------------------|
| `32'h0000_0000` | `32'h6000_0000` | External - routed to AXI output            |
| `32'h6000_0000` | `32'h6001_0000` | Memory Bank 1                              |
| `32'h6001_0000` | `32'h6002_0000` | Memory Bank 2                              |
| `32'h6002_0000` | `32'h6020_0000` | Error - will respond with error            |
| `32'h6020_0000` | `32'h6020_1000` | SoC control registers                      |
| `32'h6020_1000` | `32'h6020_2000` | Boot ROM                                   |
| `32'h6020_2000` | `32'h6020_3000` | Error - will respond with error (reserved) |
| `32'h6020_3000` | `32'h6020_4000` | Debug ROM - debug module                   |
| `32'h6020_4000` | `32'h6020_4040` | ECC manager                                |
| `32'h6020_4040` | `32'h6020_6000` | Error - will respond with error            |
| `32'h6020_6000` | `32'h6020_7000` | Simulation Printf (error when synthesized) |
| `32'h6020_7000` | `32'h6020_8000` | Error - will respond with error            |
| `32'h6020_8000` | `32'h6020_D000` | Timer                                      |
| `32'h6020_D000` | `32'h6020_E000` | TCLS registers                             |
| `32'h6020_E000` | `32'h6021_0000` | Error - will respond with error            |
| `32'h6021_0000` | `32'h6022_0000` | CLIC                                       |
| `32'h6022_0000` | `32'h6022_0010` | Instruction bus error registers            |
| `32'h6022_0010` | `32'h6022_0020` | Data bus error registers                   |
| `32'h6022_0020` | `32'h6022_0030` | Shadow bus error registers                 |
| `32'h6022_0030` | `32'h6080_0000` | Error - will respond with error            |
| `32'h6080_0000` | `32'hFFFF_FFFF` | External - routed to AXI output            |

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
* Preloaded bootmode: it expectes an external master to handle the bootflow through the AXI slave (fot the safety_island) interface

Compile and execute a test with `pulp-runtime` or `pulp-freertos`

```
cd sw/tests/{freertos, runtime}_<test_name>
make clean all run
```

This will start a simulation in Questasim. To activate GUI mode, add `gui=1` to
the end of the last command.

## Citing

The safety island was presented at the RISC-V Summit Europe 2024 as SentryCore. If you use the safety island in your work, you can cite us:

```
@inproceedings{rogenmoser_sentrycore_2024
  title = {SentryCore: A RISC-V Co-Processor System for Safe, Real-Time Control Applications},
  author = {Rogenmoser, Michael and Ottaviano, Alessandro and Benz, Thomas and Balas, Robert and Perotti, Matteo and Garofalo, Angelo and Benini, Luca},
  month = {June},
  year = {2024},
  abstract = {In the last decade, we have witnessed exponential growth in the complexity of control systems for safety-critical applications (automotive, robots, industrial automation) and their transition to heterogeneous mixed-criticality systems (MCSs). The growth of the RISC-V ecosystem is creating a major opportunity to develop open-source, vendor-neutral reference platforms for safety-critical computing. We present SentryCore, a reliable, real-time, self-contained, open-source mega-IP for advanced control functions that can be seamlessly integrated into Systems-on-Chip, e.g., for automotive applications, through industry-standard Advanced eXtensible Interface 4 (AXI4). SentryCore features three embedded RISC-V processor cores in lockstep with error-correcting code (ECC) protected data memory for reliable execution of any safety-critical application. Context switching is accelerated to under 110 clock cycles via a RISC-V core-local interrupt controller (CLIC) and dedicated hardware extensions, while a timer-based direct memory access (DMA) engine streamlines sensor data readout during periodic control loops. SentryCore was implemented in Intel’s 16nm process node and tested with FreeRTOS, ThreadX, and RTIC software support.},
  booktitle = {RISC-V Summit Europe 2024},
  language = {en},
  DOI = {10.3929/ethz-b-000673440},
  address = {Munich, Germany}
}
```

## License
Unless specified otherwise in the respective file headers, all code checked into this repository is made available under a permissive license. All hardware sources and tool scripts are licensed under the Solderpad Hardware License 0.51 (see `LICENSE.md`). All software sources are licensed under Apache 2.0.
