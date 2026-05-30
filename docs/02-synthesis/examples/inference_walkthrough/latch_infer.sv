// 推断案例：不完整组合分支 → latch
module latch_infer (
    input  logic             hold,
    input  logic [7:0]       bus_in,
    output logic [7:0]       data_hold
);
    always_comb begin
        if (hold)
            data_hold = bus_in;
    end
endmodule
