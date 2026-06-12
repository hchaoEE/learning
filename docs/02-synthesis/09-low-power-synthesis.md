# 2.9 低功耗综合 — Design DB 上的功耗语义

> **本章回答**：UPF/ICG 如何在 DB 里变成可综合的功耗语义。
> **读完应能**：① 分项读动态/漏电 ② 说清 retention/isolation 插入点 ③ 区分 02 ICG 推断与 09 UPF
> **先修**：[02 §9](./02-inference.md)、[05](./05-constraints-sdc.md) · **难度**：★★★☆☆ · **walkthrough**：[power_walkthrough](./examples/power_walkthrough/)

ASIC 低功耗靠 **架构 + RTL + 综合 + 物理** 协同。本章讲 **power intent 与 ICG 如何在 Design DB 里变成标注与额外逻辑**，与 [02 §9 ICG 推断](./02-inference.md#9-时钟门控icg推断--asic-低功耗)、[06 细粒度](./06-timing-driven-optimization.md) 衔接。

> 配套案例：[examples/power_walkthrough/](./examples/power_walkthrough/)

---

## 1. 功耗组成（综合内部视角）
> **一句话**：功耗组成（综合内部视角）——本章核心机制点。

| 类型 | DB 上可建模的量 | 综合 pass 能动的 |
|------|-----------------|------------------|
| **动态** | toggle rate × net cap × V² | **ICG** 降 clock toggle；删冗余逻辑（03） |
| **漏电** | 单元 I_leak(V,T) | **VT swap**（06）；关断域（UPF→PSW） |

综合阶段 **无真实 SAIF** 时常用 **默认 toggle**；数值仅 **相对比较**，非签核功耗。

### 输入/输出案例 1.1 — 动态 vs 漏电分项

**输入**：ICG 改造前后（默认活动度，同 corner）。

| 分项 | ICG 前（相对） | ICG 后 | 主要机制 |
|------|----------------|--------|----------|
| 动态-clock | 1.00 | 0.45 | **ICG**（§3） |
| 动态-data | 1.00 | 0.98 | 数据锥几乎不变 |
| Leakage | 1.00 | 1.01 | ICG 单元自身漏电 |

**输出**：读报告须 **分项** — 总功耗降不代表 data 动态降（见 [08 §6](./08-synthesis-reports.md#6-功耗报告聚合与可信度)）。

---

## 2. UPF / CPF：Power Intent 编译层
> **一句话**：UPF / CPF：Power Intent 编译层——本章核心机制点。

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

### 输入/输出案例 2.1 — retention 关断序列

**输入**（[examples/power_walkthrough/retention_domain.sv](./examples/power_walkthrough/retention_domain.sv) + UPF `set_retention` on `PD_CPU` FF 组）：

| 控制阶段 | 信号顺序 | DB 动作 |
|----------|----------|---------|
| 关断前 | `ret_save=1` | retention cell **采样** FF 状态到 shadow |
| 关断 | `psw_off=1` | 域内 supply 断开；FF 漏电模型切换 |
| 上电 | `psw_on=1` | supply 恢复 |
| 恢复后 | `ret_restore=1` | shadow **写回** FF |

**输出（映射后）**：普通 `DFFRX1` → `RETENTION_DFF`（多 save/restore pin）；LEC 须 UPF 感知比对（[10 章](./10-logical-equivalence-checking.md)）。

### 2.2 Isolation 插入 pass（内部）

`set_isolation` 不只是标注；插入是一个独立 pass：

```text
1. 枚举 cut point：可关断域 → 常开域的每条 crossing net（fanout 在域外）
2. 选 ISO 单元：依 clamp 策略（0 → AND 型；1 → OR 型；keep → latch 型）
3. 决定位置：-location self（源域侧，须用常开 supply 的 ISO 单元）/ parent（宿域侧）
4. 重连：crossing net 断开 → ISO 插入 → iso_enable net 接入控制信号
5. DB 标注：实例打 isolation_cell 标签（06 不得移除/复制跨过它）
```

| Clamp 策略 | 单元形态 | 适用 |
|------------|----------|------|
| `clamp 0` | AND(data, !iso_en) | 下游默认非激活 = 0 |
| `clamp 1` | OR(data, iso_en) | 下游 active-low 控制信号 |
| `latch/hold` | 保持型 ISO | 下游需保持最后值 |

**Enable 的时序语义**：关断序列有 **顺序 check** — `iso_en` 必须先于电源开关动作生效、后于其释放：

```text
关断：iso_en 置位 ──► ret_save ──► psw_off
上电：psw_on ──► ret_restore ──► iso_en 释放
```

综合期此序列由 **电源控制 FSM**（常开域内的普通逻辑）实现；引擎检查 `iso_en` 锥 **必须由常开域驱动**（被关断域驱动自身 ISO = UPF 违例）。

### 输入/输出案例 2.2

**意图**：`PD_CPU`（可关断）→ `PD_AON` 的 8 位总线，`clamp 0`，location parent。

| | 插入前 | 插入后 |
|---|--------|--------|
| crossing net | 8 条直连 | 8 × AND 型 ISO（AON 侧） |
| iso_en | — | 1 条 enable net，fanout 8 |
| timing graph | 8 条 net arc | +8 个 ISO cell arc；`iso_en` 成新时序锥（06 须收敛） |
| LEC | 直接对应 | ISO 是 **I 侧新增逻辑**，须 UPF 感知比对（[10 章](./10-logical-equivalence-checking.md)） |

### 2.3 Level shifter 方向与时序弧

LS 解决 **电压域间信号摆幅不匹配**（低压驱动高压门 → 漏电/误翻转）：

| UPF 规则 | 插入位置 | 单元类型 |
|----------|----------|----------|
| `-applies_to inputs` | 信号 **进入** 本域处（宿域侧） | 依电压差选升/降压 |
| `-applies_to outputs` | 信号 **离开** 本域处（源域侧） | 同上 |
| `both` | 双向 crossing 都插 | — |

**内部决策**：对每条 `crossing_domain` net 比较两域 supply 电压 → **升压**（L→H，需双电源 LS 单元，两个 supply pin）/ **降压**（H→L，简单 buffer 型）/ 同压（仅域不同：可与 ISO 合并为 **enable level shifter** 组合单元）。

**时序**：LS arc（NLDM 同机制，[07 §2](./07-internal-sta-and-qor.md#2-timing-graph-数据结构)）显著慢于普通 buffer — 跨压域路径在 06 常成关键路径；MCMM 下 LS 两端电压 **各自变 corner**，arc 表按 corner 对组合查（§4）。

### 输入/输出案例 2.1（升压跨域）

**意图**：`PD_CPU` @ 0.9V，`PD_IO` @ 1.0V，CPU→IO 数据 net 跨域。

**DB 标注**：该 net `crossing_domain = {PD_CPU, PD_IO}`，策略 `level_shifter = both`；电压比较 0.9 < 1.0 → **升压 LS**（双 supply）。

**04 映射后网表**：边界插入 `LEVEL_SHIFTER` 实例；timing graph 增加 **LS arc delay**（典型 ≈ 2–3 倍 buffer delay）。

---

## 3. 时钟门控（ICG）— 与 02 推断的衔接
> **一句话**：时钟门控（ICG）— 与 02 推断的衔接——本章核心机制点。

| 方式 | 内部 |
|------|------|
| RTL 手写 `clk & en` | 常 **违综合规则** 或推断为 **gated clock 结构**（毛刺风险） |
| **综合 ICG 推断** | 在 **GTECH_SEQGEN 簇** 前插 **ICG 壳**，再映射到 `CKLN*` |

ICG 的 **推断算法骨架与识别条件**（bank 分组、min_bits、enable 同步性）是 02 的内容，见 [02 §9](./02-inference.md#9-时钟门控icg推断--asic-低功耗)。本章只看 **09 增加的三层语义**：

| 层 | 09 视角 |
|----|---------|
| **策略覆盖** | 功耗策略 / UPF 流程可对指定 instance **强制 gating 或禁止 gating**（`force` / `no_gating` 类属性），**覆盖** 02 的启发式判定 |
| **映射 / 时序** | ICG 壳 → `.lib` 时钟门控单元（`CKLN*` 等），属 clock network cell；`en → clk_out` 的 **gating check**（enable 的 setup/hold）作为时序弧进入 06 的 timing graph |
| **功耗模型** | clock net toggle 在 DB 活动度模型中 **按 en 概率缩放** → 进入 §6 早期估计 |

### 输入/输出案例 3.1 — 推断之后，09 看到什么

**输入**：02 已对 32 位 bank 插好 ICG 壳（RTL 与推断过程见 [02 §9 案例](./02-inference.md#9-时钟门控icg推断--asic-低功耗)、`power_walkthrough/icg_bank.sv`）。

**输出（09/04/06 侧 DB 变化）**：

| 维度 | 变化 |
|------|------|
| 映射 | 壳 → `CKLNQD1` 实例（clock network，默认 dont_touch） |
| timing graph | 新增 `en → CKLNQD1` gating check 弧 |
| 活动度 | `clk_g` toggle = clk toggle × P(en) |

---

## 4. 多电压与 MCMM（内部）
> **一句话**：多电压与 MCMM（内部）——本章核心机制点。

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
> **一句话**：Operand isolation 与 power gating（内部）——本章核心机制点。

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
> **一句话**：早期功耗估计（内部量）——本章核心机制点。

| 内部量 | 来源 | 可信度 |
|--------|------|--------|
| Net toggle × cap | 默认或 SAIF 注解 | 综合：**趋势** |
| ICG 节省 | clock network 活动度 × cap | 相对 before/after |
| Leakage | 单元 I_leak 求和 | 依赖 VT 分布 |

### 6.1 活动度传播引擎

无 SAIF 时，引擎从 PI 假设出发 **沿网表前向传播** 每个 net 的 (toggle rate, static probability)：

```text
PI：默认假设（如 toggle=0.1/cycle, P(1)=0.5）；clock net：toggle=2/cycle（确定）
    │ 按拓扑序过每个门：
    │   AND：P(out=1) = P(a)·P(b)（独立假设）；toggle 由输入联合分布近似
    │   MUX：按选择端概率加权
    │   FF：输出 toggle ≤ clock 域速率，由 D 的 P(变化) 缩放
    ▼
每 net (toggle, P) → P_dyn = Σ toggle × C × V²
```

**截断规则**（结构性信息修正传播图）：

| 结构 | 传播修正 |
|------|----------|
| 常量 net（tie） | toggle = 0，下游锥整体衰减 |
| **ICG 之后的 clock** | toggle × P(en) — §3 案例 3.1 的来源 |
| **operand iso 之后的 datapath** | en=0 区间 toggle ≈ 0 → 等效 × P(en) |
| 关断域（PSW off mode） | 域内全部 net toggle = 0、leakage 换关断模型 |

**误差来源**：独立性假设（重汇聚扇出的相关性被忽略）、glitch 不建模 — 所以只用于 **同一假设下的相对比较**（[08 §6](./08-synthesis-reports.md#6-功耗报告聚合与可信度) 的可信度表同源）。

### 输入/输出案例 6.1 — operand iso 的传播效果

**输入**：§5.1 的 ALU（`alu_en` P(1)=0.2），iso 前加法器内部 net 平均 toggle = 0.30。

| net 区段 | iso 前 toggle | iso 后 |
|----------|----------------|--------|
| op_a/op_b（iso 输出） | 0.30 | 0.30 × 0.2 = **0.06** |
| 加法器内部锥 | 0.30 | ≈ 0.06（随输入衰减传播） |
| ALU 输出 | 0.30 | 0.06 |

**输出（估计）**：ALU 动态功耗分项 ↓ ≈ 80% — 与 P(en)=0.2 一致；clock 分项不变（区别于 ICG）。

**不替代** PrimePower 等签核；用于 **ICG/VT 决策反馈**。

---

## 7. 与全流程关系
> **一句话**：与全流程关系——本章核心机制点。

```text
09 intent/ICG 标注 ──► 02 推断 ICG ──► 04 映射特殊单元 ──► 06 时序（LS/ISO/ICG arc）
                                                              │
                                                              ▼
                                                         PnR 电源网
```

---


## 知识点清单（自检）

- [ ] 动态 vs 漏电分项
- [ ] ICG 降 clock toggle
- [ ] retention/isolation 语义
- [ ] UPF 编译到 DB 标注
- [ ] 综合期功耗仅相对比较

---

## 8. 小结
> **一句话**：小结——本章核心机制点。

低功耗 = **DB 上的 domain 标注 + ICG 壳 + 特殊单元映射**；综合 **不替代** 架构与物理电源设计。

---

## 下一节

- [02 §9 ICG](./02-inference.md#9-时钟门控icg推断--asic-低功耗)
- [05 MCMM](./05-constraints-sdc.md#6-mcmm多-corner-在-db-上的挂接)
- [08 内部量](./08-synthesis-reports.md)
- [examples/power_walkthrough/](./examples/power_walkthrough/)
