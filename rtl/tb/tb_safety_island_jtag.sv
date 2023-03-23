// Copyright 2023 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

module tb_safety_island_jtag;

  fixture_safety_island fixt_safety_island();

  logic [31:0] entry_point;
  int exit_status;

  initial begin : jtag_boot_process
    fixt_safety_island.read_entry_point(entry_point);

    fixt_safety_island.apply_rstn();

    fixt_safety_island.jtag_reset();

    fixt_safety_island.jtag_smoke_tests(entry_point);

    fixt_safety_island.jtag_load_binary(entry_point);

    fixt_safety_island.jtag_resume_hart();

    fixt_safety_island.jtag_wait_for_eoc(exit_status);

    $stop;
  end // block: jtag_boot_process

endmodule
