// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Authors:
// - Michael Rogenmoser <michaero@iis.ee.ethz.ch>

`include "idma/typedef.svh"
`include "obi/typedef.svh"

module safety_island_dma import safety_island_pkg::*; #(
  parameter type                reg_req_t       = logic,
  parameter type                reg_rsp_t       = logic,

  /// OBI Request and Response channel type
  parameter obi_pkg::obi_cfg_t  ObiCfg          = obi_pkg::ObiDefaultConfig,
  parameter type                obi_a_chan_t    = logic,
  parameter type                obi_r_chan_t    = logic,
  parameter type                obi_req_t       = logic,
  parameter type                obi_rsp_t       = logic
) (
  input  logic           clk_i,
  input  logic           rst_ni,
  input  logic           test_mode_i,

  /// Register configuration ports
  input  reg_req_t       reg_req_i,
  output reg_rsp_t       reg_rsp_o,

  // OBI ports
  output obi_req_t [1:0] obi_req_o,
  input  obi_rsp_t [1:0] obi_rsp_i
);

  localparam int unsigned TFLenWidth = 24;

  `IDMA_TYPEDEF_FULL_REQ_T(idma_req_t,
                           logic[ObiCfg.IdWidth-1:0],
                           logic[ObiCfg.AddrWidth-1:0],
                           logic[TFLenWidth-1:0])
  `IDMA_TYPEDEF_FULL_RSP_T(idma_rsp_t, logic[ObiCfg.AddrWidth-1:0])

  typedef struct packed {
    obi_a_chan_t a_chan;
    logic [0:0] padding;
  } obi_read_a_chan_padded_t;

  typedef union packed {
    obi_read_a_chan_padded_t obi;
  } read_meta_channel_t;

  typedef struct packed {
    obi_a_chan_t a_chan;
    logic [0:0] padding;
  } obi_write_a_chan_padded_t;

  typedef union packed {
    obi_write_a_chan_padded_t obi;
  } write_meta_channel_t;

  `OBI_TYPEDEF_REQ_T(internal_obi_req_t, obi_a_chan_t)

  idma_req_t backend_req;
  idma_rsp_t backend_rsp;
  logic      backend_req_valid,
             backend_req_ready,
             backend_rsp_valid,
             backend_rsp_ready;

  idma_pkg::idma_busy_t backend_busy;

  logic [31:0] next_id, completed_id;

  internal_obi_req_t [1:0] internal_obi_req, internal_obi_req_spill;
  obi_rsp_t          [1:0] internal_obi_rsp, internal_obi_rsp_spill;

  // reg_frontend
  idma_reg32_1d #(
    .NumRegs       ( 1 ),
    .NumStreams    ( 1 ),
    .IdCounterWidth ( 32 ),
    .reg_req_t     ( reg_req_t ),
    .reg_rsp_t     ( reg_rsp_t ),
    .dma_req_t     ( idma_req_t )
  ) i_frontend (
    .clk_i,
    .rst_ni,
    .dma_ctrl_req_i( reg_req_i ),
    .dma_ctrl_rsp_o( reg_rsp_o ),
    .dma_req_o     ( backend_req ),
    .req_valid_o   ( backend_req_valid ),
    .req_ready_i   ( backend_req_ready ),
    .next_id_i     ( next_id ),
    .stream_idx_o  (),
    .done_id_i     ( completed_id ),
    .busy_i        ( backend_busy ),
    .midend_busy_i ('0)
  );

  idma_transfer_id_gen #(
    .IdWidth ( 32 )
  ) i_transfer_id_gen (
    .clk_i,
    .rst_ni,

    .issue_i    ( backend_req_valid & backend_req_ready ),
    .retire_i   ( backend_rsp_valid ),
    .next_o     ( next_id ),
    .completed_o( completed_id )
  );

  assign backend_rsp_ready = 1'b1;

  // Backend
  idma_backend_rw_obi #(
    .DataWidth           ( ObiCfg.DataWidth ),
    .AddrWidth           ( ObiCfg.AddrWidth ),
    .UserWidth           ( 1 ), // unused internally, needs >0
    .AxiIdWidth          ( ObiCfg.IdWidth ),
    .NumAxInFlight       ( 3 ),
    .BufferDepth         ( 3 ),
    .TFLenWidth          ( TFLenWidth ),
    .MemSysDepth         ( 3 ),
    .CombinedShifter     ( 1'b0 ),
    .RAWCouplingAvail    ( 1'b0 ),
    .MaskInvalidData     ( 1'b1 ),
    .HardwareLegalizer   ( 1'b1 ),
    .RejectZeroTransfers ( 1'b1 ),
    .ErrorCap            ( idma_pkg::NO_ERROR_HANDLING ),
    .PrintFifoInfo       ( 1'b0 ),
    .idma_req_t          ( idma_req_t ),
    .idma_rsp_t          ( idma_rsp_t ),
    .idma_eh_req_t       ( idma_pkg::idma_eh_req_t ),
    .idma_busy_t         ( idma_pkg::idma_busy_t ),
    .obi_req_t           ( internal_obi_req_t ),
    .obi_rsp_t           ( obi_rsp_t ),
    .read_meta_channel_t ( read_meta_channel_t ),
    .write_meta_channel_t( write_meta_channel_t )
  ) i_backend (
    .clk_i,
    .rst_ni,
    .testmode_i     ( test_mode_i ),

    .idma_req_i     ( backend_req ),
    .req_valid_i    ( backend_req_valid ),
    .req_ready_o    ( backend_req_ready ),

    .idma_rsp_o     ( backend_rsp ),
    .rsp_valid_o    ( backend_rsp_valid ),
    .rsp_ready_i    ( backend_rsp_ready ),

    .idma_eh_req_i  ( '0 ),
    .eh_req_valid_i ( '0 ),
    .eh_req_ready_o (),

    .obi_read_req_o ( internal_obi_req[0] ),
    .obi_read_rsp_i ( internal_obi_rsp[0] ),

    .obi_write_req_o( internal_obi_req[1] ),
    .obi_write_rsp_i( internal_obi_rsp[1] ),

    .busy_o         ( backend_busy )
  );

  for (genvar i = 0; i < 2; i++) begin : gen_rready_convert
    spill_register #(
      .T (obi_a_chan_t ),
      .Bypass ( '0 )
    ) i_spill_a (
      .clk_i,
      .rst_ni,
      .valid_i (internal_obi_req[i].req),
      .ready_o (internal_obi_rsp[i].gnt),
      .data_i  (internal_obi_req[i].a),
      .valid_o (internal_obi_req_spill[i].req),
      .ready_i (internal_obi_rsp_spill[i].gnt),
      .data_o  (internal_obi_req_spill[i].a)
    );

    spill_register #(
      .T (obi_r_chan_t ),
      .Bypass ( '0 )
    ) i_spill_r (
      .clk_i,
      .rst_ni,
      .valid_i (internal_obi_rsp_spill[i].rvalid),
      .ready_o (internal_obi_req_spill[i].rready),
      .data_i  (internal_obi_rsp_spill[i].r),
      .valid_o (internal_obi_rsp[i].rvalid),
      .ready_i (internal_obi_req[i].rready),
      .data_o  (internal_obi_rsp[i].r)
    );

    obi_rready_converter #(
      .obi_a_chan_t( obi_a_chan_t ),
      .obi_r_chan_t( obi_r_chan_t ),
      .Depth       ( 2            ),
      .CombRspReq  ( 1'b1         )
    ) i_obi_rready_converter (
      .clk_i,
      .rst_ni,
      .test_mode_i,

      .sbr_a_chan_i( internal_obi_req_spill[i].a      ),
      .req_i       ( internal_obi_req_spill[i].req    ),
      .gnt_o       ( internal_obi_rsp_spill[i].gnt    ),
      .sbr_r_chan_o( internal_obi_rsp_spill[i].r      ),
      .rvalid_o    ( internal_obi_rsp_spill[i].rvalid ),
      .rready_i    ( internal_obi_req_spill[i].rready ),

      .mgr_a_chan_o( obi_req_o[i].a      ),
      .req_o       ( obi_req_o[i].req    ),
      .gnt_i       ( obi_rsp_i[i].gnt    ),
      .mgr_r_chan_i( obi_rsp_i[i].r      ),
      .rvalid_i    ( obi_rsp_i[i].rvalid )
    );
  end

endmodule
