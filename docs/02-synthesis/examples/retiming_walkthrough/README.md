# Retiming walkthrough

与 [06 章 §8 Retiming](../06-timing-driven-optimization.md#8-retiming寄存器搬移--流水线重平衡) 对照。

| 文件 | 说明 |
|------|------|
| `long_comb.sv` | 多级组合；对比 `set_optimize_registers` 开/关 的 FF 数量与 WNS |

```tcl
# 对比实验（概念）
set_optimize_registers false
compile_ultra
report_timing > no_retime.tim
report_reference -hierarchy | grep -c DFF

set_optimize_registers true
compile_ultra
report_timing > with_retime.tim
```

注意：若 RTL 已固定流水，retime 可能几乎不动寄存器。
