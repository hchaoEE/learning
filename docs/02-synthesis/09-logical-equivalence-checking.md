# 2.9 逻辑等价性检查（LEC）— 内部机制

综合把 RTL **改写成** 门级网表（换结构、插 buffer、搬移 FF）。**LEC** 用形式化方法证明：**在相同输入约束下，Reference 与 Implementation 行为一致**。

> 本章讲 **miter、比对点匹配、时序等价** 的内部算法骨架，不是工具 flow 教程。  
> 与 [07 内部量](./07-synthesis-reports.md)、[06 retiming](./06-timing-driven-optimization.md#8-retiming寄存器搬移--流水线重平衡) 衔接。

---

## 1. 在综合流程中的位置

```text
RTL（Reference R）
        │ compile（01–06 passes）
        ▼
门级网表（Implementation I）
        │
        ▼
【LEC 引擎】compare point 匹配 → miter → SAT/BDD
        │
        ├─ UNSAT（无差异输入）→ Equivalent
        └─ SAT → counter-example
```

| 时机 | 对比对象 | 内部证什么 |
|------|----------|------------|
| 综合后 | RTL ↔ mapped netlist | sequential equivalence |
| 物理后 | RTL ↔ 布线网表 | 同上（若仅缓冲应仍等价） |
| ECO | 旧 I ↔ 新 I | 增量等价 |

---

## 2. 核心数据结构

| 概念 | 内部含义 |
|------|----------|
| **Compare point** | R 与 I 上 **一一映射** 的观测点（FF Q、PO、黑盒边界） |
| **Miter** | R、I 同输入并联，输出 **XOR/NOR 判差** 的组合电路 |
| **Logic cone** | 从 compare point **反向剪枝** 到 PI/FF 的逻辑锥 |
| **Equivalence class** | 工具判定 **恒等** 的中间 net/寄存器对 |

```text
        inputs ──┬──► R ──► r_out ──┐
                 │                  XOR ──► diff
                 └──► I ──► i_out ──┘

问题：∃ inputs, diff=1 ?  → SAT 求 diff=1
                         → UNSAT 则等价（在约束下）
```

---

## 3. Compare point 匹配（内部）

匹配 **在 miter 之前** 完成；质量决定 verify 可否分解。

### 3.1 匹配来源（优先级）

| 来源 | 内部信息 |
|------|----------|
| **名字 / 层次** | elaboration 后 symbol 名一致 |
| **拓扑签名** | FF 扇入扇出结构、复位类型 |
| **综合引导日志** | 记录 rename、merge、constant、retime（概念上为 **变换日志**） |
| **手动等价对** | 工程师指定 `r_pin ↔ i_pin` |

### 3.2 综合变换如何破坏匹配

| compile 变换 | 匹配难点 |
|--------------|----------|
| `ungroup` | 层次名消失 → 靠拓扑 |
| 常量传播 | 一侧 net tie 0/1，另一侧消失 |
| retiming | **FF 数/位置变化** → 需 **状态映射** |
| 黑盒宏 | 两侧须 **同模型** |

### 输入/输出案例 3.1

**R**：`u_ctrl/q_reg`  
**I**：`u_ctrl/U142/Q`（ungroup 后扁平名）

**内部**：拓扑匹配（同 reset、同 D 锥）→ 建立 **equivalent point** → 纳入 miter **不比较** 该 FF 两侧锥（已配对）。

---

## 4. 组合等价 vs 时序等价

| 类型 | 判定问题 | 引擎 |
|------|----------|------|
| **组合等价** | 纯组合锥：∀输入，输出相等 | 组合 miter + SAT |
| **时序等价** | FF 状态转移一致 | **展开** 或 **关系推理**（k-induction、BMC 深度） |

综合后 LEC 默认 **sequential equivalence**：

- 复位周期、async reset 极性 **必须对齐**  
- 未初始化 X：R 与 I 须 **同一 X 语义策略**（乐观/悲观）

### 输入/输出案例 4.1

**R**：`always_ff @(posedge clk or negedge rst_n) if (!rst_n) q<=0; else q<=d;`  
**I**：`DFFRX1` + `.RN(rst_n)`

**内部**：识别 **async reset arc** 为 compare point 约束的一部分，而非仅比 D→Q 组合锥。

---

## 5. 求解引擎（概念）

| 方法 | 适用 |
|------|------|
| **SAT** | 大组合锥、AIG 化后 CNF |
| **BDD** | 小锥、变量少 |
| **Hybrid** | 先 BDD 化简再 SAT |
| **ABC &cec** | 学术/开源对照（组合） |

**Incremental verify**：层次化时 **子模块先证**，顶层 miter **缩小**。

---

## 6. 综合引导信息（Transformation Log）

综合器可导出 **结构变换日志**（商业工具常称 SVF 等），内部记录：

| 事件 | LEC 用途 |
|------|----------|
| rename | 自动 **r ↔ i** 名映射 |
| merge / ungroup | 恢复 **逻辑等价类** |
| constant propagation | 标记 **tie 点** |
| retime move | **FF  relocation 配对** |

**无日志**：仍可做 LEC，但匹配阶段 **搜索空间更大**。

### 输入/输出案例 6.1

**有日志**：retime 插入 2000 FF → 引擎知 **哪 2000 个 I 中 FF 对应 R 中哪些逻辑段**  
**无日志**：2000 **unmatched** → 需手动或 retiming-aware 配置

---

## 7. 常见不等价根因（机制视角）

| 根因 | 内部表现 |
|------|----------|
| 黑盒不一致 | 一侧 cone **截断**，miter 输入不全 |
| 常数/ case 不一致 | `set_case_analysis` 仅一侧生效 |
| X 语义 | SAT 找到 **X 传播差异** 输入 |
| Latch 推断 | R 无 latch，I 有 → 状态模型不同 |
| Memory | 数组 vs 宏 **端口序** 不一致 |
| async 控制 | reset 极性或 **recovery/removal** 未对齐 |

### 输入/输出案例 7.1

**Counter-example（概念）**：

```text
rst_n=0, d=1, clk edge … → R.q=0, I.Q=1  → diff=1 → 不等价
```

常因 **reset 极性** 或 **scan 模式 pin** 未约束。

---

## 8. 层次化 LEC（内部）

与 [10 章](./10-hierarchical-block-synthesis.md) 配合：

```text
Block A: miter(A_R, A_I) → proven
Block B: miter(B_R, B_I) → proven
Top:     仅 glue + 接口 compare points
```

**子模块已证** → 顶层 miter **黑盒化** 子块，只比 **边界 PO/PI 行为**。

---

## 9. Retiming 与 LEC

[06 §8 retiming](./06-timing-driven-optimization.md#8-retiming寄存器搬移--流水线重平衡) 改变 FF 拓扑。

| 情况 | 内部处理 |
|------|----------|
| I 比 R **多 FF** | **Pipeline equivalence**：允许 latency 变化，证 **输入输出关系** 在适当展开深度下一致 |
| 固定 latency | R、I FF 数须 **可配对** |
| 引导日志含 retime | 自动 **state mapping** |

---

## 10. 与交付

LEC **Pass** 是 [12 章](./12-deliverables-and-handoff.md) PnR 前 **质量门**；与 WNS 无关（见 [07 §5](./07-synthesis-reports.md#5-内部量与-lec-的关系)）。

---

## 11. 小结

| 要点 | |
|------|--|
| **证什么** | 在约束下 R 与 I **无输入使 diff=1** |
| **关键** | compare point 匹配 + 时序等价假设 |
| **综合相关** | retime、ungroup、常量 → 匹配难度 |
| **失败** | 查 reset、X、黑盒、memory，非先看 QoR |

---

## 下一节

- [06 Retiming](./06-timing-driven-optimization.md#8-retiming寄存器搬移--流水线重平衡)
- [10 层次化综合](./10-hierarchical-block-synthesis.md)
- [11 DFT](./11-dft-and-scan.md)
- [12 交付](./12-deliverables-and-handoff.md)
