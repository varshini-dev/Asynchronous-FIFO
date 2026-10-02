`timescale 1ns/1ps
// Self-checking testbench for the dual-clock FIFO.  Phases change clock ratio and traffic
// pattern: W>R fill-up, R>W drain, similar clocks, random.  Scoreboard checks order/data,
// no underflow, no overflow, and that FULL and EMPTY were both exercised.
module tb_async_fifo;
    localparam DSIZE = 8, ASIZE = 4, DEPTH = 1 << ASIZE, NMAX = 20000;

    reg wclk = 0, rclk = 0, wrst_n = 0, rrst_n = 0;
    real wper = 10.0, rper = 27.0;               // ns, changed per phase
    always begin #(wper/2.0) wclk = ~wclk; end
    always begin #(rper/2.0) rclk = ~rclk; end

    reg  winc = 0, rinc = 0;
    integer wr_idx = 0, rd_idx = 0, pw = 70, pr = 70, errors = 0, max_occ = 0;
    reg saw_full = 0, saw_empty = 0;
    wire [DSIZE-1:0] wdata = wr_idx * 7 + 3;     // deterministic pseudo-data
    wire [DSIZE-1:0] rdata;
    wire wfull, rempty;

    async_fifo #(DSIZE, ASIZE) dut (.wclk(wclk), .wrst_n(wrst_n), .winc(winc), .wdata(wdata), .wfull(wfull),
                                    .rclk(rclk), .rrst_n(rrst_n), .rinc(rinc), .rdata(rdata), .rempty(rempty));

    reg [DSIZE-1:0] sb [0:NMAX-1];

    // write side stimulus + scoreboard capture
    always @(posedge wclk) if (wrst_n) begin
        if (winc && !wfull) begin sb[wr_idx] <= wdata; wr_idx <= wr_idx + 1; end
        if (wfull) saw_full <= 1;
        winc <= (($random & 32'h7fffffff) % 100) < pw;
    end
    // read side stimulus + checker
    always @(posedge rclk) if (rrst_n) begin
        if (rempty) saw_empty <= 1;
        if (rinc && !rempty) begin
            if (rd_idx >= wr_idx) begin errors = errors + 1; $display("%t UNDERFLOW", $time); end
            else if (rdata !== sb[rd_idx]) begin
                errors = errors + 1;
                if (errors < 10) $display("%t DATA ERR idx %0d got %h exp %h", $time, rd_idx, rdata, sb[rd_idx]);
            end
            rd_idx <= rd_idx + 1;
        end
        rinc <= (($random & 32'h7fffffff) % 100) < pr;
    end
    // occupancy must never exceed depth
    always @(posedge wclk) if (wr_idx - rd_idx > max_occ) max_occ = wr_idx - rd_idx;

    task phase(input real wp, input real rp, input integer pwi, input integer pri, input integer nwords);
        integer target;
        begin
            wper = wp; rper = rp; pw = pwi; pr = pri;
            target = wr_idx + nwords;
            while (wr_idx < target) @(posedge wclk);
        end
    endtask

    initial begin
        #53 wrst_n = 1; #17 rrst_n = 1;                      // staggered reset release
        phase(10.0, 27.0,  70,  70, 2000);                   // write faster than read -> FULL
        phase(27.0, 10.0,  70,  70, 2000);                   // read faster than write -> EMPTY
        phase(10.0, 10.3, 100, 100, 3000);                   // nearly equal clocks, max throughput
        phase(13.0, 11.0,  50,  90, 3000);                   // random
        phase(10.0, 40.0, 100,  15, 1000);                   // burst fill
        phase(40.0,  9.0,  10, 100, 1000);                   // burst drain
        pw = 0;                                              // drain
        repeat (200) @(posedge rclk);
        $display("words written = %0d, read = %0d, max occupancy = %0d (depth %0d)", wr_idx, rd_idx, max_occ, DEPTH);
        if (errors == 0 && rd_idx == wr_idx && saw_full && saw_empty && max_occ <= DEPTH)
            $display("PASS: FIFO data integrity OK, FULL and EMPTY both exercised");
        else
            $display("FAIL: errors=%0d wr=%0d rd=%0d full=%b empty=%b occ=%0d", errors, wr_idx, rd_idx, saw_full, saw_empty, max_occ);
        $finish;
    end
endmodule
