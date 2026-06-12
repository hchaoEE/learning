# 2.12 DFT 与可测性 — 网表结构变换

> **本章回答**：Scan 如何改 FF 结构与 test mode 时序。
> **读完应能**：① 说清 DFF→SDFF 变换 ② 区分 shift/capture ③ 知道须在 mapped 后插入
> **先修**：[06](./06-timing-driven-optimization.md) · **难度**：★★★☆☆ · **walkthrough**：[dft_walkthrough](./examples/dft_walkthrough/)

生产测试需 **控制/观测内部 FF**。**DFT** 在功能综合后把 mapped 网表 **改写为可扫描结构**，再进入 [06](./06-timing-driven-optimization.md) 再收敛与 [10 LEC](./10-logical-equivalence-checking.md)。

> 本章讲 **scan 如何改 DB 拓扑**；ATPG 工具链从简。

---

## 1. 在流程中的位置
> **一句话**：在流程中的位置——本章核心机制点。

```text
功能 compile（01–06）→ mapped netlist + timing clean
        │
        ▼
【DFT pass】DFF → SDFF，SI/SO/SE 连接，链序确定
        │
        ▼
06 再优化（scan 路径 timing）→ LEC（10）→ 交付（13）
```

**顺序不可乱**：scan 改 FF 结构 → **delay 变** → 必须 **再 STA/再优化**。

### 1.1 为何在 mapped + clean 之后

| 候选时机 | 为何不行 / 为何行 |
|----------|---------------------|
| Elaboration 前（RTL 加 mux） | SDFF 是 **库单元概念**，GTECH 层无对应；且 03/04 会把手写 scan mux 优化掉或拆散 |
| 03/04 期间 | scan 链连接依赖 **最终 FF 集合** — retiming/寄存器优化（02 §10、06 §8）还会增删 FF |
| **mapped + timing clean 后**（实际） | FF 集合冻结、库单元已绑定 → 换型只是 **同 footprint ref 替换** + 链布线 |

**Pass 内部顺序**：`scan 替换（DFF→SDFF）→ 链规划（§5.1）→ stitching（§5.3）→（可选）compression 插入（§5.2）→（可选）OCC 插入 → 06 再收敛`。

**与 09 ICG 的冲突**：被 ICG 门控的 FF 在 shift 模式必须 **保证收到时钟**（否则链断）→ ICG 单元的 **test 旁路 pin**（`CKLN*` 的 TE 端）在 DFT pass 接 `scan_en`/test mode 信号 — `TE=1` 强制透传。漏接 = shift 时链中断，ATPG 全失败。

**OCC（on-chip clock controller）**：at-speed 测试需在 shift（慢 test clock）与 capture（功能速率 2 拍）间切换时钟源；OCC 作为独立 DFT 子 pass 插在 clock 网络根部，并带来 **test mode 下的 generated clock 定义**（05 §9.1 机制）。

### 输入/输出案例 1.1 — mapped 后插 scan + OCC

**输入**：功能 WNS=+0.02；DFT pass 换 SDFF + ICG `TE` 旁路 + OCC 根节点。

| 阶段 | FF 类型 | clock 图 | 06 动作 |
|------|---------|----------|---------|
| 功能闭合后 | DFF | 单 `clk` | — |
| scan 替换后 | SDFF+SI/SE | 同 | shift 路径 **新违例** |
| OCC 后 | 同 | **test generated clk** | 再收敛 |

