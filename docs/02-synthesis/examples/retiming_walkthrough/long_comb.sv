// 教学用：单周期长组合链 — 综合可能 retime 切分（若未 set_dont_retime）
module long_comb (
    input  logic             clk,
    input  logic [7:0]         a, b, c,
    output logic [7:0]         q
);
    logic [7:0] t1, t2;

    always_ff @(posedge clk) begin
        t1 <= (a & b) | c;
        t2 <= t1 + 8'h01;
        q  <= {t2[6:0], t2[7]};  // 示意多级组合；实际 retime 由工具决定
    end
endmodule
