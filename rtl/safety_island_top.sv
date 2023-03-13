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

module safety_island_top import safety_island_pkg::*; #(
  parameter int unsigned             HartId          = 32'd1,
  parameter int unsigned             GlobalAddrWidth = 48,
  parameter bit[GlobalAddrWidth-1:0] BaseAddr        = 48'h0003_0000_0000,
  parameter bit[31:0]                AddrRange       =      32'h0080_0000,
  parameter bit[31:0]                MemOffset       =      32'h0000_0000,
  parameter bit[31:0]                PeriphOffset    =      32'h0002_0000,
  parameter int unsigned             BankNumBytes    =      32'h0000_8000,
  parameter int unsigned             NumInterrupts   = 256,

  // LSB                       [0]:     1'h1
  // PULP Platform Manufacturer[11:1]:  11'h6d9
  // Part Number               [27:12]: 16'h0000 --> TBD!
  // Version                   [31:28]: 4'h1
  parameter int unsigned PulpJtagIdCode = 32'h1_0000_db3,

  /// AXI slave port structs (input)
  parameter type axi_input_req_t = logic,
  parameter type axi_input_resp_t = logic,

  /// AXI master port structs (output)
  parameter type axi_output_req_t = logic,
  parameter type axi_output_resp_t = logic

) (
  input  logic            clk_i,
  input  logic            rst_ni,
  input  logic            test_enable_i,

  /// JTAG
  input  logic            jtag_tck_i,
  input  logic            jtag_tdi_i,
  output logic            jtag_tdo_o,
  input  logic            jtag_tms_i,
  input  logic            jtag_trst_i,

  /// Bootmode
  input  bootmode_e       bootmode_i,

  /// AXI input
  input  axi_input_req_t  axi_input_req_i,
  output axi_input_resp_t axi_input_resp_o,

  /// AXI output
  output axi_output_req_t  axi_output_req_i,
  input  axi_output_resp_t axi_output_resp_o
);

  localparam int unsigned AddrWidth = 32;
  localparam int unsigned DataWidth = 32;
  localparam int unsigned BaseAddr32 = BaseAddr[31:0];
  localparam int unsigned BankNumWords = BankNumBytes/4;

  localparam WDataAggLen =  1 +  4 +   32 +    32;
  //                       we   be   addr   wdata
  localparam RDataAggLen =    32 +   1;
  //                       rdata   err

  `REG_BUS_TYPEDEF_ALL(safety_reg, logic[AddrWidth-1:0], logic[DataWidth-1:0], logic[(DataWidth/8)-1:0]);

  // Address map of miniPULP
  typedef struct packed {
      logic [31:0] idx;
      logic [31:0] start_addr;
      logic [31:0] end_addr;
  } addr_map_rule_t;

  localparam int unsigned NumSlaves = 4;
  localparam int unsigned NumRules  = 3;
  localparam addr_map_rule_t [NumRules-1:0] main_addr_map = '{             // 0: below/above address space, so AXI out (default)
    '{ idx: 1, start_addr: BaseAddr32+MemOffset,              end_addr: BaseAddr32+MemOffset+BankNumBytes  }, // 1: Instr bank
    '{ idx: 2, start_addr: BaseAddr32+MemOffset+BankNumBytes, end_addr: BaseAddr32+MemOffset+2*BankNumBytes}, // 2: Data bank
    '{ idx: 3, start_addr: BaseAddr32,                        end_addr: BaseAddr32+AddrRange}                 // 3: Periphs
  };

`ifdef TARGET_SIMULATION
  localparam int unsigned NumPeriphs     = 7;
  localparam int unsigned NumPeriphRules = 7;
