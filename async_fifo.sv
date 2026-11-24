`timescale 1ns/1ps

//=============================================================================
// Design       : Asynchronous FIFO
// Description  : Dual-clock FIFO using Gray-code pointer synchronization
//
// Features:
//   - Independent write and read clock domains
//   - Binary and Gray-code pointers
//   - Two-flop pointer synchronizers
//   - Full and empty flag generation
//   - First-Word Fall-Through (FWFT) read behavior
//
// Parameters:
//   DATA_WIDTH : Width of FIFO data
//   ADDR_WIDTH: Address width (FIFO depth = 2**ADDR_WIDTH)
//
// Note:
//   ADDR_WIDTH must be >= 2 for the full-flag comparison.
//=============================================================================

module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
)(
    //=========================== WRITE INTERFACE =============================

    input  wire                  wclk,
    input  wire                  wrst_n,
    input  wire                  winc,
    input  wire [DATA_WIDTH-1:0] wdata,

    output reg                   wfull,


    //=========================== READ INTERFACE ==============================

    input  wire                  rclk,
    input  wire                  rrst_n,
    input  wire                  rinc,

    output wire [DATA_WIDTH-1:0] rdata,
    output reg                   rempty
);


    //=========================================================================
    // FIFO PARAMETERS AND MEMORY
    //=========================================================================

    localparam DEPTH = 1 << ADDR_WIDTH;

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];


    //=========================================================================
    // BINARY AND GRAY-CODE POINTERS
    //=========================================================================

    reg  [ADDR_WIDTH:0] wbin;
    reg  [ADDR_WIDTH:0] wgray;

    reg  [ADDR_WIDTH:0] rbin;
    reg  [ADDR_WIDTH:0] rgray;


    wire [ADDR_WIDTH:0] wbin_next;
    wire [ADDR_WIDTH:0] wgray_next;

    wire [ADDR_WIDTH:0] rbin_next;
    wire [ADDR_WIDTH:0] rgray_next;


    //=========================================================================
    // POINTER SYNCHRONIZERS
    //=========================================================================

    // Read pointer synchronized into write clock domain

    reg [ADDR_WIDTH:0] wq1_rptr;
    reg [ADDR_WIDTH:0] wq2_rptr;


    // Write pointer synchronized into read clock domain

    reg [ADDR_WIDTH:0] rq1_wptr;
    reg [ADDR_WIDTH:0] rq2_wptr;


    //------------------------------------------------------------------------
    // Read Gray pointer synchronization
    //------------------------------------------------------------------------

    always @(posedge wclk or negedge wrst_n) begin

        if (!wrst_n) begin

            wq1_rptr <= '0;
            wq2_rptr <= '0;

        end
        else begin

            wq1_rptr <= rgray;
            wq2_rptr <= wq1_rptr;

        end

    end


    //------------------------------------------------------------------------
    // Write Gray pointer synchronization
    //------------------------------------------------------------------------

    always @(posedge rclk or negedge rrst_n) begin

        if (!rrst_n) begin

            rq1_wptr <= '0;
            rq2_wptr <= '0;

        end
        else begin

            rq1_wptr <= wgray;
            rq2_wptr <= rq1_wptr;

        end

    end


    //=========================================================================
    // WRITE DOMAIN LOGIC
    //=========================================================================

    // Accept write only when FIFO is not full

    wire wen = winc & ~wfull;


    //------------------------------------------------------------------------
    // Next binary write pointer
    //------------------------------------------------------------------------

    assign wbin_next = wbin + {{ADDR_WIDTH{1'b0}}, wen};


    //------------------------------------------------------------------------
    // Binary-to-Gray conversion
    //------------------------------------------------------------------------

    assign wgray_next = (wbin_next >> 1) ^ wbin_next;


    //------------------------------------------------------------------------
    // Write pointer update
    //------------------------------------------------------------------------

    always @(posedge wclk or negedge wrst_n) begin

        if (!wrst_n) begin

            wbin  <= '0;
            wgray <= '0;

        end
        else begin

            wbin  <= wbin_next;
            wgray <= wgray_next;

        end

    end


    //------------------------------------------------------------------------
    // FIFO memory write
    //------------------------------------------------------------------------

    always @(posedge wclk) begin

        if (wen) begin

            mem[wbin[ADDR_WIDTH-1:0]] <= wdata;

        end

    end


    //------------------------------------------------------------------------
    // Full flag generation
    //------------------------------------------------------------------------

    // FIFO is full when the next write Gray pointer equals the synchronized
    // read Gray pointer with its two most significant bits inverted.

    wire wfull_val = (
        wgray_next ==
        {
            ~wq2_rptr[ADDR_WIDTH:ADDR_WIDTH-1],
             wq2_rptr[ADDR_WIDTH-2:0]
        }
    );


    always @(posedge wclk or negedge wrst_n) begin

        if (!wrst_n) begin

            wfull <= 1'b0;

        end
        else begin

            wfull <= wfull_val;

        end

    end


    //=========================================================================
    // READ DOMAIN LOGIC
    //=========================================================================

    // Accept read only when FIFO is not empty

    wire ren = rinc & ~rempty;


    //------------------------------------------------------------------------
    // Next binary read pointer
    //------------------------------------------------------------------------

    assign rbin_next = rbin + {{ADDR_WIDTH{1'b0}}, ren};


    //------------------------------------------------------------------------
    // Binary-to-Gray conversion
    //------------------------------------------------------------------------

    assign rgray_next = (rbin_next >> 1) ^ rbin_next;


    //------------------------------------------------------------------------
    // Read pointer update
    //------------------------------------------------------------------------

    always @(posedge rclk or negedge rrst_n) begin

        if (!rrst_n) begin

            rbin  <= '0;
            rgray <= '0;

        end
        else begin

            rbin  <= rbin_next;
            rgray <= rgray_next;

        end

    end


    //------------------------------------------------------------------------
    // FIFO memory read (First-Word Fall-Through)
    //------------------------------------------------------------------------

    assign rdata = mem[rbin[ADDR_WIDTH-1:0]];


    //------------------------------------------------------------------------
    // Empty flag generation
    //------------------------------------------------------------------------

    // FIFO is empty when the next read Gray pointer equals the synchronized
    // write Gray pointer.

    wire rempty_val = (rgray_next == rq2_wptr);


    always @(posedge rclk or negedge rrst_n) begin

        if (!rrst_n) begin

            rempty <= 1'b1;

        end
        else begin

            rempty <= rempty_val;

        end

    end


endmodule
