// Copyright 2023 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

module safety_core_wrap #(
  parameter bit[31:0] DmBaseAddr       = 32'h0001_3000,
  parameter type      reg_req_t        = logic,
  parameter type      reg_rsp_t        = logic,
  parameter int unsigned NumInterrupts = 256
) (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic test_enable_i,

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

  // Debug Interface
  input  logic        debug_req_i,

  // CPU Control Signals
  input  logic        fetch_enable_i
);

`ifdef PULP_FPGA_EMUL
  cv32e40p_core #(
`elsif SYNTHESIS
  cv32e40p_core #(
`elsif VERILATOR
  cv32e40p_core #(
`else
  cv32e40p_wrapper #(
`endif
    .PULP_XPULP   (1),
    .PULP_CLUSTER (0),
    .FPU          (0),
    .PULP_ZFINX   (0),
    // .NUM_EXTERNAL_PERF(0),
    .NUM_MHPMCOUNTERS(1)
  ) i_RISCV_CORE (
    .clk_i,
    .rst_ni,

    .pulp_clock_en_i     ( '0            ),
    .scan_cg_en_i        ( test_enable_i ),
    .boot_addr_i,
    .mtvec_addr_i        ( 32'h0000_0000 ),
    .dm_halt_addr_i      ( DmBaseAddr + dm::HaltAddress[31:0]      ),
    .hart_id_i,
    .dm_exception_addr_i ( DmBaseAddr + dm::ExceptionAddress[31:0] ),

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

    .apu_req_o           (),
    .apu_gnt_i           ('0),
    .apu_operands_o      (),
    .apu_op_o            (),
    .apu_flags_o         (),
    .apu_rvalid_i        ('0),
    .apu_result_i        ('0),
    .apu_flags_i         ('0),

    .irq_i               ('0),
    .irq_ack_o           (),
    .irq_id_o            (),

    .debug_req_i,
    .debug_havereset_o   (),
    .debug_running_o     (),
    .debug_halted_o      (),

    .fetch_enable_i,
    .core_sleep_o        ()
  );

  localparam int unsigned NumCoreLocalPeriphs = 1;
  reg_req_t [NumCoreLocalPeriphs-1:0] cl_periph_req;
  reg_rsp_t [NumCoreLocalPeriphs-1:0] cl_periph_rsp;

  reg_demux #(
    .NoPorts ( NumCoreLocalPeriphs ),
    .req_t   ( reg_req_t  ),
    .rsp_t   ( reg_rsp_t  )
  ) i_reg_demux (
    .clk_i,
    .rst_ni,

    .in_select_i ( '0 ), // TODO

    .in_req_i  ( cl_periph_req_i ),
    .in_rsp_o  ( cl_periph_rsp_o ),

    .out_req_o ( cl_periph_req   ),
    .out_rsp_i ( cl_periph_rsp   )
  );

  // TODO: CLIC
  clic #(
    .reg_req_t ( reg_req_t     ),
    .reg_rsp_t ( reg_rsp_t     ),
    .N_SOURCE  ( NumInterrupts )
  ) i_clic (
    .clk_i,
    .rst_ni,

    .reg_req_i   ( cl_periph_req[0] ),
    .reg_rsp_o   ( cl_periph_rsp[0] ),

    .intr_src_i  ('0),
    .irq_valid_o (),
    .irq_ready_i ('0),
    .irq_id_o    (),
    .irq_level_o (),
    .irq_shv_o   ()
  );

  // TODO: TCLS
  // TODO: FPU?

endmodule
