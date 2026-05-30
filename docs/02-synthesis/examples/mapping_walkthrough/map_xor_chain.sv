// 映射案例：异或链 — AIG 展开后映射为 XOR 单元或 AND/INV 网络
module map_xor_chain (
    input  logic a, b, c,
    output logic p, q
);
    assign p = a ^ b;
    assign q = p ^ c;
endmodule
