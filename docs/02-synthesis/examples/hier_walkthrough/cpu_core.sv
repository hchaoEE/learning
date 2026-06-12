// 11 章层次化示意：子块 — 仅输出端口参与顶层时序预算
module cpu_core (
    input  logic       clk,
    input  logic [7:0] in_data,
    output logic [7:0] out_data
);
    logic [7:0] acc;

    always_ff @(posedge clk) begin
        acc <= acc + in_data;
    end

    assign out_data = acc;
endmodule
