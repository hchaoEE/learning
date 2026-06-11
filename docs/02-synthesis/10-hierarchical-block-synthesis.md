# 2.10 层次化与分块综合 — 内部模型

全芯片一次 compile 在 **内存、时序闭包** 上常不可行。**层次化** 在 Design DB 中引入 **子块 shell + 接口 timing 壳**，使顶层仅优化 **glue logic**。

> 本章讲 **abstract 模型、预算传播、pass 可见性**，不是分块 Tcl 脚本。

---

## 1. 动机

| 问题 | DB 层做法 |
|------|-----------|
| 单 DB 过大 | 子块 **独立 elaboration + compile** |
| 接口时序 | 边界 pin 挂 **budget / abstract delay** |
| 团队并行 | 子块 **frozen netlist** 或 **.ddc shell** |
| IP 复用 | 同一 ref 只映射一次 |

---

## 2. 两种策略的内部差异

| 策略 | DB 结构 | pass 可见性 |
|------|---------|-------------|
| **Bottom-up** | 顶层实例化 **子块 shell**（内部 blackbox 或已映射） | 子块内 **全 pass**；顶层 **仅 glue** |
| **Top-down** | 单 DB，工具 **partition** | 边界可能 **模糊** |

量产 ASIC 多用 **Bottom-up + interface model**。

```text
Block A DB: 完整 RTL_A → mapped_A + abstract_A
Block B DB: 完整 RTL_B → mapped_B + abstract_B
Top DB:     实例 A_shell, B_shell + top RTL glue
```

---

## 3. 子块交付的内部产物

| 产物 | DB / 文件语义 |
|------|---------------|
| Mapped netlist | 子块 **完整 instance 树** |
| Block SDC | 仅 **块内 clock/IO/exception** |
| **Timing abstract** | 边界 pin 的 **AT/RT/slew 壳**（不含内部逻辑） |
| **Physical abstract**（可选） |  footprint、blockage |
| LEC 证明 | 子块 R↔I 已 **等价** |

### 3.1 Timing abstract 是什么

对子块每个 **边界 pin** 存储：

| 方向 | 抽象内容 |
|------|----------|
| **Input pin** | 外部到 pin 的 **max/min delay 预算**、cap、slew |
| **Output pin** | pin 到外部 **required** 窗口 |
| **Clock pin** | **latency / uncertainty** 壳 |

顶层 STA **不展开** 子块内部 cell，只读 **abstract 弧** → 运行时间 **线性于 glue 规模**。

### 输入/输出案例 3.1

**子块 `cpu_core` 综合完成** → 导出 abstract。

**顶层 DB**：`cpu_core` 实例 **内部不可见**（dont_touch）；`cpu_core/inst_data` 边界 pin 有 **AT_max=0.3 ns** 等壳。

**06 在顶层**：仅能对 **top 胶水 net** sizing，**不能** upsize `cpu_core` 内 `ND2`。

### 3.2 Abstract 模型字段（ETM/ILM 概念）

| 字段 | 含义 | 顶层 STA 用法 |
|------|------|---------------|
| `max_delay` | 块内到边界 pin 的最坏组合 delay | 约束 **外部→pin** 路径 |
| `min_delay` | 最快路径 | hold 检查 |
| `drive_resistance` | 输出驱动强度 | 负载估算 |
| `load_cap` | 输入电容 | 外部 net 负载 |
| `clock_latency` | 边界 clock 相对 ideal 偏移 | 与 CTS 预算对齐 |

### 输入/输出案例 3.2

**Abstract 片段（示意）**：

```text
cpu_core/inst_data[31:0]  input  max_delay=0.35ns  cap=0.02pF
cpu_core/result[31:0]     output drive=0.1ohm     max_delay=0.28ns
```

顶层 **不展开** `cpu_core` 内 50 万门，仅读上表弧。

---

## 4. 接口时序预算（Budget）传播

Budget = 从 **顶层 period** 中 **分配给子块接口** 的时间份额。

```text
T_top = 2.0 ns
  − IO_budget_top
  − cpu_core.in_budget
  − cpu_core.out_budget
  − uncertainty
  = cpu_core 内部可用 T_cpu
```

**内部**：子块 compile 时 SDC 读 **T_cpu** 作为 **有效 period**；顶层读 **abstract** 验证 **接口闭合**。

| 预算 | 后果 |
|------|------|
| 过紧 | 子块 WNS 负 |
| 过松 | 子块 WNS 正，**顶层接口 timing debt** |

### 输入/输出案例 4.1

**子块 WNS = +0.1 ns**（块内闭合）  
**顶层**：`cpu_core/out_* → top_reg` **slack = −0.3 ns**

**内部诊断**：out_budget **过大**（子块占用过少）或 glue 过深 → **缩 budget 重综合子块** 或 **顶层 pipeline**。

---

## 5. 边界属性与 pass 过滤

| DB 属性 | pass 行为 |
|---------|-----------|
| `dont_touch` | 06 **不 transform** 子树 |
| `size_only` | 允许 **sizing**，禁止 **逻辑 rewrite** |
| `boundary_optimization` | 允许优化 **紧贴边界的组合锥**（可能跨 shell） |
| `dont_retime` | 06 §8 **跳过** 该区域 FF |

### 输入/输出案例 5.1

**子块 LEC 已签核 + dont_touch**：

**顶层 compile 内部队列** 遍历 instance 时 **剪枝** `cpu_core/*` → 仅 **top/glue/*` 进入 transform planner。

---

## 6. ungroup 与 LEC

**ungroup** 在 DB 中 **扁平化层次** → LEC compare point **层次名丢失**。

| 策略 | 内部 |
|------|------|
| 块内 ungroup | 块级 LEC 仍 R↔块网表；**变换日志** 记录 flatten |
| 顶层保留层次 | top LEC **分治** |
| 块已证 + blackbox | 顶层 **不展开** 块内 |

见 [09 LEC](./09-logical-equivalence-checking.md)。

---

## 7. 与 01–06 pass 的关系

| Pass | 子块 DB | 顶层 DB |
|------|---------|---------|
| Elaboration | 完整 RTL | shell + glue RTL |
| 02 推断 | 全块 | 仅 glue + shell pin |
| 03–04 | 全块 | glue（shell 已 mapped） |
| 06 | 块内完成 | 接口 + glue |
| STA | 块内全图 | abstract + glue 全图 |

---

## 8. 小结

层次化 = **DB 分区 + timing abstract + budget + dont_touch**；签核需 **块 LEC + 顶 LEC**。

---

## 下一节

- [09 LEC](./09-logical-equivalence-checking.md)
- [05 预算/MCMM](./05-constraints-sdc.md)
- [12 交付](./12-deliverables-and-handoff.md)
