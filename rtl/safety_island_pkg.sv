// Copyright 2023 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

package safety_island_pkg;

  typedef enum logic [1:0] {
    Jtag = 2'b00,
    Preloaded = 2'b01
  } bootmode_e;

  typedef enum int {
    PeriphErrorSlv,
    PeriphSocCtrl,
    PeriphBootROM,
    PeriphGlobalPrepend,
    PeriphDebug,
    PeriphEccManager,
    PeriphTimer,
    PeriphCoreLocal
`ifdef TARGET_SIMULATION
    ,
    PeriphTBPrintf
`endif
  } periph_outputs_e;

  typedef enum int {
    RegbusOutTCLS,
    RegbusOutCLIC,
    RegbusOutInstrErr,
    RegbusOutDataErr,
    RegbusOutShadowErr
  } cl_regbus_outputs_e;

  // Address map of safety_island
  typedef struct packed {
      logic [31:0] idx;
      logic [31:0] start_addr;
      logic [31:0] end_addr;
  } addr_map_rule_t;

  // Periph offsets and ranges
  localparam bit [31:0] SocCtrlAddrOffset       = 32'h0000_0000;
  localparam bit [31:0] SocCtrlAddrRange       = 32'h0000_1000;
  localparam bit [31:0] BootROMAddrOffset       = 32'h0000_1000;
  localparam bit [31:0] BootROMAddrRange       = 32'h0000_1000;
  localparam bit [31:0] GlobalPrependAddrOffset = 32'h0000_2000;
  localparam bit [31:0] GlobalPrependAddrRange = 32'h0000_1000;
  localparam bit [31:0] DebugAddrOffset         = 32'h0000_3000;
  localparam bit [31:0] DebugAddrRange         = 32'h0000_1000;
  localparam bit [31:0] EccManagerAddrOffset    = 32'h0000_4000;
  localparam bit [31:0] EccManagerAddrRange    = 32'h0000_0040; // Temporary for 2 banks
  localparam bit [31:0] TBPrintfAddrOffset      = 32'h0000_6000;
  localparam bit [31:0] TBPrintfAddrRange      = 32'h0000_1000;
  localparam bit [31:0] TimerAddrOffset         = 32'h0000_8000;
  localparam bit [31:0] TimerAddrRange         = 32'h0000_5000;
  localparam bit [31:0] CoreLocalAddrOffset     = 32'h0000_D000;
  localparam bit [31:0] CoreLocalAddrRange     = 32'h0002_3000;

  // Core-Local offsets and ranges
  localparam bit [31:0] TCLSAddrOffset  = CoreLocalAddrOffset;
  localparam bit [31:0] TCLSAddrRange  = 32'h0000_1000;
  localparam bit [31:0] ClicAddrOffset  = 32'h0001_0000;
  localparam bit [31:0] ClicAddrRange  = 32'h0001_0000;
  localparam bit [31:0] InstrErrOffset  = 32'h0002_0000;
  localparam bit [31:0] InstrErrRange  = 32'h0000_0010;
  localparam bit [31:0] DataErrOffset   = 32'h0002_0010;
  localparam bit [31:0] DataErrRange   = 32'h0000_0020;
  localparam bit [31:0] ShadowErrOffset = 32'h0002_0020;
  localparam bit [31:0] ShadowErrRange = 32'h0000_0030;

  typedef struct packed {
    int unsigned              HartId;
    int unsigned              BankNumBytes;
    int unsigned              NumBanks;
    int unsigned              PulpJtagIdCode;
    int unsigned              NumTimers;         // Number of Timers. Warning:
                                                 // currently, we only support
                                                 // one. TODO: Make the timer
                                                 // instantiation configurable.
                                                 // CV32RT configuration
    int unsigned              UseClic;           // use CLIC or legacy CLINT
    int unsigned              ClicIntCtlBits;    // Number of bits for
                                                 // level-priority encoding in
                                                 // the CLIC
    int unsigned              UseSSClic;         // Enable Supervisor mode for
                                                 // CLIC
    int unsigned              UseUSClic;         // Enable USer mode for CLIC
    int unsigned              UseVSClic;         // Enable virtual supervisor mode for CLIC
    int unsigned              NVsCtxts;          // Number of virtual contexts supported
    int unsigned              UseVSPrio;         // Enable virtual supervisor prioritization
    int unsigned              UseFastIrq;        // Use CV32RT (CV32 with fast
                                                 // interrupt extensions)
    int unsigned              UseFpu;            // Use FPU
    int unsigned              UseIntegerCluster; // Make CV32 aware of the integer cluster
    int unsigned              UseXPulp;          // Use PULP extensions for CV32
    int unsigned              UseZfinx;          // Use Zfinx extensions. If 1,
                                                 // integer RF is used for the
                                                 // FPU instead of a dedicated
                                                 // FP RF
    int unsigned              UseTCLS;           // Use Triple-core Lockstep
    int unsigned              NumInterrupts;     // Number of input interrupts
                                                 // to the safety island
    int unsigned              NumMhpmCounters;   // Number of performance
                                                 // counters implemented in CV32
    bit                       UseICache;         // Enable instruction cache for external
                                                 // memory regions for CV32
  } safety_island_cfg_t;

  localparam safety_island_cfg_t SafetyIslandDefaultConfig = '{
    HartId:             32'd8,
    BankNumBytes:       32'h0001_0000,
    NumBanks:           32'd2,
    // JTAG ID code:
    // LSB                        [0]:     1'h1
    // PULP Platform Manufacturer [11:1]:  11'h6d9
    // Part Number                [27:12]: 16'h0000 --> TBD!
    // Version                    [31:28]: 4'h1
    PulpJtagIdCode:     32'h1_0000_db3,
    NumTimers:          1,
    UseClic:            1,
    ClicIntCtlBits:     8,
    UseSSClic:          0,
    UseUSClic:          0,
    UseVSClic:          0,
    NVsCtxts:           0,
    UseVSPrio:          0,
    UseFastIrq:         1,
    UseFpu:             1,
    UseIntegerCluster:  0,
    UseXPulp:           1,
    UseZfinx:           1,
    UseTCLS:            1,
    NumInterrupts:      64,
    NumMhpmCounters:    1,
    UseICache:          1
  };

  localparam int unsigned NumTimerInterrupts = 2*SafetyIslandDefaultConfig.NumTimers;
  // localparam int unsigned NumLocalInterrupts = SafetyIslandDefaultConfig.NumInterrupts - NumTimerInterrupts;

  // 1 AXI cut, 1-cycle response
  localparam int unsigned AxiMaxInTrans = 3;
  // Cores do not support more than 2 outstanding transactions
  localparam int unsigned AxiMaxOutTrans = 2;

endpackage
