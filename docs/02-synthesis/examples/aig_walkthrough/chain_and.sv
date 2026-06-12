// 03 §5.4 balance — 六输入链状 AND，balance 后拉宽成树
module chain_and (
  input  logic a, b, c, d, e, f,
  output logic y
);
  assign y = a & b & c & d & e & f;
endmodule
