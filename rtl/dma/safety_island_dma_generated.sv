// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Authors:
// - Thomas Benz <tbenz@iis.ee.ethz.ch>
// - Tobias Senti <tsenti@ethz.ch>

`include "idma/guard.svh"
`include "common_cells/registers.svh"

/// Implementing the transport layer in the iDMA backend.
module idma_transport_layer_rw_obi #(
    /// Number of transaction that can be in-flight concurrently
    parameter int unsigned NumAxInFlight = 32'd2,
    /// Data width
    parameter int unsigned DataWidth = 32'd16,
    /// The depth of the internal reorder buffer:
    /// - '2': minimal possible configuration
    /// - '3': efficiently handle misaligned transfers (recommended)
    parameter int unsigned BufferDepth = 32'd3,
    /// Mask invalid data on the manager interface
    parameter bit MaskInvalidData = 1'b1,
    /// Print the info of the FIFO configuration
    parameter bit PrintFifoInfo = 1'b0,
    /// `r_dp_req_t` type:
    parameter type r_dp_req_t = logic,
    /// `w_dp_req_t` type:
    parameter type w_dp_req_t = logic,
    /// `r_dp_rsp_t` type:
    parameter type r_dp_rsp_t = logic,
    /// `w_dp_rsp_t` type:
    parameter type w_dp_rsp_t = logic,
    /// Write Meta channel type
    parameter type write_meta_channel_t = logic,
    /// Read Meta channel type
    parameter type read_meta_channel_t = logic,
    /// OBI Request and Response channel type
    parameter type obi_req_t = logic,
    parameter type obi_rsp_t = logic
)(
    /// Clock
    input  logic clk_i,
    /// Asynchronous reset, active low
    input  logic rst_ni,
    /// Testmode in
    input  logic testmode_i,

    /// OBI read request
    output obi_req_t obi_read_req_o,
    /// OBI read response
    input  obi_rsp_t obi_read_rsp_i,

    /// OBI write request
    output obi_req_t obi_write_req_o,
    /// OBI write response
    input  obi_rsp_t obi_write_rsp_i,

    /// Read datapath request
    input  r_dp_req_t r_dp_req_i,
    /// Read datapath request valid
    input  logic r_dp_valid_i,
    /// Read datapath request ready
    output logic r_dp_ready_o,

    /// Read datapath response
    output r_dp_rsp_t r_dp_rsp_o,
    /// Read datapath response valid
    output logic r_dp_valid_o,
    /// Read datapath response valid
    input  logic r_dp_ready_i,

    /// Write datapath request
    input  w_dp_req_t w_dp_req_i,
    /// Write datapath request valid
    input  logic w_dp_valid_i,
    /// Write datapath request ready
    output logic w_dp_ready_o,

    /// Write datapath response
    output w_dp_rsp_t w_dp_rsp_o,
    /// Write datapath response valid
    output logic w_dp_valid_o,
    /// Write datapath response valid
    input  logic w_dp_ready_i,

    /// Read meta request
    input  read_meta_channel_t ar_req_i,
    /// Read meta request valid
    input  logic ar_valid_i,
    /// Read meta request ready
    output logic ar_ready_o,

    /// Write meta request
    input  write_meta_channel_t aw_req_i,
    /// Write meta request valid
    input  logic aw_valid_i,
    /// Write meta request ready
    output logic aw_ready_o,

    /// Datapath poison signal
    input  logic dp_poison_i,

    /// Response channel valid and ready
    output logic r_chan_ready_o,
    output logic r_chan_valid_o,

    /// Read part of the datapath is busy
    output logic r_dp_busy_o,
    /// Write part of the datapath is busy
    output logic w_dp_busy_o,
    /// Buffer is busy
    output logic buffer_busy_o
);

    /// Stobe width
    localparam int unsigned StrbWidth   = DataWidth / 8;

    /// Data type
    typedef logic [DataWidth-1:0] data_t;
    /// Offset type
    typedef logic [StrbWidth-1:0] strb_t;
    /// Byte type
    typedef logic [7:0] byte_t;

    // inbound control signals to the read buffer: controlled by the read process
    strb_t buffer_in_valid;

    strb_t buffer_in_ready;
    // outbound control signals of the buffer: controlled by the write process
    strb_t buffer_out_valid, buffer_out_valid_shifted;
    strb_t
        buffer_out_ready, buffer_out_ready_shifted;

    // shifted data flowing into the buffer
    byte_t [StrbWidth-1:0]
        buffer_in, buffer_in_shifted;
    // aligned and coalesced data leaving the buffer
    byte_t [StrbWidth-1:0] buffer_out, buffer_out_shifted;

    //--------------------------------------
    // Read Ports
    //--------------------------------------

    idma_obi_read #(
        .StrbWidth        ( StrbWidth           ),
        .byte_t           ( byte_t              ),
        .strb_t           ( strb_t              ),
        .r_dp_req_t       ( r_dp_req_t          ),
        .r_dp_rsp_t       ( r_dp_rsp_t          ),
        .read_meta_chan_t ( read_meta_channel_t ),
        .read_req_t       ( obi_req_t           ),
        .read_rsp_t       ( obi_rsp_t           )
    ) i_idma_obi_read (
        .r_dp_req_i        ( r_dp_req_i ),
        .r_dp_valid_i      ( r_dp_valid_i ),
        .r_dp_ready_o      ( r_dp_ready_o ),
        .r_dp_rsp_o        ( r_dp_rsp_o ),
        .r_dp_valid_o      ( r_dp_valid_o ),
        .r_dp_ready_i      ( r_dp_ready_i ),
        .read_meta_req_i   ( ar_req_i ),
        .read_meta_valid_i ( ar_valid_i ),
        .read_meta_ready_o ( ar_ready_o ),
        .read_req_o        ( obi_read_req_o ),
        .read_rsp_i        ( obi_read_rsp_i ),
        .r_chan_valid_o    ( r_chan_valid_o ),
        .r_chan_ready_o    ( r_chan_ready_o ),
        .buffer_in_o       ( buffer_in ),
        .buffer_in_valid_o ( buffer_in_valid ),
        .buffer_in_ready_i ( buffer_in_ready )
    );

    //--------------------------------------
    // Read Barrel shifter
    //--------------------------------------

    assign buffer_in_shifted = {buffer_in, buffer_in} >> (r_dp_req_i.shift * 8);

    //--------------------------------------
    // Buffer
    //--------------------------------------

    idma_dataflow_element #(
        .BufferDepth   ( BufferDepth   ),
        .StrbWidth     ( StrbWidth     ),
        .PrintFifoInfo ( PrintFifoInfo ),
        .strb_t        ( strb_t        ),
        .byte_t        ( byte_t        )
    ) i_dataflow_element (
        .clk_i       ( clk_i                    ),
        .rst_ni      ( rst_ni                   ),
        .testmode_i  ( testmode_i               ),
        .data_i      ( buffer_in_shifted        ),
        .valid_i     ( buffer_in_valid          ),
        .ready_o     ( buffer_in_ready          ),
        .data_o      ( buffer_out               ),
        .valid_o     ( buffer_out_valid         ),
        .ready_i     ( buffer_out_ready_shifted )
    );

    //--------------------------------------
    // Write Barrel shifter
    //--------------------------------------

    assign buffer_out_shifted       = {buffer_out, buffer_out}             >>  (w_dp_req_i.shift*8);
    assign buffer_out_valid_shifted = {buffer_out_valid, buffer_out_valid} >>   w_dp_req_i.shift;
    assign buffer_out_ready_shifted = {buffer_out_ready, buffer_out_ready} >> - w_dp_req_i.shift;

    //--------------------------------------
    // Write Ports
    //--------------------------------------

    idma_obi_write #(
        .StrbWidth            ( StrbWidth            ),
        .MaskInvalidData      ( MaskInvalidData      ),
        .byte_t               ( byte_t               ),
        .data_t               ( data_t               ),
        .strb_t               ( strb_t               ),
        .w_dp_req_t           ( w_dp_req_t           ),
        .w_dp_rsp_t           ( w_dp_rsp_t           ),
        .write_meta_channel_t ( write_meta_channel_t ),
        .write_req_t          ( obi_req_t            ),
        .write_rsp_t          ( obi_rsp_t            )
    ) i_idma_obi_write (
        .w_dp_req_i         ( w_dp_req_i ),
        .w_dp_valid_i       ( w_dp_valid_i ),
        .w_dp_ready_o       ( w_dp_ready_o ),
        .dp_poison_i        ( dp_poison_i ),
        .w_dp_rsp_o         ( w_dp_rsp_o ),
        .w_dp_valid_o       ( w_dp_valid_o ),
        .w_dp_ready_i       ( w_dp_ready_i ),
        .aw_req_i           ( aw_req_i ),
        .aw_valid_i         ( aw_valid_i ),
        .aw_ready_o         ( aw_ready_o  ),
        .write_req_o        ( obi_write_req_o ),
        .write_rsp_i        ( obi_write_rsp_i ),
        .buffer_out_i       ( buffer_out_shifted ),
        .buffer_out_valid_i ( buffer_out_valid_shifted ),
        .buffer_out_ready_o ( buffer_out_ready )
    );

    //--------------------------------------
    // Module Control
    //--------------------------------------
    assign r_dp_busy_o   = r_dp_valid_i;
    assign w_dp_busy_o   = w_dp_valid_i | w_dp_ready_o;
    assign buffer_busy_o = |buffer_out_valid;

endmodule

// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Authors:
// - Thomas Benz <tbenz@iis.ee.ethz.ch>
// - Tobias Senti <tsenti@ethz.ch>

