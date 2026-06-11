# 推断（Inference）walkthrough — 内部 DB 对照

与 [02 章 推断](../02-inference.md) 各节案例对应。

## 文件 ↔ 推断类型

| 文件 | 章节 | 预期 DB 标签 |
|------|------|--------------|
| `reg_en.sv` | §3 寄存器 | `REGISTER` + clock enable |
| `latch_infer.sv` | §4 Latch | `LATCH`（缺 else） |
| `sync_ram.sv` | §5 RAM | `RAM 1R1W` depth×width |
| `mult_16x16.sv` | §6 乘法器 | `MULT 16×16` |

---

## 案例 A — reg_en.sv

**RTL**：带使能 DFF。

**DB（示意）**：

```text
SEQGEN u_reg:
  resource_type = REGISTER
  clock_pin     = clk
  enable_expr   = en
  async_reset   = none
```

---

## 案例 B — latch_infer.sv

**RTL**：`always_comb if (hold) q = d;`（无 else）

**DB**：

```text
SEQGEN u_latch:
  resource_type = LATCH
  transparent_when = hold
```

**策略 `latch_inference=none`** → elaborate/check **报错**，不进入映射。

---

## 案例 C — sync_ram.sv

**DB**：

```text
Memory ram:
  depth=1024 width=32 ports=1R1W
  implementation_target = register_array | sram_macro
```

---

## 案例 D — mult_16x16.sv

**DB**：

```text
Instance u_mult:
  resource_type = MULT
  width_a=16 width_b=16
  implementation_target = DW02_mult | booth_array
```

→ 内部量索引 [07 章](../07-synthesis-reports.md)。
