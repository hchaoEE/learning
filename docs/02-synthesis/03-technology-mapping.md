# 2.3 工艺映射（待写）

## 本章与 AIG 的分工

**AIG 的详细原理与优化 pass 在 [04 优化](./04-optimization.md)**。本章只写映射侧：

| 内容 | 归属本章 |
|------|----------|
| **基于 AIG 的 technology mapping**（cut enumeration、cover） | 主写 |
| .lib 单元绑定、延时/面积驱动选单元 | 主写 |
| 映射后网表与 **STA** 衔接 | 主写 |
| AIG rewrite / balancing | 见 **04 章** |

## 计划章节

1. Mapping 在综合中的位置（推断之后）
2. 标准单元库 .lib 与 liberty 弧
3. **组合逻辑映射**：AIG → NAND/NOR/AND 或直接 → 标准单元
4. 时序元件映射（DFF、latch、ICG）
5. RAM / 乘法器 → 宏或 IP
6. `compile_ultra` 与 mapping 策略（概念）

## 前置阅读

- [02 推断](./02-inference.md)  
- [04 优化](./04-optimization.md)（AIG）
