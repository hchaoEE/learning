# 2.11 DFT 与可测性 — 网表结构变换

生产测试需 **控制/观测内部 FF**。**DFT** 在功能综合后把 mapped 网表 **改写为可扫描结构**，再进入 [06](./06-timing-driven-optimization.md) 再收敛与 [09 LEC](./09-logical-equivalence-checking.md)。

> 本章讲 **scan 如何改 DB 拓扑**；ATPG 工具链从简。

---

## 1. 在流程中的位置

```text
功能 compile（01–06）→ mapped netlist + timing clean
        │
        ▼
【DFT pass】DFF → SDFF，SI/SO/SE 连接，链序确定
        │
        ▼
06 再优化（scan 路径 timing）→ LEC（09）→ 交付（12）
```

**顺序不可乱**：scan 改 FF 结构 → **delay 变** → 必须 **再 STA/再优化**。

---

## 2. Scan 的 IR 变换（内部）

### 2.1 功能 FF → Scan cell

| 功能单元 | Scan 单元（概念） | 新增 pin |
|----------|-------------------|----------|
| `DFFX1` (D, CK, Q) | `SDFFX1` | **SI**（scan in）、**SE**（scan enable） |

**内部连接**：

```text
Functional mode (SE=0):  D → FF → Q  （与原来相同）
Scan shift mode (SE=1):  SI → FF → Q  （串链移位）
Capture:                 D → FF → Q  （组合结果打入）
```

### 2.2 Scan chain 拓扑

```text
SDI ──► FF0 ──► FF1 ──► … ──► FFk ──► SDO
         Q→SI   Q→SI         Q→SO
```

**链序算法**（启发式）：

- 按 **clock domain** 分链  
- 平衡 **链长**（ATPG 时间）  
- 避开 **dont_scan** / **retention** / **macro 内 FF**

### 输入/输出案例 2.1

**输入 DB**：100k 功能 DFF  
**DFT pass 后**：100k SDFF，**20 链** × ~5k 级；netlist 增 **SI/SO/SE** port 与 **scan 控制** net。

---

## 3. 对 timing graph 的影响

| 影响 | 内部 |
|------|------|
| 单元换型 | cell arc **delay 略变** |
| SE/SI net | 新 **data/check** 路径（test mode） |
| Hold | **shift 模式** 下 fast corner 易违例 |
| Clock | 测试可能用 **OCC** 切 test clock |

**MCMM**：functional mode 与 **test mode** 为 **不同 mode** → 各自 timing graph 子集（见 [05 §6](./05-constraints-sdc.md#6-mcmm多-corner-在-db-上的挂接)）。

### 输入/输出案例 3.1

**Functional WNS = +0.05 ns** → DFT 后 **−0.02 ns** → 06 在 **functional corner** 再 sizing。

---

## 4. 与 LEC 的内部关系

| 比对模式 | R | I |
|----------|---|---|
| Pre-scan | RTL | 功能 mapped 网表 |
| Post-scan | **DFT RTL**（含 scan 端口）或 **scan 等价约束** | scan 网表 |

**失败机制**：R 无 `SI`，I 有 → compare point **维度不匹配** → 需在 R 加 **scan wrapper 模型** 或 **blackbox scan logic**。

---

## 5. Scan 链序算法与压缩（内部）

### 5.1 链序（启发式）

```text
1. 按 clock domain 分组 FF
2. 排除 dont_scan / macro 内 FF
3. 每组内平衡链长（≈5000 FF/链 示意）
4. 连接 SI←Q→SI…→SO
```

### 输入/输出案例 5.1

**100k FF，20 链**：每链 ~5k 级；**同一 clock 域** 内串链，避免跨域 shift 时序问题。

### 5.2 Scan compression

| 结构 | DB 效果 |
|------|---------|
| **decompressor** | SDI→多条虚拟链 |
| **compactor** | 多条链→SDO |
| 逻辑锥 | 增大 → **06 再优化** + **LEC 比对点增加** |

---

## 6. 约束语义（test mode）

Test mode 在 DB 上 **额外 clock / false_path / case**：

| 语义 | 作用 |
|------|------|
| test clock | shift 时序 check |
| functional false_path on scan | 避免虚假 cross-mode 违例 |
| `scan_enable` case | SE=0/1 分模式 STA |

仅 functional SDC 签核 → **test 路径未检** → ATPG **untested** 高。

---

## 7. 与 retiming、层次

| 交互 | 内部 |
|------|------|
| **Retiming 后 DFT** | FF 顺序变 → **链重排** |
| **层次块** | 块内 scan 先完成 → 顶层 **串链** |
| **dont_touch 宏** | 宏内 FF **不可 scan** → 覆盖率洞 |

见 [06 §8.5](./06-timing-driven-optimization.md#85-与-dft层次化)、[10 章](./10-hierarchical-block-synthesis.md)。

---

## 8. 小结

DFT = **mapped IR 的结构 rewrite**（SDFF + 链）+ **再 06** + **再 LEC**；与功能综合 **串行**。

---

## 下一节

- [09 LEC](./09-logical-equivalence-checking.md)
- [06 细粒度](./06-timing-driven-optimization.md)
- [12 交付](./12-deliverables-and-handoff.md)
