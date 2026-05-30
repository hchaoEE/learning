// 案例：MUX / case → AIG（可能先膨胀再 rewrite）
module comb_mux (
    input  logic        sel,
    input  logic [3:0]  a,
    input  logic [3:0]  b,
    output logic [3:0]  y
);
    always_comb begin
        unique case (sel)
            1'b0: y = a;
            1'b1: y = b;
            default: y = '0;
        endcase
    end
endmodule
