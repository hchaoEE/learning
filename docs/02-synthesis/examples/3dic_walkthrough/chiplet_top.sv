// 两 die chiplet 最小示例 — 与 15 章 §2、§3 对照
// die0: 计算；die1: 存储；单时钟域经 bump 连接

module die0_compute #(
    parameter int W = 16
) (
    input  logic             clk,
    input  logic [W-1:0]     a,
    input  logic [W-1:0]     b,
    output logic [W-1:0]     die_bus_out
);
    logic [W-1:0] sum_r;
    always_ff @(posedge clk) sum_r <= a + b;
    assign die_bus_out = sum_r;  // 驱动 bump_out（概念）
endmodule

module die1_mem #(
    parameter int W = 16
) (
    input  logic             clk,
    input  logic [W-1:0]     die_bus_in,   // 来自 bump_in
    output logic [W-1:0]     q
);
    logic [W-1:0] mem_r;
    always_ff @(posedge clk) mem_r <= die_bus_in;
    assign q = mem_r;
endmodule

module chiplet_top #(
    parameter int W = 16
) (
    input  logic             clk,
    input  logic [W-1:0]     a,
    input  logic [W-1:0]     b,
    output logic [W-1:0]     q
);
    logic [W-1:0] die_bus;

  // 综合分区：u_compute → die D0；u_mem → die D1
    die0_compute #(.W(W)) u_compute (
        .clk(clk), .a(a), .b(b), .die_bus_out(die_bus)
    );
    die1_mem #(.W(W)) u_mem (
        .clk(clk), .die_bus_in(die_bus), .q(q)
    );
endmodule
