# 2.0 逻辑综合总览

ASIC **逻辑综合**：RTL → **可交付的门级网表**，并在 **时序、等价性、可测性、低功耗** 上签核。

> 完整章节地图：[README](./README.md) · 设计说明：[DESIGN.md](./DESIGN.md) · **方方面面索引**：[12 §8](./12-deliverables-and-handoff.md#8-综合方方面面索引)

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
| 粗/细 | [README §9](./README.md#9-粗粒度优化-vs-细粒度优化写在哪一章) |

---

## 5. 签核三角

| 维度 | 章节 | 工具例 |
|------|------|--------|
| **时序** | 05、06、07 | DC/Genus + PrimeTime |
| **等价** | **09** | Formality / Conformal |
| **可测** | **11** | DFT Compiler / Modus |

三者 **都过** 才可视为综合阶段关闭（见 [12 门控](./12-deliverables-and-handoff.md#3-签核门控quality-gates)）。

---

## 6. 交付物（短答）

网表、SDC、UPF（可选）、LEC 报告、QoR 报告 — 详见 [12](./12-deliverables-and-handoff.md)。

---

## 下一节

[01 RTL 解析与 Elaboration](./01-rtl-parsing-and-elaboration.md)
