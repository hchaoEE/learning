# 1.8 RTL 编码规范与反模式

## 1. 命名约定（示例）

| 对象 | 建议 | 示例 |
|------|------|------|
| 模块 | 小写+下划线 | `uart_tx` |
| 时钟 | `clk` / `clk_<domain>` | `clk_cpu` |
| 复位 | 低有效 `_n` | `rst_n` |
| 使能 | `_en` | `wr_en` |
| 寄存器输出 | `_q` 或语义名 | `cnt_q` |
| 次态 | `_next` | `state_next` |
| 流水线级 | `_s1` `_s2` | `data_s1` |
| 实例 | `u_<name>` | `u_fifo` |

## 2. 文件与格式

- 一文件一模块；文件名 `uart_tx.v` 与 `module uart_tx` 一致。
- `default_nettype none`（Verilog）避免隐式 wire。
- 缩进统一（2 或 4 空格），禁止 Tab 混用。

```verilog
`default_nettype none
`timescale 1ns / 1ps
```

## 3. 必须遵守的规则

1. **组合完整赋值**，防止 latch。
2. **时序只用 NBA**；组合只用阻塞赋值。
3. **单时钟域块内不写另一时钟域信号**；CDC 用专用同步模块。
4. **复位值明确**：寄存器复位到已知常量。
5. **位宽显式**：端口、常数、拼接一致。
6. **禁止多驱动**（除三态总线协议清晰）。
7. **魔数用 localparam**；状态用 `enum` 或命名常量。

## 4. 常见反模式

### 4.1 组合环

```verilog
// 错误：组合反馈
assign y = a & y;
```

### 4.2 在时钟块内写大组合逻辑

应拆到 `always_comb`，时序块只寄存。

### 4.3 门控时钟替代使能

```verilog
// 避免（功能 RTL）
assign gated_clk = clk & en;
always @(posedge gated_clk) ...  // 毛刺风险
```

### 4.4 跨时钟域单触发器采样

```verilog
// 错误：单级 sync
always @(posedge clk_b)
    data_b <= data_a;  // data_a 在 clk_a 域
```

应使用 **双触发器同步器** 或 FIFO。

### 4.5 `#0` 与阻塞赋值混用“修”时序

仿真技巧不可综合，且掩盖真实问题。

## 5. Review Checklist（摘录）

- [ ] 所有 `always_comb` 路径是否覆盖全部输出？
- [ ] 是否存在 latch 警告（综合报告）？
- [ ] 复位是否异步/同步与项目一致？是否同步释放？
- [ ] CDC 路径是否标注并实例化同步结构？
- [ ] 乘法/除法/ROM 规模是否可接受？
- [ ] 端口位宽与顶层约束是否一致？

完整清单见 [05-practice/rtl-review-checklist.md](../05-practice/rtl-review-checklist.md)（待扩充）。

## 6. 小结

规范的目标：**可读、可综合、可约束、可调试**。RTL 质量直接决定综合结果与后端收敛难度。

---

**01-rtl 章节完结。** 下一步学习：[02-synthesis / 01 RTL 解析与 Elaboration](../02-synthesis/01-rtl-parsing-and-elaboration.md)。
