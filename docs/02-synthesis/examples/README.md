# 02-synthesis 示例

| 目录 | 用途 |
|------|------|
| [elab_walkthrough/](./elab_walkthrough/) | 与 [01 章](../01-rtl-parsing-and-elaboration.md) **各节「输入/输出案例」** 对照 |
| [inference_walkthrough/](./inference_walkthrough/) | 与 [02 章 推断](../02-inference.md) 对照 |
| [aig_walkthrough/](./aig_walkthrough/) |
| [retiming_walkthrough/](./retiming_walkthrough/) | 与 [06 §8 Retiming](../06-timing-driven-optimization.md#8-retiming寄存器搬移--流水线重平衡) | 与 [03 章 粗粒度优化](../03-optimization.md) §11 对照 |

阅读文档时，每阶段（预处理、词法、Elaboration、Lowering 等）文末即有对应 I/O 示意；可用本目录 RTL 在 DC/Genus 中复现。

```tcl
# filelist 示例
${WALKTHROUGH_ROOT}/child.sv
${WALKTHROUGH_ROOT}/top.sv
```
