// Board demo for the dual-clock FIFO (Basys-3 style, 100 MHz input clock).
//   MMCM makes wclk = 100 MHz and rclk = 40 MHz  (asynchronous to each other in the constraints).
//   Writer pushes an incrementing counter whenever not full (so FULL is hit often),
//   reader pops whenever not empty and checks the sequence.  Any mismatch latches led[1].
module fifo_board_top (
    input  wire        clk100,
    input  wire        btnC,
    output wire [15:0] led
);
    wire clkfb_u, clkfb, wclk_u, rclk_u, wclk, rclk, locked;

    MMCME2_BASE #(
        .CLKIN1_PERIOD(10.0), .DIVCLK_DIVIDE(1), .CLKFBOUT_MULT_F(10.0),   // VCO = 1000 MHz
        .CLKOUT0_DIVIDE_F(10.0),                                           // 100 MHz
        .CLKOUT1_DIVIDE(25)                                                //  40 MHz
    ) u_mmcm (
        .CLKIN1(clk100), .CLKFBIN(clkfb), .CLKFBOUT(clkfb_u),
        .CLKOUT0(wclk_u), .CLKOUT1(rclk_u), .LOCKED(locked), .PWRDWN(1'b0), .RST(1'b0)
    );
    BUFG u_fb (.I(clkfb_u), .O(clkfb));
    BUFG u_bw (.I(wclk_u),  .O(wclk));
    BUFG u_br (.I(rclk_u),  .O(rclk));

    wire arst_n = locked & ~btnC;
    wire wrst_n, rrst_n;
    reset_sync u_wrs (.clk(wclk), .arst_n(arst_n), .rst_n(wrst_n));
    reset_sync u_rrs (.clk(rclk), .arst_n(arst_n), .rst_n(rrst_n));

    wire        wfull, rempty;
    wire [7:0]  rdata;
    reg  [7:0]  wcnt, rexp;
    reg  [31:0] rtotal;
    reg         err, saw_full, saw_empty;
    reg  [26:0] hb;

    wire winc = ~wfull;
    wire rinc = ~rempty;

    async_fifo #(.DSIZE(8), .ASIZE(4)) u_fifo (
        .wclk(wclk), .wrst_n(wrst_n), .winc(winc), .wdata(wcnt), .wfull(wfull),
        .rclk(rclk), .rrst_n(rrst_n), .rinc(rinc), .rdata(rdata), .rempty(rempty));

    // write side (100 MHz)
    always @(posedge wclk or negedge wrst_n)
        if (!wrst_n) begin wcnt <= 0; saw_full <= 0; hb <= 0; end
        else begin
            hb <= hb + 1;
            if (winc) wcnt <= wcnt + 1;
            if (wfull) saw_full <= 1;
        end

    // read side (40 MHz): data checker
    always @(posedge rclk or negedge rrst_n)
        if (!rrst_n) begin rexp <= 0; rtotal <= 0; err <= 0; saw_empty <= 0; end
        else begin
            if (rempty) saw_empty <= 1;
            if (rinc) begin
                rexp   <= rexp + 1;
                rtotal <= rtotal + 1;
                if (rdata !== rexp) err <= 1;
            end
        end

    assign led[0]    = locked;
    assign led[1]    = err;          // must stay 0
    assign led[2]    = saw_full;     // should become 1 (write faster than read)
    assign led[3]    = saw_empty;
    assign led[4]    = hb[26];       // heartbeat
    assign led[7:5]  = 3'b000;
    assign led[15:8] = rtotal[31:24];
endmodule
