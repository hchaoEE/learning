# 2.6 时序驱动优化（待写）

映射后门级网表已有 **真实单元延时**；本章讲 **如何用 SDC 驱动迭代优化** 消除 setup/hold 违例。

## 1. 与 03 章的区别

| | 03 优化 | 本章 06 |
|---|---------|---------|
| 输入 IR | AIG / 未映射或弱映射 | **Mapped** 门级 |
| 依据 | 拓扑、节点数 | **.lib 延时 + SDC** |
| 典型 pass | rewrite、balance | sizing、buffering、VT swap |

## 2. 计划内容

| 节 | 主题 |
|----|------|
| 2.1 | `compile_ultra` 迭代模型（概念） |
| 2.2 | Setup / hold 修复策略 |
| 2.3 | 缓冲器插入、单元缩放 |
| 2.4 | 拓扑模式（physical synthesis 简述） |
| 2.5 | 输入/输出案例（违例前后） |

## 3. 前置 / 后续

- 前置：[04 映射](./04-technology-mapping.md)、[05 SDC](./05-constraints-sdc.md)
- 后续：[07 报告](./07-synthesis-reports.md)
