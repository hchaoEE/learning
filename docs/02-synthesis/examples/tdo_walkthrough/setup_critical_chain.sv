// 细粒度优化 walkthrough：故意深组合链，映射后 setup 易违例
// 对照 06 章 §2.5、§3 内部 delay/slack 表（见 README）
// 拓扑：reg_a/Q → 5 级 AND 链（u1–u5）→ reg_q/D

module setup_critical_chain (
    input  logic       clk,
    input  logic       a, b, c, d, e, f,
    output logic       q
);

    logic a_r;                       // launch FF：reg_a
    logic w1, w2, w3, w4, w5;

    always_ff @(posedge clk) begin
        a_r <= a;
    end

    assign w1 = a_r & b;             // u1
    assign w2 = w1  & c;             // u2
    assign w3 = w2  & d;             // u3
    assign w4 = w3  & e;             // u4
    assign w5 = w4  & f;             // u5

    always_ff @(posedge clk) begin
        q <= w5;                     // capture FF：reg_q
    end

endmodule