`else
  localparam int unsigned NumPeriphs     = 6;
  localparam int unsigned NumPeriphRules = 6;
`endif
  localparam bit[31:0] PeriphBaseAddr = BaseAddr32+PeriphOffset;
  localparam int unsigned PeriphErrorSlv      = 0;
  localparam int unsigned PeriphSocCtrl       = 1;
  localparam int unsigned PeriphBootROM       = 2;
  localparam int unsigned PeriphGlobalPrepend = 3;
  localparam int unsigned PeriphDebug         = 4;
  localparam int unsigned PeriphCoreLocal     = 5;
  localparam int unsigned PeriphTBPrintf      = 6;
  localparam addr_map_rule_t [NumPeriphRules-1:0] periph_addr_map = '{                                  // 0: Error slave (default)
    '{ idx: PeriphSocCtrl,       start_addr: PeriphBaseAddr+32'h0000_0000, end_addr: PeriphBaseAddr+32'h0000_1000}, // 1: SoC control
    '{ idx: PeriphBootROM,       start_addr: PeriphBaseAddr+32'h0000_1000, end_addr: PeriphBaseAddr+32'h0000_2000}, // 2: Boot ROM
    '{ idx: PeriphGlobalPrepend, start_addr: PeriphBaseAddr+32'h0000_2000, end_addr: PeriphBaseAddr+32'h0000_3000}, // 3: Global prepend
    '{ idx: PeriphDebug,         start_addr: PeriphBaseAddr+32'h0000_3000, end_addr: PeriphBaseAddr+32'h0000_4000}, // 4: Debug
    '{ idx: PeriphCoreLocal,     start_addr: PeriphBaseAddr+32'h0000_4000, end_addr: PeriphBaseAddr+32'h0000_5000}, // 5: CLIC
    '{ idx: PeriphCoreLocal,     start_addr: PeriphBaseAddr+32'h0000_5000, end_addr: PeriphBaseAddr+32'h0000_6000}  // 6: TCLS
