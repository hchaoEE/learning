# 推断（Inference）walkthrough 示例

与 [02-inference.md](../../02-inference.md) 各节 **输入/输出案例** 对应。

| 文件 | 推断主题 |
|------|----------|
| `reg_en.sv` | 寄存器 + clock enable |
| `latch_infer.sv` | Latch 推断 |
| `sync_ram.sv` | 同步 RAM 1R1W |
| `mult_16x16.sv` | 乘法器 |

```tcl
analyze -format sverilog {reg_en.sv latch_infer.sv sync_ram.sv mult_16x16.sv}
elaborate sync_ram
compile -stage :pre_map
report_memory
report_latch
report_registers
```
