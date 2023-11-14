// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Alessandro Ottaviano <aottaviano@iis.ee.ethz.ch>

// Collects all existing verification IP (VIP) in one module for use in testbenches of
// Safety Island-based SoCs and Chips. IOs are of inout direction where applicable.

module vip_safety_island_soc import safety_island_pkg::*; #(
  // DUT
  parameter safety_island_cfg_t DutCfg      = '0,
  parameter type          axi_mst_ext_req_t = logic,
  parameter type          axi_mst_ext_rsp_t = logic,
  parameter type          axi_slv_ext_req_t = logic,
  parameter type          axi_slv_ext_rsp_t = logic,
  parameter  int unsigned GlobalAddrWidth   = 32,
  parameter  bit [GlobalAddrWidth-1:0] BaseAddr = 32'h0000_0000,
  parameter  bit [31:0]   AddrRange         = 32'h0080_0000,
  parameter  bit [31:0]   MemOffset         = 32'h0000_0000,
  parameter  bit [31:0]   PeriphOffset      = 32'h0020_0000,
  // Timing
  parameter time          ClkPeriodSys      = 5ns,
  parameter time          ClkPeriodExt      = 2ns,
  parameter time          ClkPeriodJtag     = 20ns,
  parameter time          ClkPeriodRtc      = 30518ns,
  parameter int unsigned  RstCycles         = 5,
  parameter int unsigned  AxiDataWidth      = 64,
  parameter int unsigned  AxiAddrWidth      = 32,
  parameter int unsigned  AxiInputIdWidth   = 4,
  parameter int unsigned  AxiOutputIdWidth  = 2,
  parameter int unsigned  AxiUserWidth      = 1,
  parameter bit           AxiDebug          = 0,
  parameter int unsigned  AxiBurstBytes     = 512,
  parameter real          ApplFrac          = 0.1,
  parameter real          TestFrac          = 0.9,
  // Derived Parameters;  *do not override*
  localparam int unsigned  AxiStrbWidth      = AxiDataWidth/8,
  localparam int unsigned  AxiStrbBits       = $clog2(AxiDataWidth/8)
) (
  output logic       clk_vip,
  output logic       ext_clk_vip,
  output logic       rst_n_vip,
  output logic       test_mode,
  output logic [1:0] boot_mode,
  output logic       rtc,
  // External AXI master port
  input  axi_mst_ext_req_t axi_mst_req,
  output axi_mst_ext_rsp_t axi_mst_rsp,
  // External AXI slave port
  output  axi_slv_ext_req_t axi_slv_req,
  input   axi_slv_ext_rsp_t axi_slv_rsp,
  // JTAG interface
  output logic jtag_tck,
  output logic jtag_trst_n,
  output logic jtag_tms,
  output logic jtag_tdi,
  input  logic jtag_tdo,
  // Exit
  output bit exit_status
);

  `include "axi/typedef.svh"
  `include "axi/assign.svh"

  localparam SocCtrlAddr    = BaseAddr + PeriphOffset + SocCtrlAddrOffset;
  localparam BootAddrAddr   = SocCtrlAddr + safety_soc_ctrl_reg_pkg::SAFETY_SOC_CTRL_BOOTADDR_OFFSET;
  localparam FetchEnAddr    = SocCtrlAddr + safety_soc_ctrl_reg_pkg::SAFETY_SOC_CTRL_FETCHEN_OFFSET;
  localparam CoreStatusAddr = SocCtrlAddr + safety_soc_ctrl_reg_pkg::SAFETY_SOC_CTRL_CORESTATUS_OFFSET;
  localparam BootModeAddr   = SocCtrlAddr + safety_soc_ctrl_reg_pkg::SAFETY_SOC_CTRL_BOOTMODE_OFFSET;

  typedef logic [AxiAddrWidth-1:0] addr_t;
  typedef logic [AxiDataWidth-1:0] axi_data_t;

  // Bit vector types for parameters.
  // We limit range to keep parameters sane.
  typedef bit [ 7:0] byte_bt;
  typedef bit [15:0] shrt_bt;
  typedef bit [31:0] word_bt;
  typedef bit [63:0] doub_bt;

  logic  clk, ext_clk, rst_n;
  assign clk_vip = clk;
  assign ext_clk_vip = ext_clk;
  assign rst_n_vip = rst_n;

  ///////////
  //  DPI  //
  ///////////

  import "DPI-C" function byte read_elf(input string filename);
  import "DPI-C" function byte get_entry(output longint entry);
  import "DPI-C" function byte get_section(output longint address, output longint len);
  import "DPI-C" context function byte read_section(input longint address, inout byte buffer[], input longint len);

  //////////////////////////////
  // AXI external master port //
  //////////////////////////////

  axi_mst_ext_req_t filtered_to_ext_req;
  axi_mst_ext_rsp_t filtered_to_ext_rsp;

  axi_riscv_atomics_structs #(
    .AxiAddrWidth   ( AxiAddrWidth      ),
    .AxiDataWidth   ( AxiDataWidth      ),
    .AxiIdWidth     ( AxiOutputIdWidth  ),
    .AxiUserWidth   ( AxiUserWidth      ),
    .AxiMaxReadTxns ( 2                 ),
    .AxiMaxWriteTxns( 2                 ),
    .AxiUserAsId    ( 1 ),
    .AxiUserIdMsb   ( AxiUserWidth-1 ),
    .AxiUserIdLsb   ( 0 ),
    .RiscvWordWidth ( 32                ),
    .NAxiCuts       ( 1                 ),
    .axi_req_t      ( axi_mst_ext_req_t ),
    .axi_rsp_t      ( axi_mst_ext_rsp_t )
  ) i_axi_atomics (
    .clk_i         ( ext_clk              ),
    .rst_ni        ( rst_n                ),
    .axi_slv_req_i ( axi_mst_req          ),
    .axi_slv_rsp_o ( axi_mst_rsp          ),
    .axi_mst_req_o ( filtered_to_ext_req  ),
    .axi_mst_rsp_i ( filtered_to_ext_rsp  )
  );

  axi_sim_mem #(
    .AddrWidth         ( AxiAddrWidth          ),
    .DataWidth         ( AxiDataWidth          ),
    .IdWidth           ( AxiOutputIdWidth      ),
    .UserWidth         ( AxiUserWidth          ),
    .axi_req_t         ( axi_mst_ext_req_t     ),
    .axi_rsp_t         ( axi_mst_ext_rsp_t     ),
    .WarnUninitialized ( 1'b0                  ),
    .ClearErrOnAccess  ( 1'b0                  ),
    .ApplDelay         ( ClkPeriodExt * ApplFrac ),
    .AcqDelay          ( ClkPeriodExt * TestFrac )
  ) i_ext_mem (
    .clk_i              ( ext_clk   ),
    .rst_ni             ( rst_n     ),
    .axi_req_i          ( filtered_to_ext_req ),
    .axi_rsp_o          ( filtered_to_ext_rsp ),
    .mon_w_valid_o      (),
    .mon_w_addr_o       (),
    .mon_w_data_o       (),
    .mon_w_id_o         (),
    .mon_w_user_o       (),
    .mon_w_beat_count_o (),
    .mon_w_last_o       (),
    .mon_r_valid_o      (),
    .mon_r_addr_o       (),
    .mon_r_data_o       (),
    .mon_r_id_o         (),
    .mon_r_user_o       (),
    .mon_r_beat_count_o (),
    .mon_r_last_o       ()
  );

  ///////////////////////////////
  //  SoC Clock, Reset, Modes  //
  ///////////////////////////////

  clk_rst_gen #(
    .ClkPeriod    ( ClkPeriodSys ),
    .RstClkCycles ( RstCycles )
  ) i_clk_rst_sys (
    .clk_o  ( clk   ),
    .rst_no ( rst_n )
  );

  clk_rst_gen #(
    .ClkPeriod    ( ClkPeriodExt ),
    .RstClkCycles ( RstCycles )
  ) i_clk_rst_ext (
    .clk_o  ( ext_clk ),
    .rst_no ( )
  );

  clk_rst_gen #(
    .ClkPeriod    ( ClkPeriodRtc ),
    .RstClkCycles ( RstCycles )
  ) i_clk_rst_rtc (
    .clk_o  ( rtc ),
    .rst_no ( )
  );

  initial begin
    test_mode = '0;
    boot_mode = '0;
  end

  task safed_wait_for_reset;
    @(posedge rst_n);
    @(posedge clk);
  endtask

  task set_safed_test_mode(input logic mode);
    test_mode = mode;
  endtask

  task set_safed_boot_mode(input logic [1:0] mode);
    boot_mode = mode;
  endtask

  ////////////
  //  JTAG  //
  ////////////

  localparam dm::sbcs_t JtagInitSbcs = dm::sbcs_t'{
      sbautoincrement: 1'b1, sbreadondata: 1'b1, sbaccess: 2, default: '0};

  // Generate clock
  clk_rst_gen #(
    .ClkPeriod    ( ClkPeriodJtag ),
    .RstClkCycles ( RstCycles )
  ) i_clk_jtag (
    .clk_o  ( jtag_tck ),
    .rst_no ( )
  );

  // Define test bus and driver
  JTAG_DV jtag(jtag_tck);

  typedef jtag_test::riscv_dbg #(
    .IrLength ( 5 ),
    .TA       ( ClkPeriodJtag * ApplFrac ),
    .TT       ( ClkPeriodJtag * TestFrac )
  ) riscv_dbg_t;

  riscv_dbg_t::jtag_driver_t  jtag_dv   = new (jtag);
  riscv_dbg_t                 jtag_dbg  = new (jtag_dv);

  // Connect DUT to test bus
  assign jtag_trst_n  = jtag.trst_n;
  assign jtag_tms     = jtag.tms;
  assign jtag_tdi     = jtag.tdi;
  assign jtag.tdo     = jtag_tdo;

  initial begin
    @(negedge rst_n);
    jtag_dbg.reset_master();
  end

  task automatic jtag_safed_write(
    input dm::dm_csr_e addr,
    input word_bt data,
    input bit wait_cmd = 0,
    input bit wait_sba = 0
  );
    jtag_dbg.write_dmi(addr, data);
    if (wait_cmd) begin
      dm::abstractcs_t acs;
      do begin
        jtag_dbg.read_dmi_exp_backoff(dm::AbstractCS, acs);
        if (acs.cmderr) $fatal(1, "[JTAG] Abstract command error!");
      end while (acs.busy);
    end
    if (wait_sba) begin
      dm::sbcs_t sbcs;
      do begin
        jtag_dbg.read_dmi_exp_backoff(dm::SBCS, sbcs);
        if (sbcs.sberror | sbcs.sbbusyerror) $fatal(1, "[JTAG] System bus error!");
      end while (sbcs.sbbusy);
    end
  endtask

  task automatic jtag_safed_poll_bit31(
    input word_bt addr,
    output word_bt data,
    input int unsigned idle_cycles
  );
    automatic dm::sbcs_t sbcs = dm::sbcs_t'{sbreadonaddr: 1'b1, sbaccess: 2, default: '0};
    jtag_safed_write(dm::SBCS, sbcs, 0, 1);
    // jtag_safed_write(dm::SBAddress1, addr[63:32]);
    do begin
      jtag_safed_write(dm::SBAddress0, addr[31:0]);
      jtag_dbg.wait_idle(idle_cycles);
      jtag_dbg.read_dmi_exp_backoff(dm::SBData0, data);
    end while (~data[31]);
  endtask

  // Initialize the debug module
  task automatic jtag_safed_init;
    logic [31:0] idcode;
    dm::dmcontrol_t dmcontrol = '{dmactive: 1, default: '0};
    // Check ID code
    repeat(100) @(posedge jtag_tck);
    jtag_dbg.get_idcode(idcode);
    if (idcode != DutCfg.PulpJtagIdCode)
        $fatal(1, "[JTAG] %t - Unexpected ID code: expected 0x%h, got 0x%h!", $realtime, DutCfg.PulpJtagIdCode, idcode);
    // Activate, wait for debug module
    jtag_safed_write(dm::DMControl, dmcontrol);
    do jtag_dbg.read_dmi_exp_backoff(dm::DMControl, dmcontrol);
    while (~dmcontrol.dmactive);
    // Activate, wait for system bus
    jtag_safed_write(dm::SBCS, JtagInitSbcs, 0, 1);
    $display("[JTAG] %t - Initialization success", $realtime);
  endtask

  // Test read and write to memory
  task automatic jtag_write_test(
    input word_bt addr,
    input word_bt data_i
  );
    automatic logic [31:0] data_out;
    automatic dm::sbcs_t sbcs;

    sbcs = dm::sbcs_t'{sbreadonaddr: 1'b1, sbaccess: 2, default: '0};
    jtag_safed_write(dm::SBCS, sbcs, 1, 1);

    // write data_i
    jtag_safed_write(dm::SBAddress0, addr);
    jtag_safed_write(dm::SBData0, data_i);

    // wait
    #5us;

    // read to data_out
    sbcs = dm::sbcs_t'{sbreadonaddr: 1'b1, sbaccess: 2, default: '0};
    jtag_safed_write(dm::SBCS, sbcs, 0, 1);
    jtag_safed_write(dm::SBAddress0, addr[31:0]);
    jtag_dbg.read_dmi_exp_backoff(dm::SBData0, data_out);

    if (data_out != data_i)

      $display("[JTAG] %t - R/W test of L2 failed: %h != %h", $realtime, data_out, data_i);

    else $display("[JTAG] %t - R/W test of L2 succeeded", $realtime);

  endtask

  // Load a binary
  task automatic jtag_safed_elf_preload(input string binary, output word_bt entry);
    longint sec_addr, sec_len;
    $display("[JTAG] %t - Preloading ELF binary: %s", $realtime, binary);
    if (read_elf(binary))
      $fatal(1, "[JTAG] Failed to load ELF!");
    while (get_section(sec_addr, sec_len)) begin
      byte bf[] = new [sec_len];
      $display("[JTAG] %t - Preloading section at 0x%h (%0d bytes)", $realtime, sec_addr, sec_len);
      if (read_section(sec_addr, bf, sec_len)) $fatal(1, "[JTAG] Failed to read ELF section!");
      jtag_safed_write(dm::SBCS, JtagInitSbcs, 1, 1);
      // Write address as 32-bit word
      jtag_safed_write(dm::SBAddress0, sec_addr[31:0]);
      for (longint i = 0; i <= sec_len ; i += 4) begin
        bit checkpoint = (i != 0 && i % 512 == 0);
        if (checkpoint)
          $display("[JTAG] %t - %0d/%0d bytes (%0d%%)", $realtime, i, sec_len, i*100/(sec_len>1 ? sec_len-1 : 1));
        jtag_safed_write(dm::SBData0, {bf[i+3], bf[i+2], bf[i+1], bf[i]}, checkpoint, checkpoint);
      end
    end
    void'(get_entry(entry));
    $display("[JTAG] %t - Preload complete", $realtime);
  endtask

  // Run a binary
  task automatic jtag_safed_elf_run(input string binary);
    dm::dmstatus_t status;
    word_bt entry;
    // Halt hart
    jtag_safed_write(dm::DMControl, dm::dmcontrol_t'{haltreq: 1, hartsello: DutCfg.HartId[9:0], hartselhi: DutCfg.HartId[19:10], dmactive: 1, default: '0});
    do jtag_dbg.read_dmi_exp_backoff(dm::DMStatus, status);
    while (~status.allhalted);
    $display("[JTAG] %t - Halted hart %d", $realtime, DutCfg.HartId);
    // Preload binary
    jtag_safed_elf_preload(binary, entry);
    // Write entry point
    // jtag_safed_write(dm::Data1, entry[63:32]);
    jtag_safed_write(dm::Data0, entry[31:0]);
    jtag_safed_write(dm::Command, {8'h0, 1'b0, 3'd2, 1'b0, 1'b0, 1'b1, 1'b1, 4'h0, riscv_pkg::CSR_DPC}, 0, 1);//32'h0033_07b1, 0, 1);
    // Resume hart
    jtag_safed_write(dm::DMControl, dm::dmcontrol_t'{resumereq: 1, hartsello: DutCfg.HartId[9:0], hartselhi: DutCfg.HartId[19:10], dmactive: 1, default: '0});
    $display("[JTAG] %t - Resumed hart %d from 0x%h", $realtime, DutCfg.HartId, entry);
  endtask

  // Wait for termination signal and get return code
  task automatic jtag_safed_wait_for_eoc(output word_bt exit_code, output bit ext_status);
    jtag_safed_poll_bit31(CoreStatusAddr, exit_code, 800);
    exit_status = exit_code[31];
    if (exit_code[30:0]) $error("[JTAG] %t - FAILED: return code %0d", $realtime, exit_code[30:0]);
    else $display("[JTAG] %t - SUCCESS", $realtime);
  endtask

  /////////
  // AXI //
  /////////

  AXI_BUS_DV #(
    .AXI_ADDR_WIDTH ( AxiAddrWidth    ),
    .AXI_DATA_WIDTH ( AxiDataWidth    ),
    .AXI_ID_WIDTH   ( AxiInputIdWidth ),
    .AXI_USER_WIDTH ( AxiUserWidth    )
  ) ext_driver (
    .clk_i  ( clk )
  );

  `AXI_ASSIGN_TO_REQ(axi_slv_req, ext_driver)
  `AXI_ASSIGN_FROM_RESP(ext_driver, axi_slv_rsp)

  // We use an AXI driver to inject serial link transfers
  typedef axi_test::axi_driver #(
    .AW ( AxiAddrWidth         ),
    .DW ( AxiDataWidth         ),
    .IW ( AxiInputIdWidth      ),
    .UW ( AxiUserWidth         ),
    .TA ( ClkPeriodSys * ApplFrac ),
    .TT ( ClkPeriodSys * TestFrac )
  ) axi_ext_driver_t;

  axi_ext_driver_t axi_ext_driver = new (ext_driver);

  initial begin
    @(negedge rst_n);
    axi_ext_driver.reset_master();
  end

  task automatic axi_write_beats(
    input addr_t          addr,
    input axi_pkg::size_t size,
    ref axi_data_t        beats [$]
  );
    axi_ext_driver_t::ax_beat_t ax = new();
    axi_ext_driver_t::w_beat_t w = new();
    axi_ext_driver_t::b_beat_t b;
    int i = 0;
    int size_bytes = (1 << size);
    if (beats.size() == 0)
      $fatal(1, "[AXI] Zero-length write requested!");
    @(posedge clk);
    if (AxiDebug) $display("[AXI] Write to address: %h, len: %0d", addr, beats.size()-1);
    ax.ax_addr  = addr;
    ax.ax_id    = '0;
    ax.ax_len   = beats.size() - 1;
    ax.ax_size  = size;
    ax.ax_burst = axi_pkg::BURST_INCR;
    if (AxiDebug) $display("[AXI] - Sending AW ");
    axi_ext_driver.send_aw(ax);
    do begin
      w.w_strb = i == 0 ? (~('1 << size_bytes)) << addr[AxiStrbBits-1:0] : '1;
      w.w_data = beats[i];
      w.w_last = (i == ax.ax_len);
      if (AxiDebug) $display("[AXI] - Sending W (%0d)", i);
      axi_ext_driver.send_w(w);
      addr += size_bytes;
      addr &= size_bytes - 1;
      i++;
    end while (i <= ax.ax_len);
    if (AxiDebug) $display("[AXI] - Receiving B");
    axi_ext_driver.recv_b(b);
    if (b.b_resp != axi_pkg::RESP_OKAY)
      $error("[AXI] - Write error response: %d!", b.b_resp);
    if (AxiDebug) $display("[AXI] - Done");
  endtask

  task automatic axi_read_beats(
    input addr_t          addr,
    input axi_pkg::size_t size,
    input axi_pkg::len_t  len,
    ref axi_data_t        beats [$]
  );
    axi_ext_driver_t::ax_beat_t ax = new();
    axi_ext_driver_t::r_beat_t r;
    int i = 0;
    @(posedge clk)
    if (AxiDebug) $display("[AXI] Read from address: %h, len: %0d", addr, len);
    ax.ax_addr  = addr;
    ax.ax_id    = '0;
    ax.ax_len   = len;
    ax.ax_size  = size;
    ax.ax_burst = axi_pkg::BURST_INCR;
    if (AxiDebug) $display("[AXI] - Sending AR");
    axi_ext_driver.send_ar(ax);
    do begin
      if (AxiDebug) $display("[AXI] - Receiving R (%0d)", i);
      axi_ext_driver.recv_r(r);
      beats.push_back(r.r_data);
      addr += (1 << size);
      addr &= (1 << size) - 1;
      i++;
      if (r.r_resp != axi_pkg::RESP_OKAY)
        $error("[AXI] - Read error response: %d!", r.r_resp);
    end while (!r.r_last);
    if (AxiDebug) $display("[AXI] - Done");
  endtask

  task automatic axi_write_32(input addr_t addr, input word_bt data);
    axi_data_t beats [$];
    beats.push_back(data << (8 * addr[AxiStrbBits-1:0]));
    axi_write_beats(addr, 2, beats);
  endtask

  task automatic axi_poll_bit31(
    input doub_bt addr,
    output word_bt data,
    input int unsigned idle_cycles
  );
    do begin
        axi_data_t beats [$];
        #(ClkPeriodSys * idle_cycles);
        axi_read_beats(addr, 2, 0, beats);
        data = beats[0] >> addr[AxiStrbBits-1:0];
    end while (~data[31]);
  endtask

  // Load a binary
  task automatic axi_elf_preload(input string binary, output word_bt entry);
    longint sec_addr, sec_len, bus_offset, write_addr;
    $display("[AXI] Preloading ELF binary: %s", binary);
    if (read_elf(binary))
      $fatal(1, "[AXI] Failed to load ELF!");
    while (get_section(sec_addr, sec_len)) begin
      byte bf[] = new [sec_len];
      $display("[AXI] Preloading section at 0x%h (%0d bytes)", sec_addr, sec_len);
      if (read_section(sec_addr, bf, sec_len)) $fatal(1, "[AXI] Failed to read ELF section!");
      // Write section as fixed-size bursts
      bus_offset = sec_addr[AxiStrbBits-1:0];
      for (longint i = 0; i <= sec_len ; i += AxiBurstBytes) begin
        axi_data_t beats [$];
        if (i != 0)
          $display("[AXI] - %0d/%0d bytes (%0d%%)", i, sec_len, i*100/(sec_len>1 ? sec_len-1 : 1));
        // Assemble beats for current burst from section buffer
        for (int b = 0; b < AxiBurstBytes; b += AxiStrbWidth) begin
          axi_data_t beat;
          // We handle incomplete bursts
          if (i+b-bus_offset >= sec_len) break;
          for (int e = 0; e < AxiStrbWidth; ++e)
            if (i+b+e < bus_offset) begin
              beat[8*e +: 8] = '0;
            end else if (i+b+e-bus_offset >= sec_len) begin
              beat[8*e +: 8] = '0;
            end else begin
              beat[8*e +: 8] = bf [i+b+e-bus_offset];
            end
          beats.push_back(beat);
        end
        write_addr = sec_addr + (i==0 ? 0 : i - sec_addr%AxiStrbWidth);
        // Write this burst
        axi_write_beats(write_addr, AxiStrbBits, beats);
      end
    end
    void'(get_entry(entry));
    $display("[AXI] Preload complete");
  endtask

  // Run a binary
  task automatic axi_safed_elf_run(input string binary);
    word_bt entry;
    // Preload
    $display("[AXI] Preload memory");
    axi_elf_preload(binary, entry);
    // Write entry point
    $display("[AXI] Write entry point 0x%h", entry[31:0]);
    axi_write_32(BootAddrAddr, entry[31:0]);
    // Write fetch enable
    $display("[AXI] Write lauch signal (fetch enable)");
    axi_write_32(FetchEnAddr, 1);
    $display("[AXI] Wrote launch signal and entry point 0x%h", entry[31:0]);
  endtask

  // Wait for termination signal and get return code
  task automatic axi_safed_wait_for_eoc(output word_bt exit_code, output bit exit_status);
    axi_poll_bit31(CoreStatusAddr, exit_code, 800);
    exit_status = exit_code[31];
    if (exit_code[30:0]) $error("[AXI] FAILED: return code %0d", exit_code[30:0]);
    else $display("[AXI] SUCCESS");
  endtask

endmodule
