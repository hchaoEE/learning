// 细粒度优化 walkthrough：故意深组合链，映射后 setup 易违例
// 对照 06 章 §2.5、§3 内部 delay/slack 表（见 README）

module setup_critical_chain (
    input  logic       clk,
    input  logic       a, b, c, d, e,
    output logic       q
);

    logic w1, w2, w3, w4;

    assign w1 = a & b;
    assign w2 = w1 & c;
    assign w3 = w2 & d;
    assign w4 = w3 & e;

    always_ff @(posedge clk) begin
        q <= w4;
    end

endmodule
