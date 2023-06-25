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

  string       preload_elf;
  bit   [31:0] exit_code;
  bit          exit_status;

  initial begin : axi_boot_process

    if (!$value$plusargs("BINARY=%s",   preload_elf))   preload_elf   = "";

    fixt_safety_island.vip.set_safed_boot_mode(safety_island_pkg::Preloaded);
    fixt_safety_island.vip.safed_wait_for_reset();
    fixt_safety_island.vip.axi_safed_elf_run(preload_elf);
    fixt_safety_island.vip.axi_safed_wait_for_eoc(exit_code, exit_status);

    $finish;
  end  // block: axi_boot_process

endmodule
