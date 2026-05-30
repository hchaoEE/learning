# 1.1 模块与端口

## 1. 模块是设计的基本单元

Verilog 用 `module` … `endmodule` 描述一块可综合逻辑（或 testbench 中的仿真模型）。

```verilog
module adder #(
    parameter WIDTH = 8
) (
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    output wire [WIDTH-1:0] sum
);
    assign sum = a + b;
endmodule
```

- **模块名**：与文件名一致是常见工程约定（一个文件一个 module）。
- **parameter**：编译期/elaboration 期常量，用于位宽、深度等可配置项。
- **端口列表**：建议 ANSI-C 风格（在端口声明处直接写 `input`/`output` 与位宽）。

## 2. 端口方向与类型

| 关键字 | 方向 | 综合中的角色 |
|--------|------|----------------|
| `input` | 模块输入 | 来自上级模块或顶层 IO |
| `output` | 模块输出 | 驱动下级或顶层 IO |
| `inout` | 双向 | 多用于 PAD/总线；需三态控制，使用要谨慎 |

端口数据类型常用：

- **`wire`**：线网，表示连接或连续赋值驱动。
- **`reg`**：在 **过程块**（`always`）中赋值的变量；综合后不一定对应物理寄存器。
- SystemVerilog 中推荐 **`logic`**：既可连续赋值也可过程赋值（单驱动前提下）。

```verilog
// 推荐：ANSI 端口 + 明确位宽
module fifo_ctrl (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        wr_en,
    output logic        full
);
    // ...
endmodule
```

## 3. 层次化实例化

下级模块通过 **实例化** 连接：

```verilog
adder #(.WIDTH(16)) u_add (
    .a   (op_a),
    .b   (op_b),
    .sum (result)
);
```

- **按名连接**（`.port(sig)`）优于按序连接，便于维护。
- 实例名 `u_add` 建议带功能前缀（`u_` / `gen_` 等），便于网表与波形定位。

## 4. 顶层与 IO 约束的衔接（ASIC）

综合与 PnR 需要将 RTL 端口与 **芯片 PAD / IO 单元** 及签核约束对齐：

- **SDC**：`create_clock`、`set_input_delay` / `set_output_delay`、`set_drive` 等，描述芯片边界时序。
- **物理**：IO 单元来自工艺 **IO library**；pin 顺序、电源域、ESD 规则在 floorplan 阶段确定，RTL 端口名需与 **DEF / pad frame** 约定一致。

RTL 阶段应保证：**时钟、复位、关键数据端口命名稳定**，避免后期改端口名导致 SDC、形式验证与后端网表不一致。

## 5. 小结

- 使用 **parameter + ANSI 端口** 提高可读性与可配置性。
- 层次化设计通过实例化拼装；保持 **单模块单文件** 与清晰命名。
- 端口位宽在模块边界写清楚，减少隐式扩展问题（见 [02-data-types-and-operators.md](./02-data-types-and-operators.md)）。

## 延伸阅读

- IEEE 1364 Verilog / IEEE 1800 SystemVerilog 端口与实例化章节
- 下一节：[02 数据类型与运算符](./02-data-types-and-operators.md)
