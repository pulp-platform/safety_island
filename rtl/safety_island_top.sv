// Copyright 2023 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

`include "register_interface/typedef.svh"
`include "axi/typedef.svh"
`include "axi/assign.svh"
`include "obi/typedef.svh"
`include "apb/typedef.svh"

module safety_island_top import safety_island_pkg::*; #(
  parameter safety_island_pkg::safety_island_cfg_t SafetyIslandCfg =
            safety_island_pkg::SafetyIslandDefaultConfig,

  parameter  int unsigned              GlobalAddrWidth = 32,
  parameter  bit [GlobalAddrWidth-1:0] BaseAddr        = 32'h0000_0000,
  parameter  bit [31:0]                AddrRange       = 32'h0080_0000,
  parameter  bit [31:0]                MemOffset       = 32'h0000_0000,
  parameter  bit [31:0]                PeriphOffset    = 32'h0020_0000,

  parameter  int unsigned              NumDebug        = 96,
  parameter  bit [NumDebug-1:0]        SelectableHarts = {NumDebug{1'b0}},
  parameter  dm::hartinfo_t [NumDebug-1:0] HartInfo    = {NumDebug{'0}},

  parameter bit          AxiUserAtop      = 1'b1,
  parameter int unsigned AxiUserAtopMsb   = 3,
  parameter int unsigned AxiUserAtopLsb   = 0,
  parameter bit          AxiUserEccErr    = 1'b1,
  parameter int unsigned AxiUserEccErrBit = 4,

  /// AXI slave port structs (input)
  parameter int unsigned AxiDataWidth      = 64,
  parameter int unsigned AxiAddrWidth      = GlobalAddrWidth,
  parameter int unsigned AxiInputIdWidth   = 1,
  parameter int unsigned AxiUserWidth      = 1,
  parameter type         axi_input_req_t   = logic,
  parameter type         axi_input_resp_t  = logic,

  /// AXI master port structs (output)
  parameter int unsigned AxiOutputIdWidth  = 1,
  parameter bit [AxiUserWidth-1:0] DefaultUser = '0,
  parameter type         axi_output_req_t  = logic,
  parameter type         axi_output_resp_t = logic
) (
  input  logic            clk_i,
  input  logic            ref_clk_i,
  input  logic            rst_ni,
  input  logic            test_enable_i,

  /// JTAG
  input  logic            jtag_tck_i,
  input  logic            jtag_tdi_i,
  output logic            jtag_tdo_o,
  input  logic            jtag_tms_i,
  input  logic            jtag_trst_ni,

  input  bootmode_e       bootmode_i,

  input  logic            fetch_enable_i,

  input  logic [SafetyIslandCfg.NumInterrupts-1:0] irqs_i,

  output logic [NumDebug-1:0]   debug_req_o,

  /// AXI input
  input  axi_input_req_t  axi_input_req_i,
  output axi_input_resp_t axi_input_resp_o,

  /// AXI output
  output axi_output_req_t  axi_output_req_o,
  input  axi_output_resp_t axi_output_resp_i
);

  localparam int unsigned AddrWidth = 32;
  localparam int unsigned DataWidth = 32;
  localparam int unsigned BankNumWords = SafetyIslandCfg.BankNumBytes/4;

  // Base addresses
  localparam bit [31:0] BaseAddr32     = BaseAddr[31:0];
  localparam bit [31:0] PeriphBaseAddr = BaseAddr32+PeriphOffset;

  localparam int unsigned NumManagers = 5; // AXI, DBG, Core Instr, Core Data, Core Shadow

  // typedef obi for default config
  localparam obi_pkg::obi_optional_cfg_t MgrObiOptionalCfg= '{
    UseAtop:    1'b1,
    UseMemtype: 1'b0,
    UseProt:    1'b0,
    UseDbg:     1'b0,
    AUserWidth:    0,
    WUserWidth:    0,
    RUserWidth:    1,
    MidWidth:      0,
    AChkWidth:     0,
    RChkWidth:     0
  };
  localparam obi_pkg::obi_optional_cfg_t SbrObiOptionalCfg= '{
    UseAtop:    1'b0,
    UseMemtype: 1'b0,
    UseProt:    1'b0,
    UseDbg:     1'b0,
    AUserWidth:    0,
    WUserWidth:    0,
    RUserWidth:    1,
    MidWidth:      0,
    AChkWidth:     0,
    RChkWidth:     0
  };
  localparam obi_pkg::obi_cfg_t MgrObiCfg =
             obi_pkg::obi_default_cfg(AddrWidth,
                                      DataWidth,
                                      (AxiUserAtop ?
                                        AxiUserAtopMsb+1-AxiUserAtopLsb :
                                        AxiInputIdWidth),
                                      MgrObiOptionalCfg);
  localparam obi_pkg::obi_cfg_t XbarSbrObiCfg = obi_pkg::mux_grow_cfg(MgrObiCfg, NumManagers);
  localparam obi_pkg::obi_cfg_t SbrObiCfg = obi_pkg::obi_default_cfg(AddrWidth,
                                                                     DataWidth,
                                                                     XbarSbrObiCfg.IdWidth,
                                                                     SbrObiOptionalCfg);
  `OBI_TYPEDEF_ATOP_A_OPTIONAL(obi_a_optional_t)
  `OBI_TYPEDEF_MINIMAL_A_OPTIONAL(sbr_obi_a_optional_t)
  `OBI_TYPEDEF_A_CHAN_T(mgr_obi_a_chan_t,
                        MgrObiCfg.AddrWidth,
                        MgrObiCfg.DataWidth,
                        MgrObiCfg.IdWidth,
                        obi_a_optional_t)
  `OBI_TYPEDEF_A_CHAN_T(xbar_sbr_obi_a_chan_t,
                        XbarSbrObiCfg.AddrWidth,
                        XbarSbrObiCfg.DataWidth,
                        XbarSbrObiCfg.IdWidth,
                        obi_a_optional_t)
  `OBI_TYPEDEF_A_CHAN_T(sbr_obi_a_chan_t,
                        SbrObiCfg.AddrWidth,
                        SbrObiCfg.DataWidth,
                        SbrObiCfg.IdWidth,
                        sbr_obi_a_optional_t)
  `OBI_TYPEDEF_DEFAULT_REQ_T(mgr_obi_req_t, mgr_obi_a_chan_t)
  `OBI_TYPEDEF_DEFAULT_REQ_T(xbar_sbr_obi_req_t, xbar_sbr_obi_a_chan_t)
  `OBI_TYPEDEF_DEFAULT_REQ_T(sbr_obi_req_t, sbr_obi_a_chan_t)
  typedef struct packed {
    logic [0:0] ruser;
    logic       exokay;
  } obi_r_optional_t;
  typedef struct packed {
    logic [0:0] ruser; // ECC error
  } sbr_obi_r_optional_t;
  `OBI_TYPEDEF_R_CHAN_T(mgr_obi_r_chan_t, MgrObiCfg.DataWidth, MgrObiCfg.IdWidth, obi_r_optional_t)
  `OBI_TYPEDEF_R_CHAN_T(xbar_sbr_obi_r_chan_t,
                        XbarSbrObiCfg.DataWidth,
                        XbarSbrObiCfg.IdWidth,
                        obi_r_optional_t)
  `OBI_TYPEDEF_R_CHAN_T(sbr_obi_r_chan_t,
                        SbrObiCfg.DataWidth,
                        SbrObiCfg.IdWidth,
                        sbr_obi_r_optional_t)
  `OBI_TYPEDEF_RSP_T(mgr_obi_rsp_t, mgr_obi_r_chan_t)
  `OBI_TYPEDEF_RSP_T(xbar_sbr_obi_rsp_t, xbar_sbr_obi_r_chan_t)
  `OBI_TYPEDEF_RSP_T(sbr_obi_rsp_t, sbr_obi_r_chan_t)
  `REG_BUS_TYPEDEF_ALL(safety_reg,
                       logic[AddrWidth-1:0],
                       logic[DataWidth-1:0],
                       logic[(DataWidth/8)-1:0]);

