# 1.6 generate 与参数化设计

## 1. parameter 与 localparam

```verilog
module shift_reg #(
    parameter WIDTH = 8,
    parameter DEPTH = 4
) (
    input  logic             clk,
    input  logic             din,
    output logic [WIDTH-1:0] dout
);
    localparam int ADDR_W = $clog2(DEPTH);
    // ...
endmodule
```

实例化时覆盖：

```verilog
shift_reg #(.WIDTH(16), .DEPTH(8)) u_sr (...);
```

## 2. `generate` 块

在 **elaboration** 阶段展开，用于复制结构、条件实例化。

### 按条件实例化

```verilog
generate
    if (USE_PARITY)
        parity_gen u_par (.data(data), .parity(parity));
    else
        assign parity = 1'b0;
endgenerate
```

### `for` 生成阵列

```verilog
genvar i;
generate
    for (i = 0; i < N; i = i + 1) begin : gen_slice
        assign out[i] = in[i] ^ mask[i];
    end
endgenerate
```

- `genvar` 仅用于 generate 循环。
- 块标签 `gen_slice` 会出现在层次路径中（`out[3]` → `gen_slice[3].out`）。

## 3. 参数化总线与函数

```verilog
function automatic logic [WIDTH-1:0] reverse_bits;
    input logic [WIDTH-1:0] x;
    for (int k = 0; k < WIDTH; k++)
        reverse_bits[k] = x[WIDTH-1-k];
endfunction
```

- `automatic` 函数在综合中可内联为组合逻辑（工具支持度需验证）。
- 复杂算法更适合 **手写结构** 或 **高层次综合（HLS）** 流程。

## 4. 与综合的关系

- `parameter` 在综合前常可 **折叠** 为常量，生成不同网表配置。
- `generate` 不产生额外硬件类型，只是 **复制/选择** 模块。
- 避免用 `parameter` 表达 **运行时** 才知的配置（应走寄存器或软件配置接口）。

## 5. 小结

- 用 `parameter` + `generate` 实现可配置 IP，而非复制粘贴多份 RTL。
- generate 层次命名要有意义，便于调试。
- 函数保持简单、可综合。

## 下一节

[07 可综合子集](./07-synthesizable-subset.md)
