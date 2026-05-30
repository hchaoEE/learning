# 1.5 有限状态机（FSM）

## 1. 状态编码

| 编码 | 特点 | 适用 |
|------|------|------|
| 二进制 / 格雷 | 状态位少；格雷减少多比特同时翻转 | 大型 FSM、低功耗 |
| One-hot | 每位表示一个状态，译码简单 | FPGA、高速控制 |
| 独热 + 二进制混合 | 折中 | 视工艺与工具 |

SystemVerilog `enum` 提高可读性：

```verilog
typedef enum logic [1:0] {
    S_IDLE = 2'b00,
    S_RUN  = 2'b01,
    S_DONE = 2'b10
} state_e;

state_e state, next_state;
```

## 2. 两段式 vs 三段式

### 三段式（推荐：组合次态 + 时序状态 + 时序输出可选）

**段 1：次态逻辑（组合）**

```verilog
always_comb begin
    next_state = state;
    case (state)
        S_IDLE: if (start) next_state = S_RUN;
        S_RUN:  if (done)  next_state = S_DONE;
        S_DONE: next_state = S_IDLE;
        default: next_state = S_IDLE;
    endcase
end
```

**段 2：状态寄存器（时序）**

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state <= S_IDLE;
    else
        state <= next_state;
end
```

**段 3：输出逻辑**

- 若输出仅依赖 `state`：**Moore**，可放在组合块。
- 若依赖 `state` 与输入：**Mealy**，注意输出毛刺；关键输出建议 **寄存一拍**。

```verilog
// Moore 输出
always_comb begin
    busy = (state != S_IDLE);
end

// 关键 Mealy 输出寄存
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        ack <= 1'b0;
    else
        ack <= (state == S_RUN) && done;
end
```

### 两段式

将次态与输出写在同一 `always` 块（常为组合+时序混合），易出错，**不推荐**新手使用。

## 3. 默认状态与安全

```verilog
default: next_state = S_IDLE;  // 非法状态恢复
```

- 对 **未使用编码** 考虑 `default` 跳转，避免状态机卡死。
- 安全关键设计可加强 **状态监测 + 硬件复位**。

## 4. 综合与 FSM 编码

综合工具常有 `set_fsm_encoding` 或属性：

```verilog
(* fsm_encoding = "one_hot" *) reg [3:0] state;  // 工具相关
```

以项目脚本与工具文档为准；RTL 保持 **可读状态名** 比强行 one-hot 更重要。

## 5. 小结

- 使用 **三段式**：`next` 组合、`state` 时序、输出按需 Moore/Mealy。
- `case` 加 `default`；关键输出 **寄存**。
- 用 `enum` 与命名常量，避免魔数状态值。

## 下一节

[06 generate 与参数](./06-generate-and-parameters.md)
