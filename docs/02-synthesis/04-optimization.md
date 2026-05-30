# 2.4 逻辑优化（待写）

> **AIG 正文应写在本章**，而非 01 Elaboration 或 02 推断。

## 本章与 AIG 的分工

| 内容 | 归属本章 |
|------|----------|
| GTECH 组合云 → **AIG** 的转换 | § 待定 |
| **结构哈希（strash）**、节点共享 | § 待定 |
| **Rewriting / refactoring / balancing**（ABC 类） | § 待定 |
| 与 **时序/面积** 目标联动的技术无关优化 | § 待定 |
| 优化后交回 **映射**（见 [03 章](./03-technology-mapping.md) § AIG mapping） | 交叉引用 |

## 计划章节

1. 优化在 `compile` 中的 pass 顺序（概念）
2. **AIG 数据结构与构造**（AND + inverter edge）
3. AIG 上的等价变换与代价模型
4. 与 BDD、SAT 的辅助关系（简述）
5. 寄存器/边界保留：sequential optimization 与组合 AIG 的切分
6. 报告与调试（节点数、深度、面积估算）

## 前置阅读

- [00 总览 §4 AIG 在哪一步](./00-synthesis-overview.md#4-aig-在哪一步做) — 流程定位  
- [01 Elaboration](./01-rtl-parsing-and-elaboration.md) — GTECH 从哪来  
- [02 推断](./02-inference.md) — 时序元件与 RAM 边界  

## 下一节

- [03 工艺映射](./03-technology-mapping.md) — AIG **cut / cover** 映射到标准单元
