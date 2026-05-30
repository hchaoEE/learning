# 2.0 逻辑综合总览

ASIC **逻辑综合**：RTL → **门级网表**（标准单元 + 宏），在满足 **SDC** 的前提下优化时序、面积、功耗。

> 章节怎么排、AIG 写在哪一章，见 **[02-synthesis/README.md](./README.md)** 与 **[DESIGN.md](./DESIGN.md)**。

---

## 1. 一张图看懂全篇

```text
                    ┌─────────────────────────────────────────┐
  RTL + filelist    │  01 前端：Elaboration → GTECH          │
 ─────────────────►│  02 推断：REG / LATCH / RAM / MULT      │
                    │  03 优化：AIG、技术无关化简              │
                    │  04 映射：.lib 标准单元                  │
                    │  06 时序驱动优化（mapped）               │
                    └─────────────────────────────────────────┘
                                        │
                    05 SDC ─────────────┘（全程约束输入）
                                        ▼
                              门级网表 + 07 报告
                    08 低功耗（UPF/ICG，与 02/06 交叉）
```

---

## 2. 章节与状态

| 章 | 文档 | 状态 | 一句话 |
|----|------|------|--------|
| 0 | 本文 | 已写 | 地图 |
| 1 | [01-rtl-parsing-and-elaboration](./01-rtl-parsing-and-elaboration.md) | **已写** | RTL → GTECH |
| 2 | [02-inference](./02-inference.md) | **已写** | GTECH → 资源标签 |
| 3 | [03-optimization](./03-optimization.md) | 骨架 | 组合 → **AIG** → 优化 |
| 4 | [04-technology-mapping](./04-technology-mapping.md) | 骨架 | AIG/网表 → 单元 |
| 5 | [05-constraints-sdc](./05-constraints-sdc.md) | 骨架 | SDC 约束语言 |
| 6 | [06-timing-driven-optimization](./06-timing-driven-optimization.md) | 骨架 | 映射后修时序 |
| 7 | [07-synthesis-reports](./07-synthesis-reports.md) | 骨架 | 读报告 |
| 8 | [08-low-power-synthesis](./08-low-power-synthesis.md) | 骨架 | UPF/ICG |

---

## 3. AIG 在哪一章？（短答）

| 问题 | 答案 |
|------|------|
| 在 Elaboration 里吗？ | **否**（01 止于 GTECH） |
| 主文写哪？ | **[03 优化](./03-optimization.md)** |
| 映射怎么用 AIG？ | **[04 工艺映射](./04-technology-mapping.md)** 的 cut/cover |
| 长流程图 | 见 [README §2 IR 映射](./README.md#2-内部-ir-与章节映射) |

不在 00 章展开算法细节，避免与 03 重复。

---

## 4. 交付物

| 类型 | 说明 |
|------|------|
| 输入 | RTL、filelist、**SDC**、.lib（+ DB）、UPF（可选） |
| 输出 | 门级 Verilog、SDF（可选）、DDC/NDM、综合报告 |

---

## 5. 工具链（ASIC）

Synopsys DC/Fusion、Cadence Genus + PrimeTime；内部 pass 不同，**IR 主链一致**（GTECH → AIG → mapped）。

---

## 下一节

- 主链起点：[01 RTL 解析与 Elaboration](./01-rtl-parsing-and-elaboration.md)
- 章节设计：[README](./README.md) · [DESIGN](./DESIGN.md)
