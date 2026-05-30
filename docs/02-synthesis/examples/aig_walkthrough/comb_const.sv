// 案例：常量传播 + 死逻辑消除
module comb_const (
    input  logic [3:0] din,
    output logic [3:0] y,
    output logic       flag
);
    localparam logic [3:0] MASK = 4'b1010;
    assign y    = din & MASK;
    assign flag = din[0] & 1'b0;  // 恒 0
endmodule
