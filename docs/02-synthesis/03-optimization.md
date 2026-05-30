# 2.3 粗粒度优化：技术无关布尔优化与 AIG（待写）

> **本章是 AIG 的主章节。** 编号 **03** 表示在 **04 工艺映射之前** 完成（见 [DESIGN.md](./DESIGN.md)）。

## 1. 在流程中的位置

```text
02 推断（带标签 GTECH）
        │
        ▼  组合逻辑布尔化
     【本章】AIG 构建 + rewrite / balance / strash
        │
        ▼
04 工艺映射（在 AIG 或等价图上做 cover）
```

## 2. 计划内容

| 节 | 主题 |
|----|------|
| 2.1 | 组合 GTECH 云 → AIG 的 lowering |
| 2.2 | AIG 数据结构（AND + inverter edge、strash） |
| 2.3 | 技术无关优化 pass（rewrite、refactor、balance） |
| 2.4 | 与 ABC 流程对照（开源参考） |
| 2.5 | 时序/面积代价模型（映射前估算） |
| 2.6 | 与寄存器边界：sequential 不进入 AIG 的部分 |
| 2.7 | 输入/输出案例（节点数、深度前后对比） |

## 3. 与其它章边界

| 不写 | 见 |
|------|-----|
| Elaboration、GTECH 产生 | [01](./01-rtl-parsing-and-elaboration.md) |
| 寄存器/RAM 推断 | [02](./02-inference.md) |
| cut/cover、.lib 单元 | [04](./04-technology-mapping.md) |
| 映射后 setup/hold 迭代 | [06](./06-timing-driven-optimization.md) |

## 4. 前置 / 后续

- 前置：[02 推断](./02-inference.md)
- 后续：[04 工艺映射](./04-technology-mapping.md)
