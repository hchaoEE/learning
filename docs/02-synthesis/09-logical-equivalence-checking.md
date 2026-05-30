# 2.9 逻辑等价性检查（LEC）

综合把 RTL **改写成** 门级网表（换结构、插 buffer、拆算术）。**逻辑等价性检查（Logical Equivalence Checking, LEC）** 用形式化方法证明：**在相同输入约束下，实现与参考模型产生相同输出**，弥补仿真 **覆盖率不足**。

> 工具例：**Synopsys Formality**、**Cadence Conformal LEC**。本章讲 **原理 + 签核流程**；与 [07 报告](./07-synthesis-reports.md)（QoR）互补。

---

## 1. 在综合流程中的位置

```text
RTL（Golden / Reference）
        │
        ▼ compile
门级网表（Revised / Implementation）
        │
        ▼
【本章 LEC】── Pass → 交付 PnR / 失败 → 查根因
        │
        ▼
（可选）PnR 后再 LEC：RTL vs 布线后网表
```

| 时机 | 对比对象 | 目的 |
|------|----------|------|
| **综合后（必做）** | RTL ↔ 综合网表 | 验证 `compile` 未改语义 |
| 物理后（常见） | RTL ↔ 布线网表 | 验证 PnR/CTS 未改逻辑 |
| ECO 后 | 旧网表 ↔ 新网表 | 增量变更范围 |

### 输入/输出案例

**输入**：`top.v`（RTL）、`top.mapped.v`（综合后）、同一 `top.sdc` 约束环境

**输出**：

```text
Verification SUCCEEDED
  Equivalent: 12450 compare points
  Failed:     0
```

| 输入 | 输出 |
|------|------|
| 等价 | 签核 **LEC clean** 报告 |
| 不等价 | **failing point** 列表 + 反例波形（部分工具） |

---

## 2. 内部在做什么（概念）

LEC 工具 **不是** 跑向量仿真，而是建立 **数学判定问题**：

```text
Reference model R（RTL /elaborate 后）
Implementation model I（门级网表）
        │
        ▼
匹配 compare points（寄存器 Q、PO、黑盒边界）
        │
        ▼
构造 miter：同一输入驱动 R 与 I，比较输出是否恒等
        │
        ▼
SAT / BDD / 混合引擎 求解：是否存在输入使输出不同？
        │
        ├─ 无解 → Equivalent
        └─ 有解 → Counter-example（不等价）
```

| 概念 | 说明 |
|------|------|
| **Compare point** | 一一对应的比对点（常为 FF 输出、primary output） |
| **Miter** | R、I 并联，输出 XOR 判差异 |
| **Cone** | 从比对点反向剪出的逻辑锥 |
| **Constant / X 处理** | 需约束非法输入状态 |

### 输入/输出案例

**输入**：RTL 寄存器 `q`，网表单元 `u_reg/Q`

**输出**：工具建立映射 `q ↔ u_reg/Q` 为 **equivalent point**，纳入 miter。

---

## 3. 组合等价 vs 时序等价

| 类型 | 要求 | 综合后 LEC |
|------|------|------------|
| **组合等价** | 纯组合锥功能相同 | 组合路径自动处理 |
| **时序等价** | 寄存器 **功能 + 状态转移** 一致 | 需 **映射 FF**、处理 reset/clock |

**综合后网表** 与 RTL 在 **同一时钟域假设** 下做 **sequential equivalence**：

- 复位值、异步复位极性必须一致  
- 未初始化的 X：RTL 仿真与形式 **语义需对齐**（常对 X 乐观/悲观配置）

### 输入/输出案例

**RTL**：

```systemverilog
always_ff @(posedge clk or negedge rst_n)
  if (!rst_n) q <= 0;
  else        q <= d;
```

**网表**：`DFFRX1` 带 `.RN(rst_n)` — LEC 需识别 **reset arc** 对应，而非仅比对组合锥。

| 失败模式 | 常见原因 |
|----------|----------|
| FF 未映射 | 层次名变化、`ungroup` |
| 不等价 | 综合改语义（极少）或 **约束/常数** 不一致 |

---

## 4. 与仿真的对比

| | 仿真 | LEC |
|---|------|-----|
| 方法 | 向量驱动 | 形式化全空间（在约束下） |
| 覆盖率 | 依赖用例 | 对 **已映射点** 完备 |
| 速度 | 长回归 | 小时级（设计规模相关） |
| 用途 | 功能、协议 | **结构变换** 签核 |

**结论**：综合交付前 **LEC + 关键仿真**；LEC 不能替代系统级验证。

