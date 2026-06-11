# 工艺映射 walkthrough

与 [04-technology-mapping.md](../../04-technology-mapping.md) **§11 案例集锦** 对应。

| 文件 | 主题 |
|------|------|
| `map_and_or.sv` | 与或非 → ND2/INVX |
| `map_mux.sv` | MUX 映射 |
| `map_xor_chain.sv` | XOR 链 |
| `demo.genlib` | 手写门库（AOI21/OAI21），见 [04 §5.4](../../04-technology-mapping.md#54-手写-genlib--abc-map理解-cover-从哪来) |
| `run_abc_map.sh` | AIG 导出 + `abc -g AND` 对比实验 |

## AOI/OAI

阅读 [04 章 §5.3](../../04-technology-mapping.md#53-aoi--oai--oa为何工艺库爱用复杂门)：`!(a&b)|c` 用 `OAI21` 单单元 vs 多级 ND2/INV。

## Yosys + ABC 映射（可复现组合映射）

```bash
yosys -p "read_verilog map_and_or.sv; hierarchy -top map_and_or; proc; opt;
  abc -g AND -K 6;
  write_verilog map_and_or_mapped.v"
```

对比 `map_and_or_mapped.v` 中单元名与文档 **案例 A**。

## DC 概念

```tcl
read_verilog map_and_or.sv
elaborate map_and_or
link
set_target_library slow.db
compile -map_effort medium
write -format verilog -output map_and_or.mapped.v
report_reference
```
