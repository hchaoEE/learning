// Hold 违例 walkthrough：launch 与 capture 物理邻近，组合极短
// 对照 06 章 §4  fast corner / delay 插入
// 拓扑：reg_a/Q → 单级 NAND → reg_b/D

module hold_short_path (
    input  logic       clk,
    input  logic       a, b,
    output logic       q
);

    logic a_r;                       // launch FF：reg_a
    logic nd;

    always_ff @(posedge clk) begin
        a_r <= a;
    end

    assign nd = ~(a_r & b);          // 单级 NAND（映射为强驱动 ND2D4）

    always_ff @(posedge clk) begin
        q <= nd;                     // capture FF：reg_b
    end

endmodule
