# 1.7 可综合子集与仿真专用构造

综合工具只接受 HDL 的 **子集**。下列区分“可综合”与“仅仿真”。

## 1. 通常可综合

| 构造 | 说明 |
|------|------|
| `module` / `endmodule`、实例化 | 层次结构 |
| `assign`、`always @(*)`、`always @(posedge clk)` | 组合与时序 |
| `if` / `case` / `for`（generate 中） | 控制结构 |
| `parameter`、`localparam`、`generate` | 参数化 |
| 算术、逻辑、移位、拼接 | 运算符 |
| `function`（无延时、无递归过深） | 简单组合函数 |
| `typedef enum` (SV) | FSM 状态 |

## 2. 通常不可综合或需特殊处理

| 构造 | 原因 |
|------|------|
| `#delay`、`@(posedge a or b)` 任意边沿 | 仿真调度，无物理意义 |
| `initial`（ASIC 综合） | 仅仿真/FPGA 初始化策略不同 |
| `fork` / `join`、`wait`、`force` | 测试平台专用 |
| `real`、`time` | 非硬件类型 |
| `while` 在 `always` 内（动态循环） | 循环次数非静态 |
| `deassign`、`defparam`（过时） | 避免使用 |
| 系统任务 `$display` 等 | 仅仿真；可用 `` `ifdef SYNTHESIS `` 包裹 |

```verilog
`ifndef SYNTHESIS
    initial $display("sim only");
`endif
```

## 3. 需谨慎的构造

### 3.1 数组与存储器

```verilog
logic [7:0] mem [0:255];

always @(posedge clk) begin
    if (we)
        mem[addr] <= wdata;
    rdata <= mem[addr];  // 读：可能推断为 RAM/ROM
end
```

- 综合推断 **单端口/双端口 RAM** 取决于读写模式；与工艺/FPGA 模板不匹配会出意外寄存器或 latch。
- **异步读**（组合读地址）在 FPGA 上常映射为分布式 RAM 或 LUT，ASIC 需查库。

### 3.2 除法与取模

- 非常数除法器面积大、延时高；尽量 **常数除** 或 **移位近似**。

### 3.3 递归与深度循环

- `for` 在 `always_comb` 中若边界为 parameter，可展开；运行时变量边界则困难。

## 4. SystemVerilog 可综合常用扩展

```verilog
always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) q <= '0;
    else        q <= d;

always_comb
    out = a + b;

logic [7:0] v;
assign v = '0;  // 填充零
```

- `always_ff` / `always_comb` / `always_latch` 明确意图，工具友好。
- `interface`、`class` 多用于 TB，综合支持有限。

## 5. 综合指导属性（工具相关）

```verilog
(* keep = "true" *) logic probe_sig;
(* dont_touch = "true" *) logic debug_reg;
```

用于调试、形式验证或防止优化掉关键节点；量产 RTL 应慎用。

## 6. 小结

- 默认按 **可综合子集** 写 RTL；仿真专用代码用宏隔离。
- 存储器、除法、异步读等提前查 **目标工艺/FPGA 推断指南**。
- 下一章编码规范进一步归纳 **团队级规则**。

## 下一节

[08 编码规范](./08-coding-guidelines.md)