`ifdef TARGET_SIMULATION
    ,
    '{ idx: PeriphTBPrintf,      start_addr: PeriphBaseAddr+32'h0000_6000, end_addr: PeriphBaseAddr+32'h0000_7000}  // 7: TBPrintf
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
  logic        core_instr_req, core_instr_gnt, core_instr_rvalid, core_instr_we, core_instr_err;
  logic [ 3:0] core_instr_be;
  logic [31:0] core_instr_addr, core_instr_wdata, core_instr_rdata;
  logic [WDataAggLen-1:0] core_instr_wdata_agg;
  logic [RDataAggLen-1:0] core_instr_rdata_agg;
  assign core_instr_we = '0;
  assign core_instr_be = '0;
  assign core_instr_wdata = '0;
  assign core_instr_wdata_agg = {core_instr_we, core_instr_be, core_instr_addr, core_instr_wdata};
  assign {core_instr_rdata, core_instr_err} = core_instr_rdata_agg;

  // Core data bus
  logic        core_data_req, core_data_gnt, core_data_rvalid, core_data_we, core_data_err;
  logic [ 3:0] core_data_be;
  logic [31:0] core_data_addr, core_data_wdata, core_data_rdata;
  logic [WDataAggLen-1:0] core_data_wdata_agg;
  logic [RDataAggLen-1:0] core_data_rdata_agg;
  assign core_data_wdata_agg = {core_data_we, core_data_be, core_data_addr, core_data_wdata};
  assign {core_data_rdata, core_data_err} = core_data_rdata_agg;

  // dbg req bus
  logic        dbg_req_req, dbg_req_gnt, dbg_req_rvalid, dbg_req_we, dbg_req_err;
  logic [ 3:0] dbg_req_be;
  logic [31:0] dbg_req_addr, dbg_req_wdata, dbg_req_rdata;
  logic [WDataAggLen-1:0] dbg_req_wdata_agg;
  logic [RDataAggLen-1:0] dbg_req_rdata_agg;
  assign dbg_req_wdata_agg = {dbg_req_we, dbg_req_be, dbg_req_addr, dbg_req_wdata};
  assign {dbg_req_rdata, dbg_req_err} = dbg_req_rdata_agg;

  // axi input bus
  logic        axi_input_req, axi_input_gnt, axi_input_rvalid, axi_input_we, axi_input_err;
  logic [ 3:0] axi_input_be;
  logic [31:0] axi_input_addr, axi_input_wdata, axi_input_rdata;
  logic [WDataAggLen-1:0] axi_input_wdata_agg;
  logic [RDataAggLen-1:0] axi_input_rdata_agg;
  assign axi_input_wdata_agg = {axi_input_we, axi_input_be, axi_input_addr, axi_input_wdata};
  assign {axi_input_rdata, axi_input_err} = axi_input_rdata_agg;

  // -----------------
  // Slave buses
  // -----------------

  // mem instr bus
  logic        mem_instr_req, mem_instr_gnt, mem_instr_rvalid, mem_instr_we, mem_instr_err;
  logic [ 3:0] mem_instr_be;
  logic [31:0] mem_instr_addr, mem_instr_wdata, mem_instr_rdata;
  logic [WDataAggLen-1:0] mem_instr_wdata_agg;
  logic [RDataAggLen-1:0] mem_instr_rdata_agg;
  assign {mem_instr_we, mem_instr_be, mem_instr_addr, mem_instr_wdata} = mem_instr_wdata_agg;
  assign mem_instr_rdata_agg = {mem_instr_rdata, mem_instr_err};

  // mem data bus
  logic        mem_data_req, mem_data_gnt, mem_data_rvalid, mem_data_we, mem_data_err;
  logic [ 3:0] mem_data_be;
  logic [31:0] mem_data_addr, mem_data_wdata, mem_data_rdata;
  logic [WDataAggLen-1:0] mem_data_wdata_agg;
  logic [RDataAggLen-1:0] mem_data_rdata_agg;
  assign {mem_data_we, mem_data_be, mem_data_addr, mem_data_wdata} = mem_data_wdata_agg;
  assign mem_data_rdata_agg = {mem_data_rdata, mem_data_err};

  // axi output bus
  logic        axi_output_req, axi_output_gnt, axi_output_rvalid, axi_output_we, axi_output_err;
  logic [ 3:0] axi_output_be;
  logic [31:0] axi_output_addr, axi_output_wdata, axi_output_rdata;
  logic [WDataAggLen-1:0] axi_output_wdata_agg;
  logic [RDataAggLen-1:0] axi_output_rdata_agg;
  assign {axi_output_we, axi_output_be, axi_output_addr, axi_output_wdata} = axi_output_wdata_agg;
  assign axi_output_rdata_agg = {axi_output_rdata, axi_output_err};

  // periph bus
  logic        periph_req, periph_gnt, periph_rvalid, periph_we;//, periph_err;
  logic [ 3:0] periph_be;
  logic [31:0] periph_addr, periph_wdata;//, periph_rdata;
  logic [WDataAggLen-1:0] periph_wdata_agg;
  logic [RDataAggLen-1:0] periph_rdata_agg;
  assign {periph_we, periph_be, periph_addr, periph_wdata} = periph_wdata_agg;
  // assign periph_rdata_agg = {periph_rdata, periph_err};

  // Main xbar slave buses, must align with addr map!
  logic [NumSlaves-1:0][WDataAggLen-1:0] xbar_slave_wdata;
  logic [NumSlaves-1:0][RDataAggLen-1:0] xbar_slave_rdata;
  logic [NumSlaves-1:0] xbar_slave_gnt, xbar_slave_req;
  assign axi_output_wdata_agg = xbar_slave_wdata[0];
  assign xbar_slave_rdata[0]  = axi_output_rdata_agg;
  assign axi_output_req       = xbar_slave_req[0];
  assign xbar_slave_gnt[0]    = axi_output_gnt;
  assign mem_instr_wdata_agg  = xbar_slave_wdata[1];
  assign xbar_slave_rdata[1]  = mem_instr_rdata_agg;
  assign mem_instr_req        = xbar_slave_req[1];
  assign xbar_slave_gnt[1]    = mem_instr_gnt;
  assign mem_data_wdata_agg   = xbar_slave_wdata[2];
  assign xbar_slave_rdata[2]  = mem_data_rdata_agg;
  assign mem_data_req         = xbar_slave_req[2];
  assign xbar_slave_gnt[2]    = mem_data_gnt;
  assign periph_wdata_agg     = xbar_slave_wdata[3];
  assign xbar_slave_rdata[3]  = periph_rdata_agg;
  assign periph_req           = xbar_slave_req[3];
  assign xbar_slave_gnt[3]    = periph_gnt;

  // -----------------
  // Peripheral buses
  // -----------------

  // Error bus
  logic        error_req, error_gnt, error_rvalid, error_we, error_err;
  logic [ 3:0] error_be;
  logic [31:0] error_addr, error_wdata, error_rdata;
  logic [WDataAggLen-1:0] error_wdata_agg;
  logic [RDataAggLen-1:0] error_rdata_agg;
  assign {error_we, error_be, error_addr, error_wdata} = error_wdata_agg;
  assign error_rdata_agg = {error_rdata, error_err};

  // SoC control bus
  logic        soc_ctrl_req, soc_ctrl_gnt, soc_ctrl_rvalid, soc_ctrl_we, soc_ctrl_err;
  logic [ 3:0] soc_ctrl_be;
  logic [31:0] soc_ctrl_addr, soc_ctrl_wdata, soc_ctrl_rdata;
  logic [WDataAggLen-1:0] soc_ctrl_wdata_agg;
  logic [RDataAggLen-1:0] soc_ctrl_rdata_agg;
  assign {soc_ctrl_we, soc_ctrl_be, soc_ctrl_addr, soc_ctrl_wdata} = soc_ctrl_wdata_agg;
  assign soc_ctrl_rdata_agg = {soc_ctrl_rdata, soc_ctrl_err};
  safety_reg_req_t soc_ctrl_reg_req;
  safety_reg_rsp_t soc_ctrl_reg_rsp;

  // Boot ROM bus
  logic        boot_rom_req, boot_rom_gnt, boot_rom_rvalid, boot_rom_we, boot_rom_err;
  logic [ 3:0] boot_rom_be;
  logic [31:0] boot_rom_addr, boot_rom_wdata, boot_rom_rdata;
  logic [WDataAggLen-1:0] boot_rom_wdata_agg;
  logic [RDataAggLen-1:0] boot_rom_rdata_agg;
  assign {boot_rom_we, boot_rom_be, boot_rom_addr, boot_rom_wdata} = boot_rom_wdata_agg;
  assign boot_rom_rdata_agg = {boot_rom_rdata, boot_rom_err};

  // Global prepend bus
  logic        global_prepend_req, global_prepend_gnt, global_prepend_rvalid, global_prepend_we, global_prepend_err;
  logic [ 3:0] global_prepend_be;
  logic [31:0] global_prepend_addr, global_prepend_wdata, global_prepend_rdata;
  logic [WDataAggLen-1:0] global_prepend_wdata_agg;
  logic [RDataAggLen-1:0] global_prepend_rdata_agg;
  assign {global_prepend_we, global_prepend_be, global_prepend_addr, global_prepend_wdata} = global_prepend_wdata_agg;
  assign global_prepend_rdata_agg = {global_prepend_rdata, global_prepend_err};

  // Debug mem bus
  logic        dbg_mem_req, dbg_mem_gnt, dbg_mem_rvalid, dbg_mem_we, dbg_mem_err;
  logic [ 3:0] dbg_mem_be;
  logic [31:0] dbg_mem_addr, dbg_mem_wdata, dbg_mem_rdata;
  logic [WDataAggLen-1:0] dbg_mem_wdata_agg;
  logic [RDataAggLen-1:0] dbg_mem_rdata_agg;
  assign {dbg_mem_we, dbg_mem_be, dbg_mem_addr, dbg_mem_wdata} = dbg_mem_wdata_agg;
  assign dbg_mem_rdata_agg = {dbg_mem_rdata, dbg_mem_err};

  // core local bus
  logic        cl_periph_req, cl_periph_gnt, cl_periph_rvalid, cl_periph_we, cl_periph_err;
  logic [ 3:0] cl_periph_be;
  logic [31:0] cl_periph_addr, cl_periph_wdata, cl_periph_rdata;
  logic [WDataAggLen-1:0] cl_periph_wdata_agg;
  logic [RDataAggLen-1:0] cl_periph_rdata_agg;
  assign {cl_periph_we, cl_periph_be, cl_periph_addr, cl_periph_wdata} = cl_periph_wdata_agg;
  assign cl_periph_rdata_agg = {cl_periph_rdata, cl_periph_err};
  safety_reg_req_t cl_periph_reg_req;
  safety_reg_rsp_t cl_periph_reg_rsp;

`ifdef TARGET_SIMULATION
  // TBPrintf bus
  logic        tbprintf_req, tbprintf_gnt, tbprintf_rvalid, tbprintf_we, tbprintf_err;
  logic [ 3:0] tbprintf_be;
  logic [31:0] tbprintf_addr, tbprintf_wdata, tbprintf_rdata;
  logic [WDataAggLen-1:0] tbprintf_wdata_agg;
  logic [RDataAggLen-1:0] tbprintf_rdata_agg;
  assign {tbprintf_we, tbprintf_be, tbprintf_addr, tbprintf_wdata} = tbprintf_wdata_agg;
  assign tbprintf_rdata_agg = {tbprintf_rdata, tbprintf_err};
