# 2.10 逻辑等价性检查（LEC）— 内部机制

综合把 RTL **改写成** 门级网表（换结构、插 buffer、搬移 FF）。**LEC** 用形式化方法证明：**在相同输入约束下，Reference 与 Implementation 行为一致**。

> 本章讲 **miter、比对点匹配、时序等价** 的内部算法骨架，不是工具 flow 教程。  
> 与 [08 内部量](./08-synthesis-reports.md)、[06 retiming](./06-timing-driven-optimization.md#8-retiming寄存器搬移--流水线重平衡) 衔接。

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

> 「UNSAT → 等价」的前提：① compare point 已全部配对；② 复位序列 / `set_case_analysis` 等输入约束两侧一致；③ X 语义策略一致；④ 时序等价时为 **完整证明**（k-induction 等收敛），而非仅有界深度 BMC 未找到反例。

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
| **常量/等价/无负载寄存器优化**（[02 §10](./02-inference.md#10-寄存器级优化-pass推断后的时序元件清理)） | R 侧 FF 在 I 侧 **消失或合并** → 需 constant/merge 记录，否则报 unmatched |
| **FSM re-encoding**（[02 §7](./02-inference.md#7-状态机fsm推断与状态编码)） | state 寄存器逐位含义不同 → 需 **state mapping** 或 STG 级比对 |
| retiming | **FF 数/位置变化** → 需 **状态映射** |
| 黑盒宏 | 两侧须 **同模型** |

### 输入/输出案例 3.1

**R**：`u_ctrl/q_reg`  
**I**：`u_ctrl/U142/Q`（ungroup 后扁平名）

**内部**：拓扑匹配（同 reset、同 D 锥）→ 建立 **compare point 配对** → miter 仍对该 FF 的 Q **做 XOR 判差**，但 **在配对点截断 cone**：下游锥以该点为输入边界，避免重复展开已证子锥。

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

### 输入/输出案例 4.2 — 时序 miter 展开（复位）

**R 与 I** 各 1 FF，async reset active-low。

**内部**（sequential miter 前几周期）：

```text
Cycle 0: rst_n=0 → 要求 R.q=0 且 I.Q=0
Cycle 1: rst_n=1, d=1 → 要求 Q 均为 1
Cycle 2+: 数据路径 XOR 判差
```

若 I 的 `.RN` 极性接反 → **Cycle 0** diff=1 → **counter-example 立得**。

---

## 5. 求解引擎

| 方法 | 适用 |
|------|------|
| **SAT** | 大组合锥、AIG 化后 CNF |
| **BDD** | 小锥、变量少 |
| **Hybrid** | 先 BDD 化简再 SAT |
| **ABC &cec** | 学术/开源对照（组合） |

### 5.1 SAT 管线：miter → AIG → CNF

```text
miter（R 锥 + I 锥 + XOR）
    │ ① AIG 化 + strash（两侧结构相同的子锥直接合并为同一节点）
    ▼
化简后 AIG（常常已大幅缩小 — strash 即完成大半证明）
    │ ② Tseitin 编码：每个 AND 节点引入 1 个 CNF 变量 + 3 个子句
    ▼
CNF + 目标子句（diff = 1）
    │ ③ SAT 求解器（CDCL）
    ▼
UNSAT → 等价证书      SAT → 满足赋值 = 反例输入向量
```

| 步骤要点 | 说明 |
|----------|------|
| strash 在 LEC 中的角色 | 与 [03 §5.1](./03-optimization.md) **同一算法、不同目的**：03 用它化简功能，LEC 用它 **让相同子结构两侧合一** — 若 miter 整体 strash 后 XOR 两输入是同一节点，**无需 SAT 即证等价** |
| Tseitin 线性膨胀 | CNF 规模 ∝ AIG 节点数（非指数）— 这是 SAT 路线能处理大锥的原因 |
| UNSAT = 证书 | 「不存在使 diff=1 的输入」是 **全空间命题**，由 UNSAT proof 保证（可导出供独立 checker 复验） |
| SAT = 反例 | 满足赋值直接给出 PI/伪 PI 的具体值 → §7.1 debug 入口 |

### 5.2 结构签名与证明缓存

大设计的加速核心是 **不重复证明**：

| 机制 | 内部 |
|------|------|
| **内部等价点（cut point）** | 先用随机仿真对两侧内部 net 分桶（候选等价类），再逐对 SAT 验证；已证等价的内部点对 **替换为同一伪输入**，下游锥规模骤减 |
| **证明缓存** | 已证子锥按 **拓扑签名（AIG 哈希）** 缓存；另一 compare point 共享该子锥时直接复用结论 |
| **分桶失败回退** | cut point 候选验证失败（false negative 风险）→ 回退到更大锥重证，**不影响正确性，只影响速度** |

### 5.3 四态结果与 abort 语义

每个 compare point 的 verify 结果是 **四态**，不是布尔：

| 状态 | 含义 | 交付门控（13 §3）处理 |
|------|------|------------------------|
| **proven** | UNSAT 收敛，完整证明 | pass |
| **falsified** | SAT 找到反例 | fail → §7.1 debug |
| **inconclusive** | 时序证明未收敛（induction 不闭合） | **不是 pass** — 需换策略 |
| **aborted** | 资源限制（时间/内存/锥规模）触顶 | **不是不等价** — 但也不能签核 |

**Abort 处理决策树**：

```text
aborted compare point
    │ 锥是否过大（datapath/乘法器）？
    ├─ 是 → 缩小 scope：对该宏单独建黑盒边界 / 分层验证（§8）
    │ 是否缺变换日志？
    ├─ 是 → 补 SVF/变换日志（§6）让匹配在更细粒度截断 cone
    │ 仍 abort？
    └─ 手动 compare point / 内部等价对引导（§3.1 第 4 来源），最后才是放宽资源限制硬算
```

**签核纪律**：abort 数 > 0 的 LEC 结果 **不可等同 pass** — 13 章质量门要求 proven 覆盖全部 compare point 或每个 abort 有 waiver 记录。

### 5.4 时序证明的收敛条件

§4 的 sequential equivalence 内部分两层：

| 技术 | 证明力 | 何时够用 |
|------|--------|----------|
| **BMC**（有界展开 k 个周期） | 只证「k 周期内无反例」 | 找 bug 快；**不构成完整证明** |
| **k-induction** | base（k 周期无反例）+ step（任意 k 等价状态推出 k+1 等价）闭合 → **完整** | FF 对齐良好时 k 很小（常 k=1） |
| **Retiming/pipeline 等价** | latency 差 d 进入证明目标：`R(t) = I(t+d)` | 06 §8 retiming 后（§9） |

Induction 不闭合（inconclusive）的典型根因：两侧 **状态编码不同**（FSM re-encoding，02 §7.3）且无 state mapping — 引擎无法构造归纳不变式。

**Incremental verify**：层次化时 **子模块先证**，顶层 miter **缩小**（§8）。

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

### 7.1 不等价 debug 流（内部机制）

SAT 返回 falsified 后，引擎不是只丢一个波形，而是走 **反例缩小 → 锥定位** 流程：

```text
① SAT 满足赋值（全部 PI / 伪 PI / 初态的具体值）
    │ 反例最小化：逐位翻转赋值，仍 diff=1 则该位无关 → 缩到最小触发集
    ▼
② 最小反例向量（往往只剩 2–3 个关键输入）
    │ 沿 miter 仿真该向量，标记 R/I 两锥中 值不同的第一层内部 net
    ▼
③ 最小 diff cone（两侧分歧的最浅子锥）
    │ 判定分支：
    ├─ 分歧点在 compare point 配对本身 → 匹配错误（修 §3 配对/补日志），非真不等价
    ├─ 分歧涉及 X / 未约束 pin（scan_en、test_si）→ 假设不一致（补 set_case_analysis / 约束）
    └─ 分歧在功能锥内部且假设一致 → 真不等价（综合 bug 或 RTL 修改未同步）
    ▼
④ 对照变换日志（§6）：分歧锥涉及哪条 compile 变换 → 定位到 pass
```

| Debug 信号 | 优先怀疑 |
|------------|----------|
| 反例发生在 **cycle 0**（复位期） | reset 极性 / 复位序列假设（案例 4.2） |
| 反例含 **scan/test pin = 1** | DFT pin 未 constrain（[12 §4](./12-dft-and-scan.md)） |
| 大批 compare point 同时 falsified | 系统性假设错（case_analysis、X 策略），**不是** 逐点逻辑错 |
| 单点 falsified、锥很小 | 真不等价，人工可读懂 — 直接看 diff cone |

### 输入/输出案例 7.1

**Counter-example（概念）**：

```text
原始赋值：rst_n=0, d=1, scan_en=0, b=1, c=0 … → R.q=0, I.Q=1 → diff=1
最小化后：rst_n=0（其余无关）
```

**输出（定位）**：触发集只剩复位 pin、且在 cycle 0 → 走 §7.1 分支「复位期反例」→ 查 I 侧 `.RN` 极性 — 匹配错误类，**不是** 组合逻辑不等价。

### 输入/输出案例 7.2 — 黑盒 miter 截断

```text
R: SRAM 行为模型（RTL）     I: SRAM 硬宏 .lib 黑盒
        │                           │
        └──── compare 边界 pin ─────┘
              （不展开宏内部）
```

**失败**：R 展开数组读逻辑，I 仅 **pin 级黑盒** → miter 输入维数不一致 → 须 **两侧同黑盒 + timing model**。

---

## 8. 层次化 LEC（内部）

与 [11 章](./11-hierarchical-block-synthesis.md) 配合：

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

LEC **Pass** 是 [13 章](./13-deliverables-and-handoff.md) PnR 前 **质量门**；与 WNS 无关（见 [08 §8](./08-synthesis-reports.md#8-内部量与-lec-的关系)）。

---

## 11. 小结

| 要点 | |
|------|--|
| **证什么** | 在 **声明的约束与假设下**（compare point、复位、X 策略），R 与 I **无输入使 diff=1**，且证明须 **完整收敛** 而非仅有界搜索无反例 |
| **关键** | compare point 匹配 + 时序等价假设 |
| **综合相关** | retime、ungroup、常量 → 匹配难度 |
| **失败** | 查 reset、X、黑盒、memory，非先看 QoR |

---

## 下一节

- [06 Retiming](./06-timing-driven-optimization.md#8-retiming寄存器搬移--流水线重平衡)
- [11 层次化综合](./11-hierarchical-block-synthesis.md)
- [12 DFT](./12-dft-and-scan.md)
- [13 交付](./13-deliverables-and-handoff.md)
