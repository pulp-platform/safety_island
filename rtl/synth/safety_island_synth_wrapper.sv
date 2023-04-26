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

module safety_island_synth_wrapper import safety_island_synth_pkg::*; #(
  parameter safety_island_pkg::safety_island_cfg_t SafetyIslandCfg = safety_island_pkg::SafetyIslandDefaultConfig,

  parameter int unsigned AxiAddrWidth   = SynthAxiAddrWidth,
  parameter int unsigned AxiDataWidth   = SynthAxiDataWidth,
  parameter int unsigned AxiUserWidth   = SynthAxiUserWidth,
  parameter int unsigned AxiInIdWidth   = SynthAxiInIdWidth,
  parameter int unsigned AxiOutIdWidth  = SynthAxiOutIdWidth,
  parameter int unsigned AxiMaxInTrans  = SynthAxiMaxInTrans,
  parameter int unsigned AxiMaxOutTrans = SynthAxiMaxOutTrans,
  parameter int unsigned LogDepth       = SynthLogDepth,
  
  parameter bit [AxiAddrWidth-1:0] SafetyIslandBaseAddr     = SynthSafetyIslandBaseAddr,
  parameter bit [31:0]             SafetyIslandAddrRange    = SynthSafetyIslandAddrRange,
  parameter bit [31:0]             SafetyIslandMemOffset    = SynthSafetyIslandMemOffset,
  parameter bit [31:0]             SafetyIslandPeriphOffset = SynthSafetyIslandPeriphOffset,

  parameter  int unsigned              NumDebug        = SynthNumDebug,
  parameter  bit [NumDebug-1:0]        SelectableHarts = SynthSelectableHarts,
  parameter  dm::hartinfo_t [NumDebug-1:0] HartInfo    = SynthHartInfo,

  parameter type         axi_in_aw_chan_t   = synth_axi_in_aw_chan_t,
  parameter type         axi_in_w_chan_t    = synth_axi_in_w_chan_t,
  parameter type         axi_in_b_chan_t    = synth_axi_in_b_chan_t,
  parameter type         axi_in_ar_chan_t   = synth_axi_in_ar_chan_t,
  parameter type         axi_in_r_chan_t    = synth_axi_in_r_chan_t,
  parameter type         axi_in_req_t       = synth_axi_in_req_t,
  parameter type         axi_in_resp_t      = synth_axi_in_resp_t,

  parameter type         axi_out_aw_chan_t  = synth_axi_out_aw_chan_t,
  parameter type         axi_out_w_chan_t   = synth_axi_out_w_chan_t,
  parameter type         axi_out_b_chan_t   = synth_axi_out_b_chan_t,
  parameter type         axi_out_ar_chan_t  = synth_axi_out_ar_chan_t,
  parameter type         axi_out_r_chan_t   = synth_axi_out_r_chan_t,
  parameter type         axi_out_req_t      = synth_axi_out_req_t,
  parameter type         axi_out_resp_t     = synth_axi_out_resp_t,

  parameter int unsigned AsyncAxiInAwWidth  = SynthAsyncAxiInAwWidth,
  parameter int unsigned AsyncAxiInWWidth   = SynthAsyncAxiInWWidth,
  parameter int unsigned AsyncAxiInBWidth   = SynthAsyncAxiInBWidth,
  parameter int unsigned AsyncAxiInArWidth  = SynthAsyncAxiInArWidth,
  parameter int unsigned AsyncAxiInRWidth   = SynthAsyncAxiInRWidth,

  parameter int unsigned AsyncAxiOutAwWidth = SynthAsyncAxiOutAwWidth,
  parameter int unsigned AsyncAxiOutWWidth  = SynthAsyncAxiOutWWidth,
  parameter int unsigned AsyncAxiOutBWidth  = SynthAsyncAxiOutBWidth,
  parameter int unsigned AsyncAxiOutArWidth = SynthAsyncAxiOutArWidth,
  parameter int unsigned AsyncAxiOutRWidth  = SynthAsyncAxiOutRWidth
) (
  input  logic clk_i,
  input  logic ref_clk_i,
  input  logic rst_ni,
  input  logic test_enable_i,
  input  logic [1:0] bootmode_i,
  input  logic fetch_en_i,
  input  logic axi_isolate_i,
  output logic axi_isolated_o,

  input  logic jtag_tck_i,
  input  logic jtag_trst_ni,
  input  logic jtag_tms_i,
  input  logic jtag_tdi_i,
  output logic jtag_tdo_o,

  input  logic [SafetyIslandCfg.NumInterrupts-1:0] irqs_i,

  output logic [NumDebug-1:0]                      debug_req_o,

  input  logic [AsyncAxiInAwWidth-1:0] async_axi_in_aw_data_i,
  input  logic            [LogDepth:0] async_axi_in_aw_wptr_i,
  output logic            [LogDepth:0] async_axi_in_aw_rptr_o,
  input  logic [ AsyncAxiInWWidth-1:0] async_axi_in_w_data_i,
  input  logic            [LogDepth:0] async_axi_in_w_wptr_i,
  output logic            [LogDepth:0] async_axi_in_w_rptr_o,
  output logic [ AsyncAxiInBWidth-1:0] async_axi_in_b_data_o,
  output logic            [LogDepth:0] async_axi_in_b_wptr_o,
  input  logic            [LogDepth:0] async_axi_in_b_rptr_i,
  input  logic [AsyncAxiInArWidth-1:0] async_axi_in_ar_data_i,
  input  logic            [LogDepth:0] async_axi_in_ar_wptr_i,
  output logic            [LogDepth:0] async_axi_in_ar_rptr_o,
  output logic [ AsyncAxiInRWidth-1:0] async_axi_in_r_data_o,
  output logic            [LogDepth:0] async_axi_in_r_wptr_o,
  input  logic            [LogDepth:0] async_axi_in_r_rptr_i,

  output logic [AsyncAxiOutAwWidth-1:0] async_axi_out_aw_data_o,
  output logic             [LogDepth:0] async_axi_out_aw_wptr_o,
  input  logic             [LogDepth:0] async_axi_out_aw_rptr_i,
  output logic [ AsyncAxiOutWWidth-1:0] async_axi_out_w_data_o,
  output logic             [LogDepth:0] async_axi_out_w_wptr_o,
  input  logic             [LogDepth:0] async_axi_out_w_rptr_i,
  input  logic [ AsyncAxiOutBWidth-1:0] async_axi_out_b_data_i,
  input  logic             [LogDepth:0] async_axi_out_b_wptr_i,
  output logic             [LogDepth:0] async_axi_out_b_rptr_o,
  output logic [AsyncAxiOutArWidth-1:0] async_axi_out_ar_data_o,
  output logic             [LogDepth:0] async_axi_out_ar_wptr_o,
  input  logic             [LogDepth:0] async_axi_out_ar_rptr_i,
  input  logic [ AsyncAxiOutRWidth-1:0] async_axi_out_r_data_i,
  input  logic             [LogDepth:0] async_axi_out_r_wptr_i,
  output logic             [LogDepth:0] async_axi_out_r_rptr_o
);

  logic [1:0] axi_isolated;
  assign axi_isolated_o = |axi_isolated;
 
  axi_in_req_t axi_in_req, axi_in_isolate_req;
  axi_in_resp_t axi_in_resp, axi_in_isolate_resp;

  axi_out_req_t axi_out_req, axi_out_isolate_req;
  axi_out_resp_t axi_out_resp, axi_out_isolate_resp;

  axi_cdc_dst #(
    .LogDepth   ( LogDepth         ),
    .aw_chan_t  ( axi_in_aw_chan_t ),
    .w_chan_t   ( axi_in_w_chan_t  ),
    .b_chan_t   ( axi_in_b_chan_t  ),
    .ar_chan_t  ( axi_in_ar_chan_t ),
    .r_chan_t   ( axi_in_r_chan_t  ),
    .axi_req_t  ( axi_in_req_t     ),
    .axi_resp_t ( axi_in_resp_t    )
  ) i_cdc_in (
    .async_data_slave_aw_data_i( async_axi_in_aw_data_i ),
    .async_data_slave_aw_wptr_i( async_axi_in_aw_wptr_i ),
    .async_data_slave_aw_rptr_o( async_axi_in_aw_rptr_o ),
    .async_data_slave_w_data_i ( async_axi_in_w_data_i  ),
    .async_data_slave_w_wptr_i ( async_axi_in_w_wptr_i  ),
    .async_data_slave_w_rptr_o ( async_axi_in_w_rptr_o  ),
    .async_data_slave_b_data_o ( async_axi_in_b_data_o  ),
    .async_data_slave_b_wptr_o ( async_axi_in_b_wptr_o  ),
    .async_data_slave_b_rptr_i ( async_axi_in_b_rptr_i  ),
    .async_data_slave_ar_data_i( async_axi_in_ar_data_i ),
    .async_data_slave_ar_wptr_i( async_axi_in_ar_wptr_i ),
    .async_data_slave_ar_rptr_o( async_axi_in_ar_rptr_o ),
    .async_data_slave_r_data_o ( async_axi_in_r_data_o  ),
    .async_data_slave_r_wptr_o ( async_axi_in_r_wptr_o  ),
    .async_data_slave_r_rptr_i ( async_axi_in_r_rptr_i  ),
    .dst_clk_i                 ( clk_i       ),
    .dst_rst_ni                ( rst_ni      ),
    .dst_req_o                 ( axi_in_req  ),
    .dst_resp_i                ( axi_in_resp )
  );

  axi_isolate            #(
    .NumPending           ( AxiMaxInTrans ),
    .TerminateTransaction ( 1             ),
    .AtopSupport          ( 1             ),
    .AxiAddrWidth         ( AxiAddrWidth  ),
    .AxiDataWidth         ( AxiDataWidth  ),
    .AxiIdWidth           ( AxiInIdWidth  ),
    .AxiUserWidth         ( AxiUserWidth  ),
    .axi_req_t            ( axi_in_req_t  ),
    .axi_resp_t           ( axi_in_resp_t )
  ) i_axi_in_isolate      (
    .clk_i                ( clk_i               ),
    .rst_ni               ( rst_ni              ),
    .slv_req_i            ( axi_in_req          ),
    .slv_resp_o           ( axi_in_resp         ),
    .mst_req_o            ( axi_in_isolate_req  ),
    .mst_resp_i           ( axi_in_isolate_resp ),
    .isolate_i            ( axi_isolate_i       ),
    .isolated_o           ( axi_isolated[0]     )
  );

  axi_cdc_src #(
    .LogDepth   ( LogDepth          ),
    .aw_chan_t  ( axi_out_aw_chan_t ),
    .w_chan_t   ( axi_out_w_chan_t  ),
    .b_chan_t   ( axi_out_b_chan_t  ),
    .ar_chan_t  ( axi_out_ar_chan_t ),
    .r_chan_t   ( axi_out_r_chan_t  ),
    .axi_req_t  ( axi_out_req_t     ),
    .axi_resp_t ( axi_out_resp_t    )
  ) i_cdc_out (
    .src_clk_i                  ( clk_i        ),
    .src_rst_ni                 ( rst_ni       ),
    .src_req_i                  ( axi_out_req  ),
    .src_resp_o                 ( axi_out_resp ),
    .async_data_master_aw_data_o( async_axi_out_aw_data_o ),
    .async_data_master_aw_wptr_o( async_axi_out_aw_wptr_o ),
    .async_data_master_aw_rptr_i( async_axi_out_aw_rptr_i ),
    .async_data_master_w_data_o ( async_axi_out_w_data_o  ),
    .async_data_master_w_wptr_o ( async_axi_out_w_wptr_o  ),
    .async_data_master_w_rptr_i ( async_axi_out_w_rptr_i  ),
    .async_data_master_b_data_i ( async_axi_out_b_data_i  ),
    .async_data_master_b_wptr_i ( async_axi_out_b_wptr_i  ),
    .async_data_master_b_rptr_o ( async_axi_out_b_rptr_o  ),
    .async_data_master_ar_data_o( async_axi_out_ar_data_o ),
    .async_data_master_ar_wptr_o( async_axi_out_ar_wptr_o ),
    .async_data_master_ar_rptr_i( async_axi_out_ar_rptr_i ),
    .async_data_master_r_data_i ( async_axi_out_r_data_i  ),
    .async_data_master_r_wptr_i ( async_axi_out_r_wptr_i  ),
    .async_data_master_r_rptr_o ( async_axi_out_r_rptr_o  )
  );

  axi_isolate            #(
    .NumPending           ( AxiMaxOutTrans ),
    .TerminateTransaction ( 1              ),
    .AtopSupport          ( 1              ),
    .AxiAddrWidth         ( AxiAddrWidth   ),
    .AxiDataWidth         ( AxiDataWidth   ),
    .AxiIdWidth           ( AxiOutIdWidth  ),
    .AxiUserWidth         ( AxiUserWidth   ),
    .axi_req_t            ( axi_out_req_t  ),
    .axi_resp_t           ( axi_out_resp_t )
  ) i_axi_out_isolate     (
    .clk_i                ( clk_i                ),
    .rst_ni               ( rst_ni               ),
    .slv_req_i            ( axi_out_isolate_req  ),
    .slv_resp_o           ( axi_out_isolate_resp ),
    .mst_req_o            ( axi_out_req          ),
    .mst_resp_i           ( axi_out_resp         ),
    .isolate_i            ( axi_isolate_i        ),
    .isolated_o           ( axi_isolated[1]      )
  );

  safety_island_top #(
    .SafetyIslandCfg   ( SafetyIslandCfg          ),
    .GlobalAddrWidth   ( AxiAddrWidth             ),
    .BaseAddr          ( SafetyIslandBaseAddr     ),
    .AddrRange         ( SafetyIslandAddrRange    ),
    .MemOffset         ( SafetyIslandMemOffset    ),
    .PeriphOffset      ( SafetyIslandPeriphOffset ),
    .NumDebug          ( NumDebug                 ),
    .SelectableHarts   ( SelectableHarts          ),
    .HartInfo          ( HartInfo                 ),
    .AxiDataWidth      ( AxiDataWidth             ),
    .AxiAddrWidth      ( AxiAddrWidth             ),
    .AxiInputIdWidth   ( AxiInIdWidth             ),
    .AxiUserWidth      ( AxiUserWidth             ),
    .axi_input_req_t   ( axi_in_req_t             ),
    .axi_input_resp_t  ( axi_in_resp_t            ),
    .AxiOutputIdWidth  ( AxiOutIdWidth            ),
    .axi_output_req_t  ( axi_out_req_t            ),
    .axi_output_resp_t ( axi_out_resp_t           )
  ) i_safety_island_top (
    .clk_i,
    .rst_ni,
    .ref_clk_i,
    .test_enable_i,
    .jtag_tck_i,
    .jtag_trst_ni,
    .jtag_tms_i,
    .jtag_tdi_i,
    .jtag_tdo_o,
    .bootmode_i,
    .fetch_enable_i   ( fetch_en_i           ),
    .irqs_i,
    .debug_req_o      ( debug_req_o          ),
    .axi_input_req_i  ( axi_in_isolate_req   ),
    .axi_input_resp_o ( axi_in_isolate_resp  ),
    .axi_output_req_o ( axi_out_isolate_req  ),
    .axi_output_resp_i( axi_out_isolate_resp )
  );

endmodule
