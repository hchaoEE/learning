// 可综合：带异步复位、同步风格数据路径的 D 触发器示例
`default_nettype none

module dff_async_rst #(
    parameter int WIDTH = 1
) (
    input  logic             clk,
    input  logic             rst_n,
    input  logic [WIDTH-1:0] d,
    output logic [WIDTH-1:0] q
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            q <= '0;
        else
            q <= d;
    end
endmodule
