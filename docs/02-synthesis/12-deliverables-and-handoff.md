# 2.12 综合交付物与后端交接

`compile`、LEC、DFT 完成后，需向后端（PnR）与签核团队交付 **一致、可重现** 的文件包。本章列出 **交付清单、版本一致性、签核门控**。

---

## 1. 标准交付清单

| 文件 | 内容 | 消费者 |
|------|------|--------|
| **门级网表** `*.v` / `*.vg` | mapped Verilog | PnR、形式、仿真 |
| **SDC** `*.sdc` | 时序约束 | PnR、STA |
| **UPF** `*.upf` | 低功耗意图 | PnR、功耗签核 |
| **DDC/NDM** | 工具数据库 | 同工具链增量 |
| **SDF**（可选） | 延时标注 | 仿真 |
| **SPEF**（PnR 后） | 寄生 | STA 签核 |
| **LEC 报告** | 等价性 | 质量门控 |
| **Scan DEF/CTL**（若 DFT） | 链定义 | ATPG、PnR |
| **综合报告** | QoR 摘要 | 项目管理 |

### 输入/输出案例

**输入**：`release/synth_v1.2/` 目录

**输出**：PnR 脚本 `read_verilog ../synth_v1.2/chip.mapped.v` + `read_sdc ../synth_v1.2/chip.sdc`

| 缺件 | 后果 |
|------|------|
| 无 SDC | PnR **无目标** |
| 网表与 SDC 版本不一 | **虚假违例** |

---

## 2. 版本、Corner 与 MCMM 一致性

交付包须使 PnR/STA 与综合 **同一 topology、同一 corner/mode 集**。

### 2.1 必须对齐项

| 须一致 | 不一致后果 |
|--------|------------|
| `.lib` corner 集 | delay **系统性偏差** |
| max/min `operating_conditions` | setup/hold **签核错位** |
| **MCMM mode**（functional/test） | scan 路径 **未检** 或 **虚假违例** |
| RTL git tag | 无法追溯 **哪次 compile** |
| 工具 build id | DB 语义差异 |

### 2.2 MCMM 表（概念字段）

| 字段 | 含义 |
|------|------|
| **Mode** | functional / test → 不同 power state、clock |
| **Corner** | slow_max / fast_min → `.lib` + voltage + temperature |
| **Constraint view** | 该 mode 下 **生效的 SDC 子集** |
| **Delay annotation** | 该 corner 的 cell/net 查表 |

### 输入/输出案例 2.1

**综合 DB**：`slow_0p90_max` + `fast_0p90_min` 闭合。  
**PnR 后 STA**：须读 **同一对** `.lib` + **同一 mode**；若仅用 `typ` signoff → 与综合 **不可比**。

详见 [05 §6 MCMM](./05-constraints-sdc.md#6-mcmm多-corner-在-db-上的挂接)。

---

## 3. 签核门控（Quality Gates）

```text
□ Elaboration / check_design clean
□ 无未约束时钟（report_clock）
□ WNS/TNS 达标（或 signed-off waiver）
□ Max transition/cap/fanout clean
□ LEC pass（09）
□ DFT scan 完成（若本阶段插入）（11）
□ 推断报告无意外 latch（02/07）
□ 低功耗 UPF 与网表一致（08）
```

### 输入/输出案例

**Release checklist 一项失败**：

```text
LEC: 3 failing points → 禁止 handoff
```

---

## 4. 网表交付格式注意

```verilog
// 须声明
`timescale 1ns/1ps
module chip ( clk, rst_n, ... );
  // 禁止手工编辑：no /* synthesis */
endmodule
```

| 项 | 说明 |
|----|------|
| 去 `translate_off` 区域 | 仅交付可综合网表 |
| 单元名 | 来自目标 `.lib` |
| 勿删 `dont_touch` 宏 | 与综合一致 |

---

## 5. SDC 交付

- **与网表同名** 或 `chip.sdc` 明确 `current_design`  
- 含 **clock、IO、exception、case_analysis**（若用）  
- **勿含** 仅综合临时 `set_max_area 0` 等实验命令  

### 输入/输出案例

**输入**：综合输出 `chip.final.sdc`（已 `write_sdc`）

**输出**：PrimeTime `read_sdc` 后 `check_timing` 无 **no clock** 警告。

---

## 6. 与 PnR 的物理信息

综合阶段可选交付：

| 文件 | 用途 |
|------|------|
| **Floorplan DEF**（早期） | 宏位置、拥塞预算 |
| **Physical constraints** | region、placement blockages |
| **TLU+** 早期估计 | 物理综合 |

见 [03-pnr](../03-pnr/)。

---

## 7. 仿真用网表

| 类型 | 说明 |
|------|------|
| Zero-wire SDF | 功能仿真 |
| 综合 SDF | 粗略时序 |
| 签核 SDF | PnR+SPEF 后 |

### 输入/输出案例

**输入**：`zero_wire_load` 综合

**输出**：SDF **偏乐观** — 仅用于 **bring-up**，签核必须用 **PnR SDF**。

---

## 8. 综合「方方面面」索引

| 你想了解 | 章节 |
|----------|------|
| RTL 怎么读入 | 01 |
| 寄存器/RAM 怎么来 | 02 |
| AIG / 粗优化 | 03 |
| 映射 | 04 |
| 约束 | 05 |
| 修 setup/hold | 06 |
| 读内部量 / 阶段诊断 | 07 |
| 低功耗 | 08 |
| **LEC** | **09** |
| 分块综合 | 10 |
| **DFT/scan** | 11 |
| **交什么文件** | **12（本章）** |

---

## 9. 小结

交付 = **网表 + SDC +（UPF）+ LEC + 报告 + 版本说明**；**corner 一致** 是 PnR 成功前提。

---

## 下一节

- [03-pnr](../03-pnr/)
- [09 LEC](./09-logical-equivalence-checking.md)
- [00 总览](./00-synthesis-overview.md)