`ifdef TARGET_SIMULATION
  localparam int unsigned NumPeriphs     = 9;
  localparam int unsigned NumPeriphRules = 8;
`else
  localparam int unsigned NumPeriphs     = 8;
  localparam int unsigned NumPeriphRules = 7;
`endif

  localparam int unsigned NumSubordinates = 2 + SafetyIslandCfg.NumBanks;
  localparam int unsigned NumRules = (MemOffset != 0) ?
                                        2 + SafetyIslandCfg.NumBanks :
                                        1 + SafetyIslandCfg.NumBanks;

  function automatic addr_map_rule_t [NumRules-1:0] gen_xbar_addr_rules();
    addr_map_rule_t [NumRules-1:0] ret;
    for (int i = 0; i < SafetyIslandCfg.NumBanks; i++) begin
      ret[i] = '{ idx: i+1,
                  start_addr: BaseAddr32+MemOffset+( i   *SafetyIslandCfg.BankNumBytes),
                  end_addr:   BaseAddr32+MemOffset+((i+1)*SafetyIslandCfg.BankNumBytes)};
    end
    if (MemOffset != 0) begin
      ret[NumRules-2] = '{ idx: NumSubordinates-1, // 3: Periphs
                           start_addr: BaseAddr32,
                           end_addr: BaseAddr32+MemOffset};
    end
    ret[NumRules-1]   = '{ idx: NumSubordinates-1, // 3: Periphs
                         start_addr: BaseAddr32+MemOffset+
                                     SafetyIslandCfg.NumBanks*SafetyIslandCfg.BankNumBytes,
                         end_addr: BaseAddr32+AddrRange};
    return ret;
  endfunction

  localparam addr_map_rule_t [NumRules-1:0] MainAddrMap = gen_xbar_addr_rules();

  localparam addr_map_rule_t [NumPeriphRules-1:0] PeriphAddrMap = '{ // 0: Error subordinate (def)
    '{ idx: PeriphSocCtrl,
       start_addr: PeriphBaseAddr+SocCtrlAddrOffset,
       end_addr: PeriphBaseAddr+SocCtrlAddrOffset+      SocCtrlAddrRange},       // 1: SoC control
    '{ idx: PeriphBootROM,
       start_addr: PeriphBaseAddr+BootROMAddrOffset,
       end_addr: PeriphBaseAddr+BootROMAddrOffset+      BootROMAddrRange},       // 2: Boot ROM
    '{ idx: PeriphGlobalPrepend,
       start_addr: PeriphBaseAddr+GlobalPrependAddrOffset,
       end_addr: PeriphBaseAddr+GlobalPrependAddrOffset+GlobalPrependAddrRange}, // 3: Global prep
    '{ idx: PeriphDebug,
       start_addr: PeriphBaseAddr+DebugAddrOffset,
       end_addr: PeriphBaseAddr+DebugAddrOffset+        DebugAddrRange},         // 4: Debug
    '{ idx: PeriphEccManager,
       start_addr: PeriphBaseAddr+EccManagerAddrOffset,
       end_addr: PeriphBaseAddr+EccManagerAddrOffset+   EccManagerAddrRange},    // 5: ECC Manager
    '{ idx: PeriphTimer,
       start_addr: PeriphBaseAddr+TimerAddrOffset,
       end_addr: PeriphBaseAddr+TimerAddrOffset+        TimerAddrRange},         // 6: Timer
    '{ idx: PeriphCoreLocal,
       start_addr: PeriphBaseAddr+CoreLocalAddrOffset,
       end_addr: PeriphBaseAddr+CoreLocalAddrOffset+    CoreLocalAddrRange}      // 7: Core-Local
`ifdef TARGET_SIMULATION
    ,
    '{ idx: PeriphTBPrintf,
       start_addr: PeriphBaseAddr+TBPrintfAddrOffset,
       end_addr: PeriphBaseAddr+TBPrintfAddrOffset+     TBPrintfAddrRange}       // 8: TBPrintf
`endif
  };

  // -----------------
  // Control Signals
  // -----------------
  logic fetch_enable;
  logic [31:0] boot_addr;
  logic [NumTimerInterrupts-1:0] s_timer_irqs;

  // -----------------
  // Manager buses
  // -----------------

  // Core instr bus
  mgr_obi_req_t core_instr_obi_req;
  mgr_obi_rsp_t core_instr_obi_rsp;
  assign core_instr_obi_req.a.aid = '0;
  assign core_instr_obi_req.a.a_optional = '0;
  assign core_instr_obi_req.a.we = '0;
  assign core_instr_obi_req.a.be = '1;
  assign core_instr_obi_req.a.wdata = '0;

  // Core data bus
  mgr_obi_req_t core_data_obi_req;
  mgr_obi_rsp_t core_data_obi_rsp;
  assign core_data_obi_req.a.aid = '0;
  // assign core_data_obi_req.a.a_optional = '0;

  // Core shadow bus
  mgr_obi_req_t core_shadow_obi_req;
  mgr_obi_rsp_t core_shadow_obi_rsp;
  assign core_shadow_obi_req.a.aid = '0;
  assign core_shadow_obi_req.a.a_optional = '0;

  // dbg req bus
  mgr_obi_req_t dbg_req_obi_req;
  mgr_obi_rsp_t dbg_req_obi_rsp;
  assign dbg_req_obi_req.a.aid = '0;
  assign dbg_req_obi_req.a.a_optional = '0;

  // axi input bus
  mgr_obi_req_t axi_input_obi_req;
  mgr_obi_rsp_t axi_input_obi_rsp;

  // -----------------
  // Subordinate buses
  // -----------------

  // mem bank buses
  xbar_sbr_obi_req_t [SafetyIslandCfg.NumBanks-1:0] xbar_mem_bank_obi_req;
  xbar_sbr_obi_rsp_t [SafetyIslandCfg.NumBanks-1:0] xbar_mem_bank_obi_rsp;
  sbr_obi_req_t [SafetyIslandCfg.NumBanks-1:0] mem_bank_obi_req;
  sbr_obi_rsp_t [SafetyIslandCfg.NumBanks-1:0] mem_bank_obi_rsp;

  // axi output bus
  xbar_sbr_obi_req_t axi_output_obi_req;
  xbar_sbr_obi_rsp_t axi_output_obi_rsp;

  // periph bus
  xbar_sbr_obi_req_t xbar_periph_obi_req;
  xbar_sbr_obi_rsp_t xbar_periph_obi_rsp;
  sbr_obi_req_t periph_obi_req;
  sbr_obi_rsp_t periph_obi_rsp;

  // Main xbar subordinate buses, must align with addr map!
  xbar_sbr_obi_req_t [NumSubordinates-1:0] all_sbr_obi_req;
  xbar_sbr_obi_rsp_t [NumSubordinates-1:0] all_sbr_obi_rsp;
  assign axi_output_obi_req = all_sbr_obi_req[0];
  assign all_sbr_obi_rsp[0] = axi_output_obi_rsp;
  for (genvar i = 0; i < SafetyIslandCfg.NumBanks; i++) begin : gen_xbar_sbr_connect
    assign xbar_mem_bank_obi_req[i] = all_sbr_obi_req[i+1];
    assign all_sbr_obi_rsp[i+1]     = xbar_mem_bank_obi_rsp[i];
  end
  assign xbar_periph_obi_req     = all_sbr_obi_req[NumSubordinates-1];
  assign all_sbr_obi_rsp[NumSubordinates-1] = xbar_periph_obi_rsp;

  // -----------------
  // Peripheral buses
  // -----------------

  // Error bus
  sbr_obi_req_t error_obi_req;
  sbr_obi_rsp_t error_obi_rsp;

  // SoC control bus
  sbr_obi_req_t soc_ctrl_obi_req;
  sbr_obi_rsp_t soc_ctrl_obi_rsp;
  safety_reg_req_t soc_ctrl_reg_req;
  safety_reg_rsp_t soc_ctrl_reg_rsp;

  // Boot ROM bus
  sbr_obi_req_t boot_rom_obi_req;
  sbr_obi_rsp_t boot_rom_obi_rsp;

  // Global prepend bus
  sbr_obi_req_t global_prepend_obi_req;
  sbr_obi_rsp_t global_prepend_obi_rsp;

  // Debug mem bus
  sbr_obi_req_t dbg_mem_obi_req;
  sbr_obi_rsp_t dbg_mem_obi_rsp;

  // ECC Manager bus
  sbr_obi_req_t ecc_mgr_obi_req;
  sbr_obi_rsp_t ecc_mgr_obi_rsp;
  safety_reg_req_t ecc_mgr_reg_req;
  safety_reg_rsp_t ecc_mgr_reg_rsp;

  // Core local bus
  sbr_obi_req_t timer_obi_req;
  sbr_obi_rsp_t timer_obi_rsp;
  safety_reg_req_t timer_reg_req;
  safety_reg_rsp_t timer_reg_rsp;

  // Core local bus
  sbr_obi_req_t cl_periph_obi_req;
  sbr_obi_rsp_t cl_periph_obi_rsp;
  safety_reg_req_t cl_periph_reg_req;
  safety_reg_rsp_t cl_periph_reg_rsp;

`ifdef TARGET_SIMULATION
  // TBPrintf bus
  sbr_obi_req_t tbprintf_obi_req;
  sbr_obi_rsp_t tbprintf_obi_rsp;
