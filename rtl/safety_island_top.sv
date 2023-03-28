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

module safety_island_top import safety_island_pkg::*; #(
  parameter safety_island_pkg::safety_island_cfg_t SafetyIslandCfg = safety_island_pkg::SafetyIslandDefaultConfig,

  parameter  int unsigned              GlobalAddrWidth = 32,
  parameter  bit [GlobalAddrWidth-1:0] BaseAddr        = 32'h0000_0000,
  parameter  bit [31:0]                AddrRange       = 32'h0080_0000,
  parameter  bit [31:0]                MemOffset       = 32'h0000_0000,
  parameter  bit [31:0]                PeriphOffset    = 32'h0020_0000,

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

  input logic [SafetyIslandCfg.NumInterrupts-1:0] irqs_i,

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

  localparam WDataAggLen =  1 +  4 +   32 +    32;
  //                       we   be   addr   wdata
  localparam RDataAggLen =    32 +   1;
  //                       rdata   err

  // typedef obi for default config
  `OBI_TYPEDEF_MINIMAL_A_OPTIONAL(obi_a_optional_t)
  `OBI_TYPEDEF_A_CHAN_T(obi_a_chan_t, 32, 32, 1, obi_a_optional_t)
  `OBI_TYPEDEF_DEFAULT_REQ_T(obi_req_t, obi_a_chan_t)
  `OBI_TYPEDEF_MINIMAL_R_OPTIONAL(obi_r_optional_t)
  `OBI_TYPEDEF_R_CHAN_T(obi_r_chan_t, 32, 1, obi_r_optional_t)
  `OBI_TYPEDEF_RSP_T(obi_rsp_t, obi_r_chan_t)
  `REG_BUS_TYPEDEF_ALL(safety_reg, logic[AddrWidth-1:0], logic[DataWidth-1:0], logic[(DataWidth/8)-1:0]);

`ifdef TARGET_SIMULATION
  localparam int unsigned NumPeriphs     = 7;
  localparam int unsigned NumPeriphRules = 6;

  localparam bit [31:0] TBPrintfAddrOffset = 32'h0000_6000;
  localparam bit [31:0] TBPrintfAddrRange  = 32'h0000_1000;
