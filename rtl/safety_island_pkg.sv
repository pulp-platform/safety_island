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

`ifdef TARGET_SIMULATION
  localparam int unsigned NumPeriphs     = 7;
  localparam int unsigned NumPeriphRules = 6;

  localparam bit [31:0] TBPrintfAddrOffset = 32'h0000_6000;
  localparam bit [31:0] TBPrintfAddrRange  = 32'h0000_1000;
`else
  localparam int unsigned NumPeriphs     = 6;
  localparam int unsigned NumPeriphRules = 5;
`endif
  localparam int unsigned NumCoreLocalPeriphs = 3; // CLIC, TCLS, Timer

  typedef enum int {
    PeriphErrorSlv,
    PeriphSocCtrl,
    PeriphBootROM,
    PeriphGlobalPrepend,
    PeriphDebug,
    PeriphCoreLocal
`ifdef TARGET_SIMULATION
    ,
    PeriphTBPrintf
`endif
  } periph_outputs_e;

  typedef enum int {
    RegbusOutTCLS,
    RegbusOutTimer,
    RegbusOutCLIC
  } cl_regbus_outputs_e;

  // Address map of safety_island
  typedef struct packed {
      logic [31:0] idx;
      logic [31:0] start_addr;
      logic [31:0] end_addr;
  } addr_map_rule_t;

  // Periph offsets and ranges
  localparam bit [31:0] SocCtrlAddrOffset = 32'h0000_0000;
  localparam bit [31:0] SocCtrlAddrRange  = 32'h0000_1000;
  localparam bit [31:0] BootROMAddrOffset = 32'h0000_1000;
  localparam bit [31:0] BootROMAddrRange  = 32'h0000_1000;
  localparam bit [31:0] GlobalPrependAddrOffset = 32'h0000_2000;
  localparam bit [31:0] GlobalPrependAddrRange  = 32'h0000_1000;
  localparam bit [31:0] DebugAddrOffset = 32'h0000_3000;
  localparam bit [31:0] DebugAddrRange  = 32'h0000_1000;
  localparam bit [31:0] CoreLocalAddrOffset = 32'h0000_7000;
  localparam bit [31:0] CoreLocalAddrRange  = 32'h0003_0000;

  // Core-Local offsets and ranges
  localparam bit [31:0] TCLSAddrOffset = CoreLocalAddrOffset;
  localparam bit [31:0] TCLSAddrRange  = 32'h0000_1000;
  localparam bit [31:0] TimerAddrOffset = 32'h0000_8000;
  localparam bit [31:0] TimerAddrRange = 32'h0000_5000;
  localparam bit [31:0] ClicAddrOffset = 32'h0001_0000;
  localparam bit [31:0] ClicAddrRange  = 32'h0001_0000;

  typedef struct packed {
    int unsigned              HartId;
    int unsigned              BankNumBytes;
    int unsigned              PulpJtagIdCode;
    int unsigned              NumTimers;
    // CV32RT configuration
    int unsigned              UseClic;
    int unsigned              UseFastIrq; // TODO
    int unsigned              UseFpu;
    int unsigned              UseIntegerCluster;
    int unsigned              UseXPulp;
    int unsigned              UseZfinx;
    int unsigned              NumInterrupts;
    int unsigned              NumMhpmCounters;
  } safety_island_cfg_t;

  localparam safety_island_cfg_t SafetyIslandDefaultConfig = '{
    HartId:             32'd0,
    BankNumBytes:       32'h0001_0000,
    // JTAG ID code:
    // LSB                        [0]:     1'h1
    // PULP Platform Manufacturer [11:1]:  11'h6d9
    // Part Number                [27:12]: 16'h0000 --> TBD!
    // Version                    [31:28]: 4'h1
    PulpJtagIdCode:     32'h1_0000_db3,
    NumTimers:          1,
    UseClic:            1,
    UseFastIrq:         0,
    UseFpu:             1,
    UseIntegerCluster:  0,
    UseXPulp:           1,
    UseZfinx:           1,
    NumInterrupts:      256,
    NumMhpmCounters:    1
  };

  localparam int unsigned NumTimerInterrupts = 2*SafetyIslandDefaultConfig.NumTimers;
  localparam int unsigned NumLocalInterrupts = SafetyIslandDefaultConfig.NumInterrupts - NumTimerInterrupts;

endpackage
