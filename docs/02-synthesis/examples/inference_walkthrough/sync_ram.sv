// 推断案例：同步 1R1W 存储器模板
module sync_ram (
    input  logic             clk,
    input  logic             we,
    input  logic             re,
    input  logic [9:0]       addr,
    input  logic [31:0]      wdata,
    output logic [31:0]      rdata
);
    logic [31:0] ram [0:1023];

    always_ff @(posedge clk) begin
        if (we)
            ram[addr] <= wdata;
        if (re)
            rdata <= ram[addr];
    end
endmodule
