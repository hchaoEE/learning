// 09 §2.1 retention — 关断域内可保持状态的 FF
module retention_domain (
  input  logic       clk,
  input  logic       rst_n,
  input  logic       psw_off,
  input  logic       ret_save,
  input  logic       ret_restore,
  input  logic [7:0] d,
  output logic [7:0] q
);
  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) q <= 8'b0;
    else if (!psw_off) q <= d;  // 常开：正常功能（UPF 映射为 retention DFF）
endmodule
