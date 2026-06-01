// 映射案例：与或非 → 标准单元链
module map_and_or (
    input  logic a, b, c,
    output logic y
);
    assign y = (a & b) | c;
endmodule
