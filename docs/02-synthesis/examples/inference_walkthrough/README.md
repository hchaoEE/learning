# 推断（Inference）walkthrough — 内部 DB 对照

与 [02 章 推断](../../02-inference.md) 各节案例对应。

## 文件 ↔ 推断类型

| 文件 | 章节 | 预期 DB 标签 |
|------|------|--------------|
| `reg_en.sv` | §3 寄存器 | `REGISTER` + clock enable |
| `latch_infer.sv` | §4 Latch | `LATCH`（缺 else） |
| `sync_ram.sv` | §5 RAM | `RAM 1R1W` depth×width |
| `mult_16x16.sv` | §6 乘法器 | `MULT 16×16` |
| `fsm_moore.sv` | §7 FSM | `FSM` state_count=3 + 编码策略 |

---

## 案例 A — reg_en.sv

**RTL**：带使能的累加寄存器 `if (en) cnt <= cnt + d;`

**前后对比（RTL/GTECH → 推断 DB）**：

| 前（lowering 后 GTECH） | 后（推断 DB） |
|--------------------------|----------------|
| `GTECH_SEQGEN`（.CK=clk, .EN=en, .D=add_out, .Q=cnt） | `resource_type = REGISTER` |
| `GTECH_ADD(cnt, d) → add_out` | D 锥保持组合，交 03/04 |
| EN 仅是 SEQGEN 引脚 | `enable_expr = en`，实现策略 = CE pin / D 前 MUX / ICG（§9 阈值） |

```text
SEQGEN u_reg:
  resource_type = REGISTER
  clock_pin     = clk
  enable_expr   = en
  async_reset   = none
```

---

## 案例 B — latch_infer.sv

**RTL**：`always_comb if (hold) data_hold = bus_in;`（无 else）

**前后对比**：

| 前（lowering 后） | 后（推断 DB） |
|--------------------|----------------|
| 反馈 MUX：hold 选 `bus_in`，否则保持 `data_hold` 旧值 | `resource_type = LATCH` |
| Lint: inferred latch | `transparent_when = hold` |

```text
SEQGEN u_latch:
  resource_type = LATCH
  transparent_when = hold
```

**策略 `latch_inference=none`** → elaborate/check **报错**，不进入映射。

---

## 案例 C — sync_ram.sv

**前后对比**：

| 前（lowering 后） | 后（推断 DB） |
|--------------------|----------------|
| `GTECH_RAM` 壳：1024×32，1 写口 + 1 同步读口 | `RAM 1R1W`，进入 §5.4 决策树 |
| 端口语义未定 | `implementation_target = sram_macro`（深宽超阈值）或 `register_array` |

```text
Memory ram:
  depth=1024 width=32 ports=1R1W
  implementation_target = register_array | sram_macro
```

---

## 案例 D — mult_16x16.sv

**前后对比**：

| 前（lowering 后） | 后（推断 DB） |
|--------------------|----------------|
| `GTECH_MULT` 16×16 抽象壳 | `resource_type = MULT`，进入 §6.3 决策树 |
| 内部未展开 | `implementation_target = DW02_mult`（IP）或 booth/wallace 门阵 |

```text
Instance u_mult:
  resource_type = MULT
  width_a=16 width_b=16
  implementation_target = DW02_mult | booth_array
```

## 案例 E — fsm_moore.sv

**RTL**：IDLE/RUN/DONE 三状态 Moore FSM（enum + case 闭环）。

**前后对比**：

| 前（lowering 后） | 后（推断 DB） |
|--------------------|----------------|
| 2-bit SEQGEN + case 解码 MUX 树（普通组合） | `resource_type = FSM`，STG 提取成功 |
| 编码 = RTL 字面值 00/01/10 | `encoding` 由策略决定（one-hot 时 FF 2→3） |

```text
FSM u_fsm:
  resource_type = FSM
  state_count   = 3
  state_vector  = state[1:0]
  encoding      = binary | onehot（策略）
```

**Re-encoding 提醒**：编码改变后 LEC 需 state mapping（02 §7.3、09 §6）。

---

→ 内部量索引 [07 章](../../07-synthesis-reports.md)。
