// SDC walkthrough：最小 FF→FF 路径，用于时序图与 slack 示意
// 对照 05 章 §2、§3 与 examples/sdc_walkthrough/README.md

module simple_ff_path (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       din,
    output logic       dout
);

    logic q_mid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) q_mid <= 1'b0;
        else        q_mid <= din;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) dout <= 1'b0;
        else        dout <= q_mid;
    end

endmodule