`else
  localparam int unsigned NumPeriphs     = 6;
  localparam int unsigned NumPeriphRules = 5;
`endif

  localparam int unsigned NumSlaves = 4;
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

  localparam addr_map_rule_t [NumPeriphRules-1:0] periph_addr_map = '{                                  // 0: Error slave (default)
    '{ idx: PeriphSocCtrl,       start_addr: PeriphBaseAddr+SocCtrlAddrOffset,       end_addr: PeriphBaseAddr+SocCtrlAddrOffset+      SocCtrlAddrRange},       // 1: SoC control
    '{ idx: PeriphBootROM,       start_addr: PeriphBaseAddr+BootROMAddrOffset,       end_addr: PeriphBaseAddr+BootROMAddrOffset+      BootROMAddrRange},       // 2: Boot ROM
    '{ idx: PeriphGlobalPrepend, start_addr: PeriphBaseAddr+GlobalPrependAddrOffset, end_addr: PeriphBaseAddr+GlobalPrependAddrOffset+GlobalPrependAddrRange}, // 3: Global prepend
    '{ idx: PeriphDebug,         start_addr: PeriphBaseAddr+DebugAddrOffset,         end_addr: PeriphBaseAddr+DebugAddrOffset+        DebugAddrRange},         // 4: Debug
    '{ idx: PeriphCoreLocal,     start_addr: PeriphBaseAddr+CoreLocalAddrOffset,     end_addr: PeriphBaseAddr+CoreLocalAddrOffset+    CoreLocalAddrRange}      // 5: Core-Local peripherals
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

  // -----------------
  // Master buses
  // -----------------

  // Core instr bus
  obi_req_t core_instr_obi_req;
  obi_rsp_t core_instr_obi_rsp;
  assign core_instr_obi_req.a.aid = '0;
  assign core_instr_obi_req.a.optional = '0;
  assign core_instr_obi_req.a.we = '0;
  assign core_instr_obi_req.a.be = '1;
  assign core_instr_obi_req.a.wdata = '0;

  // Core data bus
  obi_req_t core_data_obi_req;
  obi_rsp_t core_data_obi_rsp;
  assign core_data_obi_req.a.aid = '0;
  assign core_data_obi_req.a.optional = '0;

  // Core shadow bus
  obi_req_t core_shadow_obi_req;
  obi_rsp_t core_shadow_obi_rsp;
  assign core_shadow_obi_req.a.aid = '0;
  assign core_shadow_obi_req.a.optional = '0;

  // dbg req bus
  obi_req_t dbg_req_obi_req;
  obi_rsp_t dbg_req_obi_rsp;
  assign dbg_req_obi_req.a.aid = '0;
  assign dbg_req_obi_req.a.optional = '0;

  // axi input bus
  obi_req_t axi_input_obi_req;
  obi_rsp_t axi_input_obi_rsp;
  assign axi_input_obi_req.a.aid = '0;
  assign axi_input_obi_req.a.optional = '0;

  // -----------------
  // Slave buses
  // -----------------

  // mem bank0 bus
  obi_req_t mem_bank0_obi_req;
  obi_rsp_t mem_bank0_obi_rsp;
  // mem bank1 bus
  obi_req_t mem_bank1_obi_req;
  obi_rsp_t mem_bank1_obi_rsp;

  // axi output bus
  obi_req_t axi_output_obi_req;
  obi_rsp_t axi_output_obi_rsp;

  // periph bus
  obi_req_t periph_obi_req;
  obi_rsp_t periph_obi_rsp;

  // Main xbar slave buses, must align with addr map!
  obi_req_t [NumSlaves-1:0] all_slv_obi_req;
  obi_rsp_t [NumSlaves-1:0] all_slv_obi_rsp;
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
  obi_req_t error_obi_req;
  obi_rsp_t error_obi_rsp;

  // SoC control bus
  obi_req_t soc_ctrl_obi_req;
  obi_rsp_t soc_ctrl_obi_rsp;
  safety_reg_req_t soc_ctrl_reg_req;
  safety_reg_rsp_t soc_ctrl_reg_rsp;

  // Boot ROM bus
  obi_req_t boot_rom_obi_req;
  obi_rsp_t boot_rom_obi_rsp;

  // Global prepend bus
  obi_req_t global_prepend_obi_req;
  obi_rsp_t global_prepend_obi_rsp;

  // Debug mem bus
  obi_req_t dbg_mem_obi_req;
  obi_rsp_t dbg_mem_obi_rsp;

  // Core local bus
  obi_req_t cl_periph_obi_req;
  obi_rsp_t cl_periph_obi_rsp;
  safety_reg_req_t cl_periph_reg_req;
  safety_reg_rsp_t cl_periph_reg_rsp;

