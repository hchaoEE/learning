# 02-synthesis 示例

| 目录 | 用途 |
|------|------|
| [elab_walkthrough/](./elab_walkthrough/) | 与 [01 章](../01-rtl-parsing-and-elaboration.md) **各节「输入/输出案例」** 对照 |
| [inference_walkthrough/](./inference_walkthrough/) | 与 [02 章 推断](../02-inference.md) 对照 |
| [aig_walkthrough/](./aig_walkthrough/) | 与 [03 章 粗粒度优化](../03-optimization.md) §11 对照 |
| [mapping_walkthrough/](./mapping_walkthrough/) | 与 [04 工艺映射](../04-technology-mapping.md) §11 对照 |
| [sdc_walkthrough/](./sdc_walkthrough/) | 与 [05 章 SDC 内部](../05-constraints-sdc.md) timing graph 案例 |
| [tdo_walkthrough/](./tdo_walkthrough/) | 与 [06 章 §2–§5](../06-timing-driven-optimization.md) 细粒度引擎 |
| [retiming_walkthrough/](./retiming_walkthrough/) | 与 [06 §8 Retiming](../06-timing-driven-optimization.md#8-retiming寄存器搬移--流水线重平衡) |
| [power_walkthrough/](./power_walkthrough/) | 与 [02 §8](../02-inference.md#8-时钟门控icg推断--asic-低功耗)、[08 章](../08-low-power-synthesis.md) ICG/域 |

阅读文档时，每 walkthrough 提供 **RTL → 内部 IR / delay / slack** 示意；重点理解机制，非复现工具 flow。
