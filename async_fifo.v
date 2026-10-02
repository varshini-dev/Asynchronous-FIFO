// Dual-clock (asynchronous) FIFO, Gray-code pointer architecture (Cummings, SNUG 2002).
//   - write side in wclk domain, read side in rclk domain
//   - binary pointer for RAM addressing, Gray pointer crossing the clock boundary
//   - 2-flop synchronizers (ASYNC_REG) on each pointer
//   - one extra pointer bit distinguishes FULL from EMPTY
//   - rdata is valid whenever rempty = 0 (first-word-fall-through style RAM read)
module async_fifo #(
    parameter DSIZE = 8,
    parameter ASIZE = 4          // depth = 2**ASIZE  (ASIZE >= 2)
)(
    input  wire             wclk, wrst_n, winc,
    input  wire [DSIZE-1:0] wdata,
    output wire             wfull,
    input  wire             rclk, rrst_n, rinc,
    output wire [DSIZE-1:0] rdata,
    output wire             rempty
);
    wire [ASIZE-1:0] waddr, raddr;
    wire [ASIZE:0]   wptr, rptr, wq2_rptr, rq2_wptr;

    sync_r2w   u_sync_r2w   (.wclk(wclk), .wrst_n(wrst_n), .rptr(rptr),  .wq2_rptr(wq2_rptr));
    sync_w2r   u_sync_w2r   (.rclk(rclk), .rrst_n(rrst_n), .wptr(wptr),  .rq2_wptr(rq2_wptr));
    fifo_mem   #(DSIZE, ASIZE) u_mem (.wclk(wclk), .wclken(winc), .wfull(wfull), .waddr(waddr),
                                       .wdata(wdata), .raddr(raddr), .rdata(rdata));
    rptr_empty #(ASIZE) u_rptr_empty (.rclk(rclk), .rrst_n(rrst_n), .rinc(rinc), .rq2_wptr(rq2_wptr),
                                       .rempty(rempty), .raddr(raddr), .rptr(rptr));
    wptr_full  #(ASIZE) u_wptr_full  (.wclk(wclk), .wrst_n(wrst_n), .winc(winc), .wq2_rptr(wq2_rptr),
                                       .wfull(wfull), .waddr(waddr), .wptr(wptr));
endmodule

// ---------------- memory ----------------
module fifo_mem #(parameter DSIZE = 8, parameter ASIZE = 4)(
    input  wire             wclk, wclken, wfull,
    input  wire [ASIZE-1:0] waddr, raddr,
    input  wire [DSIZE-1:0] wdata,
    output wire [DSIZE-1:0] rdata
);
    localparam DEPTH = 1 << ASIZE;
    reg [DSIZE-1:0] mem [0:DEPTH-1];
    assign rdata = mem[raddr];
    always @(posedge wclk)
        if (wclken && !wfull) mem[waddr] <= wdata;
endmodule

// ---------------- synchronizers ----------------
module sync_r2w #(parameter ASIZE = 4)(          // read pointer -> write domain
    input  wire wclk, wrst_n,
    input  wire [ASIZE:0] rptr,
    output reg  [ASIZE:0] wq2_rptr
);
    (* ASYNC_REG = "TRUE" *) reg [ASIZE:0] wq1_rptr;
    always @(posedge wclk or negedge wrst_n)
        if (!wrst_n) {wq2_rptr, wq1_rptr} <= 0;
        else         {wq2_rptr, wq1_rptr} <= {wq1_rptr, rptr};
endmodule

module sync_w2r #(parameter ASIZE = 4)(          // write pointer -> read domain
    input  wire rclk, rrst_n,
    input  wire [ASIZE:0] wptr,
    output reg  [ASIZE:0] rq2_wptr
);
    (* ASYNC_REG = "TRUE" *) reg [ASIZE:0] rq1_wptr;
    always @(posedge rclk or negedge rrst_n)
        if (!rrst_n) {rq2_wptr, rq1_wptr} <= 0;
        else         {rq2_wptr, rq1_wptr} <= {rq1_wptr, wptr};
endmodule

// ---------------- read pointer + EMPTY ----------------
module rptr_empty #(parameter ASIZE = 4)(
    input  wire rclk, rrst_n, rinc,
    input  wire [ASIZE:0] rq2_wptr,
    output reg  rempty,
    output wire [ASIZE-1:0] raddr,
    output reg  [ASIZE:0] rptr
);
    reg  [ASIZE:0] rbin;
    wire [ASIZE:0] rbnext = rbin + (rinc & ~rempty);
    wire [ASIZE:0] rgnext = (rbnext >> 1) ^ rbnext;       // binary -> Gray
    assign raddr = rbin[ASIZE-1:0];
    always @(posedge rclk or negedge rrst_n)
        if (!rrst_n) {rbin, rptr} <= 0;
        else         {rbin, rptr} <= {rbnext, rgnext};
    // EMPTY when next read Gray pointer equals synchronized write Gray pointer
    always @(posedge rclk or negedge rrst_n)
        if (!rrst_n) rempty <= 1'b1;
        else         rempty <= (rgnext == rq2_wptr);
endmodule

// ---------------- write pointer + FULL ----------------
module wptr_full #(parameter ASIZE = 4)(
    input  wire wclk, wrst_n, winc,
    input  wire [ASIZE:0] wq2_rptr,
    output reg  wfull,
    output wire [ASIZE-1:0] waddr,
    output reg  [ASIZE:0] wptr
);
    reg  [ASIZE:0] wbin;
    wire [ASIZE:0] wbnext = wbin + (winc & ~wfull);
    wire [ASIZE:0] wgnext = (wbnext >> 1) ^ wbnext;
    assign waddr = wbin[ASIZE-1:0];
    always @(posedge wclk or negedge wrst_n)
        if (!wrst_n) {wbin, wptr} <= 0;
        else         {wbin, wptr} <= {wbnext, wgnext};
    // FULL when Gray pointers match with the two MSBs inverted
    always @(posedge wclk or negedge wrst_n)
        if (!wrst_n) wfull <= 1'b0;
        else         wfull <= (wgnext == {~wq2_rptr[ASIZE:ASIZE-1], wq2_rptr[ASIZE-2:0]});
endmodule
