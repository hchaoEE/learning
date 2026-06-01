# 2.8 低功耗综合 — Design DB 上的功耗语义

ASIC 低功耗靠 **架构 + RTL + 综合 + 物理** 协同。本章讲 **power intent 与 ICG 如何在 Design DB 里变成标注与额外逻辑**，与 [02 §8 ICG 推断](./02-inference.md#8-时钟门控icg推断--asic-低功耗)、[06 细粒度](./06-timing-driven-optimization.md) 衔接。

> 配套案例：[examples/power_walkthrough/](./examples/power_walkthrough/)

---

## 1. 功耗组成（综合内部视角）

| 类型 | DB 上可建模的量 | 综合 pass 能动的 |
|------|-----------------|------------------|
| **动态** | toggle rate × net cap × V² | **ICG** 降 clock toggle；删冗余逻辑（03） |
| **漏电** | 单元 I_leak(V,T) | **VT swap**（06）；关断域（UPF→PSW） |

综合阶段 **无真实 SAIF** 时常用 **默认 toggle**；数值仅 **相对比较**，非签核功耗。

---

## 2. UPF / CPF：Power Intent 编译层

```text
RTL + UPF 文本
      │  parse power domain / supply / strategy
      ▼
Power Intent Layer（附在 Design DB）
      │  instance.power_domain
      │  net.crossing_domain
      │  isolation / level_shifter / retention 策略
      ▼
04 映射：在 cut point 插入 LS / ISO / retention cell
06 时序：LS/ISO arc 进入 timing graph
```

| UPF 语义 | DB 内部 |
|----------|---------|
| `create_power_domain` | instance 集 + **primary supply** 引用 |
| `set_isolation` | 域边界 net 上 **isolation enable** 策略 |
| `set_level_shifter` | 跨电压 net 上 **LS 规则**（升/降、位置） |
| `set_retention` | 指定 FF 组 → **retention register** 替换标签 |
| `set_power_switch` | 域与 **header/footer switch** 网络关联 |

### 2.1 Retention 寄存器（内部）

**动作**：关断域前 **save** FF 状态；上电 **restore**。

```text
PD_CPU 关断： FF → retention bank
PD_CPU 上电： retention → FF
```

**DB**：`retention` 属性 on SEQGEN → 映射 **retention DFF** + save/restore 控制。

**无 UPF**：综合器 **不知域边界** → 无法自动插 LS/ISO，仅能靠 **同电压 .lib** 做普通映射。

### 输入/输出案例 2.1

**意图**：`PD_CPU` @ 0.9V，`PD_IO` @ 1.0V，CPU→IO 数据 net 跨域。

**DB 标注**：该 net `crossing_domain = {PD_CPU, PD_IO}`，策略 `level_shifter = both`。

**04 映射后网表**：边界插入 `LEVEL_SHIFTER` 实例；timing graph 增加 **LS arc delay**。

---

## 3. 时钟门控（ICG）— 与 02 推断的衔接

| 方式 | 内部 |
|------|------|
| RTL 手写 `clk & en` | 常 **违综合规则** 或推断为 **gated clock 结构**（毛刺风险） |
| **综合 ICG 推断** | 在 **GTECH_SEQGEN 簇** 前插 **ICG 壳**，再映射到 `CKLN*` |

### 3.1 ICG 推断算法骨架（内部）

```text
1. 按 clock 分组所有 SEQGEN（寄存器 bank）
2. 提取共享 enable 表达式 E（同步于 clock 的 gating 条件）
3. 若 |bank| ≥ min_bits 且 E 满足无 glitch 拓扑
4. 创建 ICG 节点：clk_in, en → clk_out
5. 将该 bank 的 clock pin 改接 clk_out
6. 映射阶段 bind 到 .lib ICG cell
```

| 条件 | 内部判定 |
|------|----------|
| enable 与 clock **同步** | 仅允许在 clock 无效沿切换 |
| 最小位宽 | 避免 1-bit ICG 面积得不偿失 |
| dont_touch / clock_network | 跳过已标记 network |

详见 [02 §8](./02-inference.md#8-时钟门控icg推断--asic-低功耗)。

### 输入/输出案例 3.1

**RTL**：32 位 `always_ff @(posedge clk) if (en) q <= d;`

**推断后 GTECH（片段）**：

```text
clk ──► [ICG shell: en] ──► clk_g ──► SEQGEN[31:0].CK
d   ───────────────────────────────► SEQGEN[31:0].D
```

**映射后**：`CKLNQD1` + 32×`DFF`；**clock net toggle** 在 DB 活动度模型中 **按 en 概率缩放**。

---

## 4. 多电压与 MCMM（内部）

多电压在 DB 上 = **多套 .lib delay** + **supply voltage 标签**：

```text
Corner slow_0p9：.lib @ 0.9V → cell/net delay 表 A
Corner slow_1p0：.lib @ 1.0V → delay 表 B
Mode functional：读 intent + 表 A/B
Mode test：可能 **不同 power state**（域上电）
```

**06 修时序**时 LS/ISO 弧在 **各 corner** 各算 slack；关断域内 FF 可能 **无有效 clock** → 对应路径 **no_check** 或 **isolation 后静态**。

### 输入/输出案例 4.1

**状态**：`PD_CPU` 关断，输出经 ISO 到 `PD_ALWAYS_ON`。

**内部**：ISO cell 输出 **固定策略**（clamp 0/1/keep）；跨域路径 timing **分 mode** 定义。

---

## 5. Operand isolation 与 power gating（内部）

### 5.1 Operand isolation

**动作**：在 **算术/总线 cone 输入** 前插 **隔离 MUX/tie**，当 block enable=0 时输入 **固定常数**，减少 **内部翻转**。

```text
en=0 时：  a_iso = 0（或 keep，依策略）
en=1 时：  a_iso = a
         ↓
      ADDER / MUX 树
```

| DB 标注 | 含义 |
|---------|------|
| `isolation_cell` on net | operand iso 已插入 |
| `clamp_value` | 无效时 tie 0/1/keep |

**与 ICG 区别**：ICG 降 **clock toggle**；operand iso 降 **datapath toggle**。

### 5.2 Power gating（PSW）

**动作**：UPF 指定 **可关断域** → 映射 **header/footer switch** → 关断时 **supply 断开**，漏电模型切换。

### 输入/输出案例 5.1

**意图**：ALU 仅在 `alu_en` 时活动 → `alu_en=0` 时 `op_a/op_b` tie 0，加法器内部 toggle **≈0**。

### 输入/输出案例 5.2

**意图**：`PD_CPU` 可关断 → 边界 LS/ISO + 域内 PSW；关断 mode 下域内 **timing no_check**。

---

## 6. 早期功耗估计（内部量）

| 内部量 | 来源 | 可信度 |
|--------|------|--------|
| Net toggle × cap | 默认或 SAIF 注解 | 综合：**趋势** |
| ICG 节省 | clock network 活动度 × cap | 相对 before/after |
| Leakage | 单元 I_leak 求和 | 依赖 VT 分布 |

**不替代** PrimePower 等签核；用于 **ICG/VT 决策反馈**。

---

## 7. 与全流程关系

```text
08 intent/ICG 标注 ──► 02 推断 ICG ──► 04 映射特殊单元 ──► 06 时序（LS/ISO/ICG arc）
                                                              │
                                                              ▼
                                                         PnR 电源网
```

---

## 8. 小结

低功耗 = **DB 上的 domain 标注 + ICG 壳 + 特殊单元映射**；综合 **不替代** 架构与物理电源设计。

---

## 下一节

- [02 §8 ICG](./02-inference.md#8-时钟门控icg推断--asic-低功耗)
- [05 MCMM](./05-constraints-sdc.md#6-mcmm多-corner-在-db-上的挂接)
- [07 内部量](./07-synthesis-reports.md)
- [examples/power_walkthrough/](./examples/power_walkthrough/)
