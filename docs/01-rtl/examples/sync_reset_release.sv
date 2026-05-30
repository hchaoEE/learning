// 可综合：异步复位输入，同步释放后的复位域内使用
`default_nettype none

module sync_reset_release (
    input  logic clk,
    input  logic rst_n,       // 芯片级异步复位，低有效
    output logic rst_sync_n   // 同步释放后的复位
);
    logic r1, r2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r1 <= 1'b0;
            r2 <= 1'b0;
        end else begin
            r1 <= 1'b1;
            r2 <= r1;
        end
    end

    assign rst_sync_n = r2;

endmodule