`ifdef TARGET_SIMULATION
  // TBPrintf bus
  obi_req_t tbprintf_obi_req;
  obi_rsp_t tbprintf_obi_rsp;
`endif

  obi_req_t [NumPeriphs-1:0] all_periph_obi_req;
  obi_rsp_t [NumPeriphs-1:0] all_periph_obi_rsp;
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
`ifdef TARGET_SIMULATION
  assign tbprintf_obi_req                     = all_periph_obi_req[PeriphTBPrintf];
  assign all_periph_obi_rsp[PeriphTBPrintf]   = tbprintf_obi_rsp;
`endif

  // -----------------
  // Core
  // -----------------

  logic debug_req;

  safety_core_wrap #(
    .SafetyIslandCfg (SafetyIslandCfg),
    .PeriphBaseAddr  ( BaseAddr32 + PeriphOffset ),
    .reg_req_t       ( safety_reg_req_t ),
    .reg_rsp_t       ( safety_reg_rsp_t )
  ) i_core_wrap (
    .clk_i,
    .ref_clk_i,
    .rst_ni,
    .test_enable_i,

    .irqs_i,

    .cl_periph_req_i  ( cl_periph_reg_req ),
    .cl_periph_rsp_o  ( cl_periph_reg_rsp ),

    .hart_id_i        ( SafetyIslandCfg.HartId ),
    .boot_addr_i      ( boot_addr         ),

    .instr_req_o      ( core_instr_obi_req.req    ),
    .instr_gnt_i      ( core_instr_obi_rsp.gnt    ),
    .instr_rvalid_i   ( core_instr_obi_rsp.rvalid ),
    .instr_addr_o     ( core_instr_obi_req.a.addr   ),
    .instr_rdata_i    ( core_instr_obi_rsp.r.rdata  ),
    .instr_err_i      ( '0),//core_instr_obi_rsp.r.err    ),

    .data_req_o       ( core_data_obi_req.req     ),
    .data_gnt_i       ( core_data_obi_rsp.gnt     ),
    .data_rvalid_i    ( core_data_obi_rsp.rvalid  ),
    .data_we_o        ( core_data_obi_req.a.we      ),
    .data_be_o        ( core_data_obi_req.a.be      ),
    .data_addr_o      ( core_data_obi_req.a.addr    ),
    .data_wdata_o     ( core_data_obi_req.a.wdata   ),
    .data_rdata_i     ( core_data_obi_rsp.r.rdata   ),
    .data_err_i       ( '0),//core_data_obi_rsp.r.err     ),

    .shadow_req_o     ( core_shadow_obi_req.req   ),
    .shadow_gnt_i     ( core_shadow_obi_rsp.gnt   ),
    .shadow_rvalid_i  ( core_shadow_obi_rsp.rvalid),
    .shadow_we_o      ( core_shadow_obi_req.a.we    ),
    .shadow_be_o      ( core_shadow_obi_req.a.be    ),
    .shadow_addr_o    ( core_shadow_obi_req.a.addr  ),
    .shadow_wdata_o   ( core_shadow_obi_req.a.wdata ),
    .shadow_rdata_i   ( core_shadow_obi_rsp.r.rdata ),
    .shadow_err_i     ( '0),//core_shadow_obi_rsp.r.err   ),

    .debug_req_i      ( debug_req         ),
    .fetch_enable_i   ( fetch_enable      )
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
    .NrHarts        ( 1  ),
    .BusWidth       ( 32 ),
    .ReadByteEnable ( 0  )
  ) i_dm_top (
    .clk_i,
    .rst_ni,
    .testmode_i           ( test_enable_i  ),
    .ndmreset_o           (),
    .dmactive_o           (),
    .debug_req_o          ( debug_req      ),
    .unavailable_i        ( 1'b0           ),
    .hartinfo_i           ( HARTINFO  ),

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
  // assign dbg_mem_obi_rsp.r.err = '0;
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_dbg_mem
    if(!rst_ni) begin
      dbg_mem_obi_rsp.rvalid <= '0;
    end else begin
      dbg_mem_obi_rsp.rvalid <= dbg_mem_obi_rsp.gnt;
    end
  end

  // -----------------
  // Main Interconnect
  // -----------------

  obi_xbar #(
    .slv_port_obi_req_t ( obi_req_t       ),
    .slv_port_a_chan_t  ( obi_a_chan_t    ),
    .slv_port_obi_rsp_t ( obi_rsp_t       ),
    .slv_port_r_chan_t  ( obi_r_chan_t    ),
    .NumSlvPorts        ( 5               ),
    .NumMstPorts        ( NumSlaves       ),
    .NumMaxTrans        ( 2               ),
    .NumAddrRules       ( NumRules        ),
    .addr_map_rule_t    ( addr_map_rule_t )
  ) i_main_xbar (
    .clk_i,
    .rst_ni,
    .testmode_i ( test_enable_i ),

    .slv_ports_obi_req_i ( {axi_input_obi_req, core_instr_obi_req, core_data_obi_req, core_shadow_obi_req, dbg_req_obi_req} ),
    .slv_ports_obi_rsp_o ( {axi_input_obi_rsp, core_instr_obi_rsp, core_data_obi_rsp, core_shadow_obi_rsp, dbg_req_obi_rsp} ),
    .mst_ports_obi_req_o ( all_slv_obi_req ),
    .mst_ports_obi_rsp_i ( all_slv_obi_rsp ),

    .addr_map_i          ( main_addr_map ),
    .en_default_idx_i    ( 5'b11111 ),
    .default_idx_i       ( '0 )
  );

  // -----------------
  // Memories
  // -----------------

  tc_sram #(
    .NumWords  ( BankNumWords ),
    .DataWidth ( 32           ),
    .ByteWidth ( 8            ),
    .NumPorts  ( 1            ),
    .Latency   ( 1            ),
    .SimInit   ( "none"       )
  ) i_instr_mem (
    .clk_i,
    .rst_ni,

    .req_i   ( mem_bank0_obi_req.req   ),
    .we_i    ( mem_bank0_obi_req.a.we    ),
    .addr_i  ( mem_bank0_obi_req.a.addr [$clog2(SafetyIslandCfg.BankNumBytes)-1:2] ),
    .wdata_i ( mem_bank0_obi_req.a.wdata ),
    .be_i    ( mem_bank0_obi_req.a.be    ),

    .rdata_o ( mem_bank0_obi_rsp.r.rdata )
  );
  // assign mem_bank0_obi_rsp.r.err = 1'b0;
  assign mem_bank0_obi_rsp.gnt = mem_bank0_obi_req.req;
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_mem_bank0_rvalid
    if(!rst_ni) begin
      mem_bank0_obi_rsp.rvalid <= '0;
    end else begin
      mem_bank0_obi_rsp.rvalid <= mem_bank0_obi_rsp.gnt;
    end
  end

  tc_sram #(
    .NumWords  ( BankNumWords ),
    .DataWidth ( 32           ),
    .ByteWidth ( 8            ),
    .NumPorts  ( 1            ),
    .Latency   ( 1            ),
    .SimInit   ( "none"       )
  ) i_data_mem (
    .clk_i,
    .rst_ni,

    .req_i   ( mem_bank1_obi_req.req   ),
    .we_i    ( mem_bank1_obi_req.a.we    ),
    .addr_i  ( mem_bank1_obi_req.a.addr[$clog2(SafetyIslandCfg.BankNumBytes)-1:2]  ),
    .wdata_i ( mem_bank1_obi_req.a.wdata ),
    .be_i    ( mem_bank1_obi_req.a.be    ),

    .rdata_o ( mem_bank1_obi_rsp.r.rdata )
  );
  // assign mem_bank1_obi_rsp.r.err = 1'b0;
  assign mem_bank1_obi_rsp.gnt = mem_bank1_obi_req.req;
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_mem_bank1_rvalid
    if(!rst_ni) begin
      mem_bank1_obi_rsp.rvalid <= '0;
    end else begin
      mem_bank1_obi_rsp.rvalid <= mem_bank1_obi_rsp.gnt;
    end
  end

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
    .obi_req_t ( obi_req_t ),
    .obi_rsp_t ( obi_rsp_t ),
    .NumMstPorts ( NumPeriphs ),
    .NumMaxTrans ( 2 )
  ) i_obi_demux (
    .clk_i,
    .rst_ni,

    .slv_port_select_i ( periph_idx ),
    .slv_port_req_i    ( periph_obi_req ),
    .slv_port_rsp_o    ( periph_obi_rsp ),

    .mst_ports_req_o   ( all_periph_obi_req ),
    .mst_ports_rsp_i   ( all_periph_obi_rsp )
  );

  // Error slave
  assign error_obi_rsp.gnt     = 1'b1;
  // assign error_obi_rsp.r.err   = 1'b1;
  assign error_obi_rsp.r.rdata = 32'hBADCAB1E;
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_error_rvalid
    if(!rst_ni) begin
      error_obi_rsp.rvalid <= '0;
    end else begin
      error_obi_rsp.rvalid <= error_obi_req.req;
    end
  end

  assign global_prepend_obi_rsp.gnt = 1'b1;
  // assign global_prepend_obi_rsp.r.err = 1'b1;
  assign global_prepend_obi_rsp.r.rdata = 32'hBADCAB1E;
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_global_prepend_rvalid
    if(!rst_ni) begin
      global_prepend_obi_rsp.rvalid <= '0;
    end else begin
      global_prepend_obi_rsp.rvalid <= global_prepend_obi_req.req;
    end
  end

  // SoC Control
  periph_to_reg #(
    .AW ( AddrWidth ),
    .DW ( DataWidth ),
    .BW ( 8 ),
    .IW ( 1 ),
    .req_t ( safety_reg_req_t ),
    .rsp_t ( safety_reg_rsp_t )
  ) i_soc_ctrl_translate (
    .clk_i,
    .rst_ni,

    .req_i     ( soc_ctrl_obi_req.req     ),
    .add_i     ( soc_ctrl_obi_req.a.addr    ),
    .wen_i     ( ~soc_ctrl_obi_req.a.we     ),
    .wdata_i   ( soc_ctrl_obi_req.a.wdata   ),
    .be_i      ( soc_ctrl_obi_req.a.be      ),
    .id_i      ( '0 ),

    .gnt_o     ( soc_ctrl_obi_rsp.gnt     ),
    .r_rdata_o ( soc_ctrl_obi_rsp.r.rdata   ),
    .r_opc_o   ( ),//soc_ctrl_err     ),
    .r_id_o    (),
    .r_valid_o ( soc_ctrl_obi_rsp.rvalid  ),

    .reg_req_o ( soc_ctrl_reg_req ),
    .reg_rsp_i ( soc_ctrl_reg_rsp )
  );

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
    .reg_req_i ( soc_ctrl_reg_req    ),
    .reg_rsp_o ( soc_ctrl_reg_rsp    ),
    .reg2hw    ( soc_ctrl_reg2hw ),
    .hw2reg    ( soc_ctrl_hw2reg ),
    .devmode_i ( 1'b0            )
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
  // assign boot_rom_obi_rsp.r.err = 1'b0;
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_boot_rom_rvalid
    if(!rst_ni) begin
      boot_rom_obi_rsp.rvalid <= '0;
    end else begin
      boot_rom_obi_rsp.rvalid <= boot_rom_obi_req.req;
    end
  end

  // Core-local Peripherals
  periph_to_reg #(
    .AW ( AddrWidth ),
    .DW ( DataWidth ),
    .BW ( 8 ),
    .IW ( 1 ),
    .req_t ( safety_reg_req_t ),
    .rsp_t ( safety_reg_rsp_t )
  ) i_core_local_translate (
    .clk_i,
    .rst_ni,

    .req_i     ( cl_periph_obi_req.req    ),
    .add_i     ( cl_periph_obi_req.a.addr   ),
    .wen_i     ( ~cl_periph_obi_req.a.we    ),
    .wdata_i   ( cl_periph_obi_req.a.wdata  ),
    .be_i      ( cl_periph_obi_req.a.be     ),
    .id_i      ( '0 ),

    .gnt_o     ( cl_periph_obi_rsp.gnt    ),
    .r_rdata_o ( cl_periph_obi_rsp.r.rdata  ),
    .r_opc_o   ( ),//cl_periph_err    ),
    .r_id_o    (),
    .r_valid_o ( cl_periph_obi_rsp.rvalid ),

    .reg_req_o ( cl_periph_reg_req ),
    .reg_rsp_i ( cl_periph_reg_rsp )
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
    .AxiMaxReads         ( 1                    ),
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
  `AXI_TYPEDEF_AW_CHAN_T(axi_out_aw32_aw_chan_t, logic[AddrWidth-1:0],                                                        logic[AxiOutputIdWidth-1:0], logic[AxiUserWidth-1:0])
  `AXI_TYPEDEF_W_CHAN_T(axi_out_w_chan_t,                                 logic[AxiDataWidth-1:0], logic[AxiDataWidth/8-1:0],                              logic[AxiUserWidth-1:0])
  `AXI_TYPEDEF_W_CHAN_T(axi_out_dw32_w_chan_t,                            logic[DataWidth-1:0],    logic[DataWidth/8-1:0],                                 logic[AxiUserWidth-1:0])
  `AXI_TYPEDEF_B_CHAN_T(axi_out_b_chan_t,                                                                                     logic[AxiOutputIdWidth-1:0], logic[AxiUserWidth-1:0])
  `AXI_TYPEDEF_AR_CHAN_T(axi_out_ar_chan_t,      logic[AxiAddrWidth-1:0],                                                     logic[AxiOutputIdWidth-1:0], logic[AxiUserWidth-1:0])
  `AXI_TYPEDEF_AR_CHAN_T(axi_out_aw32_ar_chan_t, logic[AddrWidth-1:0],                                                        logic[AxiOutputIdWidth-1:0], logic[AxiUserWidth-1:0])
  `AXI_TYPEDEF_R_CHAN_T(axi_out_r_chan_t,                                 logic[AxiDataWidth-1:0],                            logic[AxiOutputIdWidth-1:0], logic[AxiUserWidth-1:0])
  `AXI_TYPEDEF_R_CHAN_T(axi_out_dw32_r_chan_t,                            logic[DataWidth-1:0],                               logic[AxiOutputIdWidth-1:0], logic[AxiUserWidth-1:0])

  `AXI_TYPEDEF_REQ_T(axi_out_alt_req_t, axi_out_aw_chan_t, axi_out_w_chan_t, axi_out_ar_chan_t)
  `AXI_TYPEDEF_RESP_T(axi_out_alt_resp_t, axi_out_b_chan_t, axi_out_r_chan_t)
  `AXI_TYPEDEF_REQ_T(axi_out_dw32_req_t, axi_out_aw_chan_t, axi_out_dw32_w_chan_t, axi_out_ar_chan_t)
  `AXI_TYPEDEF_RESP_T(axi_out_dw32_resp_t, axi_out_b_chan_t, axi_out_dw32_r_chan_t)
  `AXI_TYPEDEF_REQ_T(axi_out_dw32_aw32_req_t, axi_out_aw32_aw_chan_t, axi_out_dw32_w_chan_t, axi_out_aw32_ar_chan_t)

  // Consistency alternates for AXI output
  axi_out_alt_req_t  axi_out_alt_req;
  axi_out_alt_resp_t axi_out_alt_resp;

  // AXI corrected data width
  axi_out_dw32_req_t  axi_out_dw32_req;
  axi_out_dw32_resp_t axi_out_dw32_resp;

  // AXI corrected address width
  axi_out_dw32_aw32_req_t axi_out_dw32_aw32_req;


  // TODO: mem to AXI
  assign axi_output_obi_rsp.gnt = 1'b0;
  assign axi_output_obi_rsp.rvalid = 1'b0;

  // TODO: AXI AddrWidth prepend

  // AXI Data Width converter
  axi_dw_converter #(
    .AxiMaxReads         ( 1                     ),
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
