// 案例：寄存器边界 — 组合锥不穿过 DFF
module reg_comb_boundary (
    input  logic clk,
    input  logic [7:0] a, b,
    output logic [7:0] q
);
    logic [7:0] sum;
    assign sum = a ^ b;   // 组合锥 1：仅 a,b → sum

    always_ff @(posedge clk)
        q <= sum + 1'b1;  // 加法/进位在 GTECH 算术边界，不拆进 AIG
endmodule
