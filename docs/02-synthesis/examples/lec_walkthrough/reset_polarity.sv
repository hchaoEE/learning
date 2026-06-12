// 10 §5 / 案例 4.2 — async reset 极性：Cycle0 LEC 反例
module reset_polarity (
  input  logic clk,
  input  logic rst_n,
  input  logic d,
  output logic q
);
  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) q <= 1'b0;
    else        q <= d;
endmodule
