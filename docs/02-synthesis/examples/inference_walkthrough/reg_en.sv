// 推断案例：带时钟使能的寄存器
module reg_en (
    input  logic             clk,
    input  logic             en,
    input  logic [7:0]       d,
    output logic [7:0]       cnt
);
    always_ff @(posedge clk) begin
        if (en)
            cnt <= cnt + d;
    end
endmodule
