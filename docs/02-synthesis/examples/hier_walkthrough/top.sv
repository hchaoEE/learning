// 11 章层次化示意：顶层 glue + 子块实例（budget 在 out_data 接口）
module top (
    input  logic       clk,
    input  logic [7:0] host_data,
    output logic [7:0] host_result
);
    logic [7:0] core_out;

    cpu_core u_cpu (
        .clk      (clk),
        .in_data  (host_data),
        .out_data (core_out)
    );

    // 顶层 glue：一级组合（示意接口逻辑）
    assign host_result = core_out + 8'd1;
endmodule
