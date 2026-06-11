# Elaboration walkthrough — 阶段 IR 对照

与 [01 章](../../01-rtl-parsing-and-elaboration.md) **§3–§10** 各阶段一一对应。

| 文件 | 对应 01 章节 |
|------|--------------|
| `preprocess_demo.sv` | §3 预处理 |
| `child.sv` | §7 例化、§8 lowering |
| `top.sv` | §7 generate 展开、§8 latch 案例 |

---

## 案例 A — preprocess_demo.sv（§3）

> `preprocess_demo.sv` 是 **预处理片段**（非完整 module，不可单独综合），演示条件编译。

**RTL（含条件编译，即文件内容）**：

```systemverilog
`ifdef SYNTHESIS
    assign active_path = in_a & in_b;
`else
    initial $display("sim only");
    wire sim_only;
`endif
```

**预处理后字符流（定义了 `SYNTHESIS` 时）**：

```systemverilog
assign active_path = in_a & in_b;
```

| 阶段（前 → 后） | 内容 |
|------------------|------|
| 预处理前 | 源文件含 `` `ifdef ``，仿真/综合两个分支并存 |
| 预处理后 | 仅保留 `SYNTHESIS` 分支；`initial`/`$display` **不进入** 后续词法分析 |
| 同理：`` `define `` 宏 | 在此阶段文本展开，**logical library 存展开后 AST** |

---

## 案例 B — top.sv + child.sv（§7 Elaboration）

**参数**：`N=2, W=8`

### B.1 Logical library（analyze 后，未 elaborate）

```text
Module templates: top(N,W), child(W)
  top: generate 循环 **未展开**
```

### B.2 Design DB（elaborate 后）

**Instance 树**：

```text
top
  g_slice[0].u_child   (child, W=8)
  g_slice[1].u_child   (child, W=8)
```

**generate 展开动作**：`for (i=0..N-1)` → **N 份独立 instance**，路径含 `g_slice[i]`。

### B.3 连接与多驱动（§7、§12 check）

`top.sv` 中两 child 均驱动 `sum` → **check_design：multi-driven net `sum`**（需 RTL 修复后才进推断）。

---

## 案例 C — child.sv lowering（§8）

**RTL**：

```systemverilog
always_ff @(posedge clk) dout <= din;
```

**Lowering 后 GTECH（片段）**：

```text
SEQGEN u_reg:
  .CK(clk)  .D(din)  .Q(dout)
  op = DFF
```

| 阶段 | IR |
|------|-----|
| RTL | `always_ff` 行为 |
| GTECH | **SEQGEN** 壳（推断前） |

---

## 案例 D — top always_comb 缺 else（§8 → 02 §4）

**RTL**：`if (en) data_out = sum;` 无 else

**Lowering / 推断**：

```text
GTECH_LAT 或 LATCH 标签 on data_out
```

→ 见 [inference_walkthrough/latch 路径](../inference_walkthrough/README.md)（若错误留在 top）。

---

## 阅读顺序

```text
01 §1 切片 → 本目录 A(preprocess) → B(elab 树) → C(SEQGEN) → 02 推断
```