`endif

  logic [NumPeriphs-1:0][WDataAggLen-1:0] all_periph_wdata_agg;
  logic [NumPeriphs-1:0][RDataAggLen-1:0] all_periph_rdata_agg;
  logic [NumPeriphs-1:0] all_periph_req, all_periph_gnt;
  assign error_wdata_agg                      = all_periph_wdata_agg[PeriphErrorSlv];
  assign all_periph_rdata_agg[PeriphErrorSlv] = error_rdata_agg;
  assign all_periph_gnt[PeriphErrorSlv]       = error_gnt;
  assign error_req                            = all_periph_req[PeriphErrorSlv];
  assign soc_ctrl_wdata_agg                   = all_periph_wdata_agg[PeriphSocCtrl];
  assign all_periph_rdata_agg[PeriphSocCtrl]  = soc_ctrl_rdata_agg;
  assign all_periph_gnt[PeriphSocCtrl]        = soc_ctrl_gnt;
  assign soc_ctrl_req                         = all_periph_req[PeriphSocCtrl];
  assign boot_rom_wdata_agg                   = all_periph_wdata_agg[PeriphBootROM];
  assign all_periph_rdata_agg[PeriphBootROM]  = boot_rom_rdata_agg;
  assign all_periph_gnt[PeriphBootROM]        = boot_rom_gnt;
  assign boot_rom_req                         = all_periph_req[PeriphBootROM];
  assign global_prepend_wdata_agg             = all_periph_wdata_agg[PeriphGlobalPrepend];
  assign all_periph_rdata_agg[PeriphGlobalPrepend] = global_prepend_rdata_agg;
  assign all_periph_gnt[PeriphGlobalPrepend]  = global_prepend_gnt;
  assign global_prepend_req                   = all_periph_req[PeriphGlobalPrepend];
  assign dbg_mem_wdata_agg                    = all_periph_wdata_agg[PeriphDebug];
  assign all_periph_rdata_agg[PeriphDebug]   = dbg_mem_rdata_agg;
  assign all_periph_gnt[PeriphDebug]          = dbg_mem_gnt;
  assign dbg_mem_req                          = all_periph_req[PeriphDebug];
  assign cl_periph_wdata_agg                  = all_periph_wdata_agg[PeriphCoreLocal];
  assign all_periph_rdata_agg[PeriphCoreLocal] = cl_periph_rdata_agg;
  assign all_periph_gnt[PeriphCoreLocal]      = cl_periph_gnt;
  assign cl_periph_req                        = all_periph_req[PeriphCoreLocal];
`ifdef TARGET_SIMULATION
  assign tbprintf_wdata_agg                   = all_periph_wdata_agg[PeriphTBPrintf];
  assign all_periph_rdata_agg[PeriphTBPrintf] = tbprintf_rdata_agg;
  assign all_periph_gnt[PeriphTBPrintf]       = tbprintf_gnt;
  assign tbprintf_req                         = all_periph_req[PeriphTBPrintf];
