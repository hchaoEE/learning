# 2.11 层次化与分块综合 — 内部模型

> **本章回答**：大设计如何分块综合、预算与 abstract。
> **读完应能**：① 说清 bottom-up 交付物 ② 解释 budget 迭代 ③ 知道 abstract 须与块 revision 锁步
> **先修**：[06](./06-timing-driven-optimization.md)、[07](./07-internal-sta-and-qor.md) · **难度**：★★★★☆ · **walkthrough**：[hier_walkthrough](./examples/hier_walkthrough/)

全芯片一次 compile 在 **内存、时序闭包** 上常不可行。**层次化** 在 Design DB 中引入 **子块 shell + 接口 timing 壳**，使顶层仅优化 **glue logic**。

> 本章讲 **abstract 模型、预算传播、pass 可见性**，不是分块 Tcl 脚本。

---

## 1. 动机
> **一句话**：动机——本章核心机制点。

| 问题 | DB 层做法 |
|------|-----------|
| 单 DB 过大 | 子块 **独立 elaboration + compile** |
| 接口时序 | 边界 pin 挂 **budget / abstract delay** |
| 团队并行 | 子块 **frozen netlist** 或 **.ddc shell** |
| IP 复用 | 同一 ref 只映射一次 |

---

## 2. 两种策略的内部差异
> **一句话**：两种策略的内部差异——本章核心机制点。

| 策略 | DB 结构 | pass 可见性 |
|------|---------|-------------|
| **Bottom-up** | 顶层实例化 **子块 shell**（内部 blackbox 或已映射） | 子块内 **全 pass**；顶层 **仅 glue** |
| **Top-down** | 单 DB，工具 **partition** | 边界可能 **模糊** |

量产 ASIC 多用 **Bottom-up + interface model**。当子块对应 **物理 die** 时，interface 还须叠加 TSV/凸点弧 — 见 [15 章](./15-3d-ic-synthesis.md)。

```text
Block A DB: 完整 RTL_A → mapped_A + abstract_A
Block B DB: 完整 RTL_B → mapped_B + abstract_B
Top DB:     实例 A_shell, B_shell + top RTL glue
```

### 输入/输出案例 2.1 — bottom-up vs top-down

**输入**：设计含 `cpu_core` + `dsp` + top glue。

| 策略 | 块内 pass | 顶层可见 | 接口模型 |
|------|-----------|----------|----------|
| **Bottom-up** | 全量 03→06 | 仅 **shell + abstract** | ILM/ETM 必交 |
| **Top-down** | partition 边界模糊 | 单 DB 全局优化 | 难拆 LEC |

