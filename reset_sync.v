// Asynchronous-assert, synchronous-deassert reset synchronizer (one per clock domain).
module reset_sync (
    input  wire clk,
    input  wire arst_n,
    output wire rst_n
);
    (* ASYNC_REG = "TRUE" *) reg q1, q2;
    always @(posedge clk or negedge arst_n)
        if (!arst_n) {q2, q1} <= 2'b00;
        else         {q2, q1} <= {q1, 1'b1};
    assign rst_n = q2;
endmodule
