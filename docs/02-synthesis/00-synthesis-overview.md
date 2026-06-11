# 2.0 逻辑综合总览

ASIC **逻辑综合**：RTL → **可交付的门级网表**，并在 **时序、等价性、可测性、低功耗** 上签核。

> 完整章节地图：[README](./README.md) · 设计说明：[DESIGN.md](./DESIGN.md) · **方方面面索引**：[12 §9](./12-deliverables-and-handoff.md#9-综合方方面面索引)

---

## 1. 一张图：从 RTL 到交付

```text
                         05 SDC ─────────────┐
                              │              │
RTL ──► 01 Elab/GTECH ──► 02 推断 ──► 03 粗优化(AIG)
                              │              │
                              ▼              ▼
                         04 映射 ──► 06 细优化 ──► 07 报告
                              │              │
                              ├──── 08 UPF/ICG
                              │
                              ▼
                         09 LEC（RTL↔网表）
                              │
                    10 层次（若分块）
                              │
                    11 DFT/Scan（若本阶段做）
                              │
                              ▼
                         12 交付 → PnR
```

---

## 2. 全文章节（00–12）

| 章 | 文档 | 一句话 |
|----|------|--------|
| 0 | 本文 | 地图 |
| 1 | [01](./01-rtl-parsing-and-elaboration.md) | 前端 → GTECH |
| 2 | [02](./02-inference.md) | 资源推断 |
| 3 | [03](./03-optimization.md) | 粗粒度 / AIG |
| 4 | [04](./04-technology-mapping.md) | 工艺映射 |
| 5 | [05](./05-constraints-sdc.md) | SDC → timing graph |
| 6 | [06](./06-timing-driven-optimization.md) | STA/transform 引擎 |
| 7 | [07](./07-synthesis-reports.md) | 内部量索引 |
| 8 | [08](./08-low-power-synthesis.md) | UPF/ICG DB 语义 |
| 9 | [09](./09-logical-equivalence-checking.md) | LEC / miter |
| 10 | [10](./10-hierarchical-block-synthesis.md) | 分块 / 预算 |
| 11 | [11](./11-dft-and-scan.md) | **DFT / 扫描** |
| 12 | [12](./12-deliverables-and-handoff.md) | **交付 / 交接** |

---

## 3. 按角色怎么读

| 角色 | 建议路径 |
|------|----------|
| RTL 工程师 | 01 → 02 → 05 → 09 |
| 综合工程师 | 00 → 01–07 → 09–12 |
| 低功耗 | 05 → 08 → 12 |
| 后端 | 12 → 05 → 06（知约束来源） |
| 新人通读 | 路径 A：[README §4](./README.md#4-阅读路径) + **09 LEC** + **12 交付** |

---

## 4. AIG 在哪一章？（短答）

| 问题 | 答案 |
|------|------|
| 主文 | [03](./03-optimization.md) |
| 映射如何用 | [04](./04-technology-mapping.md) |
| 粗/细 | [README §8](./README.md#8-粗粒度优化-vs-细粒度优化写在哪一章) |

---

## 5. 签核三角（内部视角）

| 维度 | 章节 | 内部证什么 |
|------|------|------------|
| **时序** | 05、06、07 | timing graph 上 slack/DRC 闭合 |
| **等价** | **09** | miter 无 diff 输入（R↔I） |
| **可测** | **11** | scan IR 可链、test mode 可 STA |

三者 **都过** 才可视为综合阶段关闭（见 [12 门控](./12-deliverables-and-handoff.md#3-签核门控quality-gates)）。

---

## 6. 交付物（短答）

网表、SDC、UPF（可选）、LEC 记录、内部量快照 — 详见 [12](./12-deliverables-and-handoff.md)。

---

## 7. `compile` 内部 Pass 时间线（全景）

工业综合器把一次 `compile` 拆成 **可重复调度的 pass**；每步读写 **同一 Design DB**，只是 IR 形态在变。

```text
  RTL 源
    │ ① elaborate / link / uniquify
    ▼
  GTECH 网表 + Design DB
    │ ② inference（资源标签）
    ▼
  带 resource_type 的 GTECH
    │ ③ boolean opt → AIG（03）
    ▼
  优化后 AIG + SEQ/宏 边界
    │ ④ technology mapping（04）
    ▼
  Mapped 标准单元网表
    │ ⑤ timing-driven opt 环（06）× N
    ▼
  时序闭合的 mapped 网表
    │ ⑥（可选）retime / UPF 单元插入（ICG 壳在 ② 推断期已插，04 映射为库单元）
    ▼
  签核前网表 → 09 LEC / 11 DFT
```

### 7.1 Pass 级动作与可观测变化

| Pass | 输入 IR | 输出 IR | 内部动作（细） | 可观测变化 |
|------|---------|---------|----------------|------------|
| **Elaborate** | AST | GTECH + 层次 | generate 展开、param 求值、RTL→GTECH lowering | `GTECH_*` 出现；层次 instance 树 |
| **Inference** | GTECH SEQ 云 | 带 `resource_type` | 识别 FF/latch/RAM/MULT；ICG 候选 | SEQGEN 标签；latch 列表 |
| **Strash** | GTECH 组合 | AIG | 结构性哈希去重 | AIG node ↓ |
| **Rewrite/Refactor/Balance** | AIG | AIG | 窗口替换、重构、深度平衡 | node/level 变化 |
| **Map** | AIG | Mapped gates | cut enum → cover → 实例化 | 库单元名出现；GTECH 组合消失 |
| **STA** | Mapped + SDC | 标注 timing graph | delay 标注、slack 计算 | WNS/TNS、违例标签 |
| **TDO transform** | Mapped | Mapped | upsize/buffer/VT swap | buffer 占比 ↑；slack ↑ |
| **Retiming** | Mapped | Mapped | FF 搬移/插入 | FF 数变、组合 depth 变 |

### 输入/输出案例 7.1 — 单点 assign 走完全链

**RTL**：`assign y = (a & b) | c;`（纯组合）

| 阶段 | DB 内形态（片段） |
|------|-------------------|
| Elaborate | `GTECH_AND`, `GTECH_OR` 两节点 |
| → AIG | 2 AND 节点 + 3 条 inv 边（OR 经德摩根改写，见 [03 §2.1](./03-optimization.md)） |
| 粗优化后 | 仍 2 AND（结构已最简；若 `(a&b)` 在别处复用则 strash 共享） |
| Map | 单个 `AO21D1`，或 `AN2D1`+`OR2D1` 两单元 |
| 06 | 可能 `AO21D1→AO21D2`（upsize） |

→ 逐步案例见 [03 §11](./03-optimization.md#11-案例集锦逐步理解)、[04 §11](./04-technology-mapping.md#11-案例集锦逐步理解-mapping)。

**端到端串联**：[examples/mini_chain/README.md](./examples/mini_chain/README.md)（单模块走完全链 IR 快照）。

---

## 下一节

[01 RTL 解析与 Elaboration](./01-rtl-parsing-and-elaboration.md)
