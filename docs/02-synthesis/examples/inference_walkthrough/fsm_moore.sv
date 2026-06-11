// 推断案例：3 状态 Moore FSM — 状态编码由综合器策略决定（02 §7）
module fsm_moore (
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    input  logic finish,
    output logic busy
);
    typedef enum logic [1:0] { IDLE, RUN, DONE } state_e;
    state_e state, state_n;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else        state <= state_n;
    end

    always_comb begin
        state_n = state;
        unique case (state)
            IDLE:    if (start)  state_n = RUN;
            RUN:     if (finish) state_n = DONE;
            DONE:                state_n = IDLE;
            default:             state_n = IDLE;
        endcase
    end

    assign busy = (state == RUN);
endmodule
