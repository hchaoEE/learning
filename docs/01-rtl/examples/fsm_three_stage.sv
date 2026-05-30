// 可综合：三段式 FSM 示例（Moore 输出）
`default_nettype none

module fsm_three_stage (
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    input  logic done,
    output logic busy
);
    typedef enum logic [1:0] {
        S_IDLE = 2'b00,
        S_RUN  = 2'b01,
        S_DONE = 2'b10
    } state_e;

    state_e state, next_state;

    // 段 1：次态
    always_comb begin
        next_state = state;
        unique case (state)
            S_IDLE: if (start) next_state = S_RUN;
            S_RUN:  if (done)  next_state = S_DONE;
            S_DONE: next_state = S_IDLE;
            default: next_state = S_IDLE;
        endcase
    end

    // 段 2：状态寄存器
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= S_IDLE;
        else
            state <= next_state;
    end

    // 段 3：Moore 输出
    assign busy = (state != S_IDLE);

endmodule