### 输入/输出案例

**输入**：仿真未发现 bug 的 RTL/网表对

**输出**：LEC **仍可能失败**（仿真未覆盖的常数/复位场景）→ 说明 LEC 更严。

---

## 5. 典型签核流程（Formality 风格）

```tcl
# Reference
read_verilog -r $RTL_FILES
set_top rtop
# Implementation
read_verilog -i $NETLIST_FILE
set_top itop
# 约束（可选）：read_sdc
match
verify
report_failing > lec.rpt
```

| 步骤 | 输入 | 输出 |
|------|------|------|
| `read` | RTL + 网表 | 两个 elaborated 设计 |
| `match` | 名称/拓扑启发 | compare point 配对表 |
| `verify` | 配对 + 约束 | Pass / Fail |

### 输入/输出案例

**输入**：综合脚本 `ungroup -all` 后层次扁平

**输出**：`match` 仍可能靠 **拓扑** 自动配对；失败时用手动 `set_equivalent` 指定 FF。

---

## 6. SVF / 引导（Synthesis Guidance）

Synopsys 可在综合时生成 **SVF（Setup Verification Flow）** 指导 Formality：

```tcl
# DC 侧
set_svf top.svf
compile
```

| 输入 | 输出 |
|------|------|
| `top.svf` | Formality `read_svf` 后 **自动映射** 改名、merge、constant 传播 |

**无 SVF** 时 LEC 仍可做，但 **match 工作量** 上升。

### 输入/输出案例

**有 SVF**：`match` 通过率 99%+  
**无 SVF**：大量 `unmatched points` 需人工 — 仍可能 **verify pass** 若手动补全。

---

## 7. 常见不等价根因

| 根因 | 说明 | 处理 |
|------|------|------|
| **黑盒不一致** | RTL 有模型，网表 `dont_touch` 宏 | 两边 **同黑盒** + timing model |
| **常数传播差异** | 某侧 tie 0/1 不同 | 查 `set_case_analysis`、SDC |
| **X 语义** | RTL X 乐观，形式当 0/1 | 统一 `set_verification` 策略 |
| **Latch 推断** | RTL 无 latch，网表有 | 回 [02](./02-inference.md) 改 RTL |
| **多驱动 / 浮空** | 综合已修但 RTL 未声明 | 先 `check_design` |
| **Memory 映射** | RTL 数组 vs 宏 pin 序 | 用 memory 映射文件 |

### 输入/输出案例

**失败报告**：

```text
Failing point: data_out[7]
  Reference: rtop/u_ctrl/out_reg/Q
  Implementation: itop/u_ctrl/U142/Q
  Status: Not equivalent
```

**调试**：在工具 GUI 看 **差异锥**；常发现 **async reset** 极性或 **enable** 接错。

---

## 8. 层次化 LEC

与 [10 章](./10-hierarchical-block-synthesis.md) 配合：

```text
子模块 A：RTL_A ↔ NET_A  （先验）
子模块 B：RTL_B ↔ NET_B
顶层：仅拼接口 +  glue logic
```

| 策略 | 适用 |
|------|------|
| Bottom-up | 块已单独 LEC clean |
| Top-down | 全芯片一次 verify |

### 输入/输出案例

**输入**：CPU 核已签核，综合仅改 `top` 胶水逻辑

**输出**：顶层 LEC 只比对 **少量 compare points**，运行时间 **分钟级**。

---

## 9. 物理 LEC（简述）

```text
RTL ↔ 布线后 Verilog（含寄生 back-annotation 前）
```

CTS、buffer 插入若 **仅缓冲** 逻辑应保持等价；**ECO 改逻辑** 必须重跑 LEC。

---

## 10. 与交付清单

LEC pass 是 [12 章](./12-deliverables-and-handoff.md) 交付 **PnR 前** 必备项之一。

| 交付物 | LEC 角色 |
|--------|----------|
| `*.mapped.v` | Implementation |
| `*.svf` | 可选，助 match |
| `lec.log` | 签核记录 |

---

## 11. 小结

| 要点 | |
|------|--|
| **何时** | 综合后、重大 ECO 后 |
| **证什么** | RTL 与网表 sequential equivalence |
| **工具链** | Formality / Conformal |
| **失败** | 查 mapping、复位、黑盒、常数 |

---

## 下一节

- [10 层次化综合](./10-hierarchical-block-synthesis.md)
- [12 交付与交接](./12-deliverables-and-handoff.md)
- [07 报告](./07-synthesis-reports.md)
