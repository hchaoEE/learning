# 02-synthesis 示例

| 目录 | 用途 |
|------|------|
| [mini_chain/](./mini_chain/) | **端到端** IR 快照（01→06 全链） |
| [elab_walkthrough/](./elab_walkthrough/) | [01 章 §2 一条龙](../01-rtl-parsing-and-elaboration.md#2-完整案例走读top--child一条龙) + 各阶段 IR |
| [inference_walkthrough/](./inference_walkthrough/) | [02 章](../02-inference.md) 推断 DB 字段 |
| [aig_walkthrough/](./aig_walkthrough/) | [03 章](../03-optimization.md) AIG pass |
| [mapping_walkthrough/](./mapping_walkthrough/) | [04 章](../04-technology-mapping.md) cover 选择 |
| [sdc_walkthrough/](./sdc_walkthrough/) | [05 章](../05-constraints-sdc.md) timing graph |
| [tdo_walkthrough/](./tdo_walkthrough/) | [06 章](../06-timing-driven-optimization.md) STA/transform |
| [sta_walkthrough/](./sta_walkthrough/) | [07 章](../07-internal-sta-and-qor.md) 内部 STA / AT·RT |
| [retiming_walkthrough/](./retiming_walkthrough/) | [06 §8](../06-timing-driven-optimization.md#8-retiming寄存器搬移--流水线重平衡) |
| [power_walkthrough/](./power_walkthrough/) | [02 §9](../02-inference.md#9-时钟门控icg推断--asic-低功耗)、[09 章](../09-low-power-synthesis.md) |
| [lec_walkthrough/](./lec_walkthrough/) | [10 章](../10-logical-equivalence-checking.md) miter / Cycle0 反例 |
| [dft_walkthrough/](./dft_walkthrough/) | [12 章](../12-dft-and-scan.md) scan 模式 / 压缩 / lockup |
| [hier_walkthrough/](./hier_walkthrough/) | [11 章](../11-hierarchical-block-synthesis.md) budget / 层次 LEC |
| [3dic_walkthrough/](./3dic_walkthrough/) | [15 章](../15-3d-ic-synthesis.md) 跨 die timing / TSV 弧 |

阅读顺序建议：**mini_chain** → 各专题 walkthrough。

每 walkthrough 提供 **RTL → 内部 IR / delay / slack** 示意；重点理解机制，非复现工具 flow。
