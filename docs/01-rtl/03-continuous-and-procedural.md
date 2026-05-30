# 1.3 连续赋值与过程块

## 1. 连续赋值 `assign`

描述 **组合逻辑** 或 **线网连接**，左侧必须为 `wire`/`logic`（或被连续驱动的 net）。

```verilog
assign y = (a & b) | c;
assign bus_out = enable ? driven : 1'bz;  // 三态，用于 PAD/总线时需约束配合
```

特点：

- 并行、无顺序依赖（除 RHS 表达式内部运算优先级）。
- 适合 **简单组合**、译码、多路选择。

## 2. `always` 块：组合 vs 时序

### 2.1 组合逻辑 `always @(*)`

```verilog
always @(*) begin
    if (sel)
        out = a;
    else
        out = b;
end
```

或使用 SystemVerilog：

```verilog
always_comb begin
    out = a + b;  // 阻塞赋值
end
```

**必须满足：**

1. 敏感列表完整 → 用 `@(*)` 或 `always_comb`。
2. 所有分支对 **所有输出** 赋值，否则综合推断 **锁存器**（latch）。
3. 块内使用 **阻塞赋值 `=`**。

### 2.2 时序逻辑 `always @(posedge clk)`

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        q <= 1'b0;
    else
        q <= d;
end
```

**必须满足：**

1. 使用 **非阻塞赋值 `<=`**。
2. 复位、使能、数据路径清晰；避免在同一时钟沿对同一寄存器多处 NBA 写入。
3. 避免在时序块内写 **组合环路**（同一周期内读写的依赖）。

## 3. 阻塞 vs 非阻塞

| | 阻塞 `=` | 非阻塞 `<=` |
|---|----------|-------------|
| 语义 | 立即更新，后续语句可见新值 | 本时间步末尾统一更新 |
| 适用 | `always_comb` / `always @(*)` | `always_ff` / 时钟沿 |
| 错误用法 | 在时序块中对同一变量混用 | 在组合块中使用（顺序依赖混乱） |

**反例（仿真与综合行为难维护）：**

```verilog
// 不推荐：时序块中使用阻塞赋值
always @(posedge clk) begin
    a = b;
    c = a;  // c 得到的是本周期更新后的 a，易与预期不符
end
```

## 4. `if` / `case` 与锁存器

### 不完整 `if`（组合）

```verilog
// 错误：缺少 else → 推断 latch
always @(*) begin
    if (en)
        out = in;
end
```

```verilog
// 正确
always @(*) begin
    if (en)
        out = in;
    else
        out = '0;  // 或保持上一值仅当时序逻辑；组合必须全覆盖
end
```

### `case` 与 `unique` / `priority` (SV)

```verilog
always_comb begin
    unique case (sel)
        2'b00: out = a;
        2'b01: out = b;
        default: out = '0;
    endcase
end
```

- `unique`：告诉综合互斥，利于优化。
- `priority`：保留优先级链，慎用（可能阻止并行译码优化）。

## 5. 多驱动与三态

同一 `wire` 只能有一个 **主动驱动源**（三态除外）。多 `assign` 或多 always 驱动同一信号会导致综合错误或未定义行为。

## 6. 小结

| 逻辑类型 | 模板 | 赋值 |
|----------|------|------|
| 简单组合 | `assign` | 连续 |
| 复杂组合 | `always @(*)` / `always_comb` | 阻塞 `=` |
| 寄存器 | `always @(posedge clk)` | 非阻塞 `<=` |

## 下一节

[04 时序逻辑](./04-sequential-logic.md)
