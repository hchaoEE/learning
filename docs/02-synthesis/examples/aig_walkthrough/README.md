# AIG / 粗粒度优化 walkthrough

与 [03-optimization.md](../../03-optimization.md) **§11 案例集锦** 对应。

| 文件 | 案例主题 |
|------|----------|
| `comb_dup.sv` | strash：重复 `a&b` |
| `comb_mux.sv` | MUX/case 布尔化 |
| `comb_const.sv` | 常量传播、恒 0 输出 |
| `reg_comb_boundary.sv` | 组合锥在 REG 前截止 |

```tcl
analyze -format sverilog {comb_dup.sv comb_mux.sv comb_const.sv reg_comb_boundary.sv}
elaborate comb_dup
compile -stage :pre_map   ;# 或工具等价的「仅逻辑优化」阶段
```

对比 `report_area` / 内部节点统计（若工具开放）与文档中的节点/level 示意。
