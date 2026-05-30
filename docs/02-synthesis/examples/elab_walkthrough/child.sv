// 子模块：参数化位宽 + 时序传递
module child #(
    parameter int W = 8
) (
    input  logic             clk,
    input  logic [W-1:0]     din,
    output logic [W-1:0]     dout
);
    always_ff @(posedge clk) begin
        dout <= din;
    end
endmodule
