// Copyright 2023 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

module tb_safety_island_preloaded;

  fixture_safety_island fixt_safety_island();

  logic [31:0] entry_point;
  int          exit_status;

  // pms boot driver process (AXI)
  initial begin : axi_boot_process

    // Init AXI driver
    fixt_safety_island.init_axi_driver();

    // Read entry point (different for pulp-runtime/freertos)
    fixt_safety_island.read_entry_point(entry_point);

    // Reset pms
    fixt_safety_island.apply_rstn();

    #5us;

    // Load binary into L2
    fixt_safety_island.axi_load_binary();

    // Select bootmode
    fixt_safety_island.axi_select_bootmode(32'h0000_0002);

    // Write entry point into boot address register
    fixt_safety_island.axi_write_entry_point(entry_point);

    // Assert fetch enable through CSRs
    fixt_safety_island.axi_write_fetch_enable();

    #500us;

    // Wait for EOC
    fixt_safety_island.axi_wait_for_eoc(exit_status);

    $stop;
  end  // block: axi_boot_process

endmodule
