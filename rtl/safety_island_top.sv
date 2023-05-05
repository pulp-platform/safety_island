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
  parameter safety_island_pkg::safety_island_cfg_t SafetyIslandCfg = safety_island_pkg::SafetyIslandDefaultConfig,

  parameter  int unsigned              GlobalAddrWidth = 32,
  parameter  bit [GlobalAddrWidth-1:0] BaseAddr        = 32'h0000_0000,
  parameter  bit [31:0]                AddrRange       = 32'h0080_0000,
  parameter  bit [31:0]                MemOffset       = 32'h0000_0000,
  parameter  bit [31:0]                PeriphOffset    = 32'h0020_0000,

  parameter  int unsigned              NumDebug        = 96,
  parameter  bit [NumDebug-1:0]        SelectableHarts = {NumDebug{1'b0}},
  parameter  dm::hartinfo_t [NumDebug-1:0] HartInfo    = {NumDebug{'0}},

  /// AXI slave port structs (input)
  parameter int unsigned AxiDataWidth      = 64,
  parameter int unsigned AxiAddrWidth      = GlobalAddrWidth,
  parameter int unsigned AxiInputIdWidth   = 1,
  parameter int unsigned AxiUserWidth      = 1,
  parameter type         axi_input_req_t   = logic,
  parameter type         axi_input_resp_t  = logic,

  /// AXI master port structs (output)
  parameter int unsigned AxiOutputIdWidth  = 1,
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
  localparam obi_pkg::obi_cfg_t MgrObiCfg = obi_pkg::ObiDefaultConfig;
  localparam obi_pkg::obi_cfg_t SbrObiCfg = obi_pkg::mux_grow_cfg(MgrObiCfg, NumManagers);
  `OBI_TYPEDEF_MINIMAL_A_OPTIONAL(obi_a_optional_t)
  `OBI_TYPEDEF_A_CHAN_T(mgr_obi_a_chan_t, MgrObiCfg.AddrWidth, MgrObiCfg.DataWidth, MgrObiCfg.IdWidth, obi_a_optional_t)
  `OBI_TYPEDEF_A_CHAN_T(sbr_obi_a_chan_t, SbrObiCfg.AddrWidth, SbrObiCfg.DataWidth, SbrObiCfg.IdWidth, obi_a_optional_t)
  `OBI_TYPEDEF_DEFAULT_REQ_T(mgr_obi_req_t, mgr_obi_a_chan_t)
  `OBI_TYPEDEF_DEFAULT_REQ_T(sbr_obi_req_t, sbr_obi_a_chan_t)
  `OBI_TYPEDEF_MINIMAL_R_OPTIONAL(obi_r_optional_t)
  `OBI_TYPEDEF_R_CHAN_T(mgr_obi_r_chan_t, MgrObiCfg.DataWidth, MgrObiCfg.IdWidth, obi_r_optional_t)
  `OBI_TYPEDEF_R_CHAN_T(sbr_obi_r_chan_t, SbrObiCfg.DataWidth, SbrObiCfg.IdWidth, obi_r_optional_t)
  `OBI_TYPEDEF_RSP_T(mgr_obi_rsp_t, mgr_obi_r_chan_t)
  `OBI_TYPEDEF_RSP_T(sbr_obi_rsp_t, sbr_obi_r_chan_t)
  `REG_BUS_TYPEDEF_ALL(safety_reg, logic[AddrWidth-1:0], logic[DataWidth-1:0], logic[(DataWidth/8)-1:0]);

`ifdef TARGET_SIMULATION
  localparam int unsigned NumPeriphs     = 8;
  localparam int unsigned NumPeriphRules = 7;
`else
  localparam int unsigned NumPeriphs     = 7;
  localparam int unsigned NumPeriphRules = 6;
`endif

  localparam int unsigned NumSubordinates = 4;
  localparam int unsigned NumRules = (MemOffset != 0) ? 4 : 3;

  // MemOffset != 0
  localparam addr_map_rule_t [3:0] large_addr_map = '{             // 0: below/above address space, so AXI out (default)
    '{ idx: 1, start_addr: BaseAddr32+MemOffset,                                end_addr: BaseAddr32+MemOffset+SafetyIslandCfg.BankNumBytes  }, // 1: Bank 0
    '{ idx: 2, start_addr: BaseAddr32+MemOffset+SafetyIslandCfg.BankNumBytes,   end_addr: BaseAddr32+MemOffset+2*SafetyIslandCfg.BankNumBytes}, // 2: Bank 1
    '{ idx: 3, start_addr: BaseAddr32+MemOffset+2*SafetyIslandCfg.BankNumBytes, end_addr: BaseAddr32+AddrRange},                 // 3: Periphs
    '{ idx: 3, start_addr: BaseAddr32,                                          end_addr: BaseAddr32+MemOffset}                  // 3: Periphs
  };

  // MemOffest == 0
  localparam addr_map_rule_t [2:0] small_addr_map = '{             // 0: below/above address space, so AXI out (default)
    '{ idx: 1, start_addr: BaseAddr32,                                end_addr: BaseAddr32+SafetyIslandCfg.BankNumBytes  }, // 1: Bank 0
    '{ idx: 2, start_addr: BaseAddr32+SafetyIslandCfg.BankNumBytes,   end_addr: BaseAddr32+2*SafetyIslandCfg.BankNumBytes}, // 2: Bank 1
    '{ idx: 3, start_addr: BaseAddr32+2*SafetyIslandCfg.BankNumBytes, end_addr: BaseAddr32+AddrRange}                 // 3: Periphs
  };

  localparam addr_map_rule_t [NumRules-1:0] main_addr_map = (MemOffset != 0) ? large_addr_map : small_addr_map;

  localparam addr_map_rule_t [NumPeriphRules-1:0] periph_addr_map = '{                                  // 0: Error subordinate (default)
    '{ idx: PeriphSocCtrl,       start_addr: PeriphBaseAddr+SocCtrlAddrOffset,       end_addr: PeriphBaseAddr+SocCtrlAddrOffset+      SocCtrlAddrRange},       // 1: SoC control
    '{ idx: PeriphBootROM,       start_addr: PeriphBaseAddr+BootROMAddrOffset,       end_addr: PeriphBaseAddr+BootROMAddrOffset+      BootROMAddrRange},       // 2: Boot ROM
    '{ idx: PeriphGlobalPrepend, start_addr: PeriphBaseAddr+GlobalPrependAddrOffset, end_addr: PeriphBaseAddr+GlobalPrependAddrOffset+GlobalPrependAddrRange}, // 3: Global prepend
    '{ idx: PeriphDebug,         start_addr: PeriphBaseAddr+DebugAddrOffset,         end_addr: PeriphBaseAddr+DebugAddrOffset+        DebugAddrRange},         // 4: Debug
    '{ idx: PeriphTimer,         start_addr: PeriphBaseAddr+TimerAddrOffset,         end_addr: PeriphBaseAddr+TimerAddrOffset+        TimerAddrRange},         // 5: Timer
    '{ idx: PeriphCoreLocal,     start_addr: PeriphBaseAddr+CoreLocalAddrOffset,     end_addr: PeriphBaseAddr+CoreLocalAddrOffset+    CoreLocalAddrRange}      // 4: Core-Local peripherals
`ifdef TARGET_SIMULATION
    ,
    '{ idx: PeriphTBPrintf,      start_addr: PeriphBaseAddr+TBPrintfAddrOffset,      end_addr: PeriphBaseAddr+TBPrintfAddrOffset+     TBPrintfAddrRange}       // 6: TBPrintf
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
  assign core_data_obi_req.a.a_optional = '0;

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
  assign axi_input_obi_req.a.aid = '0;
  assign axi_input_obi_req.a.a_optional = '0;

  // -----------------
  // Subordinate buses
  // -----------------

  // mem bank0 bus
  sbr_obi_req_t mem_bank0_obi_req;
  sbr_obi_rsp_t mem_bank0_obi_rsp;
  // mem bank1 bus
  sbr_obi_req_t mem_bank1_obi_req;
  sbr_obi_rsp_t mem_bank1_obi_rsp;

  // axi output bus
  sbr_obi_req_t axi_output_obi_req;
  sbr_obi_rsp_t axi_output_obi_rsp;

  // periph bus
  sbr_obi_req_t periph_obi_req;
  sbr_obi_rsp_t periph_obi_rsp;

  // Main xbar subordinate buses, must align with addr map!
  sbr_obi_req_t [NumSubordinates-1:0] all_slv_obi_req;
  sbr_obi_rsp_t [NumSubordinates-1:0] all_slv_obi_rsp;
  assign axi_output_obi_req = all_slv_obi_req[0];
  assign all_slv_obi_rsp[0] = axi_output_obi_rsp;
  assign mem_bank0_obi_req  = all_slv_obi_req[1];
  assign all_slv_obi_rsp[1] = mem_bank0_obi_rsp;
  assign mem_bank1_obi_req  = all_slv_obi_req[2];
  assign all_slv_obi_rsp[2] = mem_bank1_obi_rsp;
  assign periph_obi_req     = all_slv_obi_req[3];
  assign all_slv_obi_rsp[3] = periph_obi_rsp;

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

  localparam NumInternalDebug = NumDebug > SafetyIslandCfg.HartId ? NumDebug : SafetyIslandCfg.HartId;

  logic [NumInternalDebug-1:0] debug_req;

  always_comb begin
    debug_req_o = debug_req;
    debug_req_o[SafetyIslandCfg.HartId] = '0;
  end

  safety_core_wrap #(
    .SafetyIslandCfg ( SafetyIslandCfg           ),
    .PeriphBaseAddr  ( BaseAddr32 + PeriphOffset ),
    .reg_req_t       ( safety_reg_req_t          ),
    .reg_rsp_t       ( safety_reg_rsp_t          )
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
    .instr_err_i      ( '0),//core_instr_obi_rsp.r.err    ),

    .data_req_o       ( core_data_obi_req.req             ),
    .data_gnt_i       ( core_data_obi_rsp.gnt             ),
    .data_rvalid_i    ( core_data_obi_rsp.rvalid          ),
    .data_we_o        ( core_data_obi_req.a.we            ),
    .data_be_o        ( core_data_obi_req.a.be            ),
    .data_addr_o      ( core_data_obi_req.a.addr          ),
    .data_wdata_o     ( core_data_obi_req.a.wdata         ),
    .data_rdata_i     ( core_data_obi_rsp.r.rdata         ),
    .data_err_i       ( '0),//core_data_obi_rsp.r.err     ),

    .shadow_req_o     ( core_shadow_obi_req.req           ),
    .shadow_gnt_i     ( core_shadow_obi_rsp.gnt           ),
    .shadow_rvalid_i  ( core_shadow_obi_rsp.rvalid        ),
    .shadow_we_o      ( core_shadow_obi_req.a.we          ),
    .shadow_be_o      ( core_shadow_obi_req.a.be          ),
    .shadow_addr_o    ( core_shadow_obi_req.a.addr        ),
    .shadow_wdata_o   ( core_shadow_obi_req.a.wdata       ),
    .shadow_rdata_i   ( core_shadow_obi_rsp.r.rdata       ),
    .shadow_err_i     ( '0),//core_shadow_obi_rsp.r.err   ),

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
  localparam bit [NumInternalDebug-1:0] ActuallySelectableHarts = SelectableHarts | 1<<SafetyIslandCfg.HartId;

  dm::hartinfo_t [NumInternalDebug-1:0] hartinfo;
  for (genvar i = 0; i < NumInternalDebug; i++) begin
    if (i == SafetyIslandCfg.HartId) begin
      assign hartinfo[i] = HARTINFO;
    end else if (i <= NumDebug) begin
      assign hartinfo[i] = HartInfo[i];
    end else begin
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
    .master_r_err_i       ( '0),//dbg_req_obi_rsp.r.err    ),
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

  assign dbg_mem_obi_rsp.gnt = dbg_mem_obi_req.req;
  assign dbg_mem_obi_rsp.r.err = '0;
  assign dbg_mem_obi_rsp.r.r_optional = '0;
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_dbg_mem
    if(!rst_ni) begin
      dbg_mem_obi_rsp.rvalid <= '0;
      dbg_mem_obi_rsp.r.rid <= '0;
    end else begin
      dbg_mem_obi_rsp.rvalid <= dbg_mem_obi_rsp.gnt;
      dbg_mem_obi_rsp.r.rid <= dbg_req_obi_req.a.aid;
    end
  end

  // -----------------
  // Main Interconnect
  // -----------------

  obi_xbar #(
    .SbrPortObiCfg      ( MgrObiCfg        ),
    .MgrPortObiCfg      ( SbrObiCfg        ),
    .sbr_port_obi_req_t ( mgr_obi_req_t    ),
    .sbr_port_a_chan_t  ( mgr_obi_a_chan_t ),
    .sbr_port_obi_rsp_t ( mgr_obi_rsp_t    ),
    .sbr_port_r_chan_t  ( mgr_obi_r_chan_t ),
    .mgr_port_obi_req_t ( sbr_obi_req_t    ),
    .mgr_port_obi_rsp_t ( sbr_obi_rsp_t    ),
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

    .sbr_ports_req_i  ( {axi_input_obi_req, core_instr_obi_req, core_data_obi_req, core_shadow_obi_req, dbg_req_obi_req} ),
    .sbr_ports_rsp_o  ( {axi_input_obi_rsp, core_instr_obi_rsp, core_data_obi_rsp, core_shadow_obi_rsp, dbg_req_obi_rsp} ),
    .mgr_ports_req_o  ( all_slv_obi_req ),
    .mgr_ports_rsp_i  ( all_slv_obi_rsp ),

    .addr_map_i       ( main_addr_map ),
    .en_default_idx_i ( 5'b11111 ),
    .default_idx_i    ( '0 )
  );

  // -----------------
  // Memories
  // -----------------

  sbr_obi_rsp_t tmp_bank0_obi_rsp;
  logic bank0_req, bank0_we, bank0_gnt, bank0_single_err;
  logic [AddrWidth-1:0] bank0_addr;
  logic [DataWidth-1:0] bank0_wdata, bank0_rdata;
  logic [DataWidth/8-1:0] bank0_be;

  always_comb begin
    mem_bank0_obi_rsp = tmp_bank0_obi_rsp;
    mem_bank0_obi_rsp.r.err = bank0_single_err;
  end

  obi_sram_shim #(
    .ObiCfg    ( SbrObiCfg     ),
    .obi_req_t ( sbr_obi_req_t ),
    .obi_rsp_t ( sbr_obi_rsp_t )
  ) i_sram_shim_bank0 (
    .clk_i,
    .rst_ni,

    .obi_req_i ( mem_bank0_obi_req ),
    .obi_rsp_o ( tmp_bank0_obi_rsp ),

    .req_o   ( bank0_req   ),
    .we_o    ( bank0_we    ),
    .addr_o  ( bank0_addr  ),
    .wdata_o ( bank0_wdata ),
    .be_o    ( bank0_be    ),

    .gnt_i   ( bank0_gnt   ),
    .rdata_i ( bank0_rdata )
  );

  ecc_sram_wrap #(
    .BankSize        (BankNumWords),
    .InputECC        (0),
    .EnableTestMask  (0)
  ) i_mem_bank0 (
    .clk_i,
    .rst_ni,
    .test_enable_i         ( test_enable_i ),

    .scrub_trigger_i       ( '0 ),
    .scrubber_fix_o        (),
    .scrub_uncorrectable_o (),

    .tcdm_wdata_i          ( bank0_wdata ),
    .tcdm_add_i            ( bank0_addr  ),
    .tcdm_req_i            ( bank0_req   ),
    .tcdm_wen_i            ( ~bank0_we   ),
    .tcdm_be_i             ( bank0_be    ),
    .tcdm_rdata_o          ( bank0_rdata ),
    .tcdm_gnt_o            ( bank0_gnt   ),
    .single_error_o        (),
    .multi_error_o         ( bank0_single_err ),

    .test_write_mask_ni    ( '0 )
  );

  sbr_obi_rsp_t tmp_bank1_obi_rsp;
  logic bank1_req, bank1_we, bank1_gnt, bank1_single_err;
  logic [AddrWidth-1:0] bank1_addr;
  logic [DataWidth-1:0] bank1_wdata, bank1_rdata;
  logic [DataWidth/8-1:0] bank1_be;

  always_comb begin
    mem_bank1_obi_rsp = tmp_bank1_obi_rsp;
    mem_bank1_obi_rsp.r.err = bank1_single_err;
  end

  obi_sram_shim #(
    .ObiCfg    ( SbrObiCfg     ),
    .obi_req_t ( sbr_obi_req_t ),
    .obi_rsp_t ( sbr_obi_rsp_t )
  ) i_sram_shim_bank1 (
    .clk_i,
    .rst_ni,

    .obi_req_i ( mem_bank1_obi_req ),
    .obi_rsp_o ( tmp_bank1_obi_rsp ),

    .req_o   ( bank1_req   ),
    .we_o    ( bank1_we    ),
    .addr_o  ( bank1_addr  ),
    .wdata_o ( bank1_wdata ),
    .be_o    ( bank1_be    ),

    .gnt_i   ( bank1_gnt   ),
    .rdata_i ( bank1_rdata )
  );

  ecc_sram_wrap #(
    .BankSize        (BankNumWords),
    .InputECC        (0),
    .EnableTestMask  (0)
  ) i_mem_bank1 (
    .clk_i,
    .rst_ni,
    .test_enable_i         ( test_enable_i ),

    .scrub_trigger_i       ( '0 ),
    .scrubber_fix_o        (),
    .scrub_uncorrectable_o (),

    .tcdm_wdata_i          ( bank1_wdata ),
    .tcdm_add_i            ( bank1_addr  ),
    .tcdm_req_i            ( bank1_req   ),
    .tcdm_wen_i            ( ~bank1_we   ),
    .tcdm_be_i             ( bank1_be    ),
    .tcdm_rdata_o          ( bank1_rdata ),
    .tcdm_gnt_o            ( bank1_gnt   ),
    .single_error_o        (),
    .multi_error_o         ( bank1_single_err ),

    .test_write_mask_ni    ( '0 )
  );

  // -----------------
  // Periphs
  // -----------------

  logic [cf_math_pkg::idx_width(NumPeriphs)-1:0] periph_idx;

  addr_decode #(
    .NoIndices ( NumPeriphs      ),
    .NoRules   ( NumPeriphRules  ),
    .addr_t    ( logic[31:0]     ),
    .rule_t    ( addr_map_rule_t ),
    .Napot     ( 1'b0            )
  ) i_addr_decode_periphs (
    .addr_i           ( periph_obi_req.a.addr     ),
    .addr_map_i       ( periph_addr_map ),
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
    .CLK ( clk_i ),
    .CEN ( ~boot_rom_obi_req.req ),
    .A   ( boot_rom_obi_req.a.addr[11:2] ),
    .Q   ( boot_rom_obi_rsp.r.rdata )
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
    .COLORED_MODE ( "ON" )
  ) i_fs_handler (
    .clk_i  ( clk_i          ),
    .rst_ni ( rst_ni         ),
    .req_i  ( tbprintf_obi_req.req  ),
    .add_i  ( '0 ),//tbprintf_addr[11:0]  ),
    .dat_i  ( tbprintf_obi_req.a.wdata )
  );

  assign tbprintf_obi_rsp.r.rdata = '0;
  assign tbprintf_obi_rsp.gnt = 1'b1;
  // assign tbprintf_obi_rsp.r.err = 1'b0;
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_tbprintf_rvalid
    if(!rst_ni) begin
      tbprintf_obi_rsp.rvalid <= '0;
    end else begin
      tbprintf_obi_rsp.rvalid <= tbprintf_obi_req.req;
    end
  end
`endif

  // -----------------
  // AXI connections
  // -----------------

  // AXI input

  // Typedefs
  `AXI_TYPEDEF_AW_CHAN_T(axi_in_aw_chan_t,      logic[AxiAddrWidth-1:0],                                                     logic[AxiInputIdWidth-1:0], logic[AxiUserWidth-1:0])
  `AXI_TYPEDEF_AW_CHAN_T(axi_in_aw32_aw_chan_t, logic[AddrWidth-1:0],                                                        logic[AxiInputIdWidth-1:0], logic[AxiUserWidth-1:0])
  `AXI_TYPEDEF_W_CHAN_T(axi_in_w_chan_t,                                 logic[AxiDataWidth-1:0], logic[AxiDataWidth/8-1:0],                             logic[AxiUserWidth-1:0])
  `AXI_TYPEDEF_W_CHAN_T(axi_in_dw32_w_chan_t,                            logic[DataWidth-1:0],    logic[DataWidth/8-1:0],                                logic[AxiUserWidth-1:0])
  `AXI_TYPEDEF_B_CHAN_T(axi_in_b_chan_t,                                                                                     logic[AxiInputIdWidth-1:0], logic[AxiUserWidth-1:0])
  `AXI_TYPEDEF_AR_CHAN_T(axi_in_ar_chan_t,      logic[AxiAddrWidth-1:0],                                                     logic[AxiInputIdWidth-1:0], logic[AxiUserWidth-1:0])
  `AXI_TYPEDEF_AR_CHAN_T(axi_in_aw32_ar_chan_t, logic[AddrWidth-1:0],                                                        logic[AxiInputIdWidth-1:0], logic[AxiUserWidth-1:0])
  `AXI_TYPEDEF_R_CHAN_T(axi_in_r_chan_t,                                 logic[AxiDataWidth-1:0],                            logic[AxiInputIdWidth-1:0], logic[AxiUserWidth-1:0])
  `AXI_TYPEDEF_R_CHAN_T(axi_in_dw32_r_chan_t,                            logic[DataWidth-1:0],                               logic[AxiInputIdWidth-1:0], logic[AxiUserWidth-1:0])

  `AXI_TYPEDEF_REQ_T(axi_in_alt_req_t, axi_in_aw_chan_t, axi_in_w_chan_t, axi_in_ar_chan_t)
  `AXI_TYPEDEF_RESP_T(axi_in_alt_resp_t, axi_in_b_chan_t, axi_in_r_chan_t)
  `AXI_TYPEDEF_REQ_T(axi_in_dw32_req_t, axi_in_aw_chan_t, axi_in_dw32_w_chan_t, axi_in_ar_chan_t)
  `AXI_TYPEDEF_RESP_T(axi_in_dw32_resp_t, axi_in_b_chan_t, axi_in_dw32_r_chan_t)
  `AXI_TYPEDEF_REQ_T(axi_in_dw32_aw32_req_t, axi_in_aw32_aw_chan_t, axi_in_dw32_w_chan_t, axi_in_aw32_ar_chan_t)

  // Consistency alternates for AXI input
  axi_in_alt_req_t  axi_in_alt_req;
  axi_in_alt_resp_t axi_in_alt_resp;
  `AXI_ASSIGN_REQ_STRUCT(axi_in_alt_req, axi_input_req_i)
  `AXI_ASSIGN_RESP_STRUCT(axi_input_resp_o, axi_in_alt_resp)

  // AXI corrected data width
  axi_in_dw32_req_t  axi_in_dw32_req;
  axi_in_dw32_resp_t axi_in_dw32_resp;

  // AXI corrected address width
  axi_in_dw32_aw32_req_t axi_in_dw32_aw32_req;

  // AXI cut
  axi_in_dw32_aw32_req_t axi_in_dw32_aw32_cut_req;
  axi_in_dw32_resp_t     axi_in_dw32_cut_resp;

  // AXI Data Width converter
  axi_dw_converter #(
    .AxiMaxReads         ( safety_island_pkg::AxiMaxInTrans ),
    .AxiSlvPortDataWidth ( AxiDataWidth         ),
    .AxiMstPortDataWidth ( DataWidth            ),
    .AxiAddrWidth        ( AxiAddrWidth         ),
    .AxiIdWidth          ( AxiInputIdWidth      ),
    .aw_chan_t           ( axi_in_aw_chan_t     ),
    .mst_w_chan_t        ( axi_in_dw32_w_chan_t ),
    .slv_w_chan_t        ( axi_in_w_chan_t      ),
    .b_chan_t            ( axi_in_b_chan_t      ),
    .ar_chan_t           ( axi_in_ar_chan_t     ),
    .mst_r_chan_t        ( axi_in_dw32_r_chan_t ),
    .slv_r_chan_t        ( axi_in_r_chan_t      ),
    .axi_mst_req_t       ( axi_in_dw32_req_t    ),
    .axi_mst_resp_t      ( axi_in_dw32_resp_t   ),
    .axi_slv_req_t       ( axi_in_alt_req_t     ),
    .axi_slv_resp_t      ( axi_in_alt_resp_t    )
  ) i_axi_input_dw (
    .clk_i,
    .rst_ni,

    .slv_req_i  ( axi_in_alt_req   ),
    .slv_resp_o ( axi_in_alt_resp  ),

    .mst_req_o  ( axi_in_dw32_req  ),
    .mst_resp_i ( axi_in_dw32_resp )
  );

  // AXI Address Width aligment
  // TODO: check for correct behavior!
  `AXI_ASSIGN_REQ_STRUCT(axi_in_dw32_aw32_req, axi_in_dw32_req)

  // AXI cut to fix https://github.com/pulp-platform/axi/issues/287
  axi_cut #(
    .Bypass     ( 1'b0                   ),
    .aw_chan_t  ( axi_in_aw32_aw_chan_t  ),
    .w_chan_t   ( axi_in_dw32_w_chan_t   ),
    .b_chan_t   ( axi_in_b_chan_t        ),
    .ar_chan_t  ( axi_in_aw32_ar_chan_t  ),
    .r_chan_t   ( axi_in_dw32_r_chan_t   ),
    .axi_req_t  ( axi_in_dw32_aw32_req_t ),
    .axi_resp_t ( axi_in_dw32_resp_t     )
  ) i_axi_input_cut (
    .clk_i,
    .rst_ni,

    .slv_req_i  ( axi_in_dw32_aw32_req     ),
    .slv_resp_o ( axi_in_dw32_resp         ),
    .mst_req_o  ( axi_in_dw32_aw32_cut_req ),
    .mst_resp_i ( axi_in_dw32_cut_resp     )
  );

  // AXI to Mem
  axi_to_mem #(
    .axi_req_t    ( axi_in_dw32_aw32_req_t ),
    .axi_resp_t   ( axi_in_dw32_resp_t     ),
    .AddrWidth    ( AddrWidth              ),
    .DataWidth    ( DataWidth              ),
    .IdWidth      ( AxiInputIdWidth        ),
    .NumBanks     ( 1                      ),
    .BufDepth     ( 1                      ),
    .HideStrb     ( 1'b1                   ),
    .OutFifoDepth ( 1                      )
  ) i_axi_to_mem (
    .clk_i,
    .rst_ni,

    .busy_o       (),

    .axi_req_i    ( axi_in_dw32_aw32_cut_req  ),
    .axi_resp_o   ( axi_in_dw32_cut_resp      ),

    .mem_req_o    ( axi_input_obi_req.req     ),
    .mem_gnt_i    ( axi_input_obi_rsp.gnt     ),
    .mem_addr_o   ( axi_input_obi_req.a.addr  ),
    .mem_wdata_o  ( axi_input_obi_req.a.wdata ),
    .mem_strb_o   ( axi_input_obi_req.a.be    ),
    .mem_we_o     ( axi_input_obi_req.a.we    ),
    .mem_atop_o   (), // TODO?
    .mem_rvalid_i ( axi_input_obi_rsp.rvalid  ),
    .mem_rdata_i  ( axi_input_obi_rsp.r.rdata )
  );

  // AXI output

  // Typedefs
  `AXI_TYPEDEF_AW_CHAN_T(axi_out_aw_chan_t,      logic[AxiAddrWidth-1:0],                                                     logic[AxiOutputIdWidth-1:0], logic[AxiUserWidth-1:0])
  // `AXI_TYPEDEF_AW_CHAN_T(axi_out_aw32_aw_chan_t, logic[AddrWidth-1:0],                                                        logic[AxiOutputIdWidth-1:0], logic[AxiUserWidth-1:0])
  `AXI_TYPEDEF_W_CHAN_T(axi_out_w_chan_t,                                 logic[AxiDataWidth-1:0], logic[AxiDataWidth/8-1:0],                              logic[AxiUserWidth-1:0])
  `AXI_TYPEDEF_W_CHAN_T(axi_out_dw32_w_chan_t,                            logic[DataWidth-1:0],    logic[DataWidth/8-1:0],                                 logic[AxiUserWidth-1:0])
  `AXI_TYPEDEF_B_CHAN_T(axi_out_b_chan_t,                                                                                     logic[AxiOutputIdWidth-1:0], logic[AxiUserWidth-1:0])
  `AXI_TYPEDEF_AR_CHAN_T(axi_out_ar_chan_t,      logic[AxiAddrWidth-1:0],                                                     logic[AxiOutputIdWidth-1:0], logic[AxiUserWidth-1:0])
  // `AXI_TYPEDEF_AR_CHAN_T(axi_out_aw32_ar_chan_t, logic[AddrWidth-1:0],                                                        logic[AxiOutputIdWidth-1:0], logic[AxiUserWidth-1:0])
  `AXI_TYPEDEF_R_CHAN_T(axi_out_r_chan_t,                                 logic[AxiDataWidth-1:0],                            logic[AxiOutputIdWidth-1:0], logic[AxiUserWidth-1:0])
  `AXI_TYPEDEF_R_CHAN_T(axi_out_dw32_r_chan_t,                            logic[DataWidth-1:0],                               logic[AxiOutputIdWidth-1:0], logic[AxiUserWidth-1:0])

  `AXI_TYPEDEF_REQ_T(axi_out_alt_req_t, axi_out_aw_chan_t, axi_out_w_chan_t, axi_out_ar_chan_t)
  `AXI_TYPEDEF_RESP_T(axi_out_alt_resp_t, axi_out_b_chan_t, axi_out_r_chan_t)
  `AXI_TYPEDEF_REQ_T(axi_out_dw32_req_t, axi_out_aw_chan_t, axi_out_dw32_w_chan_t, axi_out_ar_chan_t)
  `AXI_TYPEDEF_RESP_T(axi_out_dw32_resp_t, axi_out_b_chan_t, axi_out_dw32_r_chan_t)
  // `AXI_TYPEDEF_REQ_T(axi_out_dw32_aw32_req_t, axi_out_aw32_aw_chan_t, axi_out_dw32_w_chan_t, axi_out_aw32_ar_chan_t)

  // Consistency alternates for AXI output
  axi_out_alt_req_t  axi_out_alt_req;
  axi_out_alt_resp_t axi_out_alt_resp;

  // AXI corrected data width
  axi_out_dw32_req_t  axi_out_dw32_req;
  axi_out_dw32_resp_t axi_out_dw32_resp;

  // // AXI corrected address width
  // axi_out_dw32_aw32_req_t axi_out_dw32_aw32_req;


  axi_from_mem #(
    .MemAddrWidth( AddrWidth           ),
    .AxiAddrWidth( AxiAddrWidth        ),
    .DataWidth   ( DataWidth           ),
    .MaxRequests ( safety_island_pkg::AxiMaxOutTrans ),
    .AxiProt     ( '0                  ),
    .axi_req_t   ( axi_out_dw32_req_t  ),
    .axi_rsp_t   ( axi_out_dw32_resp_t )
  ) i_mem_to_axi (
    .clk_i,
    .rst_ni,
    .mem_req_i      ( axi_output_obi_req.req     ),
    .mem_addr_i     ( axi_output_obi_req.a.addr  ),
    .mem_we_i       ( axi_output_obi_req.a.we    ),
    .mem_wdata_i    ( axi_output_obi_req.a.wdata ),
    .mem_be_i       ( axi_output_obi_req.a.be    ),
    .mem_gnt_o      ( axi_output_obi_rsp.gnt     ),
    .mem_rsp_valid_o( axi_output_obi_rsp.rvalid  ),
    .mem_rsp_rdata_o( axi_output_obi_rsp.r.rdata ),
    .mem_rsp_error_o( axi_output_obi_rsp.r.err   ),
    .slv_aw_cache_i ( axi_pkg::get_awcache(axi_pkg::NORMAL_NONCACHEABLE_NONBUFFERABLE) ),
    .slv_ar_cache_i ( axi_pkg::get_arcache(axi_pkg::NORMAL_NONCACHEABLE_NONBUFFERABLE) ),
    .axi_req_o      ( axi_out_dw32_req           ),
    .axi_rsp_i      ( axi_out_dw32_resp          )
  );
  assign axi_output_obi_rsp.r.r_optional = '0;
  assign axi_output_obi_rsp.r.rid = '0; // TODO: fix appropriately

  // TODO?: AXI AddrWidth prepend

  // AXI Data Width converter
  axi_dw_converter #(
    .AxiMaxReads         ( safety_island_pkg::AxiMaxOutTrans ),
    .AxiSlvPortDataWidth ( DataWidth             ),
    .AxiMstPortDataWidth ( AxiDataWidth          ),
    .AxiAddrWidth        ( AxiAddrWidth          ),
    .AxiIdWidth          ( AxiOutputIdWidth      ),
    .aw_chan_t           ( axi_out_aw_chan_t     ),
    .mst_w_chan_t        ( axi_out_w_chan_t      ),
    .slv_w_chan_t        ( axi_out_dw32_w_chan_t ),
    .b_chan_t            ( axi_out_b_chan_t      ),
    .ar_chan_t           ( axi_out_ar_chan_t     ),
    .mst_r_chan_t        ( axi_out_r_chan_t      ),
    .slv_r_chan_t        ( axi_out_dw32_r_chan_t ),
    .axi_mst_req_t       ( axi_out_alt_req_t     ),
    .axi_mst_resp_t      ( axi_out_alt_resp_t    ),
    .axi_slv_req_t       ( axi_out_dw32_req_t    ),
    .axi_slv_resp_t      ( axi_out_dw32_resp_t   )
  ) i_axi_output_dw (
    .clk_i,
    .rst_ni,

    .slv_req_i  ( axi_out_dw32_req  ),
    .slv_resp_o ( axi_out_dw32_resp ),
    .mst_req_o  ( axi_out_alt_req   ),
    .mst_resp_i ( axi_out_alt_resp  )
  );

  // Consistency alternatives for AXI output
  `AXI_ASSIGN_REQ_STRUCT(axi_output_req_o, axi_out_alt_req)
  `AXI_ASSIGN_RESP_STRUCT(axi_out_alt_resp, axi_output_resp_i)

endmodule
