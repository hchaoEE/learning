// 端到端迷你链：Elab → 推断 → AIG → Map → STA（概念演示）
// 见 README.md 各阶段 IR 快照

module mini_chain (
    input  logic       clk,
    input  logic [3:0] a,
    input  logic [3:0] b,
    output logic [7:0] q
);

    logic [7:0] prod;
    logic [7:0] nxt;

    assign prod = a * b;
    assign nxt  = prod + 8'd1;

    always_ff @(posedge clk)
        q <= nxt;

endmodule