`endif

  sbr_obi_req_t [NumPeriphs-1:0] all_periph_obi_req;
  sbr_obi_rsp_t [NumPeriphs-1:0] all_periph_obi_rsp;
  assign error_obi_req                        = all_periph_obi_req[PeriphErrorSlv];
  assign all_periph_obi_rsp[PeriphErrorSlv]   = error_obi_rsp;
  assign soc_ctrl_obi_req                     = all_periph_obi_req[PeriphSocCtrl];
  assign all_periph_obi_rsp[PeriphSocCtrl]    = soc_ctrl_obi_rsp;
  assign boot_rom_obi_req                     = all_periph_obi_req[PeriphBootROM];
  assign all_periph_obi_rsp[PeriphBootROM]    = boot_rom_obi_rsp;
  assign global_prepend_obi_req               = all_periph_obi_req[PeriphGlobalPrepend];
  assign all_periph_obi_rsp[PeriphGlobalPrepend] = global_prepend_obi_rsp;
  assign dbg_mem_obi_req                      = all_periph_obi_req[PeriphDebug];
  assign all_periph_obi_rsp[PeriphDebug]      = dbg_mem_obi_rsp;
  assign ecc_mgr_obi_req                      = all_periph_obi_req[PeriphEccManager];
  assign all_periph_obi_rsp[PeriphEccManager] = ecc_mgr_obi_rsp;
  assign cl_periph_obi_req                    = all_periph_obi_req[PeriphCoreLocal];
  assign all_periph_obi_rsp[PeriphCoreLocal]  = cl_periph_obi_rsp;
  assign timer_obi_req                        = all_periph_obi_req[PeriphTimer];
  assign all_periph_obi_rsp[PeriphTimer]      = timer_obi_rsp;
`ifdef TARGET_SIMULATION
  assign tbprintf_obi_req                     = all_periph_obi_req[PeriphTBPrintf];
  assign all_periph_obi_rsp[PeriphTBPrintf]   = tbprintf_obi_rsp;
