# 02-synthesis 示例

| 目录 | 用途 |
|------|------|
| [mini_chain/](./mini_chain/) | **端到端** IR 快照（01→06 全链） |
| [elab_walkthrough/](./elab_walkthrough/) | [01 章](../01-rtl-parsing-and-elaboration.md) 各阶段 IR |
| [inference_walkthrough/](./inference_walkthrough/) | [02 章](../02-inference.md) 推断 DB 字段 |
| [aig_walkthrough/](./aig_walkthrough/) | [03 章](../03-optimization.md) AIG pass |
| [mapping_walkthrough/](./mapping_walkthrough/) | [04 章](../04-technology-mapping.md) cover 选择 |
| [sdc_walkthrough/](./sdc_walkthrough/) | [05 章](../05-constraints-sdc.md) timing graph |
| [tdo_walkthrough/](./tdo_walkthrough/) | [06 章](../06-timing-driven-optimization.md) STA/transform |
| [retiming_walkthrough/](./retiming_walkthrough/) | [06 §8](../06-timing-driven-optimization.md#8-retiming寄存器搬移--流水线重平衡) |
| [power_walkthrough/](./power_walkthrough/) | [02 §8](../02-inference.md#8-时钟门控icg推断--asic-低功耗)、[08 章](../08-low-power-synthesis.md) |

阅读顺序建议：**mini_chain** → 各专题 walkthrough。

每 walkthrough 提供 **RTL → 内部 IR / delay / slack** 示意；重点理解机制，非复现工具 flow。
