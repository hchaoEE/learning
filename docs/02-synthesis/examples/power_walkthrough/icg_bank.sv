// ICG 推断 walkthrough：32 位同步 enable bank
// 对照 02 §9、08 §3

module icg_bank (
    input  logic        clk,
    input  logic        en,
    input  logic [31:0] d,
    output logic [31:0] q
);

    always_ff @(posedge clk) begin
        if (en)
            q <= d;
    end

endmodule
