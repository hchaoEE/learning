# 2.11 DFT 与可测性（扫描链概述）

生产测试需要 **将内部节点拉到芯片管脚**。**DFT（Design For Test）** 在综合阶段或紧接综合插入 **扫描链（scan）**、压缩逻辑等，并与 **时序、LEC、功耗** 联动。

> 深度 DFT（ATPG、BIST）另有专书；本章覆盖 **综合工程师必须知道的接口**。

---

## 1. 在流程中的位置

```text
功能 RTL compile（02–06）
        │
        ▼
【DFT 插入】scan cell 替换 / 串链 / compression
        │
        ▼
时序再收敛（06）──► LEC（09）──► 交付（12）
```

| 工具例 | 阶段 |
|--------|------|
| `dft_compiler` / `insert_dft` | Synopsys |
| Genus + Modus | Cadence |

---

## 2. 扫描基本概念

| 术语 | 说明 |
|------|------|
| **Scan chain** | 将 FF 串成移位寄存器，从 SDI 灌入、SDO 读出 |
| **Scan enable (SE)** | 测试模式选择 |
| **Capture** | 组合逻辑结果打入 FF |
| **Shift** | 链上移位 |

正常模式：FF 功能工作；测试模式：链化。

### 输入/输出案例

**输入**：10 万个功能 FF

**输出**：映射为 `SDFF*`（scan DFF），**20 条** scan chain，每条 ~5000 级。

---

## 3. 对综合的影响

| 影响 | 说明 |
|------|------|
| **单元换型** | DFF → SDFF，面积略增 |
| **时序** | scan 路径、hold 在 shift 模式 |
| **复位** | 测试模式常需 **异步复位可控** |
| **时钟** | OCC（On-Chip Clock）控制测试时钟 |

### 输入/输出案例

**输入**：功能 WNS = +0.05ns

**输出**：插入 scan 后 WNS = -0.02ns → 需 **06 章** 再优化或 **放宽** 测试时钟。

---

## 4. 与 LEC 的关系

插入 scan 后网表 **结构变化** 但仍应与 **带 DFT 的 RTL** 或 **pre-DFT RTL + 形式约束** 等价。

| 模式 | 比对 |
|------|------|
| Pre-scan LEC | RTL ↔ 功能网表（交付前常见） |
| Post-scan LEC | DFT RTL ↔ scan 网表 |

### 输入/输出案例

**失败**：RTL 无 scan pin，网表有 `SI/SO` → 需 **读入 DFT wrapper RTL** 或 **blackbox scan logic**。

---

## 5. 压缩与 ATPG（简述）

| 技术 | 作用 |
|------|------|
| **Scan compression** | 减少 SDI/SDO 管脚 |
| **LBIST/MBIST** | 存储器自测，常独立 |

综合输出 **SPF/WGL** 给 ATPG 工具（Modus/Tessent）。

---

## 6. 约束

```tcl
# 测试时钟（概念）
create_clock -name test_clk -period 100 [get_ports test_clk]
set_dft_configuration -scan_chain_count 20
```

SDC 常分 **functional / test** 模式（MMMC scenario）。

### 输入/输出案例

**输入**：仅 functional SDC 签核

**输出**：ATPG 报 **untested** 过高 → 补 **test mode** 约束与 scan 定义。

---

## 7. 小结

DFT = **scan 插入 + 再优化 + 再 LEC**；与功能综合 **串行** 而非可选装饰。

---

## 下一节

- [09 LEC](./09-logical-equivalence-checking.md)
- [12 交付](./12-deliverables-and-handoff.md)
- [08 低功耗](./08-low-power-synthesis.md)
