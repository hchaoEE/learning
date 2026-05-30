// 顶层：generate 例化 + 组合逻辑（walkthrough 用）
module top #(
    parameter int N = 2,
    parameter int W = 8
) (
    input  logic             clk,
    input  logic             en,
    input  logic [W-1:0]     data_in,
    output logic [W-1:0]     data_out
);
    logic [W-1:0] sum;

    generate
        for (genvar i = 0; i < N; i++) begin : g_slice
            child #(.W(W)) u_child (
                .clk  (clk),
                .din  (data_in),
                .dout (sum)
            );
        end
    endgenerate

    always_comb begin
        if (en)
            data_out = sum;
        // 故意缺 else：文档 latch 案例
    end
endmodule
