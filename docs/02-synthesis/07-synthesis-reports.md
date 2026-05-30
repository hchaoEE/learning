# 2.7 综合报告解读

`compile` 结束后，用 **报告** 判断：时序是否闭合、面积是否超标、推断是否符合预期。本章讲 **字段含义** 与 **和内部阶段的对应**，不罗列全部 Tcl 开关。

---

## 1. 报告与章节映射

| 报告 | 回答的问题 | 相关章节 |
|------|------------|----------|
| `report_timing` | setup/hold 是否满足 | 05、06 |
| `report_constraint` | 还有哪些 DRC/时序违例 | 05、06 |
| `report_area` | 组合/时序/网表面积 | 03、04 |
| `report_power` | 早期功耗估算 | 08 |
| `report_reference` | 用了哪些单元 | 04 |
| `report_memory` / `report_latch` | 推断结果 | 02 |
| `report_hierarchy` | 层次与实例 | 01 |

---

## 2. `report_timing`

```tcl
report_timing -max_paths 10 -delay_type max
report_timing -delay_type min   # hold
```

| 字段 | 含义 |
|------|------|
| **Slack** | 要求时间 − 到达时间；负 = 违例 |
| **WNS** | 最差 slack（Worst Negative Slack） |
| **TNS** | 负 slack 路径之和 |
| **Path Group** | `clk`、`default`、`inputs` 等 |
| **Point** | pin 级路径点：FF CLK→Q、net、cell delay |

### 输入/输出案例

**输入**：`report_timing` 片段

```text
Startpoint: reg_a (rising edge-triggered flip-flop)
Endpoint:   reg_b (rising edge-triggered flip-flop)
Path Group: clk
slack (MET): 0.12
```

**解读**：该路径 **setup 满足**，余量 0.12ns。

| 输入 | 输出 |
|------|------|
| WNS = -0.2 | 至少一条路径需 [06](./06-timing-driven-optimization.md) 或改约束/RTL |

---

## 3. `report_constraint`

```tcl
report_constraint -all_violators
```

| 违例类型 | 常见原因 |
|----------|----------|
| `setup` | 路径太慢 |
| `hold` | 路径太快 |
| `max_transition` | 驱动不足 |
| `max_capacitance` | fanout 过大 |
| `max_fanout` | 需 buffer |

### 输入/输出案例

**输出**：

```text
max_transition  (12 violations)
setup            (WNS: -0.15, 45 failing endpoints)
```

→ 先修 **setup**（影响功能频率），再修 transition。

---

## 4. `report_area`

| 字段 | 含义 |
|------|------|
| Combinational | 组合逻辑面积 |
| Noncombinational | 寄存器、latch |
| Buffer / Inverter | 06 插入的缓冲占比 |
| Macro / RAM | 硬宏 |

### 输入/输出案例

**输入**：插 buffer 前后两次 `report_area`

**输出**：`Buffer/Inverter` 行增加 15% → 06 迭代代价可见。

---

## 5. `report_reference` 与 `report_cell`

```tcl
report_reference -hierarchy
```

用于确认 **04 映射** 结果：是否出现意外 `LH*`（latch）、过多 `ND2`、是否已用 **SRAM 宏**。

### 输入/输出案例

**输入**：期望无 latch

**输出**：`report_reference` 含 `TLAT*` → 回 [02](./02-inference.md) 查 RTL。

---

## 6. 推断类报告

```tcl
report_memory
report_latch -verbose
report_registers
```

与 [02 章](./02-inference.md) 案例对照；用于验证 **推断 ≠ 预期** 时先改 RTL 再 `compile`。

### 输入/输出案例

**`report_memory` 输出**：

```text
RAM: mem  1024x32  1R1W  -> register array
```

若期望 SRAM 宏 → 检查 `set_memory_implementation` / Memory Compiler 链接。

---

## 7. QoR 摘要（概念）

部分流程生成 **QoR summary**：WNS、TNS、面积、功耗、单元数 — 用于 **版本对比**（同 SDC、同 .lib）。

| 指标 | 回归对比时注意 |
|------|----------------|
| WNS | corner 一致 |
| Area | 是否含宏 |
| Cell count | 粗优化前后可能剧变 |

---

## 8. 从报告反推阶段

| 报告现象 | 可能阶段 |
|----------|----------|
| 节点数/面积骤变、无单元名 | 仍在 03 AIG |
| 出现库单元名、WNS 粗糙 | 04 映射完成 |
| buffer 激增、slack 改善 | 06 细优化 |
| LATCH 列表 | 02 推断 / RTL |

---

## 9. 小结

报告是 **05/06 的仪表盘**；**setup/hold** 看 timing，**结构** 看 reference/memory，**层次** 看 hierarchy。

---

## 10. 与 LEC 的关系

| 报告 | LEC |
|------|-----|
| QoR 满足 | **不保证** 等价 |
| 无 latch 意外 | 仍可能 **LEC fail**（复位/常数） |

**签核**：`report_timing` clean 后必须跑 [09 LEC](./09-logical-equivalence-checking.md)。

## 下一节

- [09 LEC](./09-logical-equivalence-checking.md)
- [12 交付](./12-deliverables-and-handoff.md)
- [08 低功耗](./08-low-power-synthesis.md)
- [05 SDC](./05-constraints-sdc.md)
