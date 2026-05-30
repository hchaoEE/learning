# 2.8 低功耗综合

ASIC 低功耗靠 **架构 + RTL + 综合 + 物理** 协同。本章讲综合侧：**UPF、时钟门控、多电压意图** 如何进入工具，与 [02 推断 ICG](./02-inference.md)、[06 细粒度](./06-timing-driven-optimization.md) 衔接。

---

## 1. 功耗组成（综合视角）

| 类型 | 综合能影响的 |
|------|----------------|
| **动态** | 切换活动 × 电容 × V²；**ICG**、降频、减冗余 |
| **漏电** | 单元 VT、关断域；**MV、power switch** |

---

## 2. UPF / CPF（Power Intent）

```text
RTL + UPF (.upf)
      │
      ▼
综合读 power domain、level shifter、isolation、retention
      │
      ▼
映射时插入 **LS/ISO/PSW** 单元（与 .lib 一致）
```

| UPF 概念 | 作用 |
|----------|------|
| `create_power_domain` | 电压域划分 |
| `create_supply_net` | 供电网络 |
| `set_isolation` | 关断时隔离输出 |
| `set_level_shifter` | 跨电压传数据 |
| `set_retention` | 低功耗保持寄存器状态 |

### 输入/输出案例

**输入**：CPU 核 `PD_CPU` 可关断；外围 `PD_ALWAYS_ON`

**输出**：综合网表含 **isolation cell** 于域边界；报告 `report_power_domain`。

| 输入 | 输出 |
|------|------|
| RTL 无 UPF、但要 MV | 工具不知域边界 → **不可自动插 LS** |

---

## 3. 时钟门控（ICG）

| 方式 | 章节 |
|------|------|
| RTL 手写门控时钟 | 不推荐（毛刺） |
| **综合推断 ICG** | [02 §8](./02-inference.md) |
| `compile_clock_gating` | 本章 |

推断条件（概念）：寄存器 **共享 enable**、enable 与 clock **同步**、满足最小 bit 宽度策略。

### 输入/输出案例

**输入**：32 位总线共用一个 `en`，`compile_clock_gating -global` 开启

**输出**：网表 `CKLNQD` 在 clock 树分支；**动态功耗** 报告 clock network 占比下降。

---

## 4. 多电压与 MCMM

```tcl
set_operating_conditions -max slow_0p9 -min fast_0p9
# 多 corner：0p9V / 1.0V 各一套 .lib
```

| 项 | 说明 |
|----|------|
| **MCMM** | 多模式多 corner；综合在各 corner 权衡 |
| **Level shifter** | UPF 指定策略后映射为 `LS_*` 单元 |

### 输入/输出案例

**输入**：0.9V 核驱动 1.0V IO，UPF 定义 `set_level_shifter -domain PD_IO`

**输出**：边界出现 `LEVEL_SHIFTER` 单元；STA 分 corner 报 slack。

---

## 5.  Operand 隔离与门控（简述）

| 技术 | 说明 |
|------|------|
| **Operand isolation** | 使能无效时，算术输入置常，减翻转 |
| **Power gating** | 头开关关断漏电；需 UPF + 特殊单元 |

多在 **08 + 物理** 流程完整实现；综合阶段为 **插入与约束**。

---

## 6. `report_power`（早期）

| 字段 | 可信度 |
|------|--------|
| Switching / Internal / Leakage | 基于 **SAIF/默认翻转率**；签核用 PrimePower 等 |

### 输入/输出案例

**输入**：`report_power -hierarchy`

**输出**：`u_cpu` dynamic 占 70%；指导加 ICG 或降频。

---

## 7. 与全流程关系

```text
08 UPF/ICG ──► 04 映射（特殊单元）──► 06 时序（LS/ISO 延时）──► PnR（电源网）
```

---

## 8. 小结

低功耗 = **意图（UPF）+ ICG + MV 单元**；综合 **不替代** 架构选型和物理电源设计。

---

## 下一节

- [07 报告](./07-synthesis-reports.md)
- [02 推断 ICG](./02-inference.md)
- [03-pnr](../03-pnr/) 电源网络与物理
