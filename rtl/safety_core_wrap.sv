// Copyright 2023 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

module safety_core_wrap import safety_island_pkg::*; #(
  parameter safety_island_cfg_t SafetyIslandCfg = safety_island_pkg::SafetyIslandDefaultConfig,
  parameter bit [         31:0] PeriphBaseAddr  = 32'h0020_0000,
  parameter int unsigned        NumBusErrBits   = 2,
  parameter bit                 EnableTcls      = 1'b1,
  parameter type                reg_req_t       = logic,
  parameter type                reg_rsp_t       = logic
) (
  input  logic clk_i,
  input  logic ref_clk_i,
  input  logic rst_ni,
  input  logic test_enable_i,

  input logic [SafetyIslandCfg.NumInterrupts-1:0] irqs_i,
  input logic [NumTimerInterrupts-1:0] timer_irqs_i,

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
  input  logic [NumBusErrBits-1:0] instr_err_i,

  // Data memory interface
  output logic        data_req_o,
  input  logic        data_gnt_i,
  input  logic        data_rvalid_i,
  output logic        data_we_o,
  output logic [3:0]  data_be_o,
  output logic [31:0] data_addr_o,
  output logic [31:0] data_wdata_o,
  input  logic [31:0] data_rdata_i,
  input  logic [NumBusErrBits-1:0] data_err_i,

  // Shadow memory interface
  output logic        shadow_req_o,
  input  logic        shadow_gnt_i,
  input  logic        shadow_rvalid_i,
  output logic        shadow_we_o,
  output logic [3:0]  shadow_be_o,
  output logic [31:0] shadow_addr_o,
  output logic [31:0] shadow_wdata_o,
  input  logic [31:0] shadow_rdata_i,
  input  logic [NumBusErrBits-1:0] shadow_err_i,

  // Debug Interface
  input  logic        debug_req_i,

  // CPU Control Signals
  input  logic        fetch_enable_i
);

  localparam int unsigned TotalNumInterrupts = SafetyIslandCfg.NumInterrupts + 32;

  localparam int unsigned NumCoreLocalPeriphs = 5; // CLIC, TCLS, 3xBus_err

  localparam addr_map_rule_t [NumCoreLocalPeriphs-1:0] cl_regbus_addr_map_rule = '{
   '{ idx: RegbusOutTCLS,     start_addr: PeriphBaseAddr+TCLSAddrOffset,  end_addr: PeriphBaseAddr+TCLSAddrOffset+TCLSAddrRange },   // 0: TCLS
   '{ idx: RegbusOutCLIC,     start_addr: PeriphBaseAddr+ClicAddrOffset,  end_addr: PeriphBaseAddr+ClicAddrOffset+ClicAddrRange },   // 1: CLIC
   '{ idx: RegbusOutInstrErr, start_addr: PeriphBaseAddr+InstrErrOffset,  end_addr: PeriphBaseAddr+InstrErrOffset+InstrErrRange },
   '{ idx: RegbusOutDataErr,  start_addr: PeriphBaseAddr+DataErrOffset,   end_addr: PeriphBaseAddr+DataErrOffset+DataErrRange   },
   '{ idx: RegbusOutShadowErr,start_addr: PeriphBaseAddr+ShadowErrOffset, end_addr: PeriphBaseAddr+ShadowErrOffset+ShadowErrRange }
  };

  reg_req_t [NumCoreLocalPeriphs-1:0] cl_periph_req;
  reg_rsp_t [NumCoreLocalPeriphs-1:0] cl_periph_rsp;
  logic [cf_math_pkg::idx_width(NumCoreLocalPeriphs)-1:0] regbus_idx;

  // Interrupt signals
  logic [TotalNumInterrupts-1:0] core_irq_onehot;
  logic [$clog2(TotalNumInterrupts)-1:0]  core_irq_id;
  logic [7:0]  core_irq_level;
  logic core_irq_valid, core_irq_ready, core_irq_shv;

  logic [2:0] bus_err_irq;

 // TODO: add atomic support to cv32 + adapter (if needed)

  if (EnableTcls) begin
    localparam NumBuses = 2;
    localparam DataBus = 0;
    localparam ShadowBus = 1;
    typedef struct packed {
      logic        pulp_clock_en;
      logic        scan_cg_en_i;

      logic [31:0] boot_addr;
      logic [31:0] mtvec_addr;
      logic [31:0] mtvt_addr;
      logic [31:0] dm_halt_addr;
      logic [31:0] hart_id;
      logic [31:0] dm_exception_addr;

      logic        instr_gnt;
      logic        instr_rvalid;
      logic [31:0] instr_rdata;

      logic        data_gnt;
      logic        data_rvalid;
      logic [31:0] data_rdata;

      logic        shadow_gnt;
      logic        shadow_rvalid;
      logic [31:0] shadow_rdata;

      logic [TotalNumInterrupts-1:0] irq;
      logic [ 7:0] irq_level;
      logic        irq_shv;

      logic        debug_req;
      logic        fetch_enable;
    } hmr_cv32e40p_all_inputs_t;

    typedef struct packed {
      logic        instr_req;

      logic [31:0] instr_addr;

      logic        data_req;

      logic        shadow_req;

      logic        irq_ack;
      logic [$clog2(TotalNumInterrupts)-1:0] irq_id;

      logic        debug_havereset;
      logic        debug_running;
      logic        debug_halted;

      logic        core_sleep;
    } hmr_cv32e40p_nominal_outputs_t;

    typedef struct packed {
      logic [31:0] addr;
      logic        we;
      logic [31:0] wdata;
      logic [ 3:0] be;
      // logic [ 5:0] atop;
    } hmr_cv32e40p_bus_outputs_t;

    hmr_cv32e40p_all_inputs_t       sys_inputs;
    hmr_cv32e40p_all_inputs_t [2:0] core_inputs;

    hmr_cv32e40p_nominal_outputs_t       sys_outputs;
    hmr_cv32e40p_nominal_outputs_t [2:0] core_outputs;

    hmr_cv32e40p_bus_outputs_t      [NumBuses-1:0] sys_bus_outputs;
    hmr_cv32e40p_bus_outputs_t [2:0][NumBuses-1:0] core_bus_outputs;

    logic [2:0] core_setback;

    assign sys_inputs = '{
      pulp_clock_en:     '0,
      scan_cg_en_i:      test_enable_i,
      boot_addr:         boot_addr_i,
      mtvec_addr:        32'h0000_0000,
      mtvt_addr:         32'h0000_0000,
      dm_halt_addr:      PeriphBaseAddr + DebugAddrOffset + dm::HaltAddress[31:0],
      hart_id:           hart_id_i,
      dm_exception_addr: PeriphBaseAddr + DebugAddrOffset + dm::ExceptionAddress[31:0],
      instr_gnt:         instr_gnt_i,
      instr_rvalid:      instr_rvalid_i,
      instr_rdata:       instr_rdata_i,
      data_gnt:          data_gnt_i,
      data_rvalid:       data_rvalid_i,
      data_rdata:        data_rdata_i,
      shadow_gnt:        shadow_gnt_i,
      shadow_rvalid:     shadow_rvalid_i,
      shadow_rdata:      shadow_rdata_i,
      irq:               core_irq_onehot,
      irq_level:         core_irq_level,
      irq_shv:           core_irq_shv,
      debug_req:         debug_req_i,
      fetch_enable:      fetch_enable_i
    };

    assign instr_req_o    = sys_outputs.instr_req;
    assign instr_addr_o   = sys_outputs.instr_addr;
    assign data_req_o     = sys_outputs.data_req;
    assign data_addr_o    = sys_bus_outputs[DataBus].addr;
    assign data_we_o      = sys_bus_outputs[DataBus].we;
    assign data_be_o      = sys_bus_outputs[DataBus].be;
    assign data_wdata_o   = sys_bus_outputs[DataBus].wdata;
    assign shadow_req_o   = sys_outputs.shadow_req;
    assign shadow_addr_o  = sys_bus_outputs[ShadowBus].addr;
    assign shadow_we_o    = sys_bus_outputs[ShadowBus].we;
    assign shadow_be_o    = sys_bus_outputs[ShadowBus].be;
    assign shadow_wdata_o = sys_bus_outputs[ShadowBus].wdata;
    assign irq_ack_o      = sys_outputs.irq_ack;

    hmr_unit #(
      .NumCores          (    3                           ),
      .DMRSupported      ( 1'b0                           ),
      .DMRFixed          ( 1'b0                           ),
      .TMRSupported      ( 1'b1                           ),
      .TMRFixed          ( 1'b1                           ),
      .InterleaveGrps    ( 1'b0                           ),
      .SeparateData      ( 1'b1                           ),
      .NumBusVoters      ( NumBuses                       ),
      .all_inputs_t      ( hmr_cv32e40p_all_inputs_t      ),
      .nominal_outputs_t ( hmr_cv32e40p_nominal_outputs_t ),
      .bus_outputs_t     ( hmr_cv32e40p_bus_outputs_t     ),
      .reg_req_t         ( reg_req_t                      ),
      .reg_rsp_t         ( reg_rsp_t                      )
    ) i_hmr_unit (
      .clk_i,
      .rst_ni,
      .reg_request_i         ( cl_periph_req[RegbusOutTCLS] ),
      .reg_response_o        ( cl_periph_rsp[RegbusOutTCLS] ),

      .tmr_failure_o         (),
      .tmr_error_o           (),
      .tmr_resynch_req_o     (),
      .tmr_sw_synch_req_o    (),
      .tmr_cores_synch_i     ('0),

      .dmr_failure_o         (),
      .dmr_error_o           (),
      .dmr_resynch_req_o     (),
      .dmr_sw_synch_req_o    (),
      .dmr_cores_synch_i     ('0),

      .sys_inputs_i          ( sys_inputs      ),
      .sys_nominal_outputs_o ( sys_outputs     ),
      .sys_bus_outputs_o     ( sys_bus_outputs ),
      .sys_fetch_en_i        ( fetch_enable_i  ),

      .core_setback_o        ( core_setback     ),
      .core_inputs_o         ( core_inputs      ),
      .core_nominal_outputs_i( core_outputs     ),
      .core_bus_outputs_i    ( core_bus_outputs ),
      .enable_bus_vote_i     ()
    );

    for (genvar i = 0; i < 3; i++) begin
      // APU signals
      logic                           apu_req;
      logic [cv32e40p_apu_core_pkg::APU_NARGS_CPU-1:0][31:0] apu_operands;
      logic [cv32e40p_apu_core_pkg::APU_WOP_CPU-1:0]         apu_op;
      logic [cv32e40p_apu_core_pkg::APU_NDSFLAGS_CPU-1:0]    apu_flags;
      logic                           apu_gnt;
      logic                           apu_rvalid;
      logic [31:0]                    apu_rdata;
      logic [cv32e40p_apu_core_pkg::APU_NUSFLAGS_CPU-1:0]    apu_rflags;

// `ifdef PULP_FPGA_EMUL
//       cv32e40p_core #(
// `elsif SYNTHESIS
//       cv32e40p_core #(
// `elsif VERILATOR
//       cv32e40p_core #(
// `else
      cv32e40p_wrapper #(
// `endif
        .PULP_XPULP       ( SafetyIslandCfg.UseXPulp          ),
        .PULP_CLUSTER     ( SafetyIslandCfg.UseIntegerCluster ),
        .FPU              ( SafetyIslandCfg.UseFpu            ),
        .PULP_ZFINX       ( SafetyIslandCfg.UseZfinx          ),
        .NUM_MHPMCOUNTERS ( SafetyIslandCfg.NumMhpmCounters   ),
        .NUM_INTERRUPTS   ( TotalNumInterrupts                ),
        .CLIC             ( SafetyIslandCfg.UseClic           ),
        .SHADOW           ( SafetyIslandCfg.UseFastIrq        ),
        .MCLICBASE_ADDR   ( PeriphBaseAddr+ClicAddrOffset     )
      ) i_cv32e40p (
        .clk_i,
        .rst_ni,
        .setback_i           ( core_setback[i]                  ),

        .pulp_clock_en_i     ( core_inputs[i].pulp_clock_en     ),
        .scan_cg_en_i        ( core_inputs[i].scan_cg_en_i      ),
        .boot_addr_i         ( core_inputs[i].boot_addr         ),
        .mtvec_addr_i        ( core_inputs[i].mtvec_addr        ),
        .mtvt_addr_i         ( core_inputs[i].mtvt_addr         ),
        .dm_halt_addr_i      ( core_inputs[i].dm_halt_addr      ),
        .hart_id_i           ( core_inputs[i].hart_id           ),
        .dm_exception_addr_i ( core_inputs[i].dm_exception_addr ),

        .instr_req_o         ( core_outputs[i].instr_req    ),
        .instr_gnt_i         ( core_inputs [i].instr_gnt    ),
        .instr_rvalid_i      ( core_inputs [i].instr_rvalid ),
        .instr_addr_o        ( core_outputs[i].instr_addr   ),
        .instr_rdata_i       ( core_inputs [i].instr_rdata  ),

        .data_req_o          ( core_outputs[i].data_req           ),
        .data_gnt_i          ( core_inputs [i].data_gnt           ),
        .data_rvalid_i       ( core_inputs [i].data_rvalid        ),
        .data_we_o           ( core_bus_outputs[i][DataBus].we    ),
        .data_be_o           ( core_bus_outputs[i][DataBus].be    ),
        .data_addr_o         ( core_bus_outputs[i][DataBus].addr  ),
        .data_wdata_o        ( core_bus_outputs[i][DataBus].wdata ),
        .data_rdata_i        ( core_inputs [i].data_rdata         ),
        .data_atop_o         ( ),//core_bus_outputs[i][DataBus].atop), // currently, safety_island does not support AMOs and
                          // LR/SC

        // Shadow memory interface
        .shadow_req_o        ( core_outputs[i].shadow_req           ),
        .shadow_gnt_i        ( core_inputs [i].shadow_gnt           ),
        .shadow_rvalid_i     ( core_inputs [i].shadow_rvalid        ),
        .shadow_we_o         ( core_bus_outputs[i][ShadowBus].we    ),
        .shadow_be_o         ( core_bus_outputs[i][ShadowBus].be    ),
        .shadow_addr_o       ( core_bus_outputs[i][ShadowBus].addr  ),
        .shadow_wdata_o      ( core_bus_outputs[i][ShadowBus].wdata ),
        .shadow_rdata_i      ( core_inputs [i].shadow_rdata         ),

        .apu_req_o           ( apu_req      ),
        .apu_gnt_i           ( apu_gnt      ),
        .apu_operands_o      ( apu_operands ),
        .apu_op_o            ( apu_op       ),
        .apu_flags_o         ( apu_flags    ),
        .apu_type_o          (),
        .apu_rvalid_i        ( apu_rvalid   ),
        .apu_result_i        ( apu_rdata    ),
        .apu_flags_i         ( apu_rflags   ),

        // Interrupt inputs
        .irq_i               ( core_inputs[i].irq       ),
        .irq_level_i         ( core_inputs[i].irq_level ),
        .irq_shv_i           ( core_inputs[i].irq_shv   ),
        .irq_ack_o           ( core_outputs[i].irq_ack  ),
        .irq_id_o            ( core_outputs[i].irq_id   ),

        .debug_req_i         ( core_inputs [i].debug_req       ),
        .debug_havereset_o   ( core_outputs[i].debug_havereset ),
        .debug_running_o     ( core_outputs[i].debug_running   ),
        .debug_halted_o      ( core_outputs[i].debug_halted    ),

        .fetch_enable_i      ( core_inputs [i].fetch_enable ),
        .core_sleep_o        ( core_outputs[i].core_sleep   ),
        .external_perf_i     ( '0                           )
      );

      // FPU
      if (SafetyIslandCfg.UseFpu) begin : gen_safety_island_fpu
        cv32e40p_fpu_wrap #(
          .FP_DIVSQRT (1)
        ) i_fpu (
          .clk_i,
          .rst_ni,
          .flush_i       (core_setback[i]),
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

    end

  end else begin

    // APU signals
    logic                           apu_req;
    logic [cv32e40p_apu_core_pkg::APU_NARGS_CPU-1:0][31:0] apu_operands;
    logic [cv32e40p_apu_core_pkg::APU_WOP_CPU-1:0]         apu_op;
    logic [cv32e40p_apu_core_pkg::APU_NDSFLAGS_CPU-1:0]    apu_flags;
    logic                           apu_gnt;
    logic                           apu_rvalid;
    logic [31:0]                    apu_rdata;
    logic [cv32e40p_apu_core_pkg::APU_NUSFLAGS_CPU-1:0]    apu_rflags;

// `ifdef PULP_FPGA_EMUL
//     cv32e40p_core #(
// `elsif SYNTHESIS
//     cv32e40p_core #(
// `elsif VERILATOR
//     cv32e40p_core #(
// `else
    cv32e40p_wrapper #(
// `endif
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
      .setback_i           ( '0            ),

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

    // FPU
    if (SafetyIslandCfg.UseFpu) begin : gen_safety_island_fpu
      cv32e40p_fpu_wrap #(
        .FP_DIVSQRT (1)
      ) i_fpu (
        .clk_i,
        .rst_ni,
        .flush_i       (1'b0),
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

    reg_err_slv #(
      .DW      ( 32           ),
      .ERR_VAL ( 32'hBADCAB1E ),
      .req_t   ( reg_req_t    ),
      .rsp_t   ( reg_rsp_t )
    ) i_reg_err_slv_ddr_link (
      .req_i   ( cl_periph_req[RegbusOutTCLS] ),
      .rsp_o   ( cl_periph_rsp[RegbusOutTCLS] )
    );
  end

  // Core-Local peripherals arbitration

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

  // Instr Bus Err Unit
  obi_err_unit_wrap #(
    .AddrWidth       ( 32   ),
    .ErrBits         ( NumBusErrBits ),
    .NumOutstanding  ( 2    ),
    .NumStoredErrors ( 8    ),
    .DropOldest      ( 1'b0 ),
    .reg_req_t      ( reg_req_t ),
    .reg_rsp_t      ( reg_rsp_t )
  ) i_instr_bus_err (
    .clk_i,
    .rst_ni,
    .testmode_i ( test_enable_i ),

    .obi_req_i   ( instr_req_o ),
    .obi_gnt_i   ( instr_gnt_i ),
    .obi_rvalid_i( instr_rvalid_i ),
    .obi_addr_i  ( instr_addr_o ),
    .obi_err_i   ( instr_err_i ),

    .err_irq_o   ( bus_err_irq[0] ),

    .reg_req_i   (cl_periph_req[RegbusOutInstrErr]),
    .reg_rsp_o   (cl_periph_rsp[RegbusOutInstrErr])
  );

  // Instr Bus Err Unit
  obi_err_unit_wrap #(
    .AddrWidth       ( 32   ),
    .ErrBits         ( NumBusErrBits ),
    .NumOutstanding  ( 2    ),
    .NumStoredErrors ( 8    ),
    .DropOldest      ( 1'b0 ),
    .reg_req_t      ( reg_req_t ),
    .reg_rsp_t      ( reg_rsp_t )
  ) i_data_bus_err (
    .clk_i,
    .rst_ni,
    .testmode_i ( test_enable_i ),

    .obi_req_i   ( data_req_o ),
    .obi_gnt_i   ( data_gnt_i ),
    .obi_rvalid_i( data_rvalid_i ),
    .obi_addr_i  ( data_addr_o ),
    .obi_err_i   ( data_err_i ),

    .err_irq_o   ( bus_err_irq[1] ),

    .reg_req_i   (cl_periph_req[RegbusOutDataErr]),
    .reg_rsp_o   (cl_periph_rsp[RegbusOutDataErr])
  );

  // Instr Bus Err Unit
  obi_err_unit_wrap #(
    .AddrWidth       ( 32   ),
    .ErrBits         ( NumBusErrBits ),
    .NumOutstanding  ( 2    ),
    .NumStoredErrors ( 8    ),
    .DropOldest      ( 1'b0 ),
    .reg_req_t      ( reg_req_t ),
    .reg_rsp_t      ( reg_rsp_t )
  ) i_shadow_bus_err (
    .clk_i,
    .rst_ni,
    .testmode_i ( test_enable_i ),

    .obi_req_i   ( shadow_req_o ),
    .obi_gnt_i   ( shadow_gnt_i ),
    .obi_rvalid_i( shadow_rvalid_i ),
    .obi_addr_i  ( shadow_addr_o ),
    .obi_err_i   ( shadow_err_i ),

    .err_irq_o   ( bus_err_irq[2] ),

    .reg_req_i   (cl_periph_req[RegbusOutShadowErr]),
    .reg_rsp_o   (cl_periph_rsp[RegbusOutShadowErr])
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
  assign clic_irqs[31:21] = '0;
  assign clic_irqs[20:18] = bus_err_irq[2:0];
  assign clic_irqs[17:16] = timer_irqs_i;
  assign clic_irqs[15:0]  = {
    {4{1'b0}},       // reserved
    meip,            // meip
    1'b0,            // reserved
    seip,            // seip
    1'b0,            // reserved
    timer_irqs_i[0], // mtip
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

endmodule
