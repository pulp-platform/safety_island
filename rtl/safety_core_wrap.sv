// Copyright 2023 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

`include "apb/typedef.svh"

module safety_core_wrap import safety_island_pkg::*; #(
  parameter safety_island_cfg_t SafetyIslandCfg = safety_island_pkg::SafetyIslandDefaultConfig,
  parameter bit [31:0] PeriphBaseAddr = 32'h0020_0000,
  parameter type      reg_req_t        = logic,
  parameter type      reg_rsp_t        = logic
) (
  input  logic clk_i,
  input  logic ref_clk_i,
  input  logic rst_ni,
  input  logic test_enable_i,

  input logic [SafetyIslandCfg.NumInterrupts-1:0] irqs_i,

  // Core-local peripherals
  input  reg_req_t    cl_periph_req_i,
  output reg_rsp_t    cl_periph_rsp_o,

  input  logic [31:0] hart_id_i,
  input  logic [31:0] boot_addr_i,

  // Instruction memory interface
  output logic        instr_req_o,
  input  logic        instr_gnt_i,
  input  logic        instr_rvalid_i,
  output logic [31:0] instr_addr_o,
  input  logic [31:0] instr_rdata_i,
  input  logic        instr_err_i,

  // Data memory interface
  output logic        data_req_o,
  input  logic        data_gnt_i,
  input  logic        data_rvalid_i,
  output logic        data_we_o,
  output logic [3:0]  data_be_o,
  output logic [31:0] data_addr_o,
  output logic [31:0] data_wdata_o,
  input  logic [31:0] data_rdata_i,
  input  logic        data_err_i,

  // Shadow memory interface
  output logic        shadow_req_o,
  input  logic        shadow_gnt_i,
  input  logic        shadow_rvalid_i,
  output logic        shadow_we_o,
  output logic [3:0]  shadow_be_o,
  output logic [31:0] shadow_addr_o,
  output logic [31:0] shadow_wdata_o,
  input  logic [31:0] shadow_rdata_i,
  input  logic        shadow_err_i,

  // Debug Interface
  input  logic        debug_req_i,

  // CPU Control Signals
  input  logic        fetch_enable_i
);

  localparam int unsigned TotalNumInterrupts = SafetyIslandCfg.NumInterrupts + 32;

 // Interrupt signals
 logic [TotalNumInterrupts-1:0] core_irq_onehot;
 logic [$clog2(TotalNumInterrupts)-1:0]  core_irq_id;
 logic [7:0]  core_irq_level;
 logic core_irq_valid, core_irq_ready, core_irq_shv;

 // APU signals
 logic                           apu_req;
 logic [cv32e40p_apu_core_pkg::APU_NARGS_CPU-1:0][31:0] apu_operands;
 logic [cv32e40p_apu_core_pkg::APU_WOP_CPU-1:0]         apu_op;
 logic [cv32e40p_apu_core_pkg::APU_NDSFLAGS_CPU-1:0]    apu_flags;
 logic                           apu_gnt;
 logic                           apu_rvalid;
 logic [31:0]                    apu_rdata;
 logic [cv32e40p_apu_core_pkg::APU_NUSFLAGS_CPU-1:0]    apu_rflags;

 // TODO: add mnxti to cv32
 // TODO: add fastirq extension (shadowing) to cv32
 // TODO: add atomic support to cv32 + adapter (if needed)
`ifdef PULP_FPGA_EMUL
  cv32e40p_core #(
`elsif SYNTHESIS
  cv32e40p_core #(
`elsif VERILATOR
  cv32e40p_core #(
