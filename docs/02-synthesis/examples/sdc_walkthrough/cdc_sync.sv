// 05 §4.3 clock_groups / CDC — 双 FF 同步器跨 clk_a → clk_b
module cdc_sync (
  input  logic       clk_a,
  input  logic       clk_b,
  input  logic       rst_n,
  input  logic       data_a,
  output logic       data_b
);
  logic sync0, sync1;

  always_ff @(posedge clk_a or negedge rst_n)
    if (!rst_n) sync0 <= 1'b0;
    else        sync0 <= data_a;

  always_ff @(posedge clk_b or negedge rst_n)
    if (!rst_n) {sync1, data_b} <= 2'b0;
    else        {sync1, data_b} <= {sync0, sync1};
endmodule
