// Copyright 2023 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

`include "axi/typedef.svh"

module fixture_safety_island;
  import safety_island_pkg::*;

  localparam time ClkPeriodExt      = 10ns;
  localparam time ClkPeriodSys      = 10ns;
  localparam time ClkPeriodJtag     = 20ns;
  localparam time ClkPeriodRtc      = 30517ns;
  localparam int unsigned RstCycles = 10;

  localparam real ApplFrac   = 0.1;
  localparam real TestFrac   = 0.9;

  // Safety Island Configs
  parameter safety_island_pkg::safety_island_cfg_t SafetyIslandCfg = SafetyIslandDefaultConfig;

  localparam int unsigned              GlobalAddrWidth = 32;
  localparam bit [GlobalAddrWidth-1:0] BaseAddr        = 32'h0000_0000;
  localparam bit [31:0]                AddrRange       = 32'h0080_0000;
  localparam bit [31:0]                MemOffset       = 32'h0000_0000;
  localparam bit [31:0]                PeriphOffset    = 32'h0020_0000;

  localparam SocCtrlAddr    = BaseAddr + PeriphOffset + SocCtrlAddrOffset;
  localparam BootAddrAddr   = SocCtrlAddr + safety_soc_ctrl_reg_pkg::SAFETY_SOC_CTRL_BOOTADDR_OFFSET;
  localparam FetchEnAddr    = SocCtrlAddr + safety_soc_ctrl_reg_pkg::SAFETY_SOC_CTRL_FETCHEN_OFFSET;
  localparam CoreStatusAddr = SocCtrlAddr + safety_soc_ctrl_reg_pkg::SAFETY_SOC_CTRL_CORESTATUS_OFFSET;
  localparam BootModeAddr   = SocCtrlAddr + safety_soc_ctrl_reg_pkg::SAFETY_SOC_CTRL_BOOTMODE_OFFSET;

  // Global AXI Configs
  localparam int unsigned AxiDataWidth     = 64;
  localparam int unsigned AxiAddrWidth     = GlobalAddrWidth;
  localparam int unsigned AxiInputIdWidth  = 4;
  localparam int unsigned AxiUserWidth     = 1;
  localparam int unsigned AxiOutputIdWidth = 2;

  `AXI_TYPEDEF_ALL(axi_input,  logic[AxiAddrWidth-1:0], logic[AxiInputIdWidth-1:0],  logic[AxiDataWidth-1:0], logic[AxiDataWidth/8-1:0], logic[AxiUserWidth-1:0])
  `AXI_TYPEDEF_ALL(axi_output, logic[AxiAddrWidth-1:0], logic[AxiOutputIdWidth-1:0], logic[AxiDataWidth-1:0], logic[AxiDataWidth/8-1:0], logic[AxiUserWidth-1:0])

  localparam int unsigned LogDepth = 3;

  localparam int unsigned AsyncInAwWidth = (2**LogDepth)*axi_pkg::aw_width(AxiAddrWidth, AxiInputIdWidth, AxiUserWidth);
  localparam int unsigned AsyncInWWidth  = (2**LogDepth)*axi_pkg::w_width(AxiDataWidth, AxiUserWidth);
  localparam int unsigned AsyncInBWidth  = (2**LogDepth)*axi_pkg::b_width(AxiInputIdWidth, AxiUserWidth);
  localparam int unsigned AsyncInArWidth = (2**LogDepth)*axi_pkg::ar_width(AxiAddrWidth, AxiInputIdWidth, AxiUserWidth);
  localparam int unsigned AsyncInRWidth  = (2**LogDepth)*axi_pkg::r_width(AxiDataWidth, AxiInputIdWidth, AxiUserWidth);

  localparam int unsigned AsyncOutAwWidth = (2**LogDepth)*axi_pkg::aw_width(AxiAddrWidth, AxiOutputIdWidth, AxiUserWidth);
  localparam int unsigned AsyncOutWWidth  = (2**LogDepth)*axi_pkg::w_width(AxiDataWidth, AxiUserWidth);
  localparam int unsigned AsyncOutBWidth  = (2**LogDepth)*axi_pkg::b_width(AxiOutputIdWidth, AxiUserWidth);
  localparam int unsigned AsyncOutArWidth = (2**LogDepth)*axi_pkg::ar_width(AxiAddrWidth, AxiOutputIdWidth, AxiUserWidth);
  localparam int unsigned AsyncOutRWidth  = (2**LogDepth)*axi_pkg::r_width(AxiDataWidth, AxiOutputIdWidth, AxiUserWidth);

  // exit
  localparam int EXIT_FAIL = 1;

  bit exit_status;  // per default we fail
  int stim_fd;
  int num_stim = 0;

  logic s_clk, s_ext_clk, s_ref_clk;
  logic s_fetchenable;
  logic [1:0] s_bootmode;
  logic s_rst_n;
  logic s_test_enable;

  logic s_tck;
  logic s_tdi;
  logic s_tdo;
  logic s_tms;
  logic s_trstn;

  logic [AsyncInAwWidth-1:0] async_in_aw_data;
  logic [AsyncInWWidth-1:0] async_in_w_data;
  logic [AsyncInBWidth-1:0] async_in_b_data;
  logic [AsyncInArWidth-1:0] async_in_ar_data;
  logic [AsyncInRWidth-1:0] async_in_r_data;
  logic [LogDepth:0] in_aw_wptr, in_w_wptr, in_b_wptr, in_ar_wptr, in_r_wptr;
  logic [LogDepth:0] in_aw_rptr, in_w_rptr, in_b_rptr, in_ar_rptr, in_r_rptr;

  logic [AsyncOutAwWidth-1:0] async_out_aw_data;
  logic [AsyncOutWWidth-1:0] async_out_w_data;
  logic [AsyncOutBWidth-1:0] async_out_b_data;
  logic [AsyncOutArWidth-1:0] async_out_ar_data;
  logic [AsyncOutRWidth-1:0] async_out_r_data;
  logic [LogDepth:0] out_aw_wptr, out_w_wptr, out_b_wptr, out_ar_wptr, out_r_wptr;
  logic [LogDepth:0] out_aw_rptr, out_w_rptr, out_b_rptr, out_ar_rptr, out_r_rptr;

  logic axi_isolate, axi_isolated;

  assign axi_isolate = 1'b0; // Hardcoded for now, eventually connect to control register

  axi_input_req_t from_ext_req;
  axi_input_resp_t from_ext_resp;

  axi_output_req_t to_ext_req;
  axi_output_resp_t to_ext_resp;

  axi_cdc_src #(
    .LogDepth  ( LogDepth            ),
    .aw_chan_t ( axi_input_aw_chan_t ),
    .w_chan_t  ( axi_input_w_chan_t  ),
    .b_chan_t  ( axi_input_b_chan_t  ),
    .ar_chan_t ( axi_input_ar_chan_t ),
    .r_chan_t  ( axi_input_r_chan_t  ),
    .axi_req_t ( axi_input_req_t     ),
    .axi_resp_t( axi_input_resp_t    )
  ) i_cdc_in (
    .src_clk_i                   ( s_ext_clk     ),
    .src_rst_ni                  ( s_rst_n       ),
    .src_req_i                   ( from_ext_req  ),
    .src_resp_o                  ( from_ext_resp ),

    .async_data_master_aw_data_o ( async_in_aw_data ),
    .async_data_master_aw_wptr_o ( in_aw_wptr       ),
    .async_data_master_aw_rptr_i ( in_aw_rptr       ),
    .async_data_master_w_data_o  ( async_in_w_data  ),
    .async_data_master_w_wptr_o  ( in_w_wptr        ),
    .async_data_master_w_rptr_i  ( in_w_rptr        ),
    .async_data_master_b_data_i  ( async_in_b_data  ),
    .async_data_master_b_wptr_i  ( in_b_wptr        ),
    .async_data_master_b_rptr_o  ( in_b_rptr        ),
    .async_data_master_ar_data_o ( async_in_ar_data ),
    .async_data_master_ar_wptr_o ( in_ar_wptr       ),
    .async_data_master_ar_rptr_i ( in_ar_rptr       ),
    .async_data_master_r_data_i  ( async_in_r_data  ),
    .async_data_master_r_wptr_i  ( in_r_wptr        ),
    .async_data_master_r_rptr_o  ( in_r_rptr        )
  );

  axi_cdc_dst #(
    .LogDepth   ( LogDepth ),
    .aw_chan_t  ( axi_output_aw_chan_t ),
    .w_chan_t   ( axi_output_w_chan_t  ),
    .b_chan_t   ( axi_output_b_chan_t  ),
    .ar_chan_t  ( axi_output_ar_chan_t ),
    .r_chan_t   ( axi_output_r_chan_t  ),
    .axi_req_t  ( axi_output_req_t     ),
    .axi_resp_t ( axi_output_resp_t    )
  ) i_cdc_out (
    .async_data_slave_aw_data_i ( async_out_aw_data ),
    .async_data_slave_aw_wptr_i ( out_aw_wptr       ),
    .async_data_slave_aw_rptr_o ( out_aw_rptr       ),
    .async_data_slave_w_data_i  ( async_out_w_data  ),
    .async_data_slave_w_wptr_i  ( out_w_wptr        ),
    .async_data_slave_w_rptr_o  ( out_w_rptr        ),
    .async_data_slave_b_data_o  ( async_out_b_data  ),
    .async_data_slave_b_wptr_o  ( out_b_wptr        ),
    .async_data_slave_b_rptr_i  ( out_b_rptr        ),
    .async_data_slave_ar_data_i ( async_out_ar_data ),
    .async_data_slave_ar_wptr_i ( out_ar_wptr       ),
    .async_data_slave_ar_rptr_o ( out_ar_rptr       ),
    .async_data_slave_r_data_o  ( async_out_r_data  ),
    .async_data_slave_r_wptr_o  ( out_r_wptr        ),
    .async_data_slave_r_rptr_i  ( out_r_rptr        ),

    .dst_clk_i                  ( s_ext_clk   ),
    .dst_rst_ni                 ( s_rst_n     ),
    .dst_req_o                  ( to_ext_req  ),
    .dst_resp_i                 ( to_ext_resp )
  );

  safety_island_synth_wrapper #(
    .SafetyIslandCfg         ( SafetyIslandCfg  ),
    .AxiAddrWidth            ( AxiAddrWidth     ),
    .AxiDataWidth            ( AxiDataWidth     ),
    .AxiUserWidth            ( AxiUserWidth     ),
    .AxiInIdWidth            ( AxiInputIdWidth  ),
    .AxiOutIdWidth           ( AxiOutputIdWidth ),
    .LogDepth                ( LogDepth         ),

    .SafetyIslandBaseAddr    ( BaseAddr     ),
    .SafetyIslandAddrRange   ( AddrRange    ),
    .SafetyIslandMemOffset   ( MemOffset    ),
    .SafetyIslandPeriphOffset( PeriphOffset ),

    .axi_in_aw_chan_t        ( axi_input_aw_chan_t ),
    .axi_in_w_chan_t         ( axi_input_w_chan_t  ),
    .axi_in_b_chan_t         ( axi_input_b_chan_t  ),
    .axi_in_ar_chan_t        ( axi_input_ar_chan_t ),
    .axi_in_r_chan_t         ( axi_input_r_chan_t  ),
    .axi_in_req_t            ( axi_input_req_t     ),
    .axi_in_resp_t           ( axi_input_resp_t    ),

    .axi_out_aw_chan_t       ( axi_output_aw_chan_t ),
    .axi_out_w_chan_t        ( axi_output_w_chan_t  ),
    .axi_out_b_chan_t        ( axi_output_b_chan_t  ),
    .axi_out_ar_chan_t       ( axi_output_ar_chan_t ),
    .axi_out_r_chan_t        ( axi_output_r_chan_t  ),
    .axi_out_req_t           ( axi_output_req_t     ),
    .axi_out_resp_t          ( axi_output_resp_t    ),

    .AsyncAxiInAwWidth       ( AsyncInAwWidth  ),
    .AsyncAxiInWWidth        ( AsyncInWWidth   ),
    .AsyncAxiInBWidth        ( AsyncInBWidth   ),
    .AsyncAxiInArWidth       ( AsyncInArWidth  ),
    .AsyncAxiInRWidth        ( AsyncInRWidth   ),
    .AsyncAxiOutAwWidth      ( AsyncOutAwWidth ),
    .AsyncAxiOutWWidth       ( AsyncOutWWidth  ),
    .AsyncAxiOutBWidth       ( AsyncOutBWidth  ),
    .AsyncAxiOutArWidth      ( AsyncOutArWidth ),
    .AsyncAxiOutRWidth       ( AsyncOutRWidth  )
  ) i_dut (
    .clk_i                   ( s_clk         ),
    .ref_clk_i               ( s_ref_clk     ),
    .rst_ni                  ( s_rst_n       ),
    .pwr_on_rst_ni           ( s_rst_n       ),
    .test_enable_i           ( s_test_enable ),
    .bootmode_i              ( s_bootmode    ),
    .fetch_en_i              ( '0            ), // Internal register used by default.
    .axi_isolate_i           ( axi_isolate   ),
    .axi_isolated_o          ( axi_isolated  ),

    .jtag_tck_i              ( s_tck   ),
    .jtag_trst_ni            ( s_trstn ),
    .jtag_tms_i              ( s_tms   ),
    .jtag_tdi_i              ( s_tdi   ),
    .jtag_tdo_o              ( s_tdo   ),

    .irqs_i                  ( '0 ),

    .debug_req_o             (),

    .async_axi_in_aw_data_i  ( async_in_aw_data ),
    .async_axi_in_aw_wptr_i  ( in_aw_wptr       ),
    .async_axi_in_aw_rptr_o  ( in_aw_rptr       ),
    .async_axi_in_w_data_i   ( async_in_w_data  ),
    .async_axi_in_w_wptr_i   ( in_w_wptr        ),
    .async_axi_in_w_rptr_o   ( in_w_rptr        ),
    .async_axi_in_b_data_o   ( async_in_b_data  ),
    .async_axi_in_b_wptr_o   ( in_b_wptr        ),
    .async_axi_in_b_rptr_i   ( in_b_rptr        ),
    .async_axi_in_ar_data_i  ( async_in_ar_data ),
    .async_axi_in_ar_wptr_i  ( in_ar_wptr       ),
    .async_axi_in_ar_rptr_o  ( in_ar_rptr       ),
    .async_axi_in_r_data_o   ( async_in_r_data  ),
    .async_axi_in_r_wptr_o   ( in_r_wptr        ),
    .async_axi_in_r_rptr_i   ( in_r_rptr        ),

    .async_axi_out_aw_data_o ( async_out_aw_data ),
    .async_axi_out_aw_wptr_o ( out_aw_wptr       ),
    .async_axi_out_aw_rptr_i ( out_aw_rptr       ),
    .async_axi_out_w_data_o  ( async_out_w_data  ),
    .async_axi_out_w_wptr_o  ( out_w_wptr        ),
    .async_axi_out_w_rptr_i  ( out_w_rptr        ),
    .async_axi_out_b_data_i  ( async_out_b_data  ),
    .async_axi_out_b_wptr_i  ( out_b_wptr        ),
    .async_axi_out_b_rptr_o  ( out_b_rptr        ),
    .async_axi_out_ar_data_o ( async_out_ar_data ),
    .async_axi_out_ar_wptr_o ( out_ar_wptr       ),
    .async_axi_out_ar_rptr_i ( out_ar_rptr       ),
    .async_axi_out_r_data_i  ( async_out_r_data  ),
    .async_axi_out_r_wptr_i  ( out_r_wptr        ),
    .async_axi_out_r_rptr_o  ( out_r_rptr        )
  );

  ///////////////////////
  // Safety Island VIP //
  ///////////////////////

  // VIP
  vip_safety_island_soc #(
    .DutCfg            ( SafetyIslandCfg   ),
    .axi_mst_ext_req_t ( axi_output_req_t  ),
    .axi_mst_ext_rsp_t ( axi_output_resp_t ),
    .axi_slv_ext_req_t ( axi_input_req_t   ),
    .axi_slv_ext_rsp_t ( axi_input_resp_t  ),
    .GlobalAddrWidth   ( AxiAddrWidth      ),
    .BaseAddr          ( BaseAddr          ),
    .AddrRange         ( AddrRange         ),
    .MemOffset         ( MemOffset         ),
    .PeriphOffset      ( PeriphOffset      ),
    .ClkPeriodSys      ( ClkPeriodSys      ),
    .ClkPeriodExt      ( ClkPeriodExt      ),
    .ClkPeriodJtag     ( ClkPeriodJtag     ),
    .ClkPeriodRtc      ( ClkPeriodRtc      ),
    .RstCycles         ( RstCycles         ),
    .AxiDataWidth      ( AxiDataWidth      ),
    .AxiAddrWidth      ( AxiAddrWidth      ),
    .AxiInputIdWidth   ( AxiInputIdWidth   ),
    .AxiOutputIdWidth  ( AxiOutputIdWidth  ),
    .AxiUserWidth      ( AxiUserWidth      ),
    .AxiDebug          ( 0                 ),
    .AxiBurstBytes     ( 512               ),
    .ApplFrac          ( ApplFrac          ),
    .TestFrac          ( TestFrac          )
  ) vip (
    // Generate reference clock for the PLL
    .clk_vip         ( s_clk         ),
    .ext_clk_vip     ( s_ext_clk     ),
    // Generate reset
    .rst_n_vip       ( s_rst_n       ),
    .test_mode       ( s_test_enable ),
    .boot_mode       ( s_bootmode    ),
    .rtc             ( s_ref_clk     ),
    .axi_mst_req     ( to_ext_req    ),
    .axi_mst_rsp     ( to_ext_resp   ),
    .axi_slv_req     ( from_ext_req  ),
    .axi_slv_rsp     ( from_ext_resp ),
    // JTAG interface
    .jtag_tck        ( s_tck   ),
    .jtag_trst_n     ( s_trstn ),
    .jtag_tms        ( s_tms   ),
    .jtag_tdi        ( s_tdi   ),
    .jtag_tdo        ( s_tdo   ),
    // Exit
    .exit_status
  );

endmodule
