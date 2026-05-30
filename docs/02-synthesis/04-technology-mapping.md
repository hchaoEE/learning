# 2.4 工艺映射（待写）

> 在 **[03 优化](./03-optimization.md)**（AIG/布尔优化）**之后**，将逻辑绑定到 **.lib 标准单元**。

## 1. 在流程中的位置

```text
03 优化后的 AIG / 布尔网表
        │
        ▼  【本章】technology mapping
   门级网表（DFFRX1, ND2D1, …）
        │
        ▼
06 时序驱动优化
```

## 2. 计划内容

| 节 | 主题 |
|----|------|
| 2.1 | .lib / liberty：单元、弧、wire load |
| 2.2 | **基于 AIG 的 mapping**（cut enumeration、cover） |
| 2.3 | 时序元件映射（DFF、latch、ICG） |
| 2.4 | 宏与 IP（SRAM、DesignWare mult） |
| 2.5 | `dont_touch`、size_only、group_path |
| 2.6 | 输入/输出案例（映射前后 cell 名） |

## 3. 与其它章边界

| 不写 | 见 |
|------|-----|
| AIG rewrite | [03](./03-optimization.md) |
| 推断分类 | [02](./02-inference.md) |
| SDC 语法 | [05](./05-constraints-sdc.md) |
| 迭代修违例 | [06](./06-timing-driven-optimization.md) |

## 4. 前置 / 后续

- 前置：[03 优化](./03-optimization.md)
- 后续：[06 时序驱动优化](./06-timing-driven-optimization.md)
