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

package safety_island_synth_pkg;
  import safety_island_pkg::*;

  localparam SynthAxiAddrWidth = 48;
  typedef logic [SynthAxiAddrWidth-1:0] synth_axi_addr_t;
  localparam SynthAxiDataWidth = 64;
  typedef logic [SynthAxiDataWidth-1:0] synth_axi_data_t;
  typedef logic [SynthAxiDataWidth/8-1:0] synth_axi_strb_t;
  localparam SynthAxiUserWidth = 1;
  typedef logic [SynthAxiUserWidth-1:0] synth_axi_user_t;

  localparam SynthAxiInIdWidth  = 5;
  typedef logic [SynthAxiInIdWidth-1:0] synth_axi_in_id_t;
  localparam SynthAxiOutIdWidth = 2;
  typedef logic [SynthAxiOutIdWidth-1:0] synth_axi_out_id_t;

  localparam SynthAxiMaxInTrans  = 8;
  localparam SynthAxiMaxOutTrans = 8;

  `AXI_TYPEDEF_ALL(synth_axi_in,  synth_axi_addr_t, synth_axi_in_id_t,  synth_axi_data_t, synth_axi_strb_t, synth_axi_user_t)
  `AXI_TYPEDEF_ALL(synth_axi_out, synth_axi_addr_t, synth_axi_out_id_t, synth_axi_data_t, synth_axi_strb_t, synth_axi_user_t)

  localparam SynthSafetyIslandBaseAddr = 48'h0000_6000_0000;
  localparam SynthSafetyIslandAddrRange = 32'h0080_0000;
  localparam SynthSafetyIslandMemOffset = 32'h0000_0000;
  localparam SynthSafetyIslandPeriphOffset = 32'h0020_0000;

  localparam SynthLogDepth = 3;

  localparam SynthAsyncAxiInAwWidth = (2**SynthLogDepth)*axi_pkg::aw_width(SynthAxiAddrWidth, SynthAxiInIdWidth, SynthAxiUserWidth);//$bits(synth_axi_in_aw_chan_t);
  localparam SynthAsyncAxiInWWidth  = (2**SynthLogDepth)*axi_pkg::w_width(SynthAxiDataWidth, SynthAxiUserWidth);//$bits(synth_axi_in_w_chan_t);
  localparam SynthAsyncAxiInBWidth  = (2**SynthLogDepth)*axi_pkg::b_width(SynthAxiInIdWidth, SynthAxiUserWidth);//$bits(synth_axi_in_b_chan_t);
  localparam SynthAsyncAxiInArWidth = (2**SynthLogDepth)*axi_pkg::ar_width(SynthAxiAddrWidth, SynthAxiInIdWidth, SynthAxiUserWidth);//$bits(synth_axi_in_ar_chan_t);
  localparam SynthAsyncAxiInRWidth  = (2**SynthLogDepth)*axi_pkg::r_width(SynthAxiDataWidth, SynthAxiInIdWidth, SynthAxiUserWidth);//$bits(synth_axi_in_r_chan_t);

  localparam SynthAsyncAxiOutAwWidth = (2**SynthLogDepth)*axi_pkg::aw_width(SynthAxiAddrWidth, SynthAxiOutIdWidth, SynthAxiUserWidth);//$bits(synth_axi_out_aw_chan_t);
  localparam SynthAsyncAxiOutWWidth  = (2**SynthLogDepth)*axi_pkg::w_width(SynthAxiDataWidth, SynthAxiUserWidth);//$bits(synth_axi_out_w_chan_t);
  localparam SynthAsyncAxiOutBWidth  = (2**SynthLogDepth)*axi_pkg::b_width(SynthAxiOutIdWidth, SynthAxiUserWidth);//$bits(synth_axi_out_b_chan_t);
  localparam SynthAsyncAxiOutArWidth = (2**SynthLogDepth)*axi_pkg::ar_width(SynthAxiAddrWidth, SynthAxiOutIdWidth, SynthAxiUserWidth);//$bits(synth_axi_out_ar_chan_t);
  localparam SynthAsyncAxiOutRWidth  = (2**SynthLogDepth)*axi_pkg::r_width(SynthAxiDataWidth, SynthAxiOutIdWidth, SynthAxiUserWidth);//$bits(synth_axi_out_r_chan_t);

  localparam SynthNumDebug           = 96;
  localparam SynthSelectableHarts    = 96'h0000_0003_0000_0FFF_0000_0000;
  localparam dm::hartinfo_t SynthDefaultHartInfo    = '{
    zero1: '0,
    nscratch: 2,
    zero0: '0,
    dataaccess: 1'b1,
    datasize: dm::DataCount,
    dataaddr: dm::DataAddr
  };
  localparam SynthHartInfo           = {SynthNumDebug{SynthDefaultHartInfo}};

endpackage