`endif

  // -----------------
  // Core
  // -----------------

  logic debug_req;

  safety_core_wrap #(
    .DmBaseAddr    ( PeriphBaseAddr+32'h0000_3000 ),
    .reg_req_t     ( safety_reg_req_t ),
    .reg_rsp_t     ( safety_reg_rsp_t ),
    .NumInterrupts ( NumInterrupts    )
  ) i_core_wrap (
    .clk_i,
    .rst_ni,
    .test_enable_i,

    .cl_periph_req_i  ( cl_periph_reg_req ),
    .cl_periph_rsp_o  ( cl_periph_reg_rsp ),

    .hart_id_i        ( HartId            ),
    .boot_addr_i      ( boot_addr         ),

    .instr_req_o      ( core_instr_req    ),
    .instr_gnt_i      ( core_instr_gnt    ),
    .instr_rvalid_i   ( core_instr_rvalid ),
    .instr_addr_o     ( core_instr_addr   ),
    .instr_rdata_i    ( core_instr_rdata  ),
    .instr_err_i      ( core_instr_err    ),

    .data_req_o       ( core_data_req     ),
    .data_gnt_i       ( core_data_gnt     ),
    .data_rvalid_i    ( core_data_rvalid  ),
    .data_we_o        ( core_data_we      ),
    .data_be_o        ( core_data_be      ),
    .data_addr_o      ( core_data_addr    ),
    .data_wdata_o     ( core_data_wdata   ),
    .data_rdata_i     ( core_data_rdata   ),
    .data_err_i       ( core_data_err     ),

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
    .IdcodeValue(PulpJtagIdCode)
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
    .trst_ni          ( jtag_trst_i    ),
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

    .slave_req_i          ( dbg_mem_req    ),
    .slave_we_i           ( dbg_mem_we     ),
    .slave_addr_i         ( dbg_mem_addr   ),
    .slave_be_i           ( dbg_mem_be     ),
    .slave_wdata_i        ( dbg_mem_wdata  ),
    .slave_rdata_o        ( dbg_mem_rdata  ),

    .master_req_o         ( dbg_req_req    ),
    .master_add_o         ( dbg_req_addr   ),
    .master_we_o          ( dbg_req_we     ),
    .master_wdata_o       ( dbg_req_wdata  ),
    .master_be_o          ( dbg_req_be     ),
    .master_gnt_i         ( dbg_req_gnt    ),
    .master_r_valid_i     ( dbg_req_rvalid ),
    .master_r_err_i       ( dbg_req_err    ),
    .master_r_other_err_i ( 1'b0           ),
    .master_r_rdata_i     ( dbg_req_rdata  ), 

    .dmi_rst_ni           ( dmi_rst_n      ),
    .dmi_req_valid_i      ( dmi_req_valid  ),
    .dmi_req_ready_o      ( dmi_req_ready  ),
    .dmi_req_i            ( dmi_req        ),

    .dmi_resp_valid_o     ( dmi_resp_valid ),
    .dmi_resp_ready_i     ( dmi_resp_ready ),
    .dmi_resp_o           ( dmi_resp       )
  );

  assign dbg_mem_gnt = dbg_mem_req;
  assign dbg_mem_err = '0;
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_dbg_mem
    if(!rst_ni) begin
      dbg_mem_rvalid <= '0;
    end else begin
      dbg_mem_rvalid <= dbg_mem_gnt;
    end
  end

  // -----------------
  // Main Interconnect
  // -----------------

  typedef logic[cf_math_pkg::idx_width(NumSlaves)-1:0] main_idx_t;
  main_idx_t [3:0] main_idx;
  logic [3:0][31:0] main_addr;

  for (genvar i = 0; i < 4; i++) begin : gen_main_addr_decode
    addr_decode #(
      .NoIndices ( NumSlaves       ),
      .NoRules   ( NumRules        ),
      .addr_t    ( logic[31:0]     ),
      .rule_t    ( addr_map_rule_t ),
      .Napot     ( 1'b0            )
    ) i_xbar_addr_decode (
      .addr_i           ( main_addr [i] ),
      .addr_map_i       ( main_addr_map ),
      .idx_o            ( main_idx  [i] ),
      .dec_valid_o      (),
      .dec_error_o      (),
      .en_default_idx_i ( 1'b1 ),
      .default_idx_i    ( '0 )
    );
  end

  assign main_addr = {axi_input_addr, core_instr_addr, core_data_addr, dbg_req_addr};
  xbar #(
    .NumIn         ( 4           ),
    .NumOut        ( NumSlaves   ),
    .ReqDataWidth  ( WDataAggLen ),
    .RespDataWidth ( RDataAggLen ),
    .RespLat       ( 1           ),
    .WriteRespOn   ( 1'b1        ),
    .BroadCastOn   ( 1'b0        ),
    .ExtPrio       ( 1'b0        )
  ) i_xbar_interco (
    .clk_i,
    .rst_ni,

    .rr_i    ( '0 ),

    .req_i   ( {axi_input_req,       core_instr_req,       core_data_req,       dbg_req_req      } ),
    .add_i   ( main_idx ),
    .wen_i   ( '0 ), // irrelevant for WriteRespOn
    .wdata_i ( {axi_input_wdata_agg, core_instr_wdata_agg, core_data_wdata_agg, dbg_req_wdata_agg} ),
    .gnt_o   ( {axi_input_gnt,       core_instr_gnt,       core_data_gnt,       dbg_req_gnt      } ),
    .vld_o   ( {axi_input_rvalid,    core_instr_rvalid,    core_data_rvalid,    dbg_req_rvalid   } ),
    .rdata_o ( {axi_input_rdata_agg, core_instr_rdata_agg, core_data_rdata_agg, dbg_req_rdata_agg} ),

    .gnt_i   ( xbar_slave_gnt   ),
    .req_o   ( xbar_slave_req   ),
    .wdata_o ( xbar_slave_wdata ),
    .rdata_i ( xbar_slave_rdata )
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

    .req_i   ( mem_instr_req   ),
    .we_i    ( mem_instr_we    ),
    .addr_i  ( mem_instr_addr  ),
    .wdata_i ( mem_instr_wdata ),
    .be_i    ( mem_instr_be    ),

    .rdata_o ( mem_instr_rdata )
  );
  assign mem_instr_err = 1'b0;
  assign mem_instr_gnt = mem_instr_req;
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_mem_instr_rvalid
    if(!rst_ni) begin
      mem_instr_rvalid <= '0;
    end else begin
      mem_instr_rvalid <= mem_instr_gnt;
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

    .req_i   ( mem_data_req   ),
    .we_i    ( mem_data_we    ),
    .addr_i  ( mem_data_addr  ),
    .wdata_i ( mem_data_wdata ),
    .be_i    ( mem_data_be    ),

    .rdata_o ( mem_data_rdata )
  );
  assign mem_data_err = 1'b0;
  assign mem_data_gnt = mem_data_req;
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_mem_data_rvalid
    if(!rst_ni) begin
      mem_data_rvalid <= '0;
    end else begin
      mem_data_rvalid <= mem_data_gnt;
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
    .addr_i           ( periph_addr     ),
    .addr_map_i       ( periph_addr_map ),
    .idx_o            ( periph_idx      ),
    .dec_valid_o      (),
    .dec_error_o      (),
    .en_default_idx_i ( 1'b1 ),
    .default_idx_i    ( '0 )
  );

  xbar #(
    .NumIn         ( 1           ),
    .NumOut        ( NumPeriphs  ),
    .ReqDataWidth  ( WDataAggLen ),
    .RespDataWidth ( RDataAggLen ),
    .RespLat       ( 1           ),
    .WriteRespOn   ( 1'b1        ),
    .BroadCastOn   ( 1'b0        ),
    .ExtPrio       ( 1'b0        )
  ) i_demux_periphs (
    .clk_i,
    .rst_ni,

    .rr_i    ( '0 ),

    .req_i   ( periph_req           ),
    .add_i   ( periph_idx           ),
    .wen_i   ( '0 ), // irrelevant for WriteRespOn
    .wdata_i ( periph_wdata_agg     ),
    .gnt_o   ( periph_gnt           ),
    .vld_o   ( periph_rvalid        ),
    .rdata_o ( periph_rdata_agg     ),

    .gnt_i   ( all_periph_gnt       ),
    .req_o   ( all_periph_req       ),
    .wdata_o ( all_periph_wdata_agg ),
    .rdata_i ( all_periph_rdata_agg )
  );

  // Error slave
  assign error_gnt = 1'b1;
  assign error_err = 1'b1;
  assign error_rdata = 32'hBADCAB1E;
  always_ff @(posedge clk_i or negedge rst_ni) begin : proc_error_rvalid
    if(!rst_ni) begin
      error_rvalid <= '0;
    end else begin
      error_rvalid <= error_req;
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

    .req_i     ( soc_ctrl_req     ),
    .add_i     ( soc_ctrl_addr    ),
    .wen_i     ( soc_ctrl_we      ),
    .wdata_i   ( soc_ctrl_wdata   ),
    .be_i      ( soc_ctrl_be      ),
    .id_i      ( '0 ),

    .gnt_o     ( soc_ctrl_gnt     ),
    .r_rdata_o ( soc_ctrl_rdata   ),
    .r_opc_o   ( soc_ctrl_rdata   ),
    .r_id_o    (),
    .r_valid_o ( soc_ctrl_rvalid  ),

    .reg_req_o ( soc_ctrl_reg_req ),
    .reg_rsp_i ( soc_ctrl_reg_rsp )
  );

  safety_soc_ctrl_reg_pkg::safety_soc_ctrl_reg2hw_t soc_ctrl_reg2hw;
  assign fetch_enable = soc_ctrl_reg2hw.fetchen.q;
  assign boot_addr    = soc_ctrl_reg2hw.bootaddr.q;

  safety_soc_ctrl_reg_top #(
    .reg_req_t( safety_reg_req_t ),
    .reg_rsp_t( safety_reg_rsp_t ),
    .AW       ( 32        )
  ) i_soc_ctrl (
    .clk_i,
    .rst_ni,
    .reg_req_i ( soc_ctrl_req    ),
    .reg_rsp_o ( soc_ctrl_rsp    ),
    .reg2hw    ( soc_ctrl_reg2hw ),
    .devmode_i ( 1'b0            )
  );

  // Boot ROM
  // TODO

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

    .req_i     ( cl_periph_req    ),
    .add_i     ( cl_periph_addr   ),
    .wen_i     ( cl_periph_we     ),
    .wdata_i   ( cl_periph_wdata  ),
    .be_i      ( cl_periph_be     ),
    .id_i      ( '0 ),

    .gnt_o     ( cl_periph_gnt    ),
    .r_rdata_o ( cl_periph_rdata  ),
    .r_opc_o   ( cl_periph_err    ),
    .r_id_o    (),
    .r_valid_o ( cl_periph_rvalid ),

    .reg_req_o ( cl_periph_reg_req ),
    .reg_rsp_i ( cl_periph_reg_rsp )
  );

`ifdef TARGET_SIMULATION
  // TB Printf
  // TODO
`endif

  // -----------------
  // AXI connections
  // -----------------

  // AXI input
  

  // AXI output



endmodule
