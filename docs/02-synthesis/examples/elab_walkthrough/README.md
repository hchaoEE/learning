# Elaboration walkthrough — 与 01 章 §2 一条龙案例对应

主阅读路径：[01 章 §2 完整案例走读](../../01-rtl-parsing-and-elaboration.md#2-完整案例走读top--child一条龙)（`top.sv` + `child.sv`，`N=2, W=8`）。

本目录文件与走读步骤 / 细节章节的对应关系：

| 文件 | 走读步骤 | 01 章细节 |
|------|----------|-----------|
| `top.sv` + `child.sv` | 全程（§2 主案例） | [§2](../../01-rtl-parsing-and-elaboration.md#2-完整案例走读top--child一条龙) |
| `preprocess_demo.sv` | 步骤 A（预处理） | [§4](../../01-rtl-parsing-and-elaboration.md#4-阶段-a预处理preprocess) |
| `unique_case.sv` | （独立片段）unique case lowering | [§9.4](../../01-rtl-parsing-and-elaboration.md#94-case-与-unique--priority) |

---

## 阅读顺序（推荐）

```text
01 §1 切片
  → 01 §2 完整走读（top + child，按 A→I 步骤）
  → 按需 §3 数据结构、§4–§13 各阶段机制
  → 02 推断（latch / 寄存器标签）
```

---

## 案例 A — preprocess_demo.sv（步骤 A / §4）

> 预处理片段（非完整 module），演示条件编译。

**RTL**：

```systemverilog
`ifdef SYNTHESIS
    assign active_path = in_a & in_b;
`else
    initial $display("sim only");
    wire sim_only;
`endif
```

**预处理后**（`+define+SYNTHESIS`）：

```systemverilog
assign active_path = in_a & in_b;
```

---

## 案例 B — top + child（§2 主案例摘要）

参数 `N=2, W=8`。完整逐步 IR 见 [01 §2](../../01-rtl-parsing-and-elaboration.md#2-完整案例走读top--child一条龙)。

| 阶段 | 本案例要点 |
|------|------------|
| C Parse | logical library：`top(N,W)`, `child(W)`，generate **未展开** |
| E Elaboration | `g_slice[0].u_child`, `g_slice[1].u_child`；两路 `dout→sum` |
| F Lowering | child → `8×GTECH_FD1`；top → `data_out` 上 **latch** |
| I Check | `sum` **多驱动 ERROR**；latch **Warning** |

---

## 案例 C — unique_case.sv（§9.4）

`unique case` → 并行 MUX；去掉 `unique` 可能变 priority 级联 MUX。见 [§9.4](../../01-rtl-parsing-and-elaboration.md#94-case-与-unique--priority)。
