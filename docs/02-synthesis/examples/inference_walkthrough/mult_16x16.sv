// 推断案例：乘法器
module mult_16x16 (
    input  logic [15:0] a,
    input  logic [15:0] b,
    output logic [31:0] prod
);
    assign prod = a * b;
endmodule
