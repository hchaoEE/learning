# 2.6 细粒度优化：时序驱动门级优化

> **本章 = 细粒度优化主章**：在 **mapped 网表 + .lib 延时 + SDC** 上迭代，修 setup/hold/DRC。  
> **粗粒度**见 [03](./03-optimization.md)。

映射 [04 章](./04-technology-mapping.md) 产出初版门级网表后，**真实单元延时** 已知；本章用 **时序 slack** 驱动 **局部** 变换。

---

## 1. 与 03 章对比

| | 03 粗粒度 | 06 细粒度 |
|---|-----------|-----------|
| IR | AIG / 未映射 | Mapped gates |
| 依据 | 节点数、level | **.lib delay、SDC slack** |
| 操作 | rewrite、balance | **sizing、buffer、VT swap** |
| 典型命令阶段 | `compile` 中期 | `compile_ultra` 迭代后期 |

### 输入/输出案例

**输入**：映射后 WNS = -0.35ns（setup 违例）

**输出**：插 3 级 buffer、2 处 upsize 后 WNS = +0.05ns。

---

## 2. `compile` 迭代模型（概念）

```text
loop:
  STA（WLM 或 物理估计）
  找 critical path / 违例端点
  应用 transform（细粒度）
  until 收敛或 达到 effort 上限
```

| Transform | 作用 |
|-----------|------|
| **Upsize** | 换更大驱动单元 → delay↓ |
| **Downsize** | 面积回收 |
| **Buffer insertion** | 切分 net，降 transition / delay |
| **Pin swap** | 交换等价输入脚，均衡延时 |
| **VT swap** | LVT ↔ HVT 权衡漏电与速度 |

### 输入/输出案例

**输入**：关键路径仅含 `ND2D1` 链

**输出**：关键单元换 `ND2D2` / `ND2D4`，slack 改善。

---

## 3. Setup 修复

**Setup 违例**：数据路径太长，launch→capture 来不及。

| 手段 | 说明 |
|------|------|
| 减小组合延时 | upsize、减 level（有限） |
| 减 fanout | 插 buffer 树 |
| 减线负载估计 | 物理综合（见下） |

**不能** 单靠加大时钟周期（除非改 SDC）。

### 输入/输出案例

**输入**：`report_timing -max` 显示 `u_alu/U123` 为 critical

**输出**：该单元及下游 2 级 upsize；WNS 从负变正。

---

## 4. Hold 修复

**Hold 违例**：数据 **太快** 到达，capture 沿前稳定时间不足。

| 手段 | 说明 |
|------|------|
| **Delay cell** | 插入专用缓冲/delay |
| 降驱动 | downsize 数据路径 |
| 增 min delay 路径 | 与 max corner 配合 |

Hold 常在 **fast corner** 出现；需 `set_operating_conditions -min`。

### 输入/输出案例

**输入**：`report_timing -min` hold slack = -0.08ns

**输出**：在违例捕获 FF 前插 `DELAYX1` 链。

---

## 5. 转换与电容 DRC

```tcl
set_max_transition 0.5 [current_design]
set_max_capacitance 0.2 [current_design]
```

| 违例 | 修复 |
|------|------|
| Max transition | 插 buffer、upsize driver |
| Max capacitance | 同上 |

### 输入/输出案例

**输入**：net `n123` transition = 0.8ns，limit 0.5ns

**输出**：在该 net 上插 2 个 `BUFFD1`。

---

## 6. 物理感知（Physical Synthesis，简述）

Fusion / DC-topographical、Genus 等可读 **拥塞 / 布线估计**：

| 输入 | 细粒度动作 |
|------|------------|
| 高拥塞区域 | 降密度、插 buffer、换 footprint |
| 长线 net | 更强驱动 |

完整 **布线延时** 在 PnR 后 STA；综合阶段为 **估计**。

---

## 7. 与 05 SDC、07 报告

- **05**：定义时钟、例外；06 消费 slack  
- **07**：`report_constraint`、`report_timing` 解读违例来源  

### 输入/输出案例

**输入**：`report_constraint -all_violators`

**输出**：

```text
max_transition  (violating nets: 12)
setup            (WNS: -0.12)
hold             (THS: -0.03)
```

---

## 8. 何时停止迭代

| 状态 | 含义 |
|------|------|
| WNS/TNS ≥ 0 | setup 满足（当前 corner） |
| Hold 满足 | min corner 通过 |
| `max_area` 触顶 | 面积约束阻止继续 upsize |
| `compile` effort 用尽 | 需改 RTL/约束/流程 |

---

## 9. 小结

细粒度 = **mapped 网上的局部修补**；依赖 **SDC + .lib**；与 03 **互补**。

---

## 下一节

- [07 综合报告](./07-synthesis-reports.md)
- [03 粗粒度](./03-optimization.md)