`endif

  // -----------------
  // Core
  // -----------------

  localparam int unsigned NumInternalDebug = NumDebug > SafetyIslandCfg.HartId ?
                                               NumDebug :
                                               SafetyIslandCfg.HartId;

  logic [NumInternalDebug-1:0] debug_req;

  always_comb begin : proc_debug
    debug_req_o = debug_req;
    debug_req_o[SafetyIslandCfg.HartId] = '0;
  end

  safety_core_wrap #(
    .SafetyIslandCfg ( SafetyIslandCfg           ),
    .PeriphBaseAddr  ( BaseAddr32 + PeriphOffset ),
    .reg_req_t       ( safety_reg_req_t          ),
    .reg_rsp_t       ( safety_reg_rsp_t          ),
    .NumBusErrBits   ( 2 )
  ) i_core_wrap (
    .clk_i,
    .ref_clk_i,
    .rst_ni,
    .test_enable_i,

    .irqs_i,
    .timer_irqs_i     ( s_timer_irqs                      ),

    .cl_periph_req_i  ( cl_periph_reg_req                 ),
    .cl_periph_rsp_o  ( cl_periph_reg_rsp                 ),

    .hart_id_i        ( SafetyIslandCfg.HartId            ),
    .boot_addr_i      ( boot_addr                         ),

    .instr_req_o      ( core_instr_obi_req.req            ),
    .instr_gnt_i      ( core_instr_obi_rsp.gnt            ),
    .instr_rvalid_i   ( core_instr_obi_rsp.rvalid         ),
    .instr_addr_o     ( core_instr_obi_req.a.addr         ),
    .instr_rdata_i    ( core_instr_obi_rsp.r.rdata        ),
    .instr_err_i      ( {core_instr_obi_rsp.r.r_optional.ruser[0] ,core_instr_obi_rsp.r.err} ),

    .data_req_o       ( core_data_obi_req.req             ),
    .data_gnt_i       ( core_data_obi_rsp.gnt             ),
    .data_rvalid_i    ( core_data_obi_rsp.rvalid          ),
    .data_we_o        ( core_data_obi_req.a.we            ),
    .data_be_o        ( core_data_obi_req.a.be            ),
    .data_addr_o      ( core_data_obi_req.a.addr          ),
    .data_wdata_o     ( core_data_obi_req.a.wdata         ),
    .data_atop_o      ( core_data_obi_req.a.a_optional.atop ),
    .data_rdata_i     ( core_data_obi_rsp.r.rdata         ),
    .data_err_i       ( {core_data_obi_rsp.r.r_optional.ruser[0], core_data_obi_rsp.r.err} ),

    .shadow_req_o     ( core_shadow_obi_req.req           ),
    .shadow_gnt_i     ( core_shadow_obi_rsp.gnt           ),
    .shadow_rvalid_i  ( core_shadow_obi_rsp.rvalid        ),
    .shadow_we_o      ( core_shadow_obi_req.a.we          ),
    .shadow_be_o      ( core_shadow_obi_req.a.be          ),
    .shadow_addr_o    ( core_shadow_obi_req.a.addr        ),
    .shadow_wdata_o   ( core_shadow_obi_req.a.wdata       ),
    .shadow_rdata_i   ( core_shadow_obi_rsp.r.rdata       ),
    .shadow_err_i     ( {core_shadow_obi_rsp.r.r_optional.ruser[0], core_shadow_obi_rsp.r.err} ),

    .debug_req_i      ( debug_req[SafetyIslandCfg.HartId] ),
    .fetch_enable_i   ( fetch_enable                      )
  );

  // -----------------
  // Debug
  // -----------------

  localparam dm::hartinfo_t HARTINFO = '{
    zero1: '0,
    nscratch: 2,
    zero0: '0,
    dataaccess: 1'b1,
    datasize: dm::DataCount,
    dataaddr: dm::DataAddr
  };
  localparam bit [NumInternalDebug-1:0] ActuallySelectableHarts =
    SelectableHarts | 1<<SafetyIslandCfg.HartId;

  dm::hartinfo_t [NumInternalDebug-1:0] hartinfo;
  for (genvar i = 0; i < NumInternalDebug; i++) begin : gen_hartinfo
    if (i == SafetyIslandCfg.HartId) begin : gen_static_hartinfo
      assign hartinfo[i] = HARTINFO;
    end else if (i <= NumDebug) begin : gen_ext_hartinfo
      assign hartinfo[i] = HartInfo[i];
    end else begin : gen_disable_hartinfo
      assign hartinfo[i] = '0;
    end
  end

  logic dmi_rst_n, dmi_req_valid, dmi_req_ready, dmi_resp_valid, dmi_resp_ready;
  dm::dmi_req_t dmi_req;
  dm::dmi_resp_t dmi_resp;

  dmi_jtag #(
    .IdcodeValue(SafetyIslandCfg.PulpJtagIdCode)
  ) i_dmi_jtag (
    .clk_i,
    .rst_ni,
    .testmode_i       ( test_enable_i  ),

    .dmi_rst_no       ( dmi_rst_n      ),
    .dmi_req_o        ( dmi_req        ),
    .dmi_req_valid_o  ( dmi_req_valid  ),
    .dmi_req_ready_i  ( dmi_req_ready  ),

    .dmi_resp_i       ( dmi_resp       ),
    .dmi_resp_ready_o ( dmi_resp_ready ),
    .dmi_resp_valid_i ( dmi_resp_valid ),

    .tck_i            ( jtag_tck_i     ),
    .tms_i            ( jtag_tms_i     ),
    .trst_ni          ( jtag_trst_ni    ),
    .td_i             ( jtag_tdi_i     ),
    .td_o             ( jtag_tdo_o     ),
    .tdo_oe_o         ()
  );

  dm_top #(
    .NrHarts        ( NumInternalDebug        ),
    .BusWidth       ( 32                      ),
    .SelectableHarts( ActuallySelectableHarts ),
    .ReadByteEnable ( 0                       )
  ) i_dm_top (
    .clk_i,
    .rst_ni,
    .testmode_i           ( test_enable_i  ),
    .ndmreset_o           (),
    .dmactive_o           (),
    .debug_req_o          ( debug_req                ),
    .unavailable_i        ( ~ActuallySelectableHarts ),
    .hartinfo_i           ( hartinfo                 ),

    .slave_req_i          ( dbg_mem_obi_req.req    ),
    .slave_we_i           ( dbg_mem_obi_req.a.we     ),
    .slave_addr_i         ( dbg_mem_obi_req.a.addr   ),
    .slave_be_i           ( dbg_mem_obi_req.a.be     ),
    .slave_wdata_i        ( dbg_mem_obi_req.a.wdata  ),
    .slave_rdata_o        ( dbg_mem_obi_rsp.r.rdata  ),

    .master_req_o         ( dbg_req_obi_req.req    ),
    .master_add_o         ( dbg_req_obi_req.a.addr   ),
    .master_we_o          ( dbg_req_obi_req.a.we     ),
    .master_wdata_o       ( dbg_req_obi_req.a.wdata  ),
    .master_be_o          ( dbg_req_obi_req.a.be     ),
    .master_gnt_i         ( dbg_req_obi_rsp.gnt    ),
    .master_r_valid_i     ( dbg_req_obi_rsp.rvalid ),
    .master_r_err_i       ( dbg_req_obi_rsp.r.err    ),
    .master_r_other_err_i ( 1'b0           ),
    .master_r_rdata_i     ( dbg_req_obi_rsp.r.rdata  ),

    .dmi_rst_ni           ( dmi_rst_n      ),
    .dmi_req_valid_i      ( dmi_req_valid  ),
    .dmi_req_ready_o      ( dmi_req_ready  ),
    .dmi_req_i            ( dmi_req        ),

    .dmi_resp_valid_o     ( dmi_resp_valid ),
    .dmi_resp_ready_i     ( dmi_resp_ready ),
    .dmi_resp_o           ( dmi_resp       )
  );

  assign dbg_mem_obi_rsp.gnt = 1'b1;
  assign dbg_mem_obi_rsp.r.err = '0;
  assign dbg_mem_obi_rsp.r.r_optional = '0;
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_dbg_mem
    if(!rst_ni) begin
      dbg_mem_obi_rsp.rvalid <= '0;
      dbg_mem_obi_rsp.r.rid <= '0;
    end else begin
      dbg_mem_obi_rsp.rvalid <= dbg_mem_obi_req.req;
      dbg_mem_obi_rsp.r.rid <= dbg_mem_obi_req.a.aid;
    end
  end

  // -----------------
  // Main Interconnect
  // -----------------

  obi_xbar #(
    .SbrPortObiCfg      ( MgrObiCfg        ),
    .MgrPortObiCfg      ( XbarSbrObiCfg    ),
    .sbr_port_obi_req_t ( mgr_obi_req_t    ),
    .sbr_port_a_chan_t  ( mgr_obi_a_chan_t ),
    .sbr_port_obi_rsp_t ( mgr_obi_rsp_t    ),
    .sbr_port_r_chan_t  ( mgr_obi_r_chan_t ),
    .mgr_port_obi_req_t ( xbar_sbr_obi_req_t ),
    .mgr_port_obi_rsp_t ( xbar_sbr_obi_rsp_t ),
    .NumSbrPorts        ( NumManagers      ),
    .NumMgrPorts        ( NumSubordinates  ),
    .NumMaxTrans        ( 2                ),
    .NumAddrRules       ( NumRules         ),
    .addr_map_rule_t    ( addr_map_rule_t  ),
    .UseIdForRouting    ( 1'b0             ),
    .Connectivity       ( '1               )
  ) i_main_xbar (
    .clk_i,
    .rst_ni,
    .testmode_i       ( test_enable_i ),

    .sbr_ports_req_i  ( {axi_input_obi_req,
                         core_instr_obi_req,
                         core_data_obi_req,
                         core_shadow_obi_req,
                         dbg_req_obi_req} ),
    .sbr_ports_rsp_o  ( {axi_input_obi_rsp,
                         core_instr_obi_rsp,
                         core_data_obi_rsp,
                         core_shadow_obi_rsp,
                         dbg_req_obi_rsp} ),
    .mgr_ports_req_o  ( all_sbr_obi_req ),
    .mgr_ports_rsp_i  ( all_sbr_obi_rsp ),

    .addr_map_i       ( MainAddrMap ),
    .en_default_idx_i ( 5'b11111 ),
    .default_idx_i    ( '0 )
  );

  // -----------------
  // Memories
  // -----------------

  logic [SafetyIslandCfg.NumBanks-1:0] bank_faults;
  logic [SafetyIslandCfg.NumBanks-1:0] scrub_fix;
  logic [SafetyIslandCfg.NumBanks-1:0] scrub_uncorrectable;
  logic [SafetyIslandCfg.NumBanks-1:0] scrub_trigger;

  for (genvar i = 0; i < SafetyIslandCfg.NumBanks; i++) begin : gen_sram_bank
    obi_atop_resolver #(
      .SbrPortObiCfg             ( XbarSbrObiCfg        ),
      .MgrPortObiCfg             ( SbrObiCfg            ),
      .sbr_port_obi_req_t        ( xbar_sbr_obi_req_t   ),
      .sbr_port_obi_rsp_t        ( xbar_sbr_obi_rsp_t   ),
      .mgr_port_obi_req_t        ( sbr_obi_req_t        ),
      .mgr_port_obi_rsp_t        ( sbr_obi_rsp_t        ),
      .mgr_port_obi_a_optional_t ( sbr_obi_a_optional_t ),
      .mgr_port_obi_r_optional_t ( sbr_obi_r_optional_t ),
      .LrScEnable                ( 1                    ),
      .RegisterAmo               ( 1'b0                 )
    ) i_bank_atop_resolver (
      .clk_i,
      .rst_ni,
      .testmode_i     ( test_enable_i            ),
      .sbr_port_req_i ( xbar_mem_bank_obi_req[i] ),
      .sbr_port_rsp_o ( xbar_mem_bank_obi_rsp[i] ),
      .mgr_port_req_o ( mem_bank_obi_req[i]      ),
      .mgr_port_rsp_i ( mem_bank_obi_rsp[i]      )
    );

    sbr_obi_rsp_t tmp_bank_obi_rsp;
    logic bank_req, bank_we, bank_gnt, bank_single_err;
    logic [AddrWidth-1:0] bank_addr;
    logic [DataWidth-1:0] bank_wdata, bank_rdata;
    logic [DataWidth/8-1:0] bank_be;

    always_comb begin : proc_mem_ecc_err
      mem_bank_obi_rsp[i] = tmp_bank_obi_rsp;
      mem_bank_obi_rsp[i].r.r_optional.ruser = bank_single_err;
    end

    obi_sram_shim #(
      .ObiCfg    ( SbrObiCfg     ),
      .obi_req_t ( sbr_obi_req_t ),
      .obi_rsp_t ( sbr_obi_rsp_t )
    ) i_sram_shim_bank (
      .clk_i,
      .rst_ni,

      .obi_req_i ( mem_bank_obi_req[i] ),
      .obi_rsp_o ( tmp_bank_obi_rsp ),

      .req_o   ( bank_req   ),
      .we_o    ( bank_we    ),
      .addr_o  ( bank_addr  ),
      .wdata_o ( bank_wdata ),
      .be_o    ( bank_be    ),

      .gnt_i   ( bank_gnt   ),
      .rdata_i ( bank_rdata )
    );

    ecc_sram_wrap #(
      .BankSize        (BankNumWords),
      .InputECC        (0),
      .EnableTestMask  (0)
    ) i_mem_bank (
      .clk_i,
      .rst_ni,
      .test_enable_i         ( test_enable_i ),

      .scrub_trigger_i       ( scrub_trigger      [i] ),
      .scrubber_fix_o        ( scrub_fix          [i] ),
      .scrub_uncorrectable_o ( scrub_uncorrectable[i] ),

      .tcdm_wdata_i          ( bank_wdata ),
      .tcdm_add_i            ( bank_addr  ),
      .tcdm_req_i            ( bank_req   ),
      .tcdm_wen_i            ( ~bank_we   ),
      .tcdm_be_i             ( bank_be    ),
      .tcdm_rdata_o          ( bank_rdata ),
      .tcdm_gnt_o            ( bank_gnt   ),
      .single_error_o        ( bank_faults[i] ),
      .multi_error_o         ( bank_single_err ),

      .test_write_mask_ni    ( '0 )
    );
  end

  // ECC Manager
  periph_to_reg #(
    .AW    ( AddrWidth         ),
    .DW    ( DataWidth         ),
    .BW    ( 8                 ),
    .IW    ( SbrObiCfg.IdWidth ),
    .req_t ( safety_reg_req_t  ),
    .rsp_t ( safety_reg_rsp_t  )
  ) i_ecc_mgr_translate (
    .clk_i,
    .rst_ni,

    .req_i     ( ecc_mgr_obi_req.req     ),
    .add_i     ( ecc_mgr_obi_req.a.addr  ),
    .wen_i     ( ~ecc_mgr_obi_req.a.we   ),
    .wdata_i   ( ecc_mgr_obi_req.a.wdata ),
    .be_i      ( ecc_mgr_obi_req.a.be    ),
    .id_i      ( ecc_mgr_obi_req.a.aid   ),

    .gnt_o     ( ecc_mgr_obi_rsp.gnt     ),
    .r_rdata_o ( ecc_mgr_obi_rsp.r.rdata ),
    .r_opc_o   ( ecc_mgr_obi_rsp.r.err   ),
    .r_id_o    ( ecc_mgr_obi_rsp.r.rid   ),
    .r_valid_o ( ecc_mgr_obi_rsp.rvalid  ),

    .reg_req_o ( ecc_mgr_reg_req ),
    .reg_rsp_i ( ecc_mgr_reg_rsp )
  );
  assign ecc_mgr_obi_rsp.r.r_optional = '0;

  ecc_manager #(
    .NumBanks      ( SafetyIslandCfg.NumBanks ),
    .ecc_mgr_req_t ( safety_reg_req_t ),
    .ecc_mgr_rsp_t ( safety_reg_rsp_t )
  ) i_ecc_manager (
    .clk_i,
    .rst_ni,
    .ecc_mgr_req_i        ( ecc_mgr_reg_req     ),
    .ecc_mgr_rsp_o        ( ecc_mgr_reg_rsp     ),
    .bank_faults_i        ( bank_faults         ),
    .scrub_fix_i          ( scrub_fix           ),
    .scrub_uncorrectable_i( scrub_uncorrectable ),
    .scrub_trigger_o      ( scrub_trigger       ),
    .test_write_mask_no   ()
  );

  // -----------------
  // Periphs
  // -----------------

  obi_atop_resolver #(
    .SbrPortObiCfg             ( XbarSbrObiCfg        ),
    .MgrPortObiCfg             ( SbrObiCfg            ),
    .sbr_port_obi_req_t        ( xbar_sbr_obi_req_t   ),
    .sbr_port_obi_rsp_t        ( xbar_sbr_obi_rsp_t   ),
    .mgr_port_obi_req_t        ( sbr_obi_req_t        ),
    .mgr_port_obi_rsp_t        ( sbr_obi_rsp_t        ),
    .mgr_port_obi_a_optional_t ( sbr_obi_a_optional_t ),
    .mgr_port_obi_r_optional_t ( sbr_obi_r_optional_t ),
    .LrScEnable                ( 1                    ),
    .RegisterAmo               ( 1'b0                 )
  ) i_periph_atop_resolver (
    .clk_i,
    .rst_ni,
    .testmode_i     ( test_enable_i       ),
    .sbr_port_req_i ( xbar_periph_obi_req ),
    .sbr_port_rsp_o ( xbar_periph_obi_rsp ),
    .mgr_port_req_o ( periph_obi_req      ),
    .mgr_port_rsp_i ( periph_obi_rsp      )
  );


  logic [cf_math_pkg::idx_width(NumPeriphs)-1:0] periph_idx;

  addr_decode #(
    .NoIndices ( NumPeriphs      ),
    .NoRules   ( NumPeriphRules  ),
    .addr_t    ( logic[31:0]     ),
    .rule_t    ( addr_map_rule_t ),
    .Napot     ( 1'b0            )
  ) i_addr_decode_periphs (
    .addr_i           ( periph_obi_req.a.addr ),
    .addr_map_i       ( PeriphAddrMap ),
    .idx_o            ( periph_idx      ),
    .dec_valid_o      (),
    .dec_error_o      (),
    .en_default_idx_i ( 1'b1 ),
    .default_idx_i    ( '0 )
  );

  obi_demux #(
    .ObiCfg      ( SbrObiCfg     ),
    .obi_req_t   ( sbr_obi_req_t ),
    .obi_rsp_t   ( sbr_obi_rsp_t ),
    .NumMgrPorts ( NumPeriphs    ),
    .NumMaxTrans ( 2 )
  ) i_obi_demux (
    .clk_i,
    .rst_ni,

    .sbr_port_select_i ( periph_idx     ),
    .sbr_port_req_i    ( periph_obi_req ),
    .sbr_port_rsp_o    ( periph_obi_rsp ),

    .mgr_ports_req_o   ( all_periph_obi_req ),
    .mgr_ports_rsp_i   ( all_periph_obi_rsp )
  );

  // Error subordinate
  obi_err_sbr #(
    .ObiCfg      ( SbrObiCfg     ),
    .obi_req_t   ( sbr_obi_req_t ),
    .obi_rsp_t   ( sbr_obi_rsp_t ),
    .NumMaxTrans ( 1             ),
    .RspData     ( 32'hBADCAB1E  )
  ) i_err_sbr (
    .clk_i,
    .rst_ni,
    .testmode_i ( test_enable_i ),
    .obi_req_i  ( error_obi_req ),
    .obi_rsp_o  ( error_obi_rsp )
  );

  obi_err_sbr #(
    .ObiCfg      ( SbrObiCfg     ),
    .obi_req_t   ( sbr_obi_req_t ),
    .obi_rsp_t   ( sbr_obi_rsp_t ),
    .NumMaxTrans ( 1             ),
    .RspData     ( 32'hBADCAB1E  )
  ) i_global_prepend_err (
    .clk_i,
    .rst_ni,
    .testmode_i ( test_enable_i          ),
    .obi_req_i  ( global_prepend_obi_req ),
    .obi_rsp_o  ( global_prepend_obi_rsp )
  );

  // SoC Control
  periph_to_reg #(
    .AW    ( AddrWidth         ),
    .DW    ( DataWidth         ),
    .BW    ( 8                 ),
    .IW    ( SbrObiCfg.IdWidth ),
    .req_t ( safety_reg_req_t  ),
    .rsp_t ( safety_reg_rsp_t  )
  ) i_soc_ctrl_translate (
    .clk_i,
    .rst_ni,

    .req_i     ( soc_ctrl_obi_req.req     ),
    .add_i     ( soc_ctrl_obi_req.a.addr  ),
    .wen_i     ( ~soc_ctrl_obi_req.a.we   ),
    .wdata_i   ( soc_ctrl_obi_req.a.wdata ),
    .be_i      ( soc_ctrl_obi_req.a.be    ),
    .id_i      ( soc_ctrl_obi_req.a.aid   ),

    .gnt_o     ( soc_ctrl_obi_rsp.gnt     ),
    .r_rdata_o ( soc_ctrl_obi_rsp.r.rdata ),
    .r_opc_o   ( soc_ctrl_obi_rsp.r.err   ),
    .r_id_o    ( soc_ctrl_obi_rsp.r.rid   ),
    .r_valid_o ( soc_ctrl_obi_rsp.rvalid  ),

    .reg_req_o ( soc_ctrl_reg_req ),
    .reg_rsp_i ( soc_ctrl_reg_rsp )
  );
  assign soc_ctrl_obi_rsp.r.r_optional = '0;

  logic first_cycle;
  safety_soc_ctrl_reg_pkg::safety_soc_ctrl_reg2hw_t soc_ctrl_reg2hw;
  safety_soc_ctrl_reg_pkg::safety_soc_ctrl_hw2reg_t soc_ctrl_hw2reg;
  // allow control of fetch_enable from hardware
  assign soc_ctrl_hw2reg.bootmode.d  = bootmode_i;
  assign soc_ctrl_hw2reg.bootmode.de = first_cycle;
  assign soc_ctrl_hw2reg.fetchen.d   = bootmode_i == Jtag;
  assign soc_ctrl_hw2reg.fetchen.de  = first_cycle;
  assign fetch_enable = soc_ctrl_reg2hw.fetchen.q | fetch_enable_i;
  assign boot_addr = soc_ctrl_reg2hw.bootaddr.q;


  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_initial_ff
    if(!rst_ni) begin
      first_cycle <= 1'b1;
    end else begin
      first_cycle <= '0;
    end
  end

  safety_soc_ctrl_reg_top #(
    .reg_req_t( safety_reg_req_t ),
    .reg_rsp_t( safety_reg_rsp_t ),
    .BootAddrDefault ( PeriphBaseAddr + BootROMAddrOffset + 32'h80 )
  ) i_soc_ctrl (
    .clk_i,
    .rst_ni,
    .reg_req_i ( soc_ctrl_reg_req ),
    .reg_rsp_o ( soc_ctrl_reg_rsp ),
    .reg2hw    ( soc_ctrl_reg2hw  ),
    .hw2reg    ( soc_ctrl_hw2reg  ),
    .devmode_i ( 1'b0             )
  );

  // Boot ROM
  safety_island_bootrom #(
    .ADDR_WIDTH ( 10 ),
    .DATA_WIDTH ( DataWidth )
  ) i_bootrom (
    .CLK   ( clk_i ),
    .RST_N ( rst_ni ),
    .CEN   ( ~boot_rom_obi_req.req ),
    .A     ( boot_rom_obi_req.a.addr[11:2] ),
    .Q     ( boot_rom_obi_rsp.r.rdata )
  );
  assign boot_rom_obi_rsp.gnt = 1'b1;
  assign boot_rom_obi_rsp.r.err = 1'b0;
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_boot_rom_rvalid
    if(!rst_ni) begin
      boot_rom_obi_rsp.rvalid <= '0;
      boot_rom_obi_rsp.r.rid <= '0;
    end else begin
      boot_rom_obi_rsp.rvalid <= boot_rom_obi_req.req;
      boot_rom_obi_rsp.r.rid <= boot_rom_obi_req.a.aid;
    end
  end
  assign boot_rom_obi_rsp.r.r_optional = '0;

  // Core-local Peripherals
  periph_to_reg #(
    .AW    ( AddrWidth         ),
    .DW    ( DataWidth         ),
    .BW    ( 8                 ),
    .IW    ( SbrObiCfg.IdWidth ),
    .req_t ( safety_reg_req_t  ),
    .rsp_t ( safety_reg_rsp_t  )
  ) i_core_local_translate (
    .clk_i,
    .rst_ni,

    .req_i     ( cl_periph_obi_req.req     ),
    .add_i     ( cl_periph_obi_req.a.addr  ),
    .wen_i     ( ~cl_periph_obi_req.a.we   ),
    .wdata_i   ( cl_periph_obi_req.a.wdata ),
    .be_i      ( cl_periph_obi_req.a.be    ),
    .id_i      ( cl_periph_obi_req.a.aid   ),

    .gnt_o     ( cl_periph_obi_rsp.gnt     ),
    .r_rdata_o ( cl_periph_obi_rsp.r.rdata ),
    .r_opc_o   ( cl_periph_obi_rsp.r.err   ),
    .r_id_o    ( cl_periph_obi_rsp.r.rid   ),
    .r_valid_o ( cl_periph_obi_rsp.rvalid  ),

    .reg_req_o ( cl_periph_reg_req ),
    .reg_rsp_i ( cl_periph_reg_rsp )
  );
  assign cl_periph_obi_rsp.r.r_optional = '0;


  // Core-local Peripherals
  periph_to_reg #(
    .AW    ( AddrWidth         ),
    .DW    ( DataWidth         ),
    .BW    ( 8                 ),
    .IW    ( SbrObiCfg.IdWidth ),
    .req_t ( safety_reg_req_t  ),
    .rsp_t ( safety_reg_rsp_t  )
  ) i_timer_translate (
    .clk_i,
    .rst_ni,

    .req_i     ( timer_obi_req.req     ),
    .add_i     ( timer_obi_req.a.addr  ),
    .wen_i     ( ~timer_obi_req.a.we   ),
    .wdata_i   ( timer_obi_req.a.wdata ),
    .be_i      ( timer_obi_req.a.be    ),
    .id_i      ( timer_obi_req.a.aid   ),

    .gnt_o     ( timer_obi_rsp.gnt     ),
    .r_rdata_o ( timer_obi_rsp.r.rdata ),
    .r_opc_o   ( timer_obi_rsp.r.err   ),
    .r_id_o    ( timer_obi_rsp.r.rid   ),
    .r_valid_o ( timer_obi_rsp.rvalid  ),

    .reg_req_o ( timer_reg_req ),
    .reg_rsp_i ( timer_reg_rsp )
  );
  assign timer_obi_rsp.r.r_optional = '0;

  // Timer bus (APB interface)
  `APB_TYPEDEF_REQ_T(safety_apb_req_t, logic [31:0], logic [31:0], logic [3:0])
  `APB_TYPEDEF_RESP_T(safety_apb_rsp_t, logic [31:0])
  safety_apb_req_t timer_apb_req;
  safety_apb_rsp_t timer_apb_rsp;

  reg_to_apb #(
    .reg_req_t(safety_reg_req_t),
    .reg_rsp_t(safety_reg_rsp_t),
    .apb_req_t(safety_apb_req_t),
    .apb_rsp_t(safety_apb_rsp_t)
  ) i_reg_to_apb_timer (
    .clk_i,
    .rst_ni,
    // Register interface
    .reg_req_i (timer_reg_req),
    .reg_rsp_o (timer_reg_rsp),
    // APB interface
    .apb_req_o (timer_apb_req),
    .apb_rsp_i (timer_apb_rsp)
  );

  apb_timer_unit #(
    .APB_ADDR_WIDTH(32)
  ) i_apb_timer_unit (
    .HCLK       ( clk_i                 ),
    .HRESETn    ( rst_ni                ),
    .PADDR      ( timer_apb_req.paddr   ),
    .PWDATA     ( timer_apb_req.pwdata  ),
    .PWRITE     ( timer_apb_req.pwrite  ),
    .PSEL       ( timer_apb_req.psel    ),
    .PENABLE    ( timer_apb_req.penable ),
    .PRDATA     ( timer_apb_rsp.prdata  ),
    .PREADY     ( timer_apb_rsp.pready  ),
    .PSLVERR    ( timer_apb_rsp.pslverr ),
    .ref_clk_i,
    .event_lo_i ('0/*s_timer_in_lo_event*/),
    .event_hi_i ('0/*s_timer_in_hi_event*/),
    .irq_lo_o   ( s_timer_irqs[0]       ),
    .irq_hi_o   ( s_timer_irqs[1]       ),
    .busy_o     (                       )
  );

`ifdef TARGET_SIMULATION
  // TB Printf
  tb_fs_handler_debug #(
    .ADDR_WIDTH ( 12 ),
    .DATA_WIDTH ( DataWidth ),
    .NB_CORES   ( 1         ),
    .CLUSTER_ID ( 0 ),
    .OPEN_FILES ( 1 ),
    .DEBUG_TYPE ( "PE" ),
    .SILENT_MODE ( "OFF" ),
    .FULL_LINE   ( "ON" ),
    .COLORED_MODE ( "OFF" )
  ) i_fs_handler (
    .clk_i  ( clk_i          ),
    .rst_ni ( rst_ni         ),
    .req_i  ( tbprintf_obi_req.req  ),
    .add_i  ( '0 ),//tbprintf_addr[11:0]  ),
    .dat_i  ( tbprintf_obi_req.a.wdata )
  );

  assign tbprintf_obi_rsp.r.rdata = '0;
  assign tbprintf_obi_rsp.gnt = 1'b1;
  assign tbprintf_obi_rsp.r.err = 1'b0;
  assign tbprintf_obi_rsp.r.r_optional = 1'b0;
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_tbprintf_rvalid
    if(!rst_ni) begin
      tbprintf_obi_rsp.rvalid <= '0;
      tbprintf_obi_rsp.r.rid <= '0;
    end else begin
      tbprintf_obi_rsp.rvalid <= tbprintf_obi_req.req;
      tbprintf_obi_rsp.r.rid <= tbprintf_obi_req.a.aid;
    end
  end
`endif

  // -----------------
  // AXI connections
  // -----------------

  // AXI input

  localparam int unsigned NumInterBanks = AxiDataWidth/MgrObiCfg.DataWidth;
  logic [NumInterBanks-1:0][AxiInputIdWidth-1:0] axi_in_aw_id, axi_in_ar_id;
  logic [NumInterBanks-1:0][AxiUserWidth-1:0] axi_in_aw_user, axi_in_w_user, axi_in_ar_user;
  logic [NumInterBanks-1:0][MgrObiCfg.IdWidth-1:0] obi_in_write_aid, obi_in_read_aid;

  logic [AxiUserWidth-1:0] axi_in_rsp_aw_user, axi_in_rsp_w_user, axi_in_rsp_ar_user;
  logic [AxiUserWidth-1:0] axi_in_r_user, axi_in_b_user;
  logic [NumInterBanks-1:0] axi_in_rsp_write_bank_strobe, axi_in_rsp_read_size_enable;
  logic [NumInterBanks-1:0][MgrObiCfg.IdWidth-1:0] obi_in_rsp_write_rid, obi_in_rsp_read_rid;
  logic [NumInterBanks-1:0][MgrObiCfg.OptionalCfg.RUserWidth-1:0] obi_in_rsp_write_ruser,
                                                                  obi_in_rsp_read_ruser;
  logic axi_in_rsp_write_last, axi_in_rsp_write_hs;

  logic axi_b_ecc_err_incr;

  for (genvar i = 0; i < NumInterBanks; i++) begin : gen_ext_obi_aid
    if (AxiUserAtop) begin : gen_user_atop
      assign obi_in_write_aid[i] = axi_in_aw_user[i][AxiUserAtopMsb:AxiUserAtopLsb];
      assign obi_in_read_aid [i] = axi_in_ar_user[i][AxiUserAtopMsb:AxiUserAtopLsb];
    end else begin : gen_plain_atop
      assign obi_in_write_aid[i] = axi_in_aw_id[i];
      assign obi_in_read_aid [i] = axi_in_ar_id[i];
    end
  end

  always_comb begin : proc_obi_user
    axi_in_r_user = '0;
    axi_in_b_user = '0;
    // Respond with same ATOP ID
    if (AxiUserAtop) begin
      for (int i = 0; i < NumInterBanks; i++) begin
        axi_in_r_user[AxiUserAtopMsb:AxiUserAtopLsb] |= axi_in_rsp_read_size_enable[i] ?
                                                          obi_in_rsp_read_rid[i] : '0;
        // No need to buffer the ATOP ID
        axi_in_b_user[AxiUserAtopMsb:AxiUserAtopLsb] |= axi_in_rsp_write_bank_strobe[i] ?
                                                          obi_in_rsp_write_rid[i] : '0;
      end
    end
    // Attach ECC error
    if (AxiUserEccErr) begin
      axi_in_r_user[AxiUserEccErrBit:AxiUserEccErrBit] =
        |(axi_in_rsp_read_size_enable & obi_in_rsp_read_ruser);
      axi_in_b_user[AxiUserEccErrBit:AxiUserEccErrBit] = axi_b_ecc_err_incr;
    end
  end

  // Collect ECC error
  if (AxiUserEccErr) begin : gen_ext_obi_ecc_err
    logic axi_b_ecc_err_d, axi_b_ecc_err_q;
    assign axi_b_ecc_err_incr = axi_b_ecc_err_q |
                                (axi_in_rsp_write_hs &
                                  |(obi_in_rsp_write_ruser & axi_in_rsp_write_bank_strobe));
    assign axi_b_ecc_err_d = axi_in_rsp_write_last && axi_in_rsp_write_hs ? '0 : axi_b_ecc_err_incr;
    always_ff @(posedge clk_i or negedge rst_ni) begin : proc_axi_b_ecc_err
      if(~rst_ni) begin
        axi_b_ecc_err_q <= 0;
      end else begin
        axi_b_ecc_err_q <= axi_b_ecc_err_d;
      end
    end
  end else begin : gen_ext_obi_ecc_no_err
    assign axi_b_ecc_err_incr = '0;
  end

  axi_to_obi #(
    .ObiCfg         ( MgrObiCfg        ),
    .obi_req_t      ( mgr_obi_req_t    ),
    .obi_rsp_t      ( mgr_obi_rsp_t    ),
    .obi_a_chan_t   ( mgr_obi_a_chan_t ),
    .obi_r_chan_t   ( mgr_obi_r_chan_t ),
    .AxiAddrWidth   ( AxiAddrWidth     ),
    .AxiDataWidth   ( AxiDataWidth     ),
    .AxiIdWidth     ( AxiInputIdWidth  ),
    .AxiUserWidth   ( AxiUserWidth     ),
    .MaxTrans       ( 2                ),
    .axi_req_t      ( axi_input_req_t  ),
    .axi_rsp_t      ( axi_input_resp_t )
  ) i_axi_to_obi (
    .clk_i,
    .rst_ni,
    .testmode_i        ( test_enable_i      ),
    .axi_req_i         ( axi_input_req_i    ),
    .axi_rsp_o         ( axi_input_resp_o   ),
    .obi_req_o         ( axi_input_obi_req  ),
    .obi_rsp_i         ( axi_input_obi_rsp  ),

    .req_aw_id_o       ( axi_in_aw_id       ),
    .req_aw_user_o     ( axi_in_aw_user     ),
    .req_w_user_o      ( axi_in_w_user      ),
    .req_write_aid_i   ( obi_in_write_aid   ),
    .req_write_auser_i ( '0                 ),
    .req_write_wuser_i ( '0                 ),

    .req_ar_id_o       ( axi_in_ar_id       ),
    .req_ar_user_o     ( axi_in_ar_user     ),
    .req_read_aid_i    ( obi_in_read_aid    ),
    .req_read_auser_i  ( '0  ),

    .rsp_write_aw_user_o   ( axi_in_rsp_aw_user           ),
    .rsp_write_w_user_o    ( axi_in_rsp_w_user            ),
    .rsp_write_bank_strb_o ( axi_in_rsp_write_bank_strobe ),
    .rsp_write_rid_o       ( obi_in_rsp_write_rid         ),
    .rsp_write_ruser_o     ( obi_in_rsp_write_ruser       ),
    .rsp_write_last_o      ( axi_in_rsp_write_last        ),
    .rsp_write_hs_o        ( axi_in_rsp_write_hs          ),
    .rsp_b_user_i          ( axi_in_b_user                ),

    .rsp_read_ar_user_o    ( axi_in_rsp_ar_user           ),
    .rsp_read_size_enable_o( axi_in_rsp_read_size_enable  ),
    .rsp_read_rid_o        ( obi_in_rsp_read_rid          ),
    .rsp_read_ruser_o      ( obi_in_rsp_read_ruser        ),
    .rsp_r_user_i          ( axi_in_r_user                )
  );

  // AXI output

  logic [1:0]                                      axi_out_rsp_sel;
  logic [AxiUserWidth-1:0]                         axi_out_b_user,
                                                   axi_out_r_user;
  logic [XbarSbrObiCfg.OptionalCfg.RUserWidth-1:0] axi_out_obi_user;

  // Currently only implements ECC error bit
  if (AxiUserEccErr) begin : gen_ext_ecc_err
    assign axi_out_obi_user = axi_out_rsp_sel[1] ?
                                axi_out_b_user[AxiUserEccErrBit] | axi_out_r_user[AxiUserEccErrBit]:
                                axi_out_rsp_sel[0] ?
                                  axi_out_b_user[AxiUserEccErrBit] :
                                  axi_out_r_user[AxiUserEccErrBit];
  end else begin : gen_plain_user
    assign axi_out_obi_user = '0;
  end

  obi_to_axi #(
    .ObiCfg       ( XbarSbrObiCfg      ),
    .obi_req_t    ( xbar_sbr_obi_req_t ),
    .obi_rsp_t    ( xbar_sbr_obi_rsp_t ),
    .axi_req_t    ( axi_output_req_t   ),
    .axi_rsp_t    ( axi_output_resp_t  ),
    .AxiAddrWidth ( AxiAddrWidth       ),
    .AxiDataWidth ( AxiDataWidth       ),
    .AxiUserWidth ( AxiUserWidth       ),
    .MaxRequests  ( 2                  ),
    .AxiLite      ( 1'b0               )
  ) i_obi_to_axi (
    .clk_i,
    .rst_ni,
    .obi_req_i ( axi_output_obi_req ),
    .obi_rsp_o ( axi_output_obi_rsp ),
    .user_i    ( DefaultUser        ),// Only one ATOP-capable master (cv32e40p data port),
                                      // so we have only one user config even when using user as ATOP ID.
    .axi_req_o ( axi_output_req_o   ),
    .axi_rsp_i ( axi_output_resp_i  ),

    .axi_rsp_channel_sel ( axi_out_rsp_sel  ),
    .axi_rsp_b_user_o    ( axi_out_b_user   ),
    .axi_rsp_r_user_o    ( axi_out_r_user   ),
    .obi_rsp_user_i      ( axi_out_obi_user )
  );

  // TODO?: AXI AddrWidth prepend

endmodule
