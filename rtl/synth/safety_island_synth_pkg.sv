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

  localparam int unsigned SynthAxiAddrWidth = 48;
  typedef logic [SynthAxiAddrWidth-1:0] synth_axi_addr_t;
  localparam int unsigned SynthAxiDataWidth = 64;
  typedef logic [SynthAxiDataWidth-1:0] synth_axi_data_t;
  typedef logic [SynthAxiDataWidth/8-1:0] synth_axi_strb_t;
  localparam int unsigned SynthAxiUserWidth = 10;
  typedef logic [SynthAxiUserWidth-1:0] synth_axi_user_t;

  localparam int unsigned SynthAxiInIdWidth  = 5;
  typedef logic [SynthAxiInIdWidth-1:0] synth_axi_in_id_t;
  localparam int unsigned SynthAxiOutIdWidth = 2;
  typedef logic [SynthAxiOutIdWidth-1:0] synth_axi_out_id_t;
  localparam bit [SynthAxiUserWidth-1:0] SynthDefaultUser = 10'b0000000101;

  localparam bit          SynthAxiUserAtop      = 1'b1;
  localparam int unsigned SynthAxiUserAtopMsb   = 3;
  localparam int unsigned SynthAxiUserAtopLsb   = 0;
  localparam bit          SynthAxiUserEccErr    = 1'b1;
  localparam int unsigned SynthAxiUserEccErrBit = 4;

  `AXI_TYPEDEF_ALL(synth_axi_in,
                   synth_axi_addr_t,
                   synth_axi_in_id_t,
                   synth_axi_data_t,
                   synth_axi_strb_t,
                   synth_axi_user_t)
  `AXI_TYPEDEF_ALL(synth_axi_out,
                   synth_axi_addr_t,
                   synth_axi_out_id_t,
                   synth_axi_data_t,
                   synth_axi_strb_t,
                   synth_axi_user_t)

  localparam bit [SynthAxiAddrWidth-1:0] SynthSafetyIslandBaseAddr = 48'h0000_6000_0000;
  localparam bit [31:0] SynthSafetyIslandAddrRange = 32'h0080_0000;
  localparam bit [31:0] SynthSafetyIslandMemOffset = 32'h0000_0000;
  localparam bit [31:0] SynthSafetyIslandPeriphOffset = 32'h0020_0000;

  localparam int unsigned SynthLogDepth = 3;
  localparam int unsigned SynthCdcSyncStages = 2;

  localparam int unsigned SynthAsyncAxiInAwWidth = (2**SynthLogDepth)*
                                                   axi_pkg::aw_width(SynthAxiAddrWidth,
                                                                     SynthAxiInIdWidth,
                                                                     SynthAxiUserWidth);
  localparam int unsigned SynthAsyncAxiInWWidth  = (2**SynthLogDepth)*
                                                   axi_pkg::w_width(SynthAxiDataWidth,
                                                                    SynthAxiUserWidth);
  localparam int unsigned SynthAsyncAxiInBWidth  = (2**SynthLogDepth)*
                                                   axi_pkg::b_width(SynthAxiInIdWidth,
                                                                    SynthAxiUserWidth);
  localparam int unsigned SynthAsyncAxiInArWidth = (2**SynthLogDepth)*
                                                   axi_pkg::ar_width(SynthAxiAddrWidth,
                                                                     SynthAxiInIdWidth,
                                                                     SynthAxiUserWidth);
  localparam int unsigned SynthAsyncAxiInRWidth  = (2**SynthLogDepth)*
                                                   axi_pkg::r_width(SynthAxiDataWidth,
                                                                    SynthAxiInIdWidth,
                                                                    SynthAxiUserWidth);

  localparam int unsigned SynthAsyncAxiOutAwWidth = (2**SynthLogDepth)*
                                                    axi_pkg::aw_width(SynthAxiAddrWidth,
                                                                      SynthAxiOutIdWidth,
                                                                      SynthAxiUserWidth);
  localparam int unsigned SynthAsyncAxiOutWWidth  = (2**SynthLogDepth)*
                                                    axi_pkg::w_width(SynthAxiDataWidth,
                                                                     SynthAxiUserWidth);
  localparam int unsigned SynthAsyncAxiOutBWidth  = (2**SynthLogDepth)*
                                                    axi_pkg::b_width(SynthAxiOutIdWidth,
                                                                     SynthAxiUserWidth);
  localparam int unsigned SynthAsyncAxiOutArWidth = (2**SynthLogDepth)*
                                                    axi_pkg::ar_width(SynthAxiAddrWidth,
                                                                      SynthAxiOutIdWidth,
                                                                      SynthAxiUserWidth);
  localparam int unsigned SynthAsyncAxiOutRWidth  = (2**SynthLogDepth)*
                                                    axi_pkg::r_width(SynthAxiDataWidth,
                                                                     SynthAxiOutIdWidth,
                                                                     SynthAxiUserWidth);

  localparam int unsigned SynthNumDebug                   = 96;
  localparam bit [SynthNumDebug-1:0] SynthSelectableHarts = 96'h0000_0003_0000_0FFF_0000_0000;
  localparam dm::hartinfo_t SynthDefaultHartInfo          = '{
    zero1: '0,
    nscratch: 2,
    zero0: '0,
    dataaccess: 1'b1,
    datasize: dm::DataCount,
    dataaddr: dm::DataAddr
  };
  localparam dm::hartinfo_t [SynthNumDebug-1:0] SynthHartInfo =
    {SynthNumDebug{SynthDefaultHartInfo}};

endpackage
