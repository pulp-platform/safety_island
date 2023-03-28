// Copyright 2023 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

package safety_island_synth_pkg;
  import safety_island_pkg::*;

  localparam AxiAddrWidth = 48;
  typedef logic [AxiAddrWidth-1:0] axi_addr_t;
  localparam AxiDataWidth = 64;
  typedef logic [AxiDataWidth-1:0] axi_data_t;
  typedef logic [AxiDataWidth/8-1:0] axi_strb_t;
  localparam AxiUserWidth = 1;
  typedef logic [AxiUserWidth-1:0] axi_user_t;

  localparam AxiInIdWidth  = 5;
  typedef logic [AxiInIdWidth-1:0] axi_in_id_t;
  localparam AxiOutIdWidth = 2;
  typedef logic [AxiOutIdWidth-1:0] axi_out_id_t;

  `AXI_TYPEDEF_ALL(axi_in,  axi_addr_t, axi_in_id_t,  axi_data_t, axi_strb_t, axi_user_t)
  `AXI_TYPEDEF_ALL(axi_out, axi_addr_t, axi_out_id_t, axi_data_t, axi_strb_t, axi_user_t)

  localparam SafetyIslandBaseAddr = 48'h0000_6000_0000;
  localparam SafetyIslandAddrRange = 32'h0080_0000;
  localparam SafetyIslandMemOffset = 32'h0000_0000;
  localparam SafetyIslandPeriphOffset = 32'h0020_0000;

  localparam LogDepth = 3;

  localparam AsyncAxiInAwWidth = (2**LogDepth)*$bits(axi_in_aw_chan_t);
  localparam AsyncAxiInWWidth  = (2**LogDepth)*$bits(axi_in_w_chan_t);
  localparam AsyncAxiInBWidth  = (2**LogDepth)*$bits(axi_in_b_chan_t);
  localparam AsyncAxiInArWidth = (2**LogDepth)*$bits(axi_in_ar_chan_t);
  localparam AsyncAxiInRWidth  = (2**LogDepth)*$bits(axi_in_r_chan_t);

  localparam AsyncAxiOutAwWidth = (2**LogDepth)*$bits(axi_out_aw_chan_t);
  localparam AsyncAxiOutWWidth  = (2**LogDepth)*$bits(axi_out_w_chan_t);
  localparam AsyncAxiOutBWidth  = (2**LogDepth)*$bits(axi_out_b_chan_t);
  localparam AsyncAxiOutArWidth = (2**LogDepth)*$bits(axi_out_ar_chan_t);
  localparam AsyncAxiOutRWidth  = (2**LogDepth)*$bits(axi_out_r_chan_t);

endpackage