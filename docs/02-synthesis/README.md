# 02 逻辑综合

ASIC **逻辑综合** 原理与工程实践。工具以 **Design Compiler / Fusion Compiler**、**Genus** 为主。

## 章节导航

| 序号 | 文档 | 状态 | 内容 |
|------|------|------|------|
| 0 | [00-synthesis-overview.md](./00-synthesis-overview.md) | 已写 | 综合三阶段、输入输出 |
| 1 | [01-rtl-parsing-and-elaboration.md](./01-rtl-parsing-and-elaboration.md) | **已写** | 前端内部：AST、Elab 引擎、RTL→GTECH lowering、Design DB |
| 2 | [02-inference.md](./02-inference.md) | 待写 | 寄存器、latch、RAM、乘法器推断 |
| 3 | [03-technology-mapping.md](./03-technology-mapping.md) | 待写 | 工艺映射 |
| 4 | [04-optimization.md](./04-optimization.md) | 待写 | 面积/延时/功耗优化 |
| 5 | [05-constraints-sdc.md](./05-constraints-sdc.md) | 待写 | SDC 约束 |
| 6 | [06-timing-and-area-reports.md](./06-timing-and-area-reports.md) | 待写 | 读懂报告 |
| 7 | [07-low-power-synthesis.md](./07-low-power-synthesis.md) | 待写 | 低功耗综合 |

## 阅读顺序

```text
00 总览 → 01 RTL 解析与展开 → 02 推断 → 03 映射 → 04 优化 → 05 SDC → 06 报告
```

## 与 01-rtl 的衔接

RTL 中的 `always` 风格、parameter/generate、端口位宽，直接决定 **elaboration 是否通过** 以及 **推断结果**。建议先完成 [01-rtl](../01-rtl/) 再读本章。
