// 映射案例：MUX → 常用 AO/OA/MUX 单元或 NAND 网络
module map_mux (
    input  logic        sel,
    input  logic [1:0]  a,
    input  logic [1:0]  b,
    output logic [1:0]  y
);
    assign y = sel ? b : a;
endmodule
