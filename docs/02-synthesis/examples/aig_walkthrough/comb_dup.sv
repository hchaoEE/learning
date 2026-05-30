// 案例：重复子表达式 → strash 合并
module comb_dup (
    input  logic a,
    input  logic b,
    input  logic c,
    output logic y,
    output logic z
);
    assign y = a & b;
    assign z = (a & b) | c;
endmodule