**输出**：须 **再跑 06** + test mode SDC（[13 §1.1 DFT 细项](./13-deliverables-and-handoff.md#11-层次化设计的分包结构)）。

---

## 2. Scan 的 IR 变换（内部）
> **一句话**：Scan 的 IR 变换（内部）——本章核心机制点。

### 2.1 功能 FF → Scan cell

| 功能单元 | Scan 单元（概念） | 新增 pin |
|----------|-------------------|----------|
| `DFFX1` (D, CK, Q) | `SDFFX1` | **SI**（scan in）、**SE**（scan enable） |

**内部连接**：

```text
Functional mode (SE=0):  D → FF → Q  （与原来相同）
Scan shift mode (SE=1):  SI → FF → Q  （串链移位）
Capture:                 D → FF → Q  （组合结果打入）
```

### 2.2 Scan chain 拓扑

```text
SDI ──► FF0 ──► FF1 ──► … ──► FFk ──► SDO
         Q→SI   Q→SI         Q→SO
```

**链序算法**（启发式）：

- 按 **clock domain** 分链  
- 平衡 **链长**（ATPG 时间）  
- 避开 **dont_scan** / **retention** / **macro 内 FF**

### 输入/输出案例 2.1

**输入 DB**：100k 功能 DFF  
**DFT pass 后**：100k SDFF，**20 链** × ~5k 级；netlist 增 **SI/SO/SE** port 与 **scan 控制** net。

---

## 3. 对 timing graph 的影响
> **一句话**：对 timing graph 的影响——本章核心机制点。

**换型的量化代价**（SDFF vs DFF，典型相对值）：

| 维度 | 变化 | 机制 |
|------|------|------|
| 面积 | +15~25% / FF | 内部多一级 scan mux |
| D→Q functional delay | +5~15% | D 先过 mux 再进锁存级 |
| D pin 输入 cap | 略增 | mux 栅负载 |
| setup（functional） | 全体 FF 同时变慢 → 原 WNS≈0 的设计 **必然回 06** | check 值与 arc 同变（07 §4.1） |
| hold（shift 模式） | Q→SI 直连、组合≈0 → **fast corner 极易违例** | 与 06 §4 同机制，集中在链相邻级 |

| 影响 | 内部 |
|------|------|
| 单元换型 | cell arc delay 变（上表） |
| SE/SI net | 新 **data/check** 路径（test mode） |
| Hold | **shift 模式** 下 fast corner 易违例 → 链上批量插 delay/lockup |
| Clock | 测试可能用 **OCC** 切 test clock（§1.1） |

**06 再收敛的队列策略**：functional mode 桶 **权重高于** test mode 桶（影响出货性能 vs 只影响测试）；shift hold 违例多用 **lockup latch / 链重排** 解决而非逐点 delay cell。

**MCMM**：functional mode 与 **test mode** 为 **不同 mode** → 各自 timing graph 子集（见 [05 §6](./05-constraints-sdc.md#6-mcmm多-corner-在-db-上的挂接)）。

### 输入/输出案例 3.1

**Functional WNS = +0.05 ns** → DFT 后 **−0.02 ns** → 06 在 **functional corner** 再 sizing。

---

## 4. 与 LEC 的内部关系
> **一句话**：与 LEC 的内部关系——本章核心机制点。

| 比对模式 | R | I |
|----------|---|---|
| Pre-scan | RTL | 功能 mapped 网表 |
| Post-scan | **DFT RTL**（含 scan 端口）或 **scan 等价约束** | scan 网表 |

**失败机制**：R 无 `SI`，I 有 → compare point **维度不匹配** → 需在 R 加 **scan wrapper 模型** 或 **blackbox scan logic**。

### 输入/输出案例 4.1 — pre-scan vs post-scan LEC

**输入**：功能 RTL `r`；post-scan 网表多 `scan_in/out/en` 与 mux 路径。

| 模式 | R 侧 | I 侧 | 结果 |
|------|------|------|------|
| 直接比 | 无 SI | 有 SI | **unmatched** |
| DFT RTL / wrapper | 含 scan 端口模型 | scan 网表 | **proven**（组合功能锥） |

**输出**：LEC 维度须与 **DFT 变换后拓扑** 对齐（见 [examples/dft_walkthrough/](./examples/dft_walkthrough/)）。

---

## 5. Scan 链序算法与压缩（内部）
> **一句话**：Scan 链序算法与压缩（内部）——本章核心机制点。

### 5.1 链序（启发式）

```text
1. 按 clock domain 分组 FF
2. 排除 dont_scan / macro 内 FF
3. 每组内平衡链长（≈5000 FF/链 示意）
4. 连接 SI←Q→SI…→SO
```

### 输入/输出案例 5.1

**100k FF，20 链**：每链 ~5k 级；**同一 clock 域** 内串链，避免跨域 shift 时序问题。

### 5.2 Scan compression：拓扑与代价

外部 ATE 引脚有限、pattern 量大 → 在链两端插压缩逻辑：

```text
              ┌► 内链 0（500 FF）─┐
SDI ×2 ─►decompressor（XOR 展开网络）─► 内链 1 … N─►compactor（XOR 树）─► SDO ×2
              └► 内链 99 ──────────┘

外部视角：2 进 2 出；内部：100 条短链并行 shift
```

| 维度 | 无压缩（20 链 × 5k） | 压缩（100 内链 × 1k，50:1 示意） |
|------|------------------------|-------------------------------------|
| shift 周期数/pattern | 5,000 | **1,000**（链短了） |
| 测试时间 | 1.0 | ~0.2 |
| 新增组合 | 0 | decompressor + compactor（XOR 锥，**高 fanout**） |
| 故障可观测性 | 直接 | compactor 折叠 → **X 屏蔽、混叠** 风险，ATPG 需 X-tolerant 结构 |

**对综合 pass 的负担**：压缩逻辑插入后 **04/06 必须重跑**——decompressor 输出是高 fanout net（驱动百条链首级 SI）、compactor 是宽 XOR 树（新的深组合锥），两者都可能成为 test mode 新关键路径；且压缩比越高，XOR 网络越大。

### 输入/输出案例 5.2 — 50:1 压缩代价

**输入**：100k FF，ATE 仅 2 scan 口；插入 50:1 decompressor/compactor。

| 指标 | 无压缩 | 50:1 压缩 |
|------|--------|------------|
| shift 周期/pattern | 5,000 | **1,000** |
| 新增组合门 | 0 | **+12k**（XOR 锥） |
| test mode WNS | — | **−0.18**（decompressor 高 fanout） |
| 06 动作 | — | 压缩后 **重跑 04/06** |

详见 [dft_walkthrough/](./examples/dft_walkthrough/README.md)。

### 5.3 Stitching 分层与 lockup latch

链连接（stitching）分两阶段，与 [11 层次化](./11-hierarchical-block-synthesis.md) 对齐：

| 阶段 | 动作 | 约束 |
|------|------|------|
| **块内** | 块内 FF 串成若干条链，引出块级 SI/SO port | 同 clock 域内串；物理感知时按 placement 邻近排序（减 wire + hold 风险） |
| **顶层** | 块 SO → 下一块 SI 串接（或进压缩通道） | 块序按物理位置；每链总长平衡 |

**Lockup latch**：同链相邻级时钟到达时刻差异大（跨 ICG 分支、跨块、clock skew 大）时，Q→SI 直连在 shift 下 hold 失败 — 在交界处插 **负沿 latch**：

```text
FF_a（clk 早到）──Q──► lockup latch（负沿）──► FF_b/SI（clk 晚到）
   半个周期的「缓冲」吃掉 skew → shift hold 安全
```

插入点判定：链序确定后，对每对相邻级比较 **clock 到达时刻差 vs hold 裕量**（综合期用估计 skew，PnR 后可能补插）。

### 输入/输出案例 5.3 — lockup 插入点

**输入**：链上 `FF_a`（ICG 后，clk 晚到 0.3 ns）→ `FF_b/SI`（clk 早到 0 ns），shift 模式 fast_min hold 裕量 0.05 ns。

| 方案 | Q→SI 有效 delay | hold slack |
|------|-----------------|------------|
| 直连 | ~0.02 ns | **−0.08** |
| 中间负沿 lockup | +0.5×period 缓冲 | **+0.12** |

**输出**：DFT pass 在 `FF_a/Q` 与 `FF_b/SI` 间插 `LOCKUP_LAT`；块内 stitching 完成后再顶层串链（[11 章](./11-hierarchical-block-synthesis.md)）。

---

## 6. 约束语义（test mode）
> **一句话**：约束语义（test mode）——本章核心机制点。

Test mode 在 DB 上 **额外 clock / false_path / case**：

| 语义 | 作用 |
|------|------|
| test clock | shift 时序 check |
| functional false_path on scan | 避免虚假 cross-mode 违例 |
| `scan_enable` case | SE=0/1 分模式 STA |

**Shift 与 capture 是 test mode 内的两个子模式**，check 绑定不同：

| 子模式 | case 设定 | 活跃 check |
|--------|-----------|------------|
| **shift** | SE=1 | Q→SI 链路径（慢 test clock 下 setup 宽松、**hold 是主角**） |
| **capture**（at-speed） | SE=0 + OCC 发功能速率 2 拍 | D 锥 setup **按功能频率检**——这就是 at-speed 测试能抓 transition fault 的时序基础 |

**Cross-mode 聚合**：06 的 transform 接受判定对 functional + test 两套 mode 同时检（05 §6 MCMM 机制）；修 functional setup 的 upsize 若恶化 shift hold → 回滚或在链上补 lockup，冲突处理与 06 §4.3 同源。

仅 functional SDC 签核 → **test 路径未检** → ATPG **untested** 高。

### 输入/输出案例 6.1 — shift vs capture 子模式

**输入**（[examples/dft_walkthrough/scan_modes.sdc](./examples/dft_walkthrough/scan_modes.sdc) 概念片段）：

```tcl
set_case_analysis 0 [get_ports scan_en]   ;# functional STA
# test mode: scan_en=1 → shift checks; capture 子模式另建 mode
```

| 子模式 | `scan_en` | 活跃 check | 典型违例 |
|--------|-----------|------------|----------|
| functional | 0 | D 锥 setup @ 功能频率 | setup |
| shift | 1 | Q→SI @ test_clk | **hold** |
| capture | 0 + OCC 脉冲 | D 锥 @ **at-speed** | setup |

**输出**：仅交 functional SDC → shift 链 hold **未检** → silicon shift 失败；须 **test mode SDC** 与 functional 配对交付（[13 §1.1](./13-deliverables-and-handoff.md#11-层次化设计的分包结构)）。

---

## 7. 与 retiming、层次
> **一句话**：与 retiming、层次——本章核心机制点。

| 交互 | 内部 |
|------|------|
| **Retiming 后 DFT** | FF 顺序变 → **链重排** |
| **层次块** | 块内 scan 先完成 → 顶层 **串链** |
| **dont_touch 宏** | 宏内 FF **不可 scan** → 覆盖率洞 |

见 [06 §8.5](./06-timing-driven-optimization.md#85-与-dft层次化)、[11 章](./11-hierarchical-block-synthesis.md)。

---


## 知识点清单（自检）

- [ ] scan 在 mapped 后插入
- [ ] shift vs capture 模式
- [ ] ICG TE 旁路
- [ ] lockup 与 hold
- [ ] test mode SDC 须交付

---

## 8. 小结
> **一句话**：小结——本章核心机制点。

DFT = **mapped IR 的结构 rewrite**（SDFF + 链）+ **再 06** + **再 LEC**；与功能综合 **串行**。

---

## 下一节

- [10 LEC](./10-logical-equivalence-checking.md)
- [06 细粒度](./06-timing-driven-optimization.md)
- [13 交付](./13-deliverables-and-handoff.md)