`include "common_cells/registers.svh"
`include "common_cells/assertions.svh"
`include "idma/guard.svh"

/// Legalizes a generic 1D transfer according to the rules given by the
/// used protocol.
module idma_legalizer_rw_obi #(
    /// Should both data shifts be done before the dataflow element?
    /// If this is enabled, then the data inserted into the dataflow element
    /// will no longer be word aligned, but only a single shifter is needed
    parameter bit          CombinedShifter = 1'b0,
    /// Data width
    parameter int unsigned DataWidth       = 32'd16,
    /// Address width
    parameter int unsigned AddrWidth       = 32'd24,
    /// 1D iDMA request type:
    /// - `length`: the length of the transfer in bytes
    /// - `*_addr`: the source / target byte addresses of the transfer
    /// - `opt`: the options field
    parameter type idma_req_t        = logic,
    /// Read request type
    parameter type idma_r_req_t      = logic,
    /// Write request type
    parameter type idma_w_req_t      = logic,
    /// Mutable transfer type
    parameter type idma_mut_tf_t     = logic,
    /// Mutable options type
    parameter type idma_mut_tf_opt_t = logic
)(
    /// Clock
    input  logic clk_i,
    /// Asynchronous reset, active low
    input  logic rst_ni,

    /// 1D request
    input  idma_req_t req_i,
    /// 1D request valid
    input  logic valid_i,
    /// 1D request ready
    output logic ready_o,

    /// Read request; contains datapath and meta information
    output idma_r_req_t r_req_o,
    /// Read request valid
    output logic r_valid_o,
    /// Read request ready
    input  logic r_ready_i,

    /// Write request; contains datapath and meta information
    output idma_w_req_t w_req_o,
    /// Write request valid
    output logic w_valid_o,
    /// Write request ready
    input  logic w_ready_i,

    /// Invalidate the current burst transfer, stops emission of requests
    input  logic flush_i,
    /// Kill the active 1D transfer; reload a new transfer
    input  logic kill_i,

    /// Read machine of the legalizer is busy
    output logic r_busy_o,
    /// Write machine of the legalizer is busy
    output logic w_busy_o
);
    /// Stobe width
    localparam int unsigned StrbWidth     = DataWidth / 8;
    /// Offset width
    localparam int unsigned OffsetWidth   = $clog2(StrbWidth);
    /// The size of a page in byte
    localparam int unsigned PageSize      = StrbWidth;
    /// The width of page offset byte addresses
    localparam int unsigned PageAddrWidth = $clog2(PageSize);

    /// Offset type
    typedef logic [  OffsetWidth-1:0] offset_t;
    /// Address type
    typedef logic [    AddrWidth-1:0] addr_t;
    /// Page address type
    typedef logic [PageAddrWidth-1:0] page_addr_t;
    /// Page length type
    typedef logic [  PageAddrWidth:0] page_len_t;


    // state: internally hold one transfer, this is mutated
    idma_mut_tf_t     r_tf_d,   r_tf_q;
    idma_mut_tf_t     w_tf_d,   w_tf_q;
    idma_mut_tf_opt_t opt_tf_d, opt_tf_q;

    // enable signals for next mutable transfer storage
    logic r_tf_ena;
    logic w_tf_ena;

    // page boundaries
    page_len_t r_page_num_bytes_to_pb;
    page_len_t r_num_bytes_to_pb;
    page_len_t w_page_num_bytes_to_pb;
    page_len_t w_num_bytes_to_pb;
    page_len_t c_num_bytes_to_pb;

    // read process
    page_len_t r_num_bytes_possible;
    page_len_t r_num_bytes;
    offset_t   r_addr_offset;
    logic      r_done;

    // write process
    page_len_t w_num_bytes_possible;
    page_len_t w_num_bytes;
    offset_t   w_addr_offset;
    logic      w_done;


    //--------------------------------------
    // read boundary check
    //--------------------------------------
    idma_legalizer_page_splitter #(
        .OffsetWidth   ( OffsetWidth   ),
        .PageAddrWidth ( PageAddrWidth ),
        .addr_t        ( addr_t        ),
        .page_len_t    ( page_len_t    ),
        .page_addr_t   ( page_addr_t   )
    ) i_read_page_splitter (
        .not_bursting_i    ( 1'b1 ),

        .reduce_len_i      ( opt_tf_q.src_reduce_len ),
        .max_llen_i        ( opt_tf_q.src_max_llen   ),
      
        .addr_i            ( r_tf_q.addr             ),
        .num_bytes_to_pb_o ( r_page_num_bytes_to_pb  )
    );

    assign r_num_bytes_to_pb = r_page_num_bytes_to_pb;

    //--------------------------------------
    // write boundary check
    //--------------------------------------
    idma_legalizer_page_splitter #(
        .OffsetWidth   ( OffsetWidth   ),
        .PageAddrWidth ( PageAddrWidth ),
        .addr_t        ( addr_t        ),
        .page_len_t    ( page_len_t    ),
        .page_addr_t   ( page_addr_t   )
    ) i_write_page_splitter (
        .not_bursting_i    ( 1'b1 ),

        .reduce_len_i      ( opt_tf_q.dst_reduce_len ),
        .max_llen_i        ( opt_tf_q.dst_max_llen   ),
      
        .addr_i            ( w_tf_q.addr             ),
        .num_bytes_to_pb_o ( w_page_num_bytes_to_pb  )
    );

    assign w_num_bytes_to_pb = w_page_num_bytes_to_pb;

    //--------------------------------------
    // page boundary check
    //--------------------------------------
    // how many transfers are remaining when concerning both r/w pages?
    // take the boundary that is closer
    assign c_num_bytes_to_pb = (r_num_bytes_to_pb > w_num_bytes_to_pb) ?
                                w_num_bytes_to_pb : r_num_bytes_to_pb;


    //--------------------------------------
    // Synchronized R/W process
    //--------------------------------------
    always_comb begin : proc_num_bytes_possible
        // Default: Coupled
        r_num_bytes_possible = c_num_bytes_to_pb;
        w_num_bytes_possible = c_num_bytes_to_pb;

        if (opt_tf_q.decouple_rw
            || (opt_tf_q.src_protocol inside { idma_pkg::OBI })
            || (opt_tf_q.dst_protocol inside { idma_pkg::OBI })) begin
            r_num_bytes_possible = r_num_bytes_to_pb;
            w_num_bytes_possible = w_num_bytes_to_pb;
        end
    end

    assign r_addr_offset = r_tf_q.addr[OffsetWidth-1:0];
    assign w_addr_offset = w_tf_q.addr[OffsetWidth-1:0];

    // legalization process -> read and write is coupled together
    always_comb begin : proc_read_write_transaction

        // default: keep state
        r_tf_d   = r_tf_q;
        w_tf_d   = w_tf_q;
        opt_tf_d = opt_tf_q;

        // default: not done
        r_done = 1'b0;
        w_done = 1'b0;

        //--------------------------------------
        // Legalize read transaction
        //--------------------------------------
        // more bytes remaining than we can read
        if (r_tf_q.length > r_num_bytes_possible) begin
            r_num_bytes = r_num_bytes_possible;
            // calculate remainder
            r_tf_d.length = r_tf_q.length - r_num_bytes_possible;
            // next address
            r_tf_d.addr = r_tf_q.addr + r_num_bytes;

        // remaining bytes fit in one burst
        end else begin
            r_num_bytes = r_tf_q.length[PageAddrWidth:0];
            // finished
            r_tf_d.valid = 1'b0;
            r_done = 1'b1;
        end

        //--------------------------------------
        // Legalize write transaction
        //--------------------------------------
        // more bytes remaining than we can write
        if (w_tf_q.length > w_num_bytes_possible) begin
            w_num_bytes = w_num_bytes_possible;
            // calculate remainder
            w_tf_d.length = w_tf_q.length - w_num_bytes_possible;
            // next address
            w_tf_d.addr = w_tf_q.addr + w_num_bytes;

        // remaining bytes fit in one burst
        end else begin
            w_num_bytes = w_tf_q.length[PageAddrWidth:0];
            // finished
            w_tf_d.valid = 1'b0;
            w_done = 1'b1;
        end

        //--------------------------------------
        // Kill
        //--------------------------------------
        if (kill_i) begin
            // kill the current state
            r_tf_d = '0;
            w_tf_d = '0;
            r_done = 1'b1;
            w_done = 1'b1;
        end

        //--------------------------------------
        // Refill
        //--------------------------------------
        // new request is taken in if both r and w machines are ready.
        if (ready_o & valid_i) begin

            // load all three mutable objects (source, destination, option)
            // source or read
            r_tf_d = '{
                length: req_i.length,
                addr:   req_i.src_addr,
                valid:   1'b1,
                base_addr: req_i.src_addr
            };
            // destination or write
            w_tf_d = '{
                length: req_i.length,
                addr:   req_i.dst_addr,
                valid:   1'b1,
                base_addr: req_i.dst_addr
            };
            // options
            opt_tf_d = '{
                src_protocol:   req_i.opt.src_protocol,
                dst_protocol:   req_i.opt.dst_protocol,
                read_shift:     '0,
                write_shift:    '0,
                decouple_rw:    req_i.opt.beo.decouple_rw,
                decouple_aw:    req_i.opt.beo.decouple_aw,
                src_max_llen:   req_i.opt.beo.src_max_llen,
                dst_max_llen:   req_i.opt.beo.dst_max_llen,
                src_reduce_len: req_i.opt.beo.src_reduce_len,
                dst_reduce_len: req_i.opt.beo.dst_reduce_len,
                axi_id:         req_i.opt.axi_id,
                src_axi_opt:    req_i.opt.src,
                dst_axi_opt:    req_i.opt.dst,
                super_last:     req_i.opt.last
            };
            // determine shift amount
            if (CombinedShifter) begin
                opt_tf_d.read_shift  = req_i.src_addr[OffsetWidth-1:0] - req_i.dst_addr[OffsetWidth-1:0];
                opt_tf_d.write_shift = '0;
            end else begin
                opt_tf_d.read_shift  =   req_i.src_addr[OffsetWidth-1:0];
                opt_tf_d.write_shift = - req_i.dst_addr[OffsetWidth-1:0];
            end
        end
    end


    //--------------------------------------
    // Connect outputs
    //--------------------------------------

    // Read meta channel
    always_comb begin
        r_req_o.ar_req.obi.a_chan = '{
            addr: { r_tf_q.addr[AddrWidth-1:OffsetWidth], {{OffsetWidth}{1'b0}} },
            be: '1,
            we: 1'b0,
            wdata: '0,
            aid: opt_tf_q.axi_id,
            a_optional: '0
        };
        
    end

    // assign the signals needed to set-up the read data path
    assign r_req_o.r_dp_req = '{
        src_protocol: opt_tf_q.src_protocol,
        offset:       r_addr_offset,
        tailer:       OffsetWidth'(r_num_bytes + r_addr_offset),
        shift:        opt_tf_q.read_shift,
        decouple_aw:  opt_tf_q.decouple_aw,
        is_single:    r_num_bytes <= StrbWidth
    };

    // Write meta channel and data path
    always_comb begin
        w_req_o.aw_req.obi.a_chan = '{
            addr: { w_tf_q.addr[AddrWidth-1:OffsetWidth], {{OffsetWidth}{1'b0}} },
            be: '0,
            we: 1,
            wdata: '0,
            aid: opt_tf_q.axi_id,
            a_optional: '0
        };
        
        w_req_o.w_dp_req = '{
            dst_protocol: opt_tf_q.dst_protocol,
            offset:       w_addr_offset,
            tailer:       OffsetWidth'(w_num_bytes + w_addr_offset),
            shift:        opt_tf_q.write_shift,
            num_beats:    'd0,
            is_single:    1'b1
        };
    end

    // last burst in generic 1D transfer?
    assign w_req_o.last = w_done;

    // last burst indicated by midend
    assign w_req_o.super_last = opt_tf_q.super_last;

    // assign aw decouple flag
    assign w_req_o.decouple_aw = opt_tf_q.decouple_aw;

    // busy output
    assign r_busy_o = r_tf_q.valid;
    assign w_busy_o = w_tf_q.valid;


    //--------------------------------------
    // Flow Control
    //--------------------------------------
    // only advance to next state if:
    // * rw_coupled: both machines advance
    // * rw_decoupled: either machine advances
 
    always_comb begin : proc_legalizer_flow_control
        if ( opt_tf_q.decouple_rw
            || (opt_tf_q.src_protocol inside { idma_pkg::OBI })
            || (opt_tf_q.dst_protocol inside { idma_pkg::OBI })) begin
            r_tf_ena  = (r_ready_i & !flush_i) | kill_i;
            w_tf_ena  = (w_ready_i & !flush_i) | kill_i;

            r_valid_o = r_tf_q.valid & r_ready_i & !flush_i;
            w_valid_o = w_tf_q.valid & w_ready_i & !flush_i;
        end else begin
            r_tf_ena  = (r_ready_i & w_ready_i & !flush_i) | kill_i;
            w_tf_ena  = (r_ready_i & w_ready_i & !flush_i) | kill_i;

            r_valid_o = r_tf_q.valid & w_ready_i & r_ready_i & !flush_i;
            w_valid_o = w_tf_q.valid & r_ready_i & w_ready_i & !flush_i;
        end
    end
    
    // load next idma request: if both machines are done!
    assign ready_o = r_done & w_done & r_ready_i & w_ready_i & !flush_i;


    //--------------------------------------
    // State
    //--------------------------------------
    `FF (opt_tf_q, opt_tf_d,           '0, clk_i, rst_ni)
    `FFL(r_tf_q,   r_tf_d,   r_tf_ena, '0, clk_i, rst_ni)
    `FFL(w_tf_q,   w_tf_d,   w_tf_ena, '0, clk_i, rst_ni)


    //--------------------------------------
    // Assertions
    //--------------------------------------
    // only support the decomposition of incremental bursts
    `ASSERT_NEVER(OnlyIncrementalBurstsSRC, (ready_o & valid_i &
                  req_i.opt.src.burst != axi_pkg::BURST_INCR), clk_i, !rst_ni)
    `ASSERT_NEVER(OnlyIncrementalBurstsDST, (ready_o & valid_i &
                  req_i.opt.dst.burst != axi_pkg::BURST_INCR), clk_i, !rst_ni)

endmodule

// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Authors:
// - Thomas Benz <tbenz@iis.ee.ethz.ch>
// - Tobias Senti <tsenti@ethz.ch>

`include "axi/typedef.svh"
`include "idma/guard.svh"

/// The iDMA backend implements an arbitrary 1D copy engine
module idma_backend_rw_obi #(
    /// Data width
    parameter int unsigned DataWidth        = 32'd16,
    /// Address width
    parameter int unsigned AddrWidth        = 32'd24,
    /// AXI user width
    parameter int unsigned UserWidth        = 32'd1,
    /// AXI ID width
    parameter int unsigned AxiIdWidth       = 32'd1,
    /// Number of transaction that can be in-flight concurrently
    parameter int unsigned NumAxInFlight    = 32'd2,
    /// The depth of the internal reorder buffer:
    /// - '2': minimal possible configuration
    /// - '3': efficiently handle misaligned transfers (recommended)
    parameter int unsigned BufferDepth      = 32'd2,
    /// With of a transfer: max transfer size is `2**TFLenWidth` bytes
    parameter int unsigned TFLenWidth       = 32'd24,
    /// The depth of the memory system the backend is attached to
    parameter int unsigned MemSysDepth      = 32'd0,
    /// Should both data shifts be done before the dataflow element?
    /// If this is enabled, then the data inserted into the dataflow element
    /// will no longer be word aligned, but only a single shifter is needed
    parameter bit          CombinedShifter  = 1'b0,
    /// Should the `R`-`AW` coupling hardware be present? (recommended)
    parameter bit          RAWCouplingAvail = 1'b0,
    /// Mask invalid data on the manager interface
    parameter bit MaskInvalidData            = 1'b1,
    /// Should hardware legalization be present? (recommended)
    /// If not, software legalization is required to ensure the transfers are
    /// AXI4-conformal
    parameter bit HardwareLegalizer          = 1'b1,
    /// Reject zero-length transfers
    parameter bit RejectZeroTransfers        = 1'b1,
    /// Should the error handler be present?
    parameter idma_pkg::error_cap_e ErrorCap = idma_pkg::NO_ERROR_HANDLING,
    /// Print the info of the FIFO configuration
    parameter bit PrintFifoInfo              = 1'b0,
    /// 1D iDMA request type
    parameter type idma_req_t                = logic,
    /// iDMA response type
    parameter type idma_rsp_t                = logic,
    /// Error Handler request type
    parameter type idma_eh_req_t             = logic,
    /// iDMA busy signal
    parameter type idma_busy_t               = logic,
    /// OBI Request and Response channel type
    parameter type obi_req_t = logic,
    parameter type obi_rsp_t = logic,
    /// Address Read Channel type
    parameter type read_meta_channel_t  = logic,
    /// Address Write Channel type
    parameter type write_meta_channel_t = logic,
    /// Strobe Width (do not override!)
    parameter int unsigned StrbWidth    = DataWidth / 8,
    /// Offset Width (do not override!)
    parameter int unsigned OffsetWidth  = $clog2(StrbWidth)
)(
    /// Clock
    input  logic clk_i,
    /// Asynchronous reset, active low
    input  logic rst_ni,
    /// Testmode in
    input  logic testmode_i,

    /// 1D iDMA request
    input  idma_req_t idma_req_i,
    /// 1D iDMA request valid
    input  logic req_valid_i,
    /// 1D iDMA request ready
    output logic req_ready_o,

    /// iDMA response
    output idma_rsp_t idma_rsp_o,
    /// iDMA response valid
    output logic rsp_valid_o,
    /// iDMA response ready
    input  logic rsp_ready_i,

    /// Error handler request
    input  idma_eh_req_t idma_eh_req_i,
    /// Error handler request valid
    input  logic eh_req_valid_i,
    /// Error handler request ready
    output logic eh_req_ready_o,

    /// OBI read request
    output obi_req_t obi_read_req_o,
    /// OBI read response
    input  obi_rsp_t obi_read_rsp_i,

    /// OBI write request
    output obi_req_t obi_write_req_o,
    /// OBI write response
    input  obi_rsp_t obi_write_rsp_i,

    /// iDMA busy flags
    output idma_busy_t busy_o
);

    /// The localparam MetaFifoDepth holds the maximum number of transfers that can be
    /// in-flight under any circumstances.
    localparam int unsigned MetaFifoDepth = BufferDepth + NumAxInFlight + MemSysDepth;

    /// Address type
    typedef logic [AddrWidth-1:0]   addr_t;
    /// DAta type
    typedef logic [DataWidth-1:0]   data_t;
    /// Strobe type
    typedef logic [StrbWidth-1:0]   strb_t;
    /// User type
    typedef logic [UserWidth-1:0]   user_t;
    /// ID type
    typedef logic [AxiIdWidth-1:0]  id_t;
    /// Offset type
    typedef logic [OffsetWidth-1:0] offset_t;
    /// Transfer length type
    typedef logic [TFLenWidth-1:0]  tf_len_t;

    /// The datapath read request type holds all the information required to configure the read
    /// part of the datapath. The type consists of:
    /// - `offset`: The bus offset of the read
    /// - `trailer`: How many empty bytes are required to pad the transfer to a multiple of the
    ///              bus width.
    /// - `shift`: The amount the data needs to be shifted
    /// - `decouple_aw`: If the transfer has the AW decoupled from the R
    /// - `is_single`: Is this transfer just one beat long? `(len == 0)`
    typedef struct packed {
        idma_pkg::protocol_e src_protocol;
        offset_t             offset;
        offset_t             tailer;
        offset_t             shift;
        logic                decouple_aw;
        logic                is_single;
    } r_dp_req_t;

    /// The datapath read response type provides feedback from the read part of the datapath:
    /// - `resp`: The response from the R channel of the AXI4 manager interface
    /// - `last`: The last flag from the R channel of the AXI4 manager interface
    /// - `first`: Is the current item first beat in the burst
    typedef struct packed {
        axi_pkg::resp_t resp;
        logic           last;
        logic           first;
    } r_dp_rsp_t;

    /// The datapath write request type holds all the information required to configure the write
    /// part of the datapath. The type consists of:
    /// - `offset`: The bus offset of the write
    /// - `trailer`: How many empty bytes are required to pad the transfer to a multiple of the
    ///              bus width.
    /// - `shift`: The amount the data needs to be shifted
    /// - `num_beats`: The number of beats this burst consist of
    /// - `is_single`: Is this transfer just one beat long? `(len == 0)`
    typedef struct packed {
        idma_pkg::protocol_e dst_protocol;
        offset_t             offset;
        offset_t             tailer;
        offset_t             shift;
        axi_pkg::len_t       num_beats;
        logic                is_single;
    } w_dp_req_t;

    /// The datapath write response type provides feedback from the write part of the datapath:
    /// - `resp`: The response from the B channel of the AXI4 manager interface
    /// - `user`: The user field from the B channel of the AXI4 manager interface
    typedef struct packed {
        axi_pkg::resp_t resp;
        user_t          user;
    } w_dp_rsp_t;

    /// The iDMA read request bundles an `AR` type and a datapath read response type together.
    typedef struct packed {
        r_dp_req_t          r_dp_req;
        read_meta_channel_t ar_req;
    } idma_r_req_t;

    /// The iDMA write request bundles an `AW` type and a datapath write response type together. It
    /// has an additional flags:
    /// - `last`: indicating the current burst is the last one of the generic 1D transfer currently
    ///    being processed
    /// - `midend_last`: The current transfer is marked by the controlling as last
    /// - `decouple_aw`: indicates this is an R-AW decoupled transfer
    typedef struct packed {
        w_dp_req_t           w_dp_req;
        write_meta_channel_t aw_req;
        logic                last;
        logic                super_last;
        logic                decouple_aw;
    } idma_w_req_t;

    /// The mutable transfer options type holds important information that is mutated by the
    /// `legalizer` block.
    typedef struct packed {
        idma_pkg::protocol_e    src_protocol;
        idma_pkg::protocol_e    dst_protocol;
        offset_t                read_shift;
        offset_t                write_shift;
        logic                   decouple_rw;
        logic                   decouple_aw;
        logic [2:0]             src_max_llen;
        logic [2:0]             dst_max_llen;
        logic                   src_reduce_len;
        logic                   dst_reduce_len;
        id_t                    axi_id;
        idma_pkg::axi_options_t src_axi_opt;
        idma_pkg::axi_options_t dst_axi_opt;
        logic                   super_last;
    } idma_mut_tf_opt_t;

    /// The mutable transfer type holds important information that is mutated by the
    /// `legalizer` block.
    typedef struct packed {
        tf_len_t length;
        addr_t   addr;
        logic    valid;
        addr_t   base_addr;
    } idma_mut_tf_t;


    // datapath busy indicates the datapath is actively working on a transfer. It is composed of
    // the activity of the buffer as well as both the read and write machines
    logic dp_busy;
    // blanks invalid data
    logic dp_poison;

    // read and write requests and their handshaking signals
    idma_r_req_t r_req;
    idma_w_req_t w_req;
    logic        r_valid, w_valid;
    logic        r_ready, w_ready;

    // It the current transfer the last burst in the 1D transfer?
    logic w_last_burst;
    logic w_last_ready;

    // Super last flag: The current transfer is indicated as the last one by the controlling
    // unit; e.g. by a midend
    logic w_super_last;

    // Datapath FIFO signals -> used to decouple legalizer and datapath
    logic r_dp_req_in_ready,  w_dp_req_in_ready;
    logic r_dp_req_out_valid, w_dp_req_out_valid;
    logic r_dp_req_out_ready, w_dp_req_out_ready;
    r_dp_req_t r_dp_req_out;
    w_dp_req_t w_dp_req_out;

    // datapah responses
    r_dp_rsp_t r_dp_rsp;
    w_dp_rsp_t w_dp_rsp;
    logic r_dp_rsp_valid, w_dp_rsp_valid;
    logic r_dp_rsp_ready, w_dp_rsp_ready;

    // Ax handshaking
    logic ar_ready,    ar_ready_dp;
    logic aw_ready,    aw_ready_dp;
    logic aw_valid_dp, ar_valid_dp;

    // Ax request from R-AW coupler to datapath
    write_meta_channel_t aw_req_dp;

    // Ax request from the decoupling stage to the datapath
    read_meta_channel_t ar_req_dp;

    // flush and preemptively empty the legalizer
    logic legalizer_flush, legalizer_kill;

    /// intermediate signals to reject zero length transfers
    logic      is_length_zero;
    logic      req_valid;
    idma_rsp_t idma_rsp;
    logic      rsp_valid;
    logic      rsp_ready;

    // Respone Channel valid and ready -> needed for bursting
    logic r_chan_valid;
    logic r_chan_ready;

    //--------------------------------------
    // Reject Zero Length Transfers
    //--------------------------------------
    if (RejectZeroTransfers) begin : gen_reject_zero_transfers
        // is the current transfer length 0?
        assign is_length_zero = idma_req_i.length == '0;

        // bypass valid as long as length is not zero, otherwise suppress it
        assign req_valid = is_length_zero ? 1'b0 : req_valid_i;

        // modify response
        always_comb begin : proc_modify_response_zero_length
            // default: bypass
            idma_rsp_o  = idma_rsp;
            rsp_ready   = rsp_ready_i;
            rsp_valid_o = rsp_valid;

            // a zero transfer happens
            if (is_length_zero & req_valid_i & req_ready_o) begin
                // block backend
                rsp_ready = 1'b0;
                // generate new response
                rsp_valid_o             = 1'b1;
                idma_rsp_o              =  '0;
                idma_rsp_o.last         = 1'b1;
                idma_rsp_o.error        = 1'b1;
                idma_rsp_o.pld.err_type = idma_pkg::BACKEND;
            end
        end

    // just bypass signals
    end else begin : gen_bypass_zero_transfers
        // bypass
        assign req_valid   = req_valid_i;
        assign idma_rsp_o  = idma_rsp;
        assign rsp_ready   = rsp_ready_i;
        assign rsp_valid_o = rsp_valid;
    end


    //--------------------------------------
    // Legalization
    //--------------------------------------
    if (HardwareLegalizer) begin : gen_hw_legalizer
        // hardware legalizer is present
        idma_legalizer_rw_obi #(
            .CombinedShifter   ( CombinedShifter   ),
            .DataWidth         ( DataWidth         ),
            .AddrWidth         ( AddrWidth         ),
            .idma_req_t        ( idma_req_t        ),
            .idma_r_req_t      ( idma_r_req_t      ),
            .idma_w_req_t      ( idma_w_req_t      ),
            .idma_mut_tf_t     ( idma_mut_tf_t     ),
            .idma_mut_tf_opt_t ( idma_mut_tf_opt_t )
        ) i_idma_legalizer (
            .clk_i     ( clk_i             ),
            .rst_ni    ( rst_ni            ),
            .req_i     ( idma_req_i        ),
            .valid_i   ( req_valid         ),
            .ready_o   ( req_ready_o       ),
            .r_req_o   ( r_req             ),
            .w_req_o   ( w_req             ),
            .r_valid_o ( r_valid           ),
            .w_valid_o ( w_valid           ),
            .r_ready_i ( r_ready           ),
            .w_ready_i ( w_ready           ),
            .flush_i   ( legalizer_flush   ),
            .kill_i    ( legalizer_kill    ),
            .r_busy_o  ( busy_o.r_leg_busy ),
            .w_busy_o  ( busy_o.w_leg_busy )
        );

    end else begin : gen_no_hw_legalizer
        // stream fork is used to synchronize the two decoupled channels without the need for a
        // FIFO here.
        stream_fork #(
            .N_OUP   ( 32'd2 )
        ) i_stream_fork (
            .clk_i   ( clk_i                ),
            .rst_ni  ( rst_ni               ),
            .valid_i ( req_valid            ),
            .ready_o ( req_ready_o          ),
            .valid_o ( { r_valid, w_valid } ),
            .ready_i ( { r_ready, w_ready } )
        );

        // local signal holding the length -> explicitly only doing the computation once
        axi_pkg::len_t len;
        assign len = ((idma_req_i.length + idma_req_i.src_addr[OffsetWidth-1:0] -
                     'd1) >> OffsetWidth);

        // assemble read datapath request
        assign r_req.r_dp_req = '{
            src_protocol: idma_req_i.opt.src_protocol,
            offset:      idma_req_i.src_addr[OffsetWidth-1:0],
            tailer:      OffsetWidth'(idma_req_i.length + idma_req_i.src_addr[OffsetWidth-1:0]),
            shift:       OffsetWidth'(idma_req_i.src_addr[OffsetWidth-1:0]),
            decouple_aw: idma_req_i.opt.beo.decouple_aw,
            is_single:   len == '0
        };

        // assemble write datapath request
        assign w_req.w_dp_req = '{
            dst_protocol: idma_req_i.opt.dst_protocol,
            offset:    idma_req_i.dst_addr[OffsetWidth-1:0],
            tailer:    OffsetWidth'(idma_req_i.length + idma_req_i.dst_addr[OffsetWidth-1:0]),
            shift:     OffsetWidth'(- idma_req_i.dst_addr[OffsetWidth-1:0]),
            num_beats: len,
            is_single: len == '0
        };

        // if the legalizer is bypassed; every burst is the last of the 1D transfer
        assign w_req.last = 1'b1;

        // assign the last flag of the controlling unit
        assign w_req.super_last = idma_req_i.opt.last;

        // bypass decouple signal
        assign w_req.decouple_aw = idma_req_i.opt.beo.decouple_aw;

        // there is no unit to be busy
        assign busy_o.r_leg_busy = 1'b0;
        assign busy_o.w_leg_busy = 1'b0;
    end

    // data path, meta channels, and last queues have to be ready for the legalizer to be ready
    assign r_ready = r_dp_req_in_ready & ar_ready;
    assign w_ready = w_dp_req_in_ready & aw_ready & w_last_ready;


    //--------------------------------------
    // Error handler
    //--------------------------------------
    if (ErrorCap == idma_pkg::ERROR_HANDLING) begin : gen_error_handler
        `IDMA_NONSYNTH_BLOCK(
        initial begin
            $fatal(1, "Error Handling only implemented for AXI to AXI DMA!");
        end
        )
    end else if (ErrorCap == idma_pkg::NO_ERROR_HANDLING) begin : gen_no_error_handler
        // bypass the signals, assign their neutral values
        assign idma_rsp.error     = 1'b0;
        assign idma_rsp.pld       = 1'b0;
        assign idma_rsp.last      = w_super_last;
        assign rsp_valid          = w_dp_rsp_valid & w_last_burst;
        assign eh_req_ready_o     = 1'b0;
        assign legalizer_flush    = 1'b0;
        assign legalizer_kill     = 1'b0;
        assign dp_poison          = 1'b0;
        assign r_dp_rsp_ready     = rsp_ready;
        assign w_dp_rsp_ready     = rsp_ready;
        assign busy_o.eh_fsm_busy = 1'b0;
        assign busy_o.eh_cnt_busy = 1'b0;

    end else begin : gen_param_error
        `IDMA_NONSYNTH_BLOCK(
        initial begin
            $fatal(1, "Unexpected Error Capability");
        end
        )
    end


    //--------------------------------------
    // Datapath busy signal
    //--------------------------------------
    assign dp_busy = busy_o.buffer_busy |
                     busy_o.r_dp_busy   |
                     busy_o.w_dp_busy;


    //--------------------------------------
    // Datapath decoupling
    //--------------------------------------
    stream_fifo_optimal_wrap #(
        .Depth     ( NumAxInFlight ),
        .type_t    ( r_dp_req_t    ),
        .PrintInfo ( PrintFifoInfo )
    ) i_r_dp_req (
        .clk_i      ( clk_i               ),
        .rst_ni     ( rst_ni              ),
        .testmode_i ( testmode_i          ),
        .flush_i    ( 1'b0                ),
        .usage_o    ( /* NOT CONNECTED */ ),
        .data_i     ( r_req.r_dp_req      ),
        .valid_i    ( r_valid             ),
        .ready_o    ( r_dp_req_in_ready   ),
        .data_o     ( r_dp_req_out        ),
        .valid_o    ( r_dp_req_out_valid  ),
        .ready_i    ( r_dp_req_out_ready  )
    );

    stream_fifo_optimal_wrap #(
        .Depth     ( NumAxInFlight ),
        .type_t    ( w_dp_req_t    ),
        .PrintInfo ( PrintFifoInfo )
    ) i_w_dp_req (
        .clk_i      ( clk_i               ),
        .rst_ni     ( rst_ni              ),
        .testmode_i ( testmode_i          ),
        .flush_i    ( 1'b0                ),
        .usage_o    ( /* NOT CONNECTED */ ),
        .data_i     ( w_req.w_dp_req      ),
        .valid_i    ( w_valid             ),
        .ready_o    ( w_dp_req_in_ready   ),
        .data_o     ( w_dp_req_out        ),
        .valid_o    ( w_dp_req_out_valid  ),
        .ready_i    ( w_dp_req_out_ready  )
    );

    // Add fall-through register to allow the input to be ready if the output is not. This
    // does not add a cycle of delay

    fall_through_register #(
        .T          ( read_meta_channel_t )
    ) i_ar_fall_through_register (
        .clk_i      ( clk_i             ),
        .rst_ni     ( rst_ni            ),
        .testmode_i ( testmode_i        ),
        .clr_i      ( 1'b0              ),
        .valid_i    ( r_valid           ),
        .ready_o    ( ar_ready          ),
        .data_i     ( r_req.ar_req ),
        .valid_o    ( ar_valid_dp       ),
        .ready_i    ( ar_ready_dp       ),
        .data_o     ( ar_req_dp         )
    );


    //--------------------------------------
    // Last flag store
    //--------------------------------------
    stream_fifo_optimal_wrap #(
        .Depth        ( MetaFifoDepth ),
        .type_t       ( logic [1:0]   ),
        .PrintInfo    ( PrintFifoInfo )
    ) i_w_last (
        .clk_i      ( clk_i                           ),
        .rst_ni     ( rst_ni                          ),
        .testmode_i ( testmode_i                      ),
        .flush_i    ( 1'b0                            ),
        .usage_o    ( /* NOT CONNECTED */             ),
        .data_i     ( {w_req.super_last, w_req.last}  ),
        .valid_i    ( w_valid & w_ready               ),
        .ready_o    ( w_last_ready                    ),
        .data_o     ( {w_super_last, w_last_burst}    ),
        .valid_o    ( /* NOT CONNECTED */             ),
        .ready_i    ( w_dp_rsp_valid & w_dp_rsp_ready )
    );

    //--------------------------------------
    // Transport Layer / Datapath
    //--------------------------------------
    idma_transport_layer_rw_obi #(
        .NumAxInFlight               ( NumAxInFlight               ),
        .DataWidth                   ( DataWidth                   ),
        .BufferDepth                 ( BufferDepth                 ),
        .MaskInvalidData             ( MaskInvalidData             ),
        .PrintFifoInfo               ( PrintFifoInfo               ),
        .r_dp_req_t                  ( r_dp_req_t                  ),
        .w_dp_req_t                  ( w_dp_req_t                  ),
        .r_dp_rsp_t                  ( r_dp_rsp_t                  ),
        .w_dp_rsp_t                  ( w_dp_rsp_t                  ),
        .write_meta_channel_t        ( write_meta_channel_t        ),
        .read_meta_channel_t         ( read_meta_channel_t         ),
        .obi_req_t                   ( obi_req_t                   ),
        .obi_rsp_t                   ( obi_rsp_t                   )
    ) i_idma_transport_layer (
        .clk_i           ( clk_i                ),
        .rst_ni          ( rst_ni               ),
        .testmode_i      ( testmode_i           ),
        .obi_read_req_o  ( obi_read_req_o       ),
        .obi_read_rsp_i  ( obi_read_rsp_i       ),
        .obi_write_req_o ( obi_write_req_o      ),
        .obi_write_rsp_i ( obi_write_rsp_i      ),
        .r_dp_req_i      ( r_dp_req_out         ),
        .r_dp_valid_i    ( r_dp_req_out_valid   ),
        .r_dp_ready_o    ( r_dp_req_out_ready   ),
        .r_dp_rsp_o      ( r_dp_rsp             ),
        .r_dp_valid_o    ( r_dp_rsp_valid       ),
        .r_dp_ready_i    ( r_dp_rsp_ready       ),
        .w_dp_req_i      ( w_dp_req_out         ),
        .w_dp_valid_i    ( w_dp_req_out_valid   ),
        .w_dp_ready_o    ( w_dp_req_out_ready   ),
        .w_dp_rsp_o      ( w_dp_rsp             ),
        .w_dp_valid_o    ( w_dp_rsp_valid       ),
        .w_dp_ready_i    ( w_dp_rsp_ready       ),
        .ar_req_i        ( ar_req_dp            ),
        .ar_valid_i      ( ar_valid_dp          ),
        .ar_ready_o      ( ar_ready_dp          ),
        .aw_req_i        ( aw_req_dp            ),
        .aw_valid_i      ( aw_valid_dp          ),
        .aw_ready_o      ( aw_ready_dp          ),
        .dp_poison_i     ( dp_poison            ),
        .r_dp_busy_o     ( busy_o.r_dp_busy     ),
        .w_dp_busy_o     ( busy_o.w_dp_busy     ),
        .buffer_busy_o   ( busy_o.buffer_busy   ),
        .r_chan_ready_o  ( r_chan_ready         ),
        .r_chan_valid_o  ( r_chan_valid         )
    );

    //--------------------------------------
    // R-AW channel coupler
    //--------------------------------------

    if (RAWCouplingAvail) begin : gen_r_aw_coupler
        // instantiate the channel coupler
        idma_channel_coupler #(
            .NumAxInFlight   ( NumAxInFlight               ),
            .AddrWidth       ( AddrWidth                   ),
            .UserWidth       ( UserWidth                   ),
            .AxiIdWidth      ( AxiIdWidth                  ),
            .PrintFifoInfo   ( PrintFifoInfo               ),
            .axi_aw_chan_t   ( write_meta_channel_t        )
        ) i_idma_channel_coupler (
            .clk_i            ( clk_i                       ),
            .rst_ni           ( rst_ni                      ),
            .testmode_i       ( testmode_i                  ),
            .r_rsp_valid_i    ( r_chan_valid                ),
            .r_rsp_ready_i    ( r_chan_ready                ),
            .r_rsp_first_i    ( r_dp_rsp.first              ),
            .r_decouple_aw_i  ( r_dp_req_out.decouple_aw    ),
            .aw_decouple_aw_i ( w_req.decouple_aw ),
            .aw_req_i         ( w_req.aw_req                ),
            .aw_valid_i       ( w_valid                     ),
            .aw_ready_o       ( aw_ready                    ),
            .aw_req_o         ( aw_req_dp                   ),
            .aw_valid_o       ( aw_valid_dp                 ),
            .aw_ready_i       ( aw_ready_dp                 ),
            .busy_o           ( busy_o.raw_coupler_busy     )
        );
    end else begin : gen_r_aw_bypass
        // Atleast one write protocol uses combined aw and w -> Need to buffer read meta requests
        // As a write could depend on up to two reads
        stream_fifo_optimal_wrap #(
            .Depth        ( 2                    ),
            .type_t       ( write_meta_channel_t ),
            .PrintInfo    ( PrintFifoInfo        )
        ) i_aw_fifo (
            .clk_i,
            .rst_ni,
            .testmode_i,
            .flush_i   ( 1'b0                       ),
            .usage_o   ( /* NOT CONNECTED */        ),
            .data_i    (  w_req.aw_req              ),
            .valid_i   ( w_valid && aw_ready        ),
            .ready_o   ( aw_ready                   ),
            .data_o    ( aw_req_dp                  ),
            .valid_o   ( aw_valid_dp                ),
            .ready_i   ( aw_ready_dp && aw_valid_dp )
        );

        // no unit: not busy
        assign busy_o.raw_coupler_busy = 1'b0;
    end


    //--------------------------------------
    // Assertions
    //--------------------------------------
    `IDMA_NONSYNTH_BLOCK(
    initial begin : proc_assert_params
        axi_addr_width : assert(AddrWidth >= 32'd12) else
            $fatal(1, "Parameter `AddrWidth` has to be >= 12!");
        axi_id_width   : assert(AxiIdWidth > 32'd0) else
            $fatal(1, "Parameter `AxiIdWidth` has to be > 0!");
        axi_data_width : assert(DataWidth inside {32'd16, 32'd32, 32'd64, 32'd128, 32'd256,
                                                  32'd512, 32'd1028}) else
            $fatal(1, "Parameter `DataWidth` has to be at least 16 and inside the AXI4 spec!");
        axi_user_width : assert(UserWidth > 32'd0) else
            $fatal(1, "Parameter `UserWidth` has to be > 0!");
        num_ax_in_flight : assert(NumAxInFlight > 32'd1) else
            $fatal(1, "Parameter `NumAxInFlight` has to be > 1!");
        buffer_depth : assert(BufferDepth > 32'd1) else
            $fatal(1, "Parameter `BufferDepth` has to be > 1!");
        tf_len_width : assert(TFLenWidth >= 32'd12) else
            $fatal(1, "Parameter `BufferDepth` has to be >= 12!");
        tf_len_width_max : assert(TFLenWidth <= AddrWidth) else
            $fatal(1, "Parameter `TFLenWidth` has to be <= `AddrWidth`!");
    end
    )

endmodule

// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Register Package auto-generated by `reggen` containing data structure

package idma_reg32_1d_reg_pkg;

  // Param list
  parameter int num_dims = 1;

  // Address widths within the block
  parameter int BlockAw = 8;

  ////////////////////////////
  // Typedefs for registers //
  ////////////////////////////

  typedef struct packed {
    struct packed {
      logic        q;
    } decouple_aw;
    struct packed {
      logic        q;
    } decouple_rw;
    struct packed {
      logic        q;
    } src_reduce_len;
    struct packed {
      logic        q;
    } dst_reduce_len;
    struct packed {
      logic [2:0]  q;
    } src_max_llen;
    struct packed {
      logic [2:0]  q;
    } dst_max_llen;
    struct packed {
      logic        q;
    } enable_nd;
  } idma_reg32_1d_reg2hw_conf_reg_t;

  typedef struct packed {
    logic [31:0] q;
    logic        re;
  } idma_reg32_1d_reg2hw_next_id_mreg_t;

  typedef struct packed {
    logic [31:0] q;
  } idma_reg32_1d_reg2hw_dst_addr_low_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } idma_reg32_1d_reg2hw_src_addr_low_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } idma_reg32_1d_reg2hw_length_low_reg_t;

  typedef struct packed {
    logic [9:0] d;
  } idma_reg32_1d_hw2reg_status_mreg_t;

  typedef struct packed {
    logic [31:0] d;
  } idma_reg32_1d_hw2reg_next_id_mreg_t;

  typedef struct packed {
    logic [31:0] d;
  } idma_reg32_1d_hw2reg_done_id_mreg_t;

  // Register -> HW type
  typedef struct packed {
    idma_reg32_1d_reg2hw_conf_reg_t conf; // [634:624]
    idma_reg32_1d_reg2hw_next_id_mreg_t [15:0] next_id; // [623:96]
    idma_reg32_1d_reg2hw_dst_addr_low_reg_t dst_addr_low; // [95:64]
    idma_reg32_1d_reg2hw_src_addr_low_reg_t src_addr_low; // [63:32]
    idma_reg32_1d_reg2hw_length_low_reg_t length_low; // [31:0]
  } idma_reg32_1d_reg2hw_t;

  // HW -> register type
  typedef struct packed {
    idma_reg32_1d_hw2reg_status_mreg_t [15:0] status; // [1183:1024]
    idma_reg32_1d_hw2reg_next_id_mreg_t [15:0] next_id; // [1023:512]
    idma_reg32_1d_hw2reg_done_id_mreg_t [15:0] done_id; // [511:0]
  } idma_reg32_1d_hw2reg_t;

  // Register offsets
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_CONF_OFFSET = 8'h 0;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_STATUS_0_OFFSET = 8'h 4;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_STATUS_1_OFFSET = 8'h 8;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_STATUS_2_OFFSET = 8'h c;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_STATUS_3_OFFSET = 8'h 10;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_STATUS_4_OFFSET = 8'h 14;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_STATUS_5_OFFSET = 8'h 18;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_STATUS_6_OFFSET = 8'h 1c;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_STATUS_7_OFFSET = 8'h 20;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_STATUS_8_OFFSET = 8'h 24;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_STATUS_9_OFFSET = 8'h 28;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_STATUS_10_OFFSET = 8'h 2c;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_STATUS_11_OFFSET = 8'h 30;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_STATUS_12_OFFSET = 8'h 34;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_STATUS_13_OFFSET = 8'h 38;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_STATUS_14_OFFSET = 8'h 3c;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_STATUS_15_OFFSET = 8'h 40;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_NEXT_ID_0_OFFSET = 8'h 44;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_NEXT_ID_1_OFFSET = 8'h 48;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_NEXT_ID_2_OFFSET = 8'h 4c;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_NEXT_ID_3_OFFSET = 8'h 50;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_NEXT_ID_4_OFFSET = 8'h 54;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_NEXT_ID_5_OFFSET = 8'h 58;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_NEXT_ID_6_OFFSET = 8'h 5c;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_NEXT_ID_7_OFFSET = 8'h 60;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_NEXT_ID_8_OFFSET = 8'h 64;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_NEXT_ID_9_OFFSET = 8'h 68;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_NEXT_ID_10_OFFSET = 8'h 6c;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_NEXT_ID_11_OFFSET = 8'h 70;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_NEXT_ID_12_OFFSET = 8'h 74;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_NEXT_ID_13_OFFSET = 8'h 78;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_NEXT_ID_14_OFFSET = 8'h 7c;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_NEXT_ID_15_OFFSET = 8'h 80;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_DONE_ID_0_OFFSET = 8'h 84;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_DONE_ID_1_OFFSET = 8'h 88;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_DONE_ID_2_OFFSET = 8'h 8c;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_DONE_ID_3_OFFSET = 8'h 90;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_DONE_ID_4_OFFSET = 8'h 94;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_DONE_ID_5_OFFSET = 8'h 98;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_DONE_ID_6_OFFSET = 8'h 9c;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_DONE_ID_7_OFFSET = 8'h a0;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_DONE_ID_8_OFFSET = 8'h a4;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_DONE_ID_9_OFFSET = 8'h a8;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_DONE_ID_10_OFFSET = 8'h ac;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_DONE_ID_11_OFFSET = 8'h b0;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_DONE_ID_12_OFFSET = 8'h b4;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_DONE_ID_13_OFFSET = 8'h b8;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_DONE_ID_14_OFFSET = 8'h bc;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_DONE_ID_15_OFFSET = 8'h c0;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_DST_ADDR_LOW_OFFSET = 8'h d0;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_SRC_ADDR_LOW_OFFSET = 8'h d8;
  parameter logic [BlockAw-1:0] IDMA_REG32_1D_LENGTH_LOW_OFFSET = 8'h e0;

  // Reset values for hwext registers and their fields
  parameter logic [9:0] IDMA_REG32_1D_STATUS_0_RESVAL = 10'h 0;
  parameter logic [9:0] IDMA_REG32_1D_STATUS_1_RESVAL = 10'h 0;
  parameter logic [9:0] IDMA_REG32_1D_STATUS_2_RESVAL = 10'h 0;
  parameter logic [9:0] IDMA_REG32_1D_STATUS_3_RESVAL = 10'h 0;
  parameter logic [9:0] IDMA_REG32_1D_STATUS_4_RESVAL = 10'h 0;
  parameter logic [9:0] IDMA_REG32_1D_STATUS_5_RESVAL = 10'h 0;
  parameter logic [9:0] IDMA_REG32_1D_STATUS_6_RESVAL = 10'h 0;
  parameter logic [9:0] IDMA_REG32_1D_STATUS_7_RESVAL = 10'h 0;
  parameter logic [9:0] IDMA_REG32_1D_STATUS_8_RESVAL = 10'h 0;
  parameter logic [9:0] IDMA_REG32_1D_STATUS_9_RESVAL = 10'h 0;
  parameter logic [9:0] IDMA_REG32_1D_STATUS_10_RESVAL = 10'h 0;
  parameter logic [9:0] IDMA_REG32_1D_STATUS_11_RESVAL = 10'h 0;
  parameter logic [9:0] IDMA_REG32_1D_STATUS_12_RESVAL = 10'h 0;
  parameter logic [9:0] IDMA_REG32_1D_STATUS_13_RESVAL = 10'h 0;
  parameter logic [9:0] IDMA_REG32_1D_STATUS_14_RESVAL = 10'h 0;
  parameter logic [9:0] IDMA_REG32_1D_STATUS_15_RESVAL = 10'h 0;
  parameter logic [31:0] IDMA_REG32_1D_NEXT_ID_0_RESVAL = 32'h 0;
  parameter logic [31:0] IDMA_REG32_1D_NEXT_ID_1_RESVAL = 32'h 0;
  parameter logic [31:0] IDMA_REG32_1D_NEXT_ID_2_RESVAL = 32'h 0;
  parameter logic [31:0] IDMA_REG32_1D_NEXT_ID_3_RESVAL = 32'h 0;
  parameter logic [31:0] IDMA_REG32_1D_NEXT_ID_4_RESVAL = 32'h 0;
  parameter logic [31:0] IDMA_REG32_1D_NEXT_ID_5_RESVAL = 32'h 0;
  parameter logic [31:0] IDMA_REG32_1D_NEXT_ID_6_RESVAL = 32'h 0;
  parameter logic [31:0] IDMA_REG32_1D_NEXT_ID_7_RESVAL = 32'h 0;
  parameter logic [31:0] IDMA_REG32_1D_NEXT_ID_8_RESVAL = 32'h 0;
  parameter logic [31:0] IDMA_REG32_1D_NEXT_ID_9_RESVAL = 32'h 0;
  parameter logic [31:0] IDMA_REG32_1D_NEXT_ID_10_RESVAL = 32'h 0;
  parameter logic [31:0] IDMA_REG32_1D_NEXT_ID_11_RESVAL = 32'h 0;
  parameter logic [31:0] IDMA_REG32_1D_NEXT_ID_12_RESVAL = 32'h 0;
  parameter logic [31:0] IDMA_REG32_1D_NEXT_ID_13_RESVAL = 32'h 0;
  parameter logic [31:0] IDMA_REG32_1D_NEXT_ID_14_RESVAL = 32'h 0;
  parameter logic [31:0] IDMA_REG32_1D_NEXT_ID_15_RESVAL = 32'h 0;
  parameter logic [31:0] IDMA_REG32_1D_DONE_ID_0_RESVAL = 32'h 0;
  parameter logic [31:0] IDMA_REG32_1D_DONE_ID_1_RESVAL = 32'h 0;
  parameter logic [31:0] IDMA_REG32_1D_DONE_ID_2_RESVAL = 32'h 0;
  parameter logic [31:0] IDMA_REG32_1D_DONE_ID_3_RESVAL = 32'h 0;
  parameter logic [31:0] IDMA_REG32_1D_DONE_ID_4_RESVAL = 32'h 0;
  parameter logic [31:0] IDMA_REG32_1D_DONE_ID_5_RESVAL = 32'h 0;
  parameter logic [31:0] IDMA_REG32_1D_DONE_ID_6_RESVAL = 32'h 0;
  parameter logic [31:0] IDMA_REG32_1D_DONE_ID_7_RESVAL = 32'h 0;
  parameter logic [31:0] IDMA_REG32_1D_DONE_ID_8_RESVAL = 32'h 0;
  parameter logic [31:0] IDMA_REG32_1D_DONE_ID_9_RESVAL = 32'h 0;
  parameter logic [31:0] IDMA_REG32_1D_DONE_ID_10_RESVAL = 32'h 0;
  parameter logic [31:0] IDMA_REG32_1D_DONE_ID_11_RESVAL = 32'h 0;
  parameter logic [31:0] IDMA_REG32_1D_DONE_ID_12_RESVAL = 32'h 0;
  parameter logic [31:0] IDMA_REG32_1D_DONE_ID_13_RESVAL = 32'h 0;
  parameter logic [31:0] IDMA_REG32_1D_DONE_ID_14_RESVAL = 32'h 0;
  parameter logic [31:0] IDMA_REG32_1D_DONE_ID_15_RESVAL = 32'h 0;

  // Register index
  typedef enum int {
    IDMA_REG32_1D_CONF,
    IDMA_REG32_1D_STATUS_0,
    IDMA_REG32_1D_STATUS_1,
    IDMA_REG32_1D_STATUS_2,
    IDMA_REG32_1D_STATUS_3,
    IDMA_REG32_1D_STATUS_4,
    IDMA_REG32_1D_STATUS_5,
    IDMA_REG32_1D_STATUS_6,
    IDMA_REG32_1D_STATUS_7,
    IDMA_REG32_1D_STATUS_8,
    IDMA_REG32_1D_STATUS_9,
    IDMA_REG32_1D_STATUS_10,
    IDMA_REG32_1D_STATUS_11,
    IDMA_REG32_1D_STATUS_12,
    IDMA_REG32_1D_STATUS_13,
    IDMA_REG32_1D_STATUS_14,
    IDMA_REG32_1D_STATUS_15,
    IDMA_REG32_1D_NEXT_ID_0,
    IDMA_REG32_1D_NEXT_ID_1,
    IDMA_REG32_1D_NEXT_ID_2,
    IDMA_REG32_1D_NEXT_ID_3,
    IDMA_REG32_1D_NEXT_ID_4,
    IDMA_REG32_1D_NEXT_ID_5,
    IDMA_REG32_1D_NEXT_ID_6,
    IDMA_REG32_1D_NEXT_ID_7,
    IDMA_REG32_1D_NEXT_ID_8,
    IDMA_REG32_1D_NEXT_ID_9,
    IDMA_REG32_1D_NEXT_ID_10,
    IDMA_REG32_1D_NEXT_ID_11,
    IDMA_REG32_1D_NEXT_ID_12,
    IDMA_REG32_1D_NEXT_ID_13,
    IDMA_REG32_1D_NEXT_ID_14,
    IDMA_REG32_1D_NEXT_ID_15,
    IDMA_REG32_1D_DONE_ID_0,
    IDMA_REG32_1D_DONE_ID_1,
    IDMA_REG32_1D_DONE_ID_2,
    IDMA_REG32_1D_DONE_ID_3,
    IDMA_REG32_1D_DONE_ID_4,
    IDMA_REG32_1D_DONE_ID_5,
    IDMA_REG32_1D_DONE_ID_6,
    IDMA_REG32_1D_DONE_ID_7,
    IDMA_REG32_1D_DONE_ID_8,
    IDMA_REG32_1D_DONE_ID_9,
    IDMA_REG32_1D_DONE_ID_10,
    IDMA_REG32_1D_DONE_ID_11,
    IDMA_REG32_1D_DONE_ID_12,
    IDMA_REG32_1D_DONE_ID_13,
    IDMA_REG32_1D_DONE_ID_14,
    IDMA_REG32_1D_DONE_ID_15,
    IDMA_REG32_1D_DST_ADDR_LOW,
    IDMA_REG32_1D_SRC_ADDR_LOW,
    IDMA_REG32_1D_LENGTH_LOW
  } idma_reg32_1d_id_e;

  // Register width information to check illegal writes
  parameter logic [3:0] IDMA_REG32_1D_PERMIT [52] = '{
    4'b 0011, // index[ 0] IDMA_REG32_1D_CONF
    4'b 0011, // index[ 1] IDMA_REG32_1D_STATUS_0
    4'b 0011, // index[ 2] IDMA_REG32_1D_STATUS_1
    4'b 0011, // index[ 3] IDMA_REG32_1D_STATUS_2
    4'b 0011, // index[ 4] IDMA_REG32_1D_STATUS_3
    4'b 0011, // index[ 5] IDMA_REG32_1D_STATUS_4
    4'b 0011, // index[ 6] IDMA_REG32_1D_STATUS_5
    4'b 0011, // index[ 7] IDMA_REG32_1D_STATUS_6
    4'b 0011, // index[ 8] IDMA_REG32_1D_STATUS_7
    4'b 0011, // index[ 9] IDMA_REG32_1D_STATUS_8
    4'b 0011, // index[10] IDMA_REG32_1D_STATUS_9
    4'b 0011, // index[11] IDMA_REG32_1D_STATUS_10
    4'b 0011, // index[12] IDMA_REG32_1D_STATUS_11
    4'b 0011, // index[13] IDMA_REG32_1D_STATUS_12
    4'b 0011, // index[14] IDMA_REG32_1D_STATUS_13
    4'b 0011, // index[15] IDMA_REG32_1D_STATUS_14
    4'b 0011, // index[16] IDMA_REG32_1D_STATUS_15
    4'b 1111, // index[17] IDMA_REG32_1D_NEXT_ID_0
    4'b 1111, // index[18] IDMA_REG32_1D_NEXT_ID_1
    4'b 1111, // index[19] IDMA_REG32_1D_NEXT_ID_2
    4'b 1111, // index[20] IDMA_REG32_1D_NEXT_ID_3
    4'b 1111, // index[21] IDMA_REG32_1D_NEXT_ID_4
    4'b 1111, // index[22] IDMA_REG32_1D_NEXT_ID_5
    4'b 1111, // index[23] IDMA_REG32_1D_NEXT_ID_6
    4'b 1111, // index[24] IDMA_REG32_1D_NEXT_ID_7
    4'b 1111, // index[25] IDMA_REG32_1D_NEXT_ID_8
    4'b 1111, // index[26] IDMA_REG32_1D_NEXT_ID_9
    4'b 1111, // index[27] IDMA_REG32_1D_NEXT_ID_10
    4'b 1111, // index[28] IDMA_REG32_1D_NEXT_ID_11
    4'b 1111, // index[29] IDMA_REG32_1D_NEXT_ID_12
    4'b 1111, // index[30] IDMA_REG32_1D_NEXT_ID_13
    4'b 1111, // index[31] IDMA_REG32_1D_NEXT_ID_14
    4'b 1111, // index[32] IDMA_REG32_1D_NEXT_ID_15
    4'b 1111, // index[33] IDMA_REG32_1D_DONE_ID_0
    4'b 1111, // index[34] IDMA_REG32_1D_DONE_ID_1
    4'b 1111, // index[35] IDMA_REG32_1D_DONE_ID_2
    4'b 1111, // index[36] IDMA_REG32_1D_DONE_ID_3
    4'b 1111, // index[37] IDMA_REG32_1D_DONE_ID_4
    4'b 1111, // index[38] IDMA_REG32_1D_DONE_ID_5
    4'b 1111, // index[39] IDMA_REG32_1D_DONE_ID_6
    4'b 1111, // index[40] IDMA_REG32_1D_DONE_ID_7
    4'b 1111, // index[41] IDMA_REG32_1D_DONE_ID_8
    4'b 1111, // index[42] IDMA_REG32_1D_DONE_ID_9
    4'b 1111, // index[43] IDMA_REG32_1D_DONE_ID_10
    4'b 1111, // index[44] IDMA_REG32_1D_DONE_ID_11
    4'b 1111, // index[45] IDMA_REG32_1D_DONE_ID_12
    4'b 1111, // index[46] IDMA_REG32_1D_DONE_ID_13
    4'b 1111, // index[47] IDMA_REG32_1D_DONE_ID_14
    4'b 1111, // index[48] IDMA_REG32_1D_DONE_ID_15
    4'b 1111, // index[49] IDMA_REG32_1D_DST_ADDR_LOW
    4'b 1111, // index[50] IDMA_REG32_1D_SRC_ADDR_LOW
    4'b 1111  // index[51] IDMA_REG32_1D_LENGTH_LOW
  };

endpackage

// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Register Top module auto-generated by `reggen`


`include "common_cells/assertions.svh"

module idma_reg32_1d_reg_top #(
  parameter type reg_req_t = logic,
  parameter type reg_rsp_t = logic,
  parameter int AW = 8
) (
  input logic clk_i,
  input logic rst_ni,
  input  reg_req_t reg_req_i,
  output reg_rsp_t reg_rsp_o,
  // To HW
  output idma_reg32_1d_reg_pkg::idma_reg32_1d_reg2hw_t reg2hw, // Write
  input  idma_reg32_1d_reg_pkg::idma_reg32_1d_hw2reg_t hw2reg, // Read


  // Config
  input devmode_i // If 1, explicit error return for unmapped register access
);

  import idma_reg32_1d_reg_pkg::* ;

  localparam int DW = 32;
  localparam int DBW = DW/8;                    // Byte Width

  // register signals
  logic           reg_we;
  logic           reg_re;
  logic [BlockAw-1:0]  reg_addr;
  logic [DW-1:0]  reg_wdata;
  logic [DBW-1:0] reg_be;
  logic [DW-1:0]  reg_rdata;
  logic           reg_error;

  logic          addrmiss, wr_err;

  logic [DW-1:0] reg_rdata_next;

  // Below register interface can be changed
  reg_req_t  reg_intf_req;
  reg_rsp_t  reg_intf_rsp;


  assign reg_intf_req = reg_req_i;
  assign reg_rsp_o = reg_intf_rsp;


  assign reg_we = reg_intf_req.valid & reg_intf_req.write;
  assign reg_re = reg_intf_req.valid & ~reg_intf_req.write;
  assign reg_addr = reg_intf_req.addr[BlockAw-1:0];
  assign reg_wdata = reg_intf_req.wdata;
  assign reg_be = reg_intf_req.wstrb;
  assign reg_intf_rsp.rdata = reg_rdata;
  assign reg_intf_rsp.error = reg_error;
  assign reg_intf_rsp.ready = 1'b1;

  assign reg_rdata = reg_rdata_next ;
  assign reg_error = (devmode_i & addrmiss) | wr_err;


  // Define SW related signals
  // Format: <reg>_<field>_{wd|we|qs}
  //        or <reg>_{wd|we|qs} if field == 1 or 0
  logic conf_decouple_aw_qs;
  logic conf_decouple_aw_wd;
  logic conf_decouple_aw_we;
  logic conf_decouple_rw_qs;
  logic conf_decouple_rw_wd;
  logic conf_decouple_rw_we;
  logic conf_src_reduce_len_qs;
  logic conf_src_reduce_len_wd;
  logic conf_src_reduce_len_we;
  logic conf_dst_reduce_len_qs;
  logic conf_dst_reduce_len_wd;
  logic conf_dst_reduce_len_we;
  logic [2:0] conf_src_max_llen_qs;
  logic [2:0] conf_src_max_llen_wd;
  logic conf_src_max_llen_we;
  logic [2:0] conf_dst_max_llen_qs;
  logic [2:0] conf_dst_max_llen_wd;
  logic conf_dst_max_llen_we;
  logic conf_enable_nd_qs;
  logic conf_enable_nd_wd;
  logic conf_enable_nd_we;
  logic [9:0] status_0_qs;
  logic status_0_re;
  logic [9:0] status_1_qs;
  logic status_1_re;
  logic [9:0] status_2_qs;
  logic status_2_re;
  logic [9:0] status_3_qs;
  logic status_3_re;
  logic [9:0] status_4_qs;
  logic status_4_re;
  logic [9:0] status_5_qs;
  logic status_5_re;
  logic [9:0] status_6_qs;
  logic status_6_re;
  logic [9:0] status_7_qs;
  logic status_7_re;
  logic [9:0] status_8_qs;
  logic status_8_re;
  logic [9:0] status_9_qs;
  logic status_9_re;
  logic [9:0] status_10_qs;
  logic status_10_re;
  logic [9:0] status_11_qs;
  logic status_11_re;
  logic [9:0] status_12_qs;
  logic status_12_re;
  logic [9:0] status_13_qs;
  logic status_13_re;
  logic [9:0] status_14_qs;
  logic status_14_re;
  logic [9:0] status_15_qs;
  logic status_15_re;
  logic [31:0] next_id_0_qs;
  logic next_id_0_re;
  logic [31:0] next_id_1_qs;
  logic next_id_1_re;
  logic [31:0] next_id_2_qs;
  logic next_id_2_re;
  logic [31:0] next_id_3_qs;
  logic next_id_3_re;
  logic [31:0] next_id_4_qs;
  logic next_id_4_re;
  logic [31:0] next_id_5_qs;
  logic next_id_5_re;
  logic [31:0] next_id_6_qs;
  logic next_id_6_re;
  logic [31:0] next_id_7_qs;
  logic next_id_7_re;
  logic [31:0] next_id_8_qs;
  logic next_id_8_re;
  logic [31:0] next_id_9_qs;
  logic next_id_9_re;
  logic [31:0] next_id_10_qs;
  logic next_id_10_re;
  logic [31:0] next_id_11_qs;
  logic next_id_11_re;
  logic [31:0] next_id_12_qs;
  logic next_id_12_re;
  logic [31:0] next_id_13_qs;
  logic next_id_13_re;
  logic [31:0] next_id_14_qs;
  logic next_id_14_re;
  logic [31:0] next_id_15_qs;
  logic next_id_15_re;
  logic [31:0] done_id_0_qs;
  logic done_id_0_re;
  logic [31:0] done_id_1_qs;
  logic done_id_1_re;
  logic [31:0] done_id_2_qs;
  logic done_id_2_re;
  logic [31:0] done_id_3_qs;
  logic done_id_3_re;
  logic [31:0] done_id_4_qs;
  logic done_id_4_re;
  logic [31:0] done_id_5_qs;
  logic done_id_5_re;
  logic [31:0] done_id_6_qs;
  logic done_id_6_re;
  logic [31:0] done_id_7_qs;
  logic done_id_7_re;
  logic [31:0] done_id_8_qs;
  logic done_id_8_re;
  logic [31:0] done_id_9_qs;
  logic done_id_9_re;
  logic [31:0] done_id_10_qs;
  logic done_id_10_re;
  logic [31:0] done_id_11_qs;
  logic done_id_11_re;
  logic [31:0] done_id_12_qs;
  logic done_id_12_re;
  logic [31:0] done_id_13_qs;
  logic done_id_13_re;
  logic [31:0] done_id_14_qs;
  logic done_id_14_re;
  logic [31:0] done_id_15_qs;
  logic done_id_15_re;
  logic [31:0] dst_addr_low_qs;
  logic [31:0] dst_addr_low_wd;
  logic dst_addr_low_we;
  logic [31:0] src_addr_low_qs;
  logic [31:0] src_addr_low_wd;
  logic src_addr_low_we;
  logic [31:0] length_low_qs;
  logic [31:0] length_low_wd;
  logic length_low_we;

  // Register instances
  // R[conf]: V(False)

  //   F[decouple_aw]: 0:0
  prim_subreg #(
    .DW      (1),
    .SWACCESS("RW"),
    .RESVAL  (1'h0)
  ) u_conf_decouple_aw (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (conf_decouple_aw_we),
    .wd     (conf_decouple_aw_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.conf.decouple_aw.q ),

    // to register interface (read)
    .qs     (conf_decouple_aw_qs)
  );


  //   F[decouple_rw]: 1:1
  prim_subreg #(
    .DW      (1),
    .SWACCESS("RW"),
    .RESVAL  (1'h0)
  ) u_conf_decouple_rw (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (conf_decouple_rw_we),
    .wd     (conf_decouple_rw_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.conf.decouple_rw.q ),

    // to register interface (read)
    .qs     (conf_decouple_rw_qs)
  );


  //   F[src_reduce_len]: 2:2
  prim_subreg #(
    .DW      (1),
    .SWACCESS("RW"),
    .RESVAL  (1'h0)
  ) u_conf_src_reduce_len (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (conf_src_reduce_len_we),
    .wd     (conf_src_reduce_len_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.conf.src_reduce_len.q ),

    // to register interface (read)
    .qs     (conf_src_reduce_len_qs)
  );


  //   F[dst_reduce_len]: 3:3
  prim_subreg #(
    .DW      (1),
    .SWACCESS("RW"),
    .RESVAL  (1'h0)
  ) u_conf_dst_reduce_len (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (conf_dst_reduce_len_we),
    .wd     (conf_dst_reduce_len_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.conf.dst_reduce_len.q ),

    // to register interface (read)
    .qs     (conf_dst_reduce_len_qs)
  );


  //   F[src_max_llen]: 6:4
  prim_subreg #(
    .DW      (3),
    .SWACCESS("RW"),
    .RESVAL  (3'h0)
  ) u_conf_src_max_llen (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (conf_src_max_llen_we),
    .wd     (conf_src_max_llen_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.conf.src_max_llen.q ),

    // to register interface (read)
    .qs     (conf_src_max_llen_qs)
  );


  //   F[dst_max_llen]: 9:7
  prim_subreg #(
    .DW      (3),
    .SWACCESS("RW"),
    .RESVAL  (3'h0)
  ) u_conf_dst_max_llen (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (conf_dst_max_llen_we),
    .wd     (conf_dst_max_llen_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.conf.dst_max_llen.q ),

    // to register interface (read)
    .qs     (conf_dst_max_llen_qs)
  );


  //   F[enable_nd]: 10:10
  prim_subreg #(
    .DW      (1),
    .SWACCESS("RW"),
    .RESVAL  (1'h0)
  ) u_conf_enable_nd (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (conf_enable_nd_we),
    .wd     (conf_enable_nd_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.conf.enable_nd.q ),

    // to register interface (read)
    .qs     (conf_enable_nd_qs)
  );



  // Subregister 0 of Multireg status
  // R[status_0]: V(True)

  prim_subreg_ext #(
    .DW    (10)
  ) u_status_0 (
    .re     (status_0_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.status[0].d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (status_0_qs)
  );

  // Subregister 1 of Multireg status
  // R[status_1]: V(True)

  prim_subreg_ext #(
    .DW    (10)
  ) u_status_1 (
    .re     (status_1_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.status[1].d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (status_1_qs)
  );

  // Subregister 2 of Multireg status
  // R[status_2]: V(True)

  prim_subreg_ext #(
    .DW    (10)
  ) u_status_2 (
    .re     (status_2_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.status[2].d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (status_2_qs)
  );

  // Subregister 3 of Multireg status
  // R[status_3]: V(True)

  prim_subreg_ext #(
    .DW    (10)
  ) u_status_3 (
    .re     (status_3_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.status[3].d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (status_3_qs)
  );

  // Subregister 4 of Multireg status
  // R[status_4]: V(True)

  prim_subreg_ext #(
    .DW    (10)
  ) u_status_4 (
    .re     (status_4_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.status[4].d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (status_4_qs)
  );

  // Subregister 5 of Multireg status
  // R[status_5]: V(True)

  prim_subreg_ext #(
    .DW    (10)
  ) u_status_5 (
    .re     (status_5_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.status[5].d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (status_5_qs)
  );

  // Subregister 6 of Multireg status
  // R[status_6]: V(True)

  prim_subreg_ext #(
    .DW    (10)
  ) u_status_6 (
    .re     (status_6_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.status[6].d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (status_6_qs)
  );

  // Subregister 7 of Multireg status
  // R[status_7]: V(True)

  prim_subreg_ext #(
    .DW    (10)
  ) u_status_7 (
    .re     (status_7_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.status[7].d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (status_7_qs)
  );

  // Subregister 8 of Multireg status
  // R[status_8]: V(True)

  prim_subreg_ext #(
    .DW    (10)
  ) u_status_8 (
    .re     (status_8_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.status[8].d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (status_8_qs)
  );

  // Subregister 9 of Multireg status
  // R[status_9]: V(True)

  prim_subreg_ext #(
    .DW    (10)
  ) u_status_9 (
    .re     (status_9_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.status[9].d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (status_9_qs)
  );

  // Subregister 10 of Multireg status
  // R[status_10]: V(True)

  prim_subreg_ext #(
    .DW    (10)
  ) u_status_10 (
    .re     (status_10_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.status[10].d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (status_10_qs)
  );

  // Subregister 11 of Multireg status
  // R[status_11]: V(True)

  prim_subreg_ext #(
    .DW    (10)
  ) u_status_11 (
    .re     (status_11_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.status[11].d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (status_11_qs)
  );

  // Subregister 12 of Multireg status
  // R[status_12]: V(True)

  prim_subreg_ext #(
    .DW    (10)
  ) u_status_12 (
    .re     (status_12_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.status[12].d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (status_12_qs)
  );

  // Subregister 13 of Multireg status
  // R[status_13]: V(True)

  prim_subreg_ext #(
    .DW    (10)
  ) u_status_13 (
    .re     (status_13_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.status[13].d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (status_13_qs)
  );

  // Subregister 14 of Multireg status
  // R[status_14]: V(True)

  prim_subreg_ext #(
    .DW    (10)
  ) u_status_14 (
    .re     (status_14_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.status[14].d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (status_14_qs)
  );

  // Subregister 15 of Multireg status
  // R[status_15]: V(True)

  prim_subreg_ext #(
    .DW    (10)
  ) u_status_15 (
    .re     (status_15_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.status[15].d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (status_15_qs)
  );



  // Subregister 0 of Multireg next_id
  // R[next_id_0]: V(True)

  prim_subreg_ext #(
    .DW    (32)
  ) u_next_id_0 (
    .re     (next_id_0_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.next_id[0].d),
    .qre    (reg2hw.next_id[0].re),
    .qe     (),
    .q      (reg2hw.next_id[0].q ),
    .qs     (next_id_0_qs)
  );

  // Subregister 1 of Multireg next_id
  // R[next_id_1]: V(True)

  prim_subreg_ext #(
    .DW    (32)
  ) u_next_id_1 (
    .re     (next_id_1_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.next_id[1].d),
    .qre    (reg2hw.next_id[1].re),
    .qe     (),
    .q      (reg2hw.next_id[1].q ),
    .qs     (next_id_1_qs)
  );

  // Subregister 2 of Multireg next_id
  // R[next_id_2]: V(True)

  prim_subreg_ext #(
    .DW    (32)
  ) u_next_id_2 (
    .re     (next_id_2_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.next_id[2].d),
    .qre    (reg2hw.next_id[2].re),
    .qe     (),
    .q      (reg2hw.next_id[2].q ),
    .qs     (next_id_2_qs)
  );

  // Subregister 3 of Multireg next_id
  // R[next_id_3]: V(True)

  prim_subreg_ext #(
    .DW    (32)
  ) u_next_id_3 (
    .re     (next_id_3_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.next_id[3].d),
    .qre    (reg2hw.next_id[3].re),
    .qe     (),
    .q      (reg2hw.next_id[3].q ),
    .qs     (next_id_3_qs)
  );

  // Subregister 4 of Multireg next_id
  // R[next_id_4]: V(True)

  prim_subreg_ext #(
    .DW    (32)
  ) u_next_id_4 (
    .re     (next_id_4_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.next_id[4].d),
    .qre    (reg2hw.next_id[4].re),
    .qe     (),
    .q      (reg2hw.next_id[4].q ),
    .qs     (next_id_4_qs)
  );

  // Subregister 5 of Multireg next_id
  // R[next_id_5]: V(True)

  prim_subreg_ext #(
    .DW    (32)
  ) u_next_id_5 (
    .re     (next_id_5_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.next_id[5].d),
    .qre    (reg2hw.next_id[5].re),
    .qe     (),
    .q      (reg2hw.next_id[5].q ),
    .qs     (next_id_5_qs)
  );

  // Subregister 6 of Multireg next_id
  // R[next_id_6]: V(True)

  prim_subreg_ext #(
    .DW    (32)
  ) u_next_id_6 (
    .re     (next_id_6_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.next_id[6].d),
    .qre    (reg2hw.next_id[6].re),
    .qe     (),
    .q      (reg2hw.next_id[6].q ),
    .qs     (next_id_6_qs)
  );

  // Subregister 7 of Multireg next_id
  // R[next_id_7]: V(True)

  prim_subreg_ext #(
    .DW    (32)
  ) u_next_id_7 (
    .re     (next_id_7_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.next_id[7].d),
    .qre    (reg2hw.next_id[7].re),
    .qe     (),
    .q      (reg2hw.next_id[7].q ),
    .qs     (next_id_7_qs)
  );

  // Subregister 8 of Multireg next_id
  // R[next_id_8]: V(True)

  prim_subreg_ext #(
    .DW    (32)
  ) u_next_id_8 (
    .re     (next_id_8_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.next_id[8].d),
    .qre    (reg2hw.next_id[8].re),
    .qe     (),
    .q      (reg2hw.next_id[8].q ),
    .qs     (next_id_8_qs)
  );

  // Subregister 9 of Multireg next_id
  // R[next_id_9]: V(True)

  prim_subreg_ext #(
    .DW    (32)
  ) u_next_id_9 (
    .re     (next_id_9_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.next_id[9].d),
    .qre    (reg2hw.next_id[9].re),
    .qe     (),
    .q      (reg2hw.next_id[9].q ),
    .qs     (next_id_9_qs)
  );

  // Subregister 10 of Multireg next_id
  // R[next_id_10]: V(True)

  prim_subreg_ext #(
    .DW    (32)
  ) u_next_id_10 (
    .re     (next_id_10_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.next_id[10].d),
    .qre    (reg2hw.next_id[10].re),
    .qe     (),
    .q      (reg2hw.next_id[10].q ),
    .qs     (next_id_10_qs)
  );

  // Subregister 11 of Multireg next_id
  // R[next_id_11]: V(True)

  prim_subreg_ext #(
    .DW    (32)
  ) u_next_id_11 (
    .re     (next_id_11_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.next_id[11].d),
    .qre    (reg2hw.next_id[11].re),
    .qe     (),
    .q      (reg2hw.next_id[11].q ),
    .qs     (next_id_11_qs)
  );

  // Subregister 12 of Multireg next_id
  // R[next_id_12]: V(True)

  prim_subreg_ext #(
    .DW    (32)
  ) u_next_id_12 (
    .re     (next_id_12_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.next_id[12].d),
    .qre    (reg2hw.next_id[12].re),
    .qe     (),
    .q      (reg2hw.next_id[12].q ),
    .qs     (next_id_12_qs)
  );

  // Subregister 13 of Multireg next_id
  // R[next_id_13]: V(True)

  prim_subreg_ext #(
    .DW    (32)
  ) u_next_id_13 (
    .re     (next_id_13_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.next_id[13].d),
    .qre    (reg2hw.next_id[13].re),
    .qe     (),
    .q      (reg2hw.next_id[13].q ),
    .qs     (next_id_13_qs)
  );

  // Subregister 14 of Multireg next_id
  // R[next_id_14]: V(True)

  prim_subreg_ext #(
    .DW    (32)
  ) u_next_id_14 (
    .re     (next_id_14_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.next_id[14].d),
    .qre    (reg2hw.next_id[14].re),
    .qe     (),
    .q      (reg2hw.next_id[14].q ),
    .qs     (next_id_14_qs)
  );

  // Subregister 15 of Multireg next_id
  // R[next_id_15]: V(True)

  prim_subreg_ext #(
    .DW    (32)
  ) u_next_id_15 (
    .re     (next_id_15_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.next_id[15].d),
    .qre    (reg2hw.next_id[15].re),
    .qe     (),
    .q      (reg2hw.next_id[15].q ),
    .qs     (next_id_15_qs)
  );



  // Subregister 0 of Multireg done_id
  // R[done_id_0]: V(True)

  prim_subreg_ext #(
    .DW    (32)
  ) u_done_id_0 (
    .re     (done_id_0_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.done_id[0].d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (done_id_0_qs)
  );

  // Subregister 1 of Multireg done_id
  // R[done_id_1]: V(True)

  prim_subreg_ext #(
    .DW    (32)
  ) u_done_id_1 (
    .re     (done_id_1_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.done_id[1].d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (done_id_1_qs)
  );

  // Subregister 2 of Multireg done_id
  // R[done_id_2]: V(True)

  prim_subreg_ext #(
    .DW    (32)
  ) u_done_id_2 (
    .re     (done_id_2_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.done_id[2].d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (done_id_2_qs)
  );

  // Subregister 3 of Multireg done_id
  // R[done_id_3]: V(True)

  prim_subreg_ext #(
    .DW    (32)
  ) u_done_id_3 (
    .re     (done_id_3_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.done_id[3].d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (done_id_3_qs)
  );

  // Subregister 4 of Multireg done_id
  // R[done_id_4]: V(True)

  prim_subreg_ext #(
    .DW    (32)
  ) u_done_id_4 (
    .re     (done_id_4_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.done_id[4].d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (done_id_4_qs)
  );

  // Subregister 5 of Multireg done_id
  // R[done_id_5]: V(True)

  prim_subreg_ext #(
    .DW    (32)
  ) u_done_id_5 (
    .re     (done_id_5_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.done_id[5].d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (done_id_5_qs)
  );

  // Subregister 6 of Multireg done_id
  // R[done_id_6]: V(True)

  prim_subreg_ext #(
    .DW    (32)
  ) u_done_id_6 (
    .re     (done_id_6_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.done_id[6].d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (done_id_6_qs)
  );

  // Subregister 7 of Multireg done_id
  // R[done_id_7]: V(True)

  prim_subreg_ext #(
    .DW    (32)
  ) u_done_id_7 (
    .re     (done_id_7_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.done_id[7].d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (done_id_7_qs)
  );

  // Subregister 8 of Multireg done_id
  // R[done_id_8]: V(True)

  prim_subreg_ext #(
    .DW    (32)
  ) u_done_id_8 (
    .re     (done_id_8_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.done_id[8].d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (done_id_8_qs)
  );

  // Subregister 9 of Multireg done_id
  // R[done_id_9]: V(True)

  prim_subreg_ext #(
    .DW    (32)
  ) u_done_id_9 (
    .re     (done_id_9_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.done_id[9].d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (done_id_9_qs)
  );

  // Subregister 10 of Multireg done_id
  // R[done_id_10]: V(True)

  prim_subreg_ext #(
    .DW    (32)
  ) u_done_id_10 (
    .re     (done_id_10_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.done_id[10].d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (done_id_10_qs)
  );

  // Subregister 11 of Multireg done_id
  // R[done_id_11]: V(True)

  prim_subreg_ext #(
    .DW    (32)
  ) u_done_id_11 (
    .re     (done_id_11_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.done_id[11].d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (done_id_11_qs)
  );

  // Subregister 12 of Multireg done_id
  // R[done_id_12]: V(True)

  prim_subreg_ext #(
    .DW    (32)
  ) u_done_id_12 (
    .re     (done_id_12_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.done_id[12].d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (done_id_12_qs)
  );

  // Subregister 13 of Multireg done_id
  // R[done_id_13]: V(True)

  prim_subreg_ext #(
    .DW    (32)
  ) u_done_id_13 (
    .re     (done_id_13_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.done_id[13].d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (done_id_13_qs)
  );

  // Subregister 14 of Multireg done_id
  // R[done_id_14]: V(True)

  prim_subreg_ext #(
    .DW    (32)
  ) u_done_id_14 (
    .re     (done_id_14_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.done_id[14].d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (done_id_14_qs)
  );

  // Subregister 15 of Multireg done_id
  // R[done_id_15]: V(True)

  prim_subreg_ext #(
    .DW    (32)
  ) u_done_id_15 (
    .re     (done_id_15_re),
    .we     (1'b0),
    .wd     ('0),
    .d      (hw2reg.done_id[15].d),
    .qre    (),
    .qe     (),
    .q      (),
    .qs     (done_id_15_qs)
  );


  // R[dst_addr_low]: V(False)

  prim_subreg #(
    .DW      (32),
    .SWACCESS("RW"),
    .RESVAL  (32'h0)
  ) u_dst_addr_low (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (dst_addr_low_we),
    .wd     (dst_addr_low_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.dst_addr_low.q ),

    // to register interface (read)
    .qs     (dst_addr_low_qs)
  );


  // R[src_addr_low]: V(False)

  prim_subreg #(
    .DW      (32),
    .SWACCESS("RW"),
    .RESVAL  (32'h0)
  ) u_src_addr_low (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (src_addr_low_we),
    .wd     (src_addr_low_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.src_addr_low.q ),

    // to register interface (read)
    .qs     (src_addr_low_qs)
  );


  // R[length_low]: V(False)

  prim_subreg #(
    .DW      (32),
    .SWACCESS("RW"),
    .RESVAL  (32'h0)
  ) u_length_low (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (length_low_we),
    .wd     (length_low_wd),

    // from internal hardware
    .de     (1'b0),
    .d      ('0  ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.length_low.q ),

    // to register interface (read)
    .qs     (length_low_qs)
  );




  logic [51:0] addr_hit;
  always_comb begin
    addr_hit = '0;
    addr_hit[ 0] = (reg_addr == IDMA_REG32_1D_CONF_OFFSET);
    addr_hit[ 1] = (reg_addr == IDMA_REG32_1D_STATUS_0_OFFSET);
    addr_hit[ 2] = (reg_addr == IDMA_REG32_1D_STATUS_1_OFFSET);
    addr_hit[ 3] = (reg_addr == IDMA_REG32_1D_STATUS_2_OFFSET);
    addr_hit[ 4] = (reg_addr == IDMA_REG32_1D_STATUS_3_OFFSET);
    addr_hit[ 5] = (reg_addr == IDMA_REG32_1D_STATUS_4_OFFSET);
    addr_hit[ 6] = (reg_addr == IDMA_REG32_1D_STATUS_5_OFFSET);
    addr_hit[ 7] = (reg_addr == IDMA_REG32_1D_STATUS_6_OFFSET);
    addr_hit[ 8] = (reg_addr == IDMA_REG32_1D_STATUS_7_OFFSET);
    addr_hit[ 9] = (reg_addr == IDMA_REG32_1D_STATUS_8_OFFSET);
    addr_hit[10] = (reg_addr == IDMA_REG32_1D_STATUS_9_OFFSET);
    addr_hit[11] = (reg_addr == IDMA_REG32_1D_STATUS_10_OFFSET);
    addr_hit[12] = (reg_addr == IDMA_REG32_1D_STATUS_11_OFFSET);
    addr_hit[13] = (reg_addr == IDMA_REG32_1D_STATUS_12_OFFSET);
    addr_hit[14] = (reg_addr == IDMA_REG32_1D_STATUS_13_OFFSET);
    addr_hit[15] = (reg_addr == IDMA_REG32_1D_STATUS_14_OFFSET);
    addr_hit[16] = (reg_addr == IDMA_REG32_1D_STATUS_15_OFFSET);
    addr_hit[17] = (reg_addr == IDMA_REG32_1D_NEXT_ID_0_OFFSET);
    addr_hit[18] = (reg_addr == IDMA_REG32_1D_NEXT_ID_1_OFFSET);
    addr_hit[19] = (reg_addr == IDMA_REG32_1D_NEXT_ID_2_OFFSET);
    addr_hit[20] = (reg_addr == IDMA_REG32_1D_NEXT_ID_3_OFFSET);
    addr_hit[21] = (reg_addr == IDMA_REG32_1D_NEXT_ID_4_OFFSET);
    addr_hit[22] = (reg_addr == IDMA_REG32_1D_NEXT_ID_5_OFFSET);
    addr_hit[23] = (reg_addr == IDMA_REG32_1D_NEXT_ID_6_OFFSET);
    addr_hit[24] = (reg_addr == IDMA_REG32_1D_NEXT_ID_7_OFFSET);
    addr_hit[25] = (reg_addr == IDMA_REG32_1D_NEXT_ID_8_OFFSET);
    addr_hit[26] = (reg_addr == IDMA_REG32_1D_NEXT_ID_9_OFFSET);
    addr_hit[27] = (reg_addr == IDMA_REG32_1D_NEXT_ID_10_OFFSET);
    addr_hit[28] = (reg_addr == IDMA_REG32_1D_NEXT_ID_11_OFFSET);
    addr_hit[29] = (reg_addr == IDMA_REG32_1D_NEXT_ID_12_OFFSET);
    addr_hit[30] = (reg_addr == IDMA_REG32_1D_NEXT_ID_13_OFFSET);
    addr_hit[31] = (reg_addr == IDMA_REG32_1D_NEXT_ID_14_OFFSET);
    addr_hit[32] = (reg_addr == IDMA_REG32_1D_NEXT_ID_15_OFFSET);
    addr_hit[33] = (reg_addr == IDMA_REG32_1D_DONE_ID_0_OFFSET);
    addr_hit[34] = (reg_addr == IDMA_REG32_1D_DONE_ID_1_OFFSET);
    addr_hit[35] = (reg_addr == IDMA_REG32_1D_DONE_ID_2_OFFSET);
    addr_hit[36] = (reg_addr == IDMA_REG32_1D_DONE_ID_3_OFFSET);
    addr_hit[37] = (reg_addr == IDMA_REG32_1D_DONE_ID_4_OFFSET);
    addr_hit[38] = (reg_addr == IDMA_REG32_1D_DONE_ID_5_OFFSET);
    addr_hit[39] = (reg_addr == IDMA_REG32_1D_DONE_ID_6_OFFSET);
    addr_hit[40] = (reg_addr == IDMA_REG32_1D_DONE_ID_7_OFFSET);
    addr_hit[41] = (reg_addr == IDMA_REG32_1D_DONE_ID_8_OFFSET);
    addr_hit[42] = (reg_addr == IDMA_REG32_1D_DONE_ID_9_OFFSET);
    addr_hit[43] = (reg_addr == IDMA_REG32_1D_DONE_ID_10_OFFSET);
    addr_hit[44] = (reg_addr == IDMA_REG32_1D_DONE_ID_11_OFFSET);
    addr_hit[45] = (reg_addr == IDMA_REG32_1D_DONE_ID_12_OFFSET);
    addr_hit[46] = (reg_addr == IDMA_REG32_1D_DONE_ID_13_OFFSET);
    addr_hit[47] = (reg_addr == IDMA_REG32_1D_DONE_ID_14_OFFSET);
    addr_hit[48] = (reg_addr == IDMA_REG32_1D_DONE_ID_15_OFFSET);
    addr_hit[49] = (reg_addr == IDMA_REG32_1D_DST_ADDR_LOW_OFFSET);
    addr_hit[50] = (reg_addr == IDMA_REG32_1D_SRC_ADDR_LOW_OFFSET);
    addr_hit[51] = (reg_addr == IDMA_REG32_1D_LENGTH_LOW_OFFSET);
  end

  assign addrmiss = (reg_re || reg_we) ? ~|addr_hit : 1'b0 ;

  // Check sub-word write is permitted
  always_comb begin
    wr_err = (reg_we &
              ((addr_hit[ 0] & (|(IDMA_REG32_1D_PERMIT[ 0] & ~reg_be))) |
               (addr_hit[ 1] & (|(IDMA_REG32_1D_PERMIT[ 1] & ~reg_be))) |
               (addr_hit[ 2] & (|(IDMA_REG32_1D_PERMIT[ 2] & ~reg_be))) |
               (addr_hit[ 3] & (|(IDMA_REG32_1D_PERMIT[ 3] & ~reg_be))) |
               (addr_hit[ 4] & (|(IDMA_REG32_1D_PERMIT[ 4] & ~reg_be))) |
               (addr_hit[ 5] & (|(IDMA_REG32_1D_PERMIT[ 5] & ~reg_be))) |
               (addr_hit[ 6] & (|(IDMA_REG32_1D_PERMIT[ 6] & ~reg_be))) |
               (addr_hit[ 7] & (|(IDMA_REG32_1D_PERMIT[ 7] & ~reg_be))) |
               (addr_hit[ 8] & (|(IDMA_REG32_1D_PERMIT[ 8] & ~reg_be))) |
               (addr_hit[ 9] & (|(IDMA_REG32_1D_PERMIT[ 9] & ~reg_be))) |
               (addr_hit[10] & (|(IDMA_REG32_1D_PERMIT[10] & ~reg_be))) |
               (addr_hit[11] & (|(IDMA_REG32_1D_PERMIT[11] & ~reg_be))) |
               (addr_hit[12] & (|(IDMA_REG32_1D_PERMIT[12] & ~reg_be))) |
               (addr_hit[13] & (|(IDMA_REG32_1D_PERMIT[13] & ~reg_be))) |
               (addr_hit[14] & (|(IDMA_REG32_1D_PERMIT[14] & ~reg_be))) |
               (addr_hit[15] & (|(IDMA_REG32_1D_PERMIT[15] & ~reg_be))) |
               (addr_hit[16] & (|(IDMA_REG32_1D_PERMIT[16] & ~reg_be))) |
               (addr_hit[17] & (|(IDMA_REG32_1D_PERMIT[17] & ~reg_be))) |
               (addr_hit[18] & (|(IDMA_REG32_1D_PERMIT[18] & ~reg_be))) |
               (addr_hit[19] & (|(IDMA_REG32_1D_PERMIT[19] & ~reg_be))) |
               (addr_hit[20] & (|(IDMA_REG32_1D_PERMIT[20] & ~reg_be))) |
               (addr_hit[21] & (|(IDMA_REG32_1D_PERMIT[21] & ~reg_be))) |
               (addr_hit[22] & (|(IDMA_REG32_1D_PERMIT[22] & ~reg_be))) |
               (addr_hit[23] & (|(IDMA_REG32_1D_PERMIT[23] & ~reg_be))) |
               (addr_hit[24] & (|(IDMA_REG32_1D_PERMIT[24] & ~reg_be))) |
               (addr_hit[25] & (|(IDMA_REG32_1D_PERMIT[25] & ~reg_be))) |
               (addr_hit[26] & (|(IDMA_REG32_1D_PERMIT[26] & ~reg_be))) |
               (addr_hit[27] & (|(IDMA_REG32_1D_PERMIT[27] & ~reg_be))) |
               (addr_hit[28] & (|(IDMA_REG32_1D_PERMIT[28] & ~reg_be))) |
               (addr_hit[29] & (|(IDMA_REG32_1D_PERMIT[29] & ~reg_be))) |
               (addr_hit[30] & (|(IDMA_REG32_1D_PERMIT[30] & ~reg_be))) |
               (addr_hit[31] & (|(IDMA_REG32_1D_PERMIT[31] & ~reg_be))) |
               (addr_hit[32] & (|(IDMA_REG32_1D_PERMIT[32] & ~reg_be))) |
               (addr_hit[33] & (|(IDMA_REG32_1D_PERMIT[33] & ~reg_be))) |
               (addr_hit[34] & (|(IDMA_REG32_1D_PERMIT[34] & ~reg_be))) |
               (addr_hit[35] & (|(IDMA_REG32_1D_PERMIT[35] & ~reg_be))) |
               (addr_hit[36] & (|(IDMA_REG32_1D_PERMIT[36] & ~reg_be))) |
               (addr_hit[37] & (|(IDMA_REG32_1D_PERMIT[37] & ~reg_be))) |
               (addr_hit[38] & (|(IDMA_REG32_1D_PERMIT[38] & ~reg_be))) |
               (addr_hit[39] & (|(IDMA_REG32_1D_PERMIT[39] & ~reg_be))) |
               (addr_hit[40] & (|(IDMA_REG32_1D_PERMIT[40] & ~reg_be))) |
               (addr_hit[41] & (|(IDMA_REG32_1D_PERMIT[41] & ~reg_be))) |
               (addr_hit[42] & (|(IDMA_REG32_1D_PERMIT[42] & ~reg_be))) |
               (addr_hit[43] & (|(IDMA_REG32_1D_PERMIT[43] & ~reg_be))) |
               (addr_hit[44] & (|(IDMA_REG32_1D_PERMIT[44] & ~reg_be))) |
               (addr_hit[45] & (|(IDMA_REG32_1D_PERMIT[45] & ~reg_be))) |
               (addr_hit[46] & (|(IDMA_REG32_1D_PERMIT[46] & ~reg_be))) |
               (addr_hit[47] & (|(IDMA_REG32_1D_PERMIT[47] & ~reg_be))) |
               (addr_hit[48] & (|(IDMA_REG32_1D_PERMIT[48] & ~reg_be))) |
               (addr_hit[49] & (|(IDMA_REG32_1D_PERMIT[49] & ~reg_be))) |
               (addr_hit[50] & (|(IDMA_REG32_1D_PERMIT[50] & ~reg_be))) |
               (addr_hit[51] & (|(IDMA_REG32_1D_PERMIT[51] & ~reg_be)))));
  end

  assign conf_decouple_aw_we = addr_hit[0] & reg_we & !reg_error;
  assign conf_decouple_aw_wd = reg_wdata[0];

  assign conf_decouple_rw_we = addr_hit[0] & reg_we & !reg_error;
  assign conf_decouple_rw_wd = reg_wdata[1];

  assign conf_src_reduce_len_we = addr_hit[0] & reg_we & !reg_error;
  assign conf_src_reduce_len_wd = reg_wdata[2];

  assign conf_dst_reduce_len_we = addr_hit[0] & reg_we & !reg_error;
  assign conf_dst_reduce_len_wd = reg_wdata[3];

  assign conf_src_max_llen_we = addr_hit[0] & reg_we & !reg_error;
  assign conf_src_max_llen_wd = reg_wdata[6:4];

  assign conf_dst_max_llen_we = addr_hit[0] & reg_we & !reg_error;
  assign conf_dst_max_llen_wd = reg_wdata[9:7];

  assign conf_enable_nd_we = addr_hit[0] & reg_we & !reg_error;
  assign conf_enable_nd_wd = reg_wdata[10];

  assign status_0_re = addr_hit[1] & reg_re & !reg_error;

  assign status_1_re = addr_hit[2] & reg_re & !reg_error;

  assign status_2_re = addr_hit[3] & reg_re & !reg_error;

  assign status_3_re = addr_hit[4] & reg_re & !reg_error;

  assign status_4_re = addr_hit[5] & reg_re & !reg_error;

  assign status_5_re = addr_hit[6] & reg_re & !reg_error;

  assign status_6_re = addr_hit[7] & reg_re & !reg_error;

  assign status_7_re = addr_hit[8] & reg_re & !reg_error;

  assign status_8_re = addr_hit[9] & reg_re & !reg_error;

  assign status_9_re = addr_hit[10] & reg_re & !reg_error;

  assign status_10_re = addr_hit[11] & reg_re & !reg_error;

  assign status_11_re = addr_hit[12] & reg_re & !reg_error;

  assign status_12_re = addr_hit[13] & reg_re & !reg_error;

  assign status_13_re = addr_hit[14] & reg_re & !reg_error;

  assign status_14_re = addr_hit[15] & reg_re & !reg_error;

  assign status_15_re = addr_hit[16] & reg_re & !reg_error;

  assign next_id_0_re = addr_hit[17] & reg_re & !reg_error;

  assign next_id_1_re = addr_hit[18] & reg_re & !reg_error;

  assign next_id_2_re = addr_hit[19] & reg_re & !reg_error;

  assign next_id_3_re = addr_hit[20] & reg_re & !reg_error;

  assign next_id_4_re = addr_hit[21] & reg_re & !reg_error;

  assign next_id_5_re = addr_hit[22] & reg_re & !reg_error;

  assign next_id_6_re = addr_hit[23] & reg_re & !reg_error;

  assign next_id_7_re = addr_hit[24] & reg_re & !reg_error;

  assign next_id_8_re = addr_hit[25] & reg_re & !reg_error;

  assign next_id_9_re = addr_hit[26] & reg_re & !reg_error;

  assign next_id_10_re = addr_hit[27] & reg_re & !reg_error;

  assign next_id_11_re = addr_hit[28] & reg_re & !reg_error;

  assign next_id_12_re = addr_hit[29] & reg_re & !reg_error;

  assign next_id_13_re = addr_hit[30] & reg_re & !reg_error;

  assign next_id_14_re = addr_hit[31] & reg_re & !reg_error;

  assign next_id_15_re = addr_hit[32] & reg_re & !reg_error;

  assign done_id_0_re = addr_hit[33] & reg_re & !reg_error;

  assign done_id_1_re = addr_hit[34] & reg_re & !reg_error;

  assign done_id_2_re = addr_hit[35] & reg_re & !reg_error;

  assign done_id_3_re = addr_hit[36] & reg_re & !reg_error;

  assign done_id_4_re = addr_hit[37] & reg_re & !reg_error;

  assign done_id_5_re = addr_hit[38] & reg_re & !reg_error;

  assign done_id_6_re = addr_hit[39] & reg_re & !reg_error;

  assign done_id_7_re = addr_hit[40] & reg_re & !reg_error;

  assign done_id_8_re = addr_hit[41] & reg_re & !reg_error;

  assign done_id_9_re = addr_hit[42] & reg_re & !reg_error;

  assign done_id_10_re = addr_hit[43] & reg_re & !reg_error;

  assign done_id_11_re = addr_hit[44] & reg_re & !reg_error;

  assign done_id_12_re = addr_hit[45] & reg_re & !reg_error;

  assign done_id_13_re = addr_hit[46] & reg_re & !reg_error;

  assign done_id_14_re = addr_hit[47] & reg_re & !reg_error;

  assign done_id_15_re = addr_hit[48] & reg_re & !reg_error;

  assign dst_addr_low_we = addr_hit[49] & reg_we & !reg_error;
  assign dst_addr_low_wd = reg_wdata[31:0];

  assign src_addr_low_we = addr_hit[50] & reg_we & !reg_error;
  assign src_addr_low_wd = reg_wdata[31:0];

  assign length_low_we = addr_hit[51] & reg_we & !reg_error;
  assign length_low_wd = reg_wdata[31:0];

  // Read data return
  always_comb begin
    reg_rdata_next = '0;
    unique case (1'b1)
      addr_hit[0]: begin
        reg_rdata_next[0] = conf_decouple_aw_qs;
        reg_rdata_next[1] = conf_decouple_rw_qs;
        reg_rdata_next[2] = conf_src_reduce_len_qs;
        reg_rdata_next[3] = conf_dst_reduce_len_qs;
        reg_rdata_next[6:4] = conf_src_max_llen_qs;
        reg_rdata_next[9:7] = conf_dst_max_llen_qs;
        reg_rdata_next[10] = conf_enable_nd_qs;
      end

      addr_hit[1]: begin
        reg_rdata_next[9:0] = status_0_qs;
      end

      addr_hit[2]: begin
        reg_rdata_next[9:0] = status_1_qs;
      end

      addr_hit[3]: begin
        reg_rdata_next[9:0] = status_2_qs;
      end

      addr_hit[4]: begin
        reg_rdata_next[9:0] = status_3_qs;
      end

      addr_hit[5]: begin
        reg_rdata_next[9:0] = status_4_qs;
      end

      addr_hit[6]: begin
        reg_rdata_next[9:0] = status_5_qs;
      end

      addr_hit[7]: begin
        reg_rdata_next[9:0] = status_6_qs;
      end

      addr_hit[8]: begin
        reg_rdata_next[9:0] = status_7_qs;
      end

      addr_hit[9]: begin
        reg_rdata_next[9:0] = status_8_qs;
      end

      addr_hit[10]: begin
        reg_rdata_next[9:0] = status_9_qs;
      end

      addr_hit[11]: begin
        reg_rdata_next[9:0] = status_10_qs;
      end

      addr_hit[12]: begin
        reg_rdata_next[9:0] = status_11_qs;
      end

      addr_hit[13]: begin
        reg_rdata_next[9:0] = status_12_qs;
      end

      addr_hit[14]: begin
        reg_rdata_next[9:0] = status_13_qs;
      end

      addr_hit[15]: begin
        reg_rdata_next[9:0] = status_14_qs;
      end

      addr_hit[16]: begin
        reg_rdata_next[9:0] = status_15_qs;
      end

      addr_hit[17]: begin
        reg_rdata_next[31:0] = next_id_0_qs;
      end

      addr_hit[18]: begin
        reg_rdata_next[31:0] = next_id_1_qs;
      end

      addr_hit[19]: begin
        reg_rdata_next[31:0] = next_id_2_qs;
      end

      addr_hit[20]: begin
        reg_rdata_next[31:0] = next_id_3_qs;
      end

      addr_hit[21]: begin
        reg_rdata_next[31:0] = next_id_4_qs;
      end

      addr_hit[22]: begin
        reg_rdata_next[31:0] = next_id_5_qs;
      end

      addr_hit[23]: begin
        reg_rdata_next[31:0] = next_id_6_qs;
      end

      addr_hit[24]: begin
        reg_rdata_next[31:0] = next_id_7_qs;
      end

      addr_hit[25]: begin
        reg_rdata_next[31:0] = next_id_8_qs;
      end

      addr_hit[26]: begin
        reg_rdata_next[31:0] = next_id_9_qs;
      end

      addr_hit[27]: begin
        reg_rdata_next[31:0] = next_id_10_qs;
      end

      addr_hit[28]: begin
        reg_rdata_next[31:0] = next_id_11_qs;
      end

      addr_hit[29]: begin
        reg_rdata_next[31:0] = next_id_12_qs;
      end

      addr_hit[30]: begin
        reg_rdata_next[31:0] = next_id_13_qs;
      end

      addr_hit[31]: begin
        reg_rdata_next[31:0] = next_id_14_qs;
      end

      addr_hit[32]: begin
        reg_rdata_next[31:0] = next_id_15_qs;
      end

      addr_hit[33]: begin
        reg_rdata_next[31:0] = done_id_0_qs;
      end

      addr_hit[34]: begin
        reg_rdata_next[31:0] = done_id_1_qs;
      end

      addr_hit[35]: begin
        reg_rdata_next[31:0] = done_id_2_qs;
      end

      addr_hit[36]: begin
        reg_rdata_next[31:0] = done_id_3_qs;
      end

      addr_hit[37]: begin
        reg_rdata_next[31:0] = done_id_4_qs;
      end

      addr_hit[38]: begin
        reg_rdata_next[31:0] = done_id_5_qs;
      end

      addr_hit[39]: begin
        reg_rdata_next[31:0] = done_id_6_qs;
      end

      addr_hit[40]: begin
        reg_rdata_next[31:0] = done_id_7_qs;
      end

      addr_hit[41]: begin
        reg_rdata_next[31:0] = done_id_8_qs;
      end

      addr_hit[42]: begin
        reg_rdata_next[31:0] = done_id_9_qs;
      end

      addr_hit[43]: begin
        reg_rdata_next[31:0] = done_id_10_qs;
      end

      addr_hit[44]: begin
        reg_rdata_next[31:0] = done_id_11_qs;
      end

      addr_hit[45]: begin
        reg_rdata_next[31:0] = done_id_12_qs;
      end

      addr_hit[46]: begin
        reg_rdata_next[31:0] = done_id_13_qs;
      end

      addr_hit[47]: begin
        reg_rdata_next[31:0] = done_id_14_qs;
      end

      addr_hit[48]: begin
        reg_rdata_next[31:0] = done_id_15_qs;
      end

      addr_hit[49]: begin
        reg_rdata_next[31:0] = dst_addr_low_qs;
      end

      addr_hit[50]: begin
        reg_rdata_next[31:0] = src_addr_low_qs;
      end

      addr_hit[51]: begin
        reg_rdata_next[31:0] = length_low_qs;
      end

      default: begin
        reg_rdata_next = '1;
      end
    endcase
  end

  // Unused signal tieoff

  // wdata / byte enable are not always fully used
  // add a blanket unused statement to handle lint waivers
  logic unused_wdata;
  logic unused_be;
  assign unused_wdata = ^reg_wdata;
  assign unused_be = ^reg_be;

  // Assertions for Register Interface
  `ASSERT(en2addrHit, (reg_we || reg_re) |-> $onehot0(addr_hit))

endmodule

module idma_reg32_1d_reg_top_intf
#(
  parameter int AW = 8,
  localparam int DW = 32
) (
  input logic clk_i,
  input logic rst_ni,
  REG_BUS.in  regbus_slave,
  // To HW
  output idma_reg32_1d_reg_pkg::idma_reg32_1d_reg2hw_t reg2hw, // Write
  input  idma_reg32_1d_reg_pkg::idma_reg32_1d_hw2reg_t hw2reg, // Read
  // Config
  input devmode_i // If 1, explicit error return for unmapped register access
);
 localparam int unsigned STRB_WIDTH = DW/8;

`include "register_interface/typedef.svh"
`include "register_interface/assign.svh"

  // Define structs for reg_bus
  typedef logic [AW-1:0] addr_t;
  typedef logic [DW-1:0] data_t;
  typedef logic [STRB_WIDTH-1:0] strb_t;
  `REG_BUS_TYPEDEF_ALL(reg_bus, addr_t, data_t, strb_t)

  reg_bus_req_t s_reg_req;
  reg_bus_rsp_t s_reg_rsp;
  
  // Assign SV interface to structs
  `REG_BUS_ASSIGN_TO_REQ(s_reg_req, regbus_slave)
  `REG_BUS_ASSIGN_FROM_RSP(regbus_slave, s_reg_rsp)

  

  idma_reg32_1d_reg_top #(
    .reg_req_t(reg_bus_req_t),
    .reg_rsp_t(reg_bus_rsp_t),
    .AW(AW)
  ) i_regs (
    .clk_i,
    .rst_ni,
    .reg_req_i(s_reg_req),
    .reg_rsp_o(s_reg_rsp),
    .reg2hw, // Write
    .hw2reg, // Read
    .devmode_i
  );
  
endmodule


// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Authors:
// - Michael Rogenmoser <michaero@iis.ee.ethz.ch>
// - Thomas Benz <tbenz@iis.ee.ethz.ch>

/// Description: Register-based front-end for iDMA
module idma_reg32_1d #(
  /// Number of configuration register ports
  parameter int unsigned NumRegs        = 32'd1,
  /// Number of streams (max 16)
  parameter int unsigned NumStreams     = 32'd1,
  /// Width of the transfer id (max 32-bit)
  parameter int unsigned IdCounterWidth = 32'd32,
  /// Dependent parameter: Stream Idx
  parameter int unsigned StreamWidth    = cf_math_pkg::idx_width(NumStreams),
  /// Register_interface request type
  parameter type         reg_req_t      = logic,
  /// Register_interface response type
  parameter type         reg_rsp_t      = logic,
  /// DMA 1d or ND burst request type
  parameter type         dma_req_t      = logic,
  /// Dependent type for IdCounterWidth
  parameter type         cnt_width_t    = logic [IdCounterWidth-1:0],
  /// Dependent type for StreamWidth
  parameter type         stream_t       = logic [StreamWidth-1:0]
) (
  input  logic clk_i,
  input  logic rst_ni,
  /// Register interface control slave
  input  reg_req_t [NumRegs-1:0] dma_ctrl_req_i,
  output reg_rsp_t [NumRegs-1:0] dma_ctrl_rsp_o,
  /// Request signals
  output dma_req_t   dma_req_o,
  output logic       req_valid_o,
  input  logic       req_ready_i,
  input  cnt_width_t next_id_i,
  output stream_t    stream_idx_o,
  /// Status signals
  input  cnt_width_t           [NumStreams-1:0] done_id_i,
  input  idma_pkg::idma_busy_t [NumStreams-1:0] busy_i,
  input  logic                 [NumStreams-1:0] midend_busy_i
);

  /// Maximum number of streams is set to 16. It can be enlarged, but the register file
  /// needs to be adapted too.
  localparam int unsigned MaxNumStreams = 32'd16;

  // register connections
  idma_reg32_1d_reg_pkg::idma_reg32_1d_reg2hw_t [NumRegs-1:0] dma_reg2hw;
  idma_reg32_1d_reg_pkg::idma_reg32_1d_hw2reg_t [NumRegs-1:0] dma_hw2reg;

  // arbitration output
  dma_req_t [NumRegs-1:0] arb_dma_req;
  logic     [NumRegs-1:0] arb_valid;
  logic     [NumRegs-1:0] arb_ready;

  // register signals
  reg_rsp_t [NumRegs-1:0] dma_ctrl_rsp;

  // generate the registers
  for (genvar i = 0; i < NumRegs; i++) begin : gen_core_regs

    idma_reg32_1d_reg_top #(
      .reg_req_t ( reg_req_t ),
      .reg_rsp_t ( reg_rsp_t )
    ) i_idma_reg32_1d_reg_top (
      .clk_i,
      .rst_ni,
      .reg_req_i ( dma_ctrl_req_i   [i] ),
      .reg_rsp_o ( dma_ctrl_rsp     [i] ),
      .reg2hw    ( dma_reg2hw       [i] ),
      .hw2reg    ( dma_hw2reg       [i] ),
      .devmode_i ( 1'b1                 )
    );

    // DMA backpressure
    always_comb begin : proc_dma_backpressure
      // ready signal
      dma_ctrl_rsp_o[i]       = dma_ctrl_rsp[i];
      dma_ctrl_rsp_o[i].ready = arb_ready[i];
    end

    // valid signals
    logic read_happens;
    always_comb begin : proc_launch
        read_happens = 1'b0;
        stream_idx_o = '0;
        for (int c = 0; c < NumStreams; c++) begin
            read_happens |= dma_reg2hw[i].next_id[c].re;
            if (dma_reg2hw[i].next_id[c].re) begin
                stream_idx_o = c;
            end
        end
        arb_valid[i] = read_happens;
    end

    // assign request struct
    always_comb begin : proc_hw_req_conv
      // all fields are zero per default
      arb_dma_req[i] = '0;

      // address and length
      arb_dma_req[i].length   = dma_reg2hw[i].length_low.q;
      arb_dma_req[i].src_addr = dma_reg2hw[i].src_addr_low.q;
      arb_dma_req[i].dst_addr = dma_reg2hw[i].dst_addr_low.q;

      // Current backend only supports incremental burst
      arb_dma_req[i].opt.src.burst = axi_pkg::BURST_INCR;
      arb_dma_req[i].opt.dst.burst = axi_pkg::BURST_INCR;
        // this frontend currently does not support cache variations
      arb_dma_req[i].opt.src.cache = axi_pkg::CACHE_MODIFIABLE;
      arb_dma_req[i].opt.dst.cache = axi_pkg::CACHE_MODIFIABLE;

      // Backend options
      arb_dma_req[i].opt.beo.decouple_aw    = dma_reg2hw[i].conf.decouple_aw.q;
      arb_dma_req[i].opt.beo.decouple_rw    = dma_reg2hw[i].conf.decouple_rw.q;
      arb_dma_req[i].opt.beo.src_max_llen   = dma_reg2hw[i].conf.src_max_llen.q;
      arb_dma_req[i].opt.beo.dst_max_llen   = dma_reg2hw[i].conf.dst_max_llen.q;
      arb_dma_req[i].opt.beo.src_reduce_len = dma_reg2hw[i].conf.src_reduce_len.q;
      arb_dma_req[i].opt.beo.dst_reduce_len = dma_reg2hw[i].conf.dst_reduce_len.q;

    end

    // observational registers
    for (genvar c = 0; c < NumStreams; c++) begin
        assign dma_hw2reg[i].status[c]  = {midend_busy_i[c], busy_i[c]};
        assign dma_hw2reg[i].next_id[c] = next_id_i;
        assign dma_hw2reg[i].done_id[c] = done_id_i[c];
    end

    // tie-off unused channels
    for (genvar c = NumStreams; c < MaxNumStreams; c++) begin
        assign dma_hw2reg[i].status[c]  = '0;
        assign dma_hw2reg[i].next_id[c] = '0;
        assign dma_hw2reg[i].done_id[c] = '0;
    end

  end

  // arbitration
  rr_arb_tree #(
    .NumIn     ( NumRegs   ),
    .DataType  ( dma_req_t ),
    .ExtPrio   ( 0         ),
    .AxiVldRdy ( 1         ),
    .LockIn    ( 1         )
  ) i_rr_arb_tree (
    .clk_i,
    .rst_ni,
    .flush_i ( 1'b0        ),
    .rr_i    ( '0          ),
    .req_i   ( arb_valid   ),
    .gnt_o   ( arb_ready   ),
    .data_i  ( arb_dma_req ),
    .gnt_i   ( req_ready_i ),
    .req_o   ( req_valid_o ),
    .data_o  ( dma_req_o   ),
    .idx_o   ( /* NC */    )
  );

endmodule

