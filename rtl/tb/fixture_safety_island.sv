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
  import srec_pkg::*;

  // Safety Island Configs
  localparam GlobalAddrWidth = 32;
  localparam BaseAddr        = 32'h0000_0000;

  localparam AddrRange       = 32'h0080_0000;
  localparam MemOffset       = 32'h0000_0000;
  localparam PeriphOffset    = 32'h0020_0000;
  localparam BankNumBytes    = 32'h0001_0000;
  localparam NumInterrupts   = 256;

  localparam SocCtrlAddr    = BaseAddr + PeriphOffset;
  localparam BootAddrAddr   = SocCtrlAddr + safety_soc_ctrl_reg_pkg::SAFETY_SOC_CTRL_BOOTADDR_OFFSET;
  localparam FetchEnAddr    = SocCtrlAddr + safety_soc_ctrl_reg_pkg::SAFETY_SOC_CTRL_FETCHEN_OFFSET;
  localparam CoreStatusAddr = SocCtrlAddr + safety_soc_ctrl_reg_pkg::SAFETY_SOC_CTRL_CORESTATUS_OFFSET;

  // Global AXI Configs
  localparam int unsigned AxiDataWidth     = 64;
  localparam int unsigned AxiAddrWidth     = GlobalAddrWidth;
  localparam int unsigned AxiInputIdWidth  = 4;
  localparam int unsigned AxiUserWidth     = 1;
  localparam int unsigned AxiOutputIdWidth = 2;

  `AXI_TYPEDEF_ALL(axi_input,  logic[AxiAddrWidth-1:0], logic[AxiInputIdWidth-1:0],  logic[AxiDataWidth-1:0], logic[AxiDataWidth/8-1:0], logic[AxiUserWidth-1:0])
  `AXI_TYPEDEF_ALL(axi_output, logic[AxiAddrWidth-1:0], logic[AxiOutputIdWidth-1:0], logic[AxiDataWidth-1:0], logic[AxiDataWidth/8-1:0], logic[AxiUserWidth-1:0])

  // exit
  localparam int EXIT_SUCCESS = 0;
  localparam int EXIT_FAIL = 1;
  localparam int EXIT_ERROR = -1;

  int exit_status = EXIT_FAIL;  // per default we fail
  int stim_fd;
  int num_stim = 0;

  logic s_clk;
  logic s_rst_n = 1'b0;
  logic s_test_enable = 1'b0;

  logic s_tck = 1'b0;
  logic s_tdi = 1'b0;
  logic s_tdo;
  logic s_tms = 1'b0;
  logic s_trstn = 1'b1;

  // clock gen
  clk_rst_gen #(
    .ClkPeriod   ( 10ns ),
    .RstClkCycles(1)
  ) i_clk_gen (
    .clk_o (s_clk),
    .rst_no()
  );

  safety_island_top #(
    .HartId            ( 0                 ),
    .GlobalAddrWidth   ( GlobalAddrWidth   ),
    .BaseAddr          ( BaseAddr          ),
    .AddrRange         ( AddrRange         ),
    .MemOffset         ( MemOffset         ),
    .PeriphOffset      ( PeriphOffset      ),
    .BankNumBytes      ( BankNumBytes      ),
    .NumInterrupts     ( NumInterrupts     ),
    .PulpJtagIdCode    ( 32'h1_0000_db3    ), // TODO!
    .AxiDataWidth      ( AxiDataWidth      ),
    .AxiAddrWidth      ( AxiAddrWidth      ),
    .AxiInputIdWidth   ( AxiInputIdWidth   ),
    .AxiUserWidth      ( AxiUserWidth      ),
    .axi_input_req_t   ( axi_input_req_t   ),
    .axi_input_resp_t  ( axi_input_resp_t  ),
    .AxiOutputIdWidth  ( AxiOutputIdWidth  ),
    .axi_output_req_t  ( axi_output_req_t  ),
    .axi_output_resp_t ( axi_output_resp_t )
  ) i_dut (
    .clk_i             ( s_clk                   ),
    .rst_ni            ( s_rst_n                 ),
    .test_enable_i     ( s_test_enable           ),

    .jtag_tck_i        ( s_tck                   ),
    .jtag_tdi_i        ( s_tdi                   ),
    .jtag_tdo_o        ( s_tdo                   ),
    .jtag_tms_i        ( s_tms                   ),
    .jtag_trst_i       ( s_trstn                 ),

    .bootmode_i        ( safety_island_pkg::Jtag ),

    .axi_input_req_i   ( '0 ),
    .axi_input_resp_o  (  ),
    .axi_output_req_o  (  ),
    .axi_output_resp_i ( '0 )
  );

  // ----------------
  // Tasks
  // ----------------

  // Read entry point from commandline
  task read_entry_point(output logic [31:0] begin_l2_instr);
    int entry_point;
    if ($value$plusargs("ENTRY_POINT=%h", entry_point)) begin_l2_instr = entry_point;
    else begin_l2_instr = BaseAddr[31:0]+MemOffset;
    $display("[TB  ] %t - Entry point is set to 0x%h", $realtime, begin_l2_instr);
  endtask  // read_entry_point
  

  // Apply reset
  task apply_rstn;
    $display("[TB  ] %t - Asserting hard reset", $realtime);
    s_rst_n = 1'b0;
    #1us
    // Release reset
    $display("[TB  ] %t - Releasing hard reset", $realtime);
    s_rst_n = 1'b1;
  endtask

  //
  // JTAG for riscv-dbg tap and pulp tap
  //

  jtag_pkg::test_mode_if_t test_mode_if = new;
  jtag_pkg::debug_mode_if_t debug_mode_if = new;
  // pulp_tap_pkg::pulp_tap_if_soc_t pulp_tap = new;

  task jtag_reset();
    jtag_pkg::jtag_reset(s_tck, s_tms, s_trstn, s_tdi);
    jtag_pkg::jtag_softreset(s_tck, s_tms, s_trstn, s_tdi);
    #5us;
  endtask // jtag_reset

  task jtag_smoke_tests(logic [31:0] scratch_mem);
    automatic logic [255:0][31:0] jtag_data;

    jtag_pkg::jtag_bypass_test(s_tck, s_tms, s_trstn, s_tdi, s_tdo);
    #5us;

    jtag_pkg::jtag_get_idcode(s_tck, s_tms, s_trstn, s_tdi, s_tdo);
    #5us;

    debug_mode_if.init_dmi_access(s_tck, s_tms, s_trstn, s_tdi);
    debug_mode_if.set_dmactive(1'b1,  s_tck, s_tms, s_trstn, s_tdi, s_tdo);

    debug_mode_if.writeMem(scratch_mem, 32'hABBAABBA, s_tck, s_tms, s_trstn, s_tdi, s_tdo);

    $display("[TB  ] %t = Write32 JTAG", $realtime);

    #5us
    debug_mode_if.set_sbreadonaddr(1'b1, s_tck, s_tms, s_trstn, s_tdi, s_tdo);
    debug_mode_if.readMem(scratch_mem, jtag_data[0], s_tck, s_tms, s_trstn, s_tdi, s_tdo);

    if (jtag_data[0] != 32'hABBAABBA)
      $display("[JTAG] %t - R/W test of L2 failed: %h != %h", $realtime, jtag_data[0], 32'hABBAABBA);
    else $display("[JTAG] %t - R/W test of L2 succeeded", $realtime);
  endtask // jtag_selftests

  task jtag_load_binary(input logic [31:0] entrypoint);
    automatic string stim_path, srec_path;
    automatic logic [95:0] stimuli[$];

    automatic string jtag_boot_conf;
    automatic string jtag_tap_type;
    automatic logic [255:0][31:0] jtag_data;

    automatic srec_record_t records[$];
    automatic logic [31:0] srec_entrypoint;

    // Check if stimuli exist
    if ($value$plusargs("stimuli=%s", stim_path)) begin
      $display("[TB  ] %t - Loading custom stimuli from %s", $realtime, stim_path);
      load_stim(stim_path, stimuli);
    end else if ($value$plusargs("srec=%s", srec_path)) begin
      $display("[TB  ] %t - Loading srec from %s", $realtime, srec_path);
      srec_read(srec_path, records);
      srec_records_to_stimuli(records, stimuli, srec_entrypoint);
      if (!$test$plusargs("srec_ignore_entry"))
        entrypoint = srec_entrypoint;
    end else begin
      $display("[TB  ] %t - Loading default stimuli from ./vectors/stim.txt", $realtime);
      load_stim("./vectors/stim.txt", stimuli);
    end

    // From here on starts the actual jtag booting

    // We need our core the fetching and running from the bootrom.
    debug_mode_if.init_dmi_access(s_tck, s_tms, s_trstn, s_tdi);
    debug_mode_if.set_dmactive(1'b1,  s_tck, s_tms, s_trstn, s_tdi, s_tdo);
    debug_mode_if.writeMem(BootAddrAddr, 32'h1A00_0000, s_tck, s_tms, s_trstn, s_tdi, s_tdo);
    debug_mode_if.writeMem(FetchEnAddr, 32'h0000_0001, s_tck, s_tms, s_trstn, s_tdi, s_tdo);

    // Setup debug module and hart, halt hart and set dpc (return point
    // for boot).
    // Halting the fc hart transfers control of the program execution to
    // the debug module. This might take a bit until the debug request
    // signal is propagated so meanwhile the core is executing stuff
    // from the bootrom. For jtag booting (what we are doing right now),
    // bootsel is low so the code that is being executed in said bootrom
    // is only a busy wait or wfi until the debug unit grabs control.
    debug_mode_if.init_dmi_access(s_tck, s_tms, s_trstn, s_tdi);

    debug_mode_if.set_dmactive(1'b1, s_tck, s_tms, s_trstn, s_tdi, s_tdo);

    debug_mode_if.set_hartsel('0, s_tck, s_tms, s_trstn, s_tdi, s_tdo);

    $display("[TB  ] %t - Halting the Core", $realtime);
    debug_mode_if.halt_harts(s_tck, s_tms, s_trstn, s_tdi, s_tdo);

    $display("[TB  ] %t - Writing the boot address into dpc", $realtime);
    debug_mode_if.write_reg_abstract_cmd(riscv::CSR_DPC, entrypoint + 32'h80, s_tck, s_tms, s_trstn,
                                         s_tdi, s_tdo);

    $display("[TB  ] %t - Loading L2", $realtime);

    // use debug module to load binary
    debug_mode_if.load_L2(num_stim, stimuli, s_tck, s_tms, s_trstn, s_tdi, s_tdo);

    //write bootaddress
    #10us;
    $display("[TB  ] %t - Write boot address into reset vector: 0x%h @ 0x%h",
             $realtime, entrypoint, BootAddrAddr);
    debug_mode_if.writeMem(BootAddrAddr, entrypoint, s_tck, s_tms, s_trstn, s_tdi, s_tdo);
    #10us;

  endtask // jtag_load_binary

  // if we were debugging we have to hand back to control to the hart to resume
  // execution
  task jtag_resume_hart();
    // configure for debug module dmi access again
    debug_mode_if.init_dmi_access(s_tck, s_tms, s_trstn, s_tdi);

    // we have set dpc and loaded the binary, we can go now
    $display("[TB  ] %t - Resuming the CORE", $realtime);
    debug_mode_if.resume_harts(s_tck, s_tms, s_trstn, s_tdi, s_tdo);
  endtask // jtag_resume_hart

  task jtag_wait_for_eoc(output int exit_status);
    automatic logic [255:0][31:0] jtag_data;
    automatic int read_count;

    // enable sb access for subsequent readMem calls
    debug_mode_if.set_sbreadonaddr(1'b1, s_tck, s_tms, s_trstn, s_tdi, s_tdo);

    // wait for end of computation signal
    $display("[TB  ] %t - Waiting for end of computation", $realtime);

    jtag_data[0] = 0;
    while (jtag_data[0][31] == 0) begin
      // every 10th loop iteration, clear the debug module's SBA unit CSR to make
      // sure there's no error blocking our reads. Sometimes a TCDM read
      // request issued by the debug module takes longer than it takes
      // for the read request to the debug module to arrive and it
      // stores an error in the SBCS register. By clearing it
      // periodically we make sure the test can terminate.
      // This is obviously a bit hacky
      if (read_count % 10 == 0) begin
        debug_mode_if.clear_sbcserrors(s_tck, s_tms, s_trstn, s_tdi, s_tdo);
      end
      debug_mode_if.readMem(CoreStatusAddr, jtag_data[0], s_tck, s_tms,
                            s_trstn, s_tdi, s_tdo);
      read_count++;
      #50us;
    end

    if (jtag_data[0][30:0] == 0) exit_status = EXIT_SUCCESS;
    else exit_status = EXIT_FAIL;
    $display("[TB  ] %t - Exit status: %d, Received status core: 0x%h", $realtime, exit_status, jtag_data[0][30:0]);
  endtask // jtag_wait_for_eoc

  task jtag_dm_tests(input logic [31:0] entrypoint);
    automatic string jtag_boot_conf;
    automatic logic error;
    automatic int num_err;

    error   = 1'b0;
    num_err = 0;

    // We need our core the fetching and running from the bootrom. 
    debug_mode_if.init_dmi_access(s_tck, s_tms, s_trstn, s_tdi);
    debug_mode_if.set_dmactive(1'b1,  s_tck, s_tms, s_trstn, s_tdi, s_tdo);
    debug_mode_if.writeMem(BootAddrAddr, 32'h1A00_0000, s_tck, s_tms, s_trstn, s_tdi, s_tdo);
    debug_mode_if.writeMem(FetchEnAddr, 32'h0000_0001, s_tck, s_tms, s_trstn, s_tdi, s_tdo);

    // Setup debug module and hart, halt hart and set dpc (return point
    // for boot).
    // Halting the fc hart transfers control of the program execution to
    // the debug module. This might take a bit until the debug request
    // signal is propagated so meanwhile the core is executing stuff
    // from the bootrom. For jtag booting (what we are doing right now),
    // bootsel is low so the code that is being executed in said bootrom
    // is only a busy wait or wfi until the debug unit grabs control.
    debug_mode_if.init_dmi_access(s_tck, s_tms, s_trstn, s_tdi);

    debug_mode_if.set_dmactive(1'b1, s_tck, s_tms, s_trstn, s_tdi, s_tdo);

    debug_mode_if.set_hartsel('0, s_tck, s_tms, s_trstn, s_tdi, s_tdo);

    $display("[TB  ] %t - Halting the Core", $realtime);
    debug_mode_if.halt_harts(s_tck, s_tms, s_trstn, s_tdi, s_tdo);

    $display("[TB  ] %t - Writing the boot address into dpc", $realtime);
    debug_mode_if.write_reg_abstract_cmd(riscv::CSR_DPC, entrypoint, s_tck, s_tms, s_trstn,
                                         s_tdi, s_tdo);

    debug_mode_if.run_dm_tests('0, entrypoint, error, num_err, s_tck, s_tms,
                              s_trstn, s_tdi, s_tdo);
    // we don't have any program to load so we finish the testing
    if (num_err == 0) begin
      exit_status = EXIT_SUCCESS;
    end else begin
      exit_status = EXIT_FAIL;
      $error("Debug Module: %d tests failed", num_err);
    end

    $stop;
  endtask // jtag_dm_tests

  //
  // Load stim task
  //

  task load_stim(input string stim, output logic [95:0] stimuli[$]);
    int ret;
    logic [95:0] rdata;
    stim_fd = $fopen(stim, "r");

    if (stim_fd == 0)
      $fatal(1, "Could not open stimuli file!");

    while (!$feof(stim_fd)) begin
      ret = $fscanf(stim_fd, "%h\n", rdata);
      stimuli.push_back(rdata);
    end

    $fclose(stim_fd);
  endtask  // load_stim

endmodule