**输出**：量产选 bottom-up — 块 LEC 独立、顶层只证 glue（[10 §8](./10-logical-equivalence-checking.md#8-层次化-lec)）。

---

## 3. 子块交付的内部产物
> **一句话**：子块交付的内部产物——本章核心机制点。

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

### 3.3 Abstract 的 characterize 生成机制

字段不是手填的，由 **characterize pass** 从 mapped 块 DB 计算：

```text
对每个边界 pin（在块内 timing graph 上，引擎同 07）：
  input pin  → 前向遍历到块内首批 FF/D 或 PO：
               max_delay = 该 pin 出发的 max AT 路径（per corner）
               min_delay = min AT 路径（hold 用）
               load_cap  = pin 直连的 .lib input cap
  output pin → 反向遍历：块内 launch FF → pin 的 max/min 路径
               + 输出驱动单元的 drive 参数
  clock pin  → 块内 clock 网络延时估计（综合期多 ideal + SDC latency）
每个 MCMM corner 各 characterize 一套（与顶层 corner 集对齐，否则不可比）
```

**ILM vs ETM**（两种生成路径）：

| 模型 | 生成方式 | 顶层看到什么 | 精度/保密 |
|------|----------|--------------|------------|
| **ILM**（interface logic model） | **保留** 边界 pin 到第一级 FF 之间的真实逻辑，删除纯内部锥 | 接口逻辑真实 cell + 截断点 | 精度高；暴露接口电路 |
| **ETM**（extracted timing model） | 全部归约为 **pin-to-pin 弧表**（类似 .lib） | 纯黑盒弧 | 精度依赖 characterize 假设（slew/load 范围）；IP 交付友好 |

**Abstract 过期条件**（任一发生须重新 characterize）：

- 块内任何重综合 / ECO（即使「只动内部」— slew 链可能影响边界弧）
- **边界优化改端口集**（§6.1 的副作用）
- corner 集 / `.lib` 版本变化
- 顶层负载假设超出 ETM characterize 时的 load 范围（外推不可信，同 NLDM 外推问题）

### 输入/输出案例 3.3

**输入**：`cpu_core` mapped DB，corner = {slow_max, fast_min}。

**输出（characterize 结果，单 pin 示意）**：

| pin | slow_max max_delay | fast_min min_delay | 来源路径 |
|-----|---------------------|---------------------|----------|
| `inst_data[7]`（in） | 0.35（→ if_stage_reg/D） | 0.08 | 块内首级锥 max/min |
| `result[3]`（out） | 0.28（ex_reg/Q →） | 0.06 | 末级 launch 锥 |

顶层装载后，两 corner 各自把这些值作为 **固定弧** 接入 top timing graph。

---

## 4. 接口时序预算（Budget）传播
> **一句话**：接口时序预算（Budget）传播——本章核心机制点。

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

### 4.1 Budget 在子块 SDC 中如何落地

分到的预算不是新约束类型，而是 **翻译为子块 port 上的标准 IO 约束**（[05 §3](./05-constraints-sdc.md#3-io-延时路径预算如何切分) 同一机制）：

```text
顶层接口路径：top_reg/Q ─(glue 0.3)─► cpu_core/inst_data ─(块内)─► if_reg/D
分给块外 0.45（launch + glue + margin）
    ↓ 子块 SDC
set_input_delay 0.45 -clock clk [get_ports inst_data]   ← 块外预算的等价表达
```

输出侧同理 `set_output_delay`。子块 compile 由此「感知」自己只占 period 的一部分。

### 4.2 Budget 分配启发式与迭代收敛

初始分配不是均分，而是按 **试综合（或上一版）路径形状** 分：

```text
① 顶层快速综合（粗 effort）→ 每条跨界路径的 块外延时 / 块内延时 比例
② 按比例切 budget（块内深者多分）+ 各留 margin
③ 子块并行 compile（读各自 budget SDC）
④ 子块交 abstract → 顶层 STA 验证接口
⑤ 接口负 slack？
     ├─ 子块有富余（块内 WNS > 0）→ 收紧该块 budget，回 ③（增量重综合）
     ├─ 双方都紧 → 顶层 glue 重构 / 接口加 pipeline FF（改架构）
     └─ 收敛 → freeze budget，进入 PnR
```

| 迭代要点 | 说明 |
|----------|------|
| **每轮都要重 characterize** | budget 变 → 子块重综合 → abstract 过期（§3.3） |
| **收敛判据** | 所有接口路径 slack ≥ 0 且各块内 WNS ≥ 0；振荡时 freeze 较松一侧 |
| **margin 防振荡** | 每轮预留 5–10% — budget 紧贴边界会因 WLM 误差来回翻 |

### 输入/输出案例 4.2 — 启发式分配与 characterize 闭环

**输入**（顶层粗综合路径 profile，period=2.0 ns）：

| 跨界路径 | 块外 delay | 块内 delay | 初分配 budget |
|----------|------------|------------|---------------|
| `cpu_core/out → top_reg` | 0.35 | 0.55 | out_budget **0.60**（块内偏松） |
| `din → cpu_core/in` | 0.50 | 0.30 | in_budget **0.35** |

**输出（一轮迭代）**：

```text
① 子块按 budget SDC compile → characterize → 顶层 STA
② 接口 out 路径 slack = −0.25（块内 WNS 仍 +0.12）
③ 收紧 out_budget 0.60→0.40 → 子块重综合 → 重 characterize（§3.3 过期）
④ 接口 slack → −0.04 → 顶层 glue sizing → 收敛
```

详见 [hier_walkthrough/](./examples/hier_walkthrough/README.md)。

### 输入/输出案例 4.1 — budget 迭代一轮

**第 1 轮**：`cpu_core` in_budget = 0.45；子块 WNS = **+0.10**（块内富余），顶层接口 `out_* → top_reg` slack = **−0.30**。

**诊断与动作**（走 §4.2 ⑤ 第一分支）：

| 动作 | 数值变化 |
|------|----------|
| 收紧 out_budget：0.45 → 0.25（把 0.20 还给顶层） | 子块有效 period ↓ |
| 子块增量重综合 | 子块 WNS +0.10 → +0.01（吃掉富余） |
| 重 characterize + 顶层 STA | 接口 slack −0.30 → **−0.05** |

**第 2 轮**：剩 −0.05 由顶层 glue sizing 解决 → 收敛。若子块第 1 轮就无富余，则属「双方都紧」分支 — budget 调不出时间，须改架构。

---

## 5. 边界属性与 pass 过滤
> **一句话**：边界属性与 pass 过滤——本章核心机制点。

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

## 6. Boundary optimization 与 ungroup
> **一句话**：Boundary optimization 与 ungroup——本章核心机制点。

### 6.1 Boundary optimization（边界优化）

§5 表中的 `boundary_optimization` 属性打开后，优化 pass 可以 **穿过层次边界** 做三类变换（层次仍保留，只改边界逻辑）：

| 变换 | 机制 | 边界变化 |
|------|------|----------|
| **常量端口传播** | 端口接 `1'b0/1'b1` → 常量推进子模块内折叠 | 该输入端口逻辑上消失 |
| **跨边界反相吸收** | 端口外侧 INV 与内侧首级门合并（如 INV+AND → NAND 极性） | 端口 **极性翻转** |
| **未连接输出剪枝** | 输出端口无顶层 fanout → 子模块内专属锥 DCE | 输出端口与其锥删除 |

**副作用（必须管理）**：

- 端口消失/极性变 → **LEC compare point 与 RTL 不再一一对应**（变换日志须记录，[10 §3.2](./10-logical-equivalence-checking.md)）
- 已发布的 **timing abstract（§3）失效** — 端口集变了，须重新 characterize
- 同一子模块多实例时，不同实例边界条件不同 → **uniquify 后各自优化**（面积可能分化）

关闭该属性（或 `dont_touch`）= 边界冻结，端口集与 RTL 严格一致 — 多实例复用、ECO 友好，但放弃跨边界化简。

### 输入/输出案例 6.1 — `child(.en(1'b1))`

**输入**：顶层例化 `child u0 (.en(1'b1), .a(x), .y(z));`，child 内 `y = en ? f(a) : '0;`

| | 边界优化 **关** | 边界优化 **开** |
|---|------------------|------------------|
| `en` 端口 | 保留，接 tie-1 | **消失**（常量传播入内，MUX 折叠为 `y=f(a)`） |
| child 面积 | MUX 树保留 | MUX 删除，面积 ↓ |
| LEC | 端口一一对应 | 需常量传播记录，否则 `en` 锥 unmatched |
| abstract | 仍有效 | **须重新生成** |

### 6.2 ungroup 与 LEC

**ungroup** 更进一步：在 DB 中 **扁平化层次** → LEC compare point **层次名丢失**。

| 策略 | 内部 |
|------|------|
| 块内 ungroup | 块级 LEC 仍 R↔块网表；**变换日志** 记录 flatten |
| 顶层保留层次 | top LEC **分治** |
| 块已证 + blackbox | 顶层 **不展开** 块内 |

### 输入/输出案例 6.2 — ungroup 后 compare point

**输入**：块内 `ungroup` 扁平化；R 仍保留 `u_ctrl/q_reg`，I 为 `U142/Q`。

**输出**：层次名丢失 → 靠 **SVF 变换日志 + 拓扑** 配对（[10 案例 3.1](./10-logical-equivalence-checking.md#输入输出案例-31)）；无日志则 **unmatched** 风暴。

见 [10 LEC](./10-logical-equivalence-checking.md)。

---

## 7. 与 01–06 pass 的关系
> **一句话**：与 01–06 pass 的关系——本章核心机制点。

| Pass | 子块 DB | 顶层 DB |
|------|---------|---------|
| Elaboration | 完整 RTL | shell + glue RTL |
| 02 推断 | 全块 | 仅 glue + shell pin |
| 03–04 | 全块 | glue（shell 已 mapped） |
| 06 | 块内完成 | 接口 + glue |
| STA | 块内全图 | abstract + glue 全图 |

---


## 知识点清单（自检）

- [ ] bottom-up vs top-down
- [ ] abstract/ILM 用途
- [ ] budget 迭代闭环
- [ ] 块 LEC 与顶层黑盒
- [ ] boundary optimization 与 LEC

---

## 8. 小结
> **一句话**：小结——本章核心机制点。

层次化 = **DB 分区 + timing abstract + budget + dont_touch**；签核需 **块 LEC + 顶 LEC**。

---

## 下一节

- [10 LEC](./10-logical-equivalence-checking.md)
- [05 预算/MCMM](./05-constraints-sdc.md)
- [13 交付](./13-deliverables-and-handoff.md)
