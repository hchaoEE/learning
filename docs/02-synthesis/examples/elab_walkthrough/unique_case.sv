// 01 §8.4 unique case — 并行 MUX vs priority 级联
module unique_case (
  input  logic [1:0] sel,
  input  logic       a, b, c,
  output logic       y
);
  unique case (sel)
    2'b00: y = a;
    2'b01: y = b;
    default: y = c;
  endcase
endmodule