`else
  cv32e40p_wrapper #(
`endif
    .PULP_XPULP   (SafetyIslandCfg.UseXPulp),
    .PULP_CLUSTER (SafetyIslandCfg.UseIntegerCluster),
    .FPU          (SafetyIslandCfg.UseFpu),
    .PULP_ZFINX   (SafetyIslandCfg.UseZfinx),
    .NUM_MHPMCOUNTERS (SafetyIslandCfg.NumMhpmCounters),
    .NUM_INTERRUPTS   (TotalNumInterrupts),
    .CLIC             (SafetyIslandCfg.UseClic),
    .SHADOW           (SafetyIslandCfg.UseFastIrq),
    .MCLICBASE_ADDR   (PeriphBaseAddr+ClicAddrOffset)
  ) i_cv32e40p (
    .clk_i,
    .rst_ni,

    .pulp_clock_en_i     ( '0            ),
    .scan_cg_en_i        ( test_enable_i ),
    .boot_addr_i,
    .mtvec_addr_i        ( 32'h0000_0000 ),
    .mtvt_addr_i         ( 32'h0000_0000 ),
    .dm_halt_addr_i      ( PeriphBaseAddr + DebugAddrOffset + dm::HaltAddress[31:0]      ),
    .hart_id_i,
    .dm_exception_addr_i ( PeriphBaseAddr + DebugAddrOffset + dm::ExceptionAddress[31:0] ),

    .instr_req_o,
    .instr_gnt_i,
    .instr_rvalid_i,
    .instr_addr_o,
    .instr_rdata_i,

    .data_req_o,
    .data_gnt_i,
    .data_rvalid_i,
    .data_we_o,
    .data_be_o,
    .data_addr_o,
    .data_wdata_o,
    .data_rdata_i,
    .data_atop_o ( ), // currently, safety_island does not support AMOs and
                      // LR/SC

    // Shadow memory interface
    .shadow_req_o,
    .shadow_gnt_i,
    .shadow_rvalid_i,
    .shadow_we_o,
    .shadow_be_o,
    .shadow_addr_o,
    .shadow_wdata_o,
    .shadow_rdata_i,

    .apu_req_o           (apu_req),
    .apu_gnt_i           (apu_gnt),
    .apu_operands_o      (apu_operands),
    .apu_op_o            (apu_op),
    .apu_flags_o         (apu_flags),
    .apu_type_o          ( ),
    .apu_rvalid_i        (apu_rvalid),
    .apu_result_i        (apu_rdata),
    .apu_flags_i         (apu_rflags),

    // Interrupt inputs
    .irq_i                 (core_irq_onehot),
    .irq_level_i           (core_irq_level),
    .irq_shv_i             (core_irq_shv),
    .irq_ack_o             (core_irq_ready),
    .irq_id_o              ( ),

    .debug_req_i,
    .debug_havereset_o   (),
    .debug_running_o     (),
    .debug_halted_o      (),

    .fetch_enable_i,
    .core_sleep_o        (),
    .external_perf_i     ('0)
  );

  // Core-Local peripherals arbitration

  localparam int unsigned NumCoreLocalPeriphs = 3; // CLIC, TCLS, Timer

  localparam addr_map_rule_t [NumCoreLocalPeriphs-1:0] cl_regbus_addr_map_rule = '{
   '{ idx: RegbusOutTCLS,  start_addr: PeriphBaseAddr+TCLSAddrOffset,  end_addr: PeriphBaseAddr+TCLSAddrOffset+TCLSAddrRange },   // 0: TCLS
   '{ idx: RegbusOutTimer, start_addr: PeriphBaseAddr+TimerAddrOffset, end_addr: PeriphBaseAddr+TimerAddrOffset+TimerAddrRange }, // 1: Timer
   '{ idx: RegbusOutCLIC,  start_addr: PeriphBaseAddr+ClicAddrOffset,  end_addr: PeriphBaseAddr+ClicAddrOffset+ClicAddrRange }    // 2: CLIC
  };

  reg_req_t [NumCoreLocalPeriphs-1:0] cl_periph_req;
  reg_rsp_t [NumCoreLocalPeriphs-1:0] cl_periph_rsp;
  logic [cf_math_pkg::idx_width(NumCoreLocalPeriphs)-1:0] regbus_idx;

  addr_decode #(
    .NoIndices        ( NumCoreLocalPeriphs ),
    .NoRules          ( NumCoreLocalPeriphs ),
    .addr_t           ( logic [31:0] ),
    .rule_t           ( addr_map_rule_t ),
    .Napot            ( 1'b0 )
  ) i_addr_decode_regbus (
    .addr_i           ( cl_periph_req_i.addr ),
    .addr_map_i       ( cl_regbus_addr_map_rule ),
    .idx_o            ( regbus_idx ),
    .dec_valid_o      ( ),
    .dec_error_o      ( ),
    .en_default_idx_i ( '0 ),
    .default_idx_i    ( '0 )
  );

  reg_demux #(
    .NoPorts ( NumCoreLocalPeriphs ),
    .req_t   ( reg_req_t  ),
    .rsp_t   ( reg_rsp_t  )
  ) i_reg_demux (
    .clk_i,
    .rst_ni,

    .in_select_i ( regbus_idx ),

    .in_req_i  ( cl_periph_req_i ),
    .in_rsp_o  ( cl_periph_rsp_o ),

    .out_req_o ( cl_periph_req   ),
    .out_rsp_i ( cl_periph_rsp   )
  );

  // TODO @michaero: TCLS
  reg_err_slv #(
    .DW      ( 32           ),
    .ERR_VAL ( 32'hBADCAB1E ),
    .req_t   ( reg_req_t    ),
    .rsp_t   ( reg_rsp_t )
  ) i_reg_err_slv_ddr_link (
    .req_i   ( cl_periph_req[RegbusOutTCLS] ),
    .rsp_o   ( cl_periph_rsp[RegbusOutTCLS] )
  );

  // Timer

  // Timer bus (APB interface)
  `APB_TYPEDEF_REQ_T(safety_apb_req_t, logic [31:0], logic [31:0], logic [3:0])
  `APB_TYPEDEF_RESP_T(safety_apb_rsp_t, logic [31:0])
  safety_apb_req_t timer_apb_req;
  safety_apb_rsp_t timer_apb_rsp;

  logic [NumTimerInterrupts-1:0] s_timer_irqs;

  reg_to_apb #(
    .reg_req_t(reg_req_t),
    .reg_rsp_t(reg_rsp_t),
    .apb_req_t(safety_apb_req_t),
    .apb_rsp_t(safety_apb_rsp_t)
  ) i_reg_to_apb_timer (
    .clk_i,
    .rst_ni,
    // Register interface
    .reg_req_i (cl_periph_req[RegbusOutTimer]),
    .reg_rsp_o (cl_periph_rsp[RegbusOutTimer]),
    // APB interface
    .apb_req_o (timer_apb_req),
    .apb_rsp_i (timer_apb_rsp)
  );

  apb_timer_unit #(
    .APB_ADDR_WIDTH(32)
  ) i_apb_timer_unit (
    .HCLK       ( clk_i                 ),
    .HRESETn    ( rst_ni                ),
    .PADDR      ( timer_apb_req.paddr   ),
    .PWDATA     ( timer_apb_req.pwdata  ),
    .PWRITE     ( timer_apb_req.pwrite  ),
    .PSEL       ( timer_apb_req.psel    ),
    .PENABLE    ( timer_apb_req.penable ),
    .PRDATA     ( timer_apb_rsp.prdata  ),
    .PREADY     ( timer_apb_rsp.pready  ),
    .PSLVERR    ( timer_apb_rsp.pslverr ),
    .ref_clk_i,
    .event_lo_i (/*s_timer_in_lo_event*/),
    .event_hi_i (/*s_timer_in_hi_event*/),
    .irq_lo_o   ( s_timer_irqs[0]       ),
    .irq_hi_o   ( s_timer_irqs[1]       ),
    .busy_o     (                       )
  );


  // Interrupts
  always_comb begin : gen_core_irq_onehot
    core_irq_onehot = '0;
    if (core_irq_valid) begin
        core_irq_onehot[core_irq_id] = 1'b1;
    end
  end

  logic [TotalNumInterrupts-1:0] clic_irqs;
  logic seip, meip, msip;

  assign seip = '0;
  assign meip = '0;
  assign msip  = '0;
  assign clic_irqs[TotalNumInterrupts-1:32] = irqs_i;
  assign clic_irqs[31:18] = '0;
  assign clic_irqs[17:16] = s_timer_irqs;
  assign clic_irqs[15:0]  = {
    {4{1'b0}},       // reserved
    meip,            // meip
    1'b0,            // reserved
    seip,            // seip
    1'b0,            // reserved
    s_timer_irqs[0], // mtip
    {3{1'b0}},       // reserved, stip, reserved
    msip,            // msip
    {3{1'b0}}        // reserved, ssip, reserved
  };

  clic #(
    .reg_req_t  ( reg_req_t ),
    .reg_rsp_t  ( reg_rsp_t ),
    .N_SOURCE   ( TotalNumInterrupts             ),
    .INTCTLBITS ( SafetyIslandCfg.ClicIntCtlBits ),
    .SSCLIC     ( SafetyIslandCfg.UseSSClic      ),
    .USCLIC     ( SafetyIslandCfg.UseUSClic      )
  ) i_clic (
    .clk_i,
    .rst_ni,
     // Bus Interface
    .reg_req_i   ( cl_periph_req[RegbusOutCLIC] ),
    .reg_rsp_o   ( cl_periph_rsp[RegbusOutCLIC] ),
    // Interrupt Sources
    .intr_src_i  ( clic_irqs      ),
    // Interrupt notification to core
    .irq_valid_o ( core_irq_valid ),
    .irq_ready_i ( core_irq_ready ),
    .irq_id_o    ( core_irq_id    ),
    .irq_level_o ( core_irq_level ),
    .irq_shv_o   ( core_irq_shv   ),
    .irq_priv_o     (  ),
    .irq_kill_req_o (  ),
    .irq_kill_ack_i ('0)
  );

  // FPU
  if (SafetyIslandCfg.UseFpu) begin : gen_safety_island_fpu
    cv32e40p_fpu_wrap #(
      .FP_DIVSQRT (1)
    ) i_fpu (
      .clk_i,
      .rst_ni,
      .apu_req_i     (apu_req),
      .apu_gnt_o     (apu_gnt),
      .apu_operands_i(apu_operands),
      .apu_op_i      (apu_op),
      .apu_flags_i   (apu_flags),
      .apu_rvalid_o  (apu_rvalid),
      .apu_rdata_o   (apu_rdata),
      .apu_rflags_o  (apu_rflags)
    );
  end else begin : gen_no_safety_island_fpu
    //assign apu_req      = 1'b0;
    assign apu_gnt      = 1'b0;
    //assign apu_operands = 1'b0;
    //assign apu_op       = 1'b0;
    //assign apu_flags    = 1'b0;
    assign apu_rvalid   = 1'b0;
    assign apu_rdata    = 1'b0;
    assign apu_rflags   = 1'b0;
  end

  // TODO: TCLS

endmodule
