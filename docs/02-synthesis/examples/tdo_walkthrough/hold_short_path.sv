// Hold 违例 walkthrough：launch 与 capture 物理邻近，组合极短
// 对照 06 章 §4  fast corner / delay 插入

module hold_short_path (
    input  logic       clk,
    input  logic       a, b,
    output logic       q
);

    logic d;

    assign d = a & b;

    always_ff @(posedge clk) begin
        q <= d;
    end

endmodule
