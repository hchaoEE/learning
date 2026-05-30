# 2.10 层次化与分块综合

全芯片一次 `compile` 在 **运行时间、内存、时序收敛** 上常不可行。**层次化综合** 把设计拆成 **子模块（block）** 单独综合，再用 **抽象模型（interface model）** 在顶层组装。

---

## 1. 动机

| 问题 | 层次化做法 |
|------|------------|
| 16h+ compile | 分块 2–4h/块 |
| 接口时序不清 | **budget** / **ILM** 传递约束 |
| 团队并行 | CPU 核、DMA、外设各一块 |
| 复用 | 同 IP 只综合一次 |

### 输入/输出案例

**输入**：200 万门 SoC 顶层 `chip_top`

**输出**：`cpu`/`gpu`/`noc` 三份 netlist + 顶层 **glue** compile **< 4h**。

---

## 2. 两种主流策略

| 策略 | 流程 | 优点 | 风险 |
|------|------|------|------|
| **Bottom-up** | 子块先综合 → 导出 **.ddc + 模型** → 顶层当黑盒实例 | 块 QoR 可控 | 接口乐观/悲观 |
| **Top-down + uniquify** | 顶层 compile，工具 **自动划分** | 简单 | 难控子块 |

ASIC 量产多用 **Bottom-up + 接口预算**。

```text
Block A: compile → A.mapped.v + A.sdc + A.LEC clean
Block B: compile → B.mapped.v + …
Top:     read A/B 模型 + 综合 glue + IO
```

---

## 3. 子块交付物（内部）

| 产物 | 用途 |
|------|------|
| Mapped netlist | 顶层实例化或 PnR |
| **SDC**（块级） | 块内约束 |
| **Timing abstract** | 顶层 STA：`.lib` 提取模型、**ETM/ILM**、**FRAM**（工具名不同） |
| **Physical**（可选） |  floorplan 脚、MACRO 列表 |
| LEC 报告 | 块签核 |

### 输入/输出案例

**输入**：`cpu_core` 综合完成，导出 `cpu_core.ddc`

**输出**：顶层 `read_ddc cpu_core.ddc` 后仅见 **边界 pin timing**，内部 **不可优化**（除非 `set_boundary_optimization`）。

---

## 4. 接口时序预算（Budget）

顶层 SDC 定义芯片时钟；子块需要 **预算**：

```tcl
# 概念：分配给 cpu_core 的时钟周期份额
set_clock_latency -source 0.2 [get_clocks clk]
set_input_delay  0.3 -clock clk [get_ports cpu_core/in_*]
set_output_delay 0.2 -clock clk [get_ports cpu_core/out_*]
```

| 输入 | 输出 |
|------|------|
| 顶层 2ns 周期 | 子块有效周期 ≈ 2 - 0.3 - 0.2 = **1.5ns** 可用 |

**预算过紧** → 子块 WNS 负；**过松** → 顶层接口 **timing debt**。

### 输入/输出案例

**子块 WNS = +0.1**，顶层接口 **slack = -0.3** → 需 **缩预算** 或 **顶层 pipeline** 寄存器。

---

## 5. `dont_touch` / `size_only` / 边界

| 属性 | 作用 |
|------|------|
| `dont_touch` | 顶层不改动子块内部 |
| `size_only` | 允许修时序但不改逻辑结构 |
| `set_boundary_optimization` | 允许优化接口组合逻辑 |

### 输入/输出案例

**输入**：子块 LEC 已签核，`set_dont_touch [get_cells cpu_core]`

**输出**：顶层 compile **不改** `cpu_core` 内部；仅优化 **top 胶水**。

---

## 6. `ungroup` 与 LEC

综合常 `ungroup` 扁平化以利时序；**层次 LEC** 变难。

| 策略 | 说明 |
|------|------|
| 块内 `ungroup` | 块级 LEC 仍 RTL↔块网表 |
| 顶层保留层次 | 便于 top LEC 分治 |
| SVF | 记录 flatten 映射 |

见 [09 LEC](./09-logical-equivalence-checking.md)。

---

## 7. 与 01–06 章关系

| 阶段 | 块内 | 顶层 |
|------|------|------|
| Elaboration | 完整 RTL | 实例化子块 **shell** |
| 推断/映射 | 全 pass | 仅 glue |
| 06 优化 | 块内完成 | 接口 buffer |

---

## 8. 小结

层次化 = **分块综合 + 抽象 + 预算 + dont_touch**；签核需 **块 LEC + 顶 LEC**。

---

## 下一节

- [09 LEC](./09-logical-equivalence-checking.md)
- [12 交付](./12-deliverables-and-handoff.md)
- [05 SDC](./05-constraints-sdc.md)
