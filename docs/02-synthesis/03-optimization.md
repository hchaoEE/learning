# 2.3 粗粒度优化：技术无关布尔优化与 AIG

> **本章 = 粗粒度优化主章**（映射前、技术无关）。**细粒度**见 [06](./06-timing-driven-optimization.md)。

Elaboration 与 [推断](./02-inference.md) 之后，组合逻辑仍以 **GTECH 运算节点 / MUX 树** 存在；**粗粒度优化** 把它们收成 **AIG（And-Inverter Graph）**，在 **不绑定 .lib 单元** 的前提下做全局化简，再交给 [04 工艺映射](./04-technology-mapping.md)。

---

## 1. 在流程中的位置

```text
02 推断（REG/RAM/MULT 标签）
        │
        ▼  组合云布尔化（SEQ/宏 边界保留）
【本章】AIG 构建 → strash → rewrite / balance / …
        │
        ▼
04 工艺映射（在 AIG 上做 cut/cover）
```

| 阶段 | 输入 | 输出 |
|------|------|------|
| 推断后 GTECH | MUX/AND/OR/算术壳 + 寄存器边界 | — |
| **本章** | 组合逻辑锥 | **优化后 AIG**（节点/深度变化） |
| 映射 | AIG + .lib | 门级网表 |

---

## 2. 为何用 AIG

| 对比 | 结构网表（GTECH） | AIG |
|------|-------------------|-----|
| 节点类型 | 多种（MUX、ADD…） | 仅 **AND + 反相边** |
| 优化算法 | 分散、难统一 | **rewrite / strash** 成熟（ABC 体系） |
| 映射接口 | 需先布尔化 | 直接 **cut enumeration** |

**时序元件、硬宏** 不进入 AIG；在 AIG 边界上保留 **primary input/output** 与寄存器 D/Q 针。

### 输入/输出案例

**输入**：`assign y = (a & b) | c;` 的 GTECH 树（AND/OR 混用）

**输出**（AIG 边表示，`!` 为反相）：

```text
a ──┐
    AND ──!──┐
b ──┘        AND ── y
c ───────────┘
```

| 输入 | 输出 |
|------|------|
| 任意组合锥 | 仅含 2-input AND + inverter 边的 DAG |

---

## 3. GTECH 组合云 → AIG（Lowering）

内部 pass 大致顺序：

```text
1. 提取组合逻辑锥（不含 REG、RAM 读写的时序壳）
2. 将 MUX、XOR、OR 等分解为 AND/INV（布尔分解）
3. 构建 AIG 节点，建立 driver → fanout
4. strash：结构相同子图合并为单节点
```

| GTECH | 常见 AIG 化 |
|-------|-------------|
| `GTECH_MUX2` | AND/INV 多级（或保留 MUX 边界再映射，工具策略不同） |
| `GTECH_XOR` | 固定 XOR 分解式 |
| `GTECH_ADD` | 常保留 **算术边界**，不强行进 AIG（避免破坏映射） |

### 输入/输出案例

**输入**：8 输入 MUX 树（来自 `unique case`）

**输出**：AIG 节点数可能 **大于** 直观 MUX 数；后续 **rewrite** 再压缩。

---

## 4. AIG 数据结构（内部）

```text
struct AigNode {
  id;
  left_child, right_child;   // 2-input AND
  left_inv, right_inv;       // 边是否反相
}
```

| 概念 | 说明 |
|------|------|
| **strash** | 同一 `(left,right,inv)` 只建一个节点 → 自动 CSE |
| **PI/PO** | 锥输入/输出，接寄存器 Q 或 primary input |
| **level** | 逻辑深度，供 balance 与映射延时估算 |

### 输入/输出案例

**输入**：`y = a & b; z = a & b;`

**输出**：**一个** AND 节点驱动 `y`、`z` 两条边（strash 后）。

---

## 5. 典型粗粒度 Pass

### 5.1 Rewriting / Refactoring

在 **k 输入窗口**（如 4–6）内用 **更小** 的等价 AIG 替换：

```text
局部 AIG 子图  →  查表 / NPN 分类  →  更省节点/更浅深度的等价类
```

| 目标 | 效果 |
|------|------|
| 减节点 | 面积 ↓ |
| 减 level | 关键路径 ↓（映射前估算） |

### 5.2 Balancing

重组 AND 树深度，使 **关键路径更短**（可能增加节点）：

```text
        AND                AND──AND
       /   \      →       /  \  /  \
      ...              平衡后的树
```

### 5.3 常量 / 冗余消除

- 常 0/1 传播、**死节点** 删除  
- **不可达** PO 删除  

### 5.4 与算术的关系

宽 **乘法器** 常在 GTECH 保留；周围 **控制逻辑** 进 AIG。推断在 [02 章](./02-inference.md) 已选 IP/门阵，本章 **不拆乘法器** 除非策略允许。

### 输入/输出案例

**输入**：优化前 AIG 节点数 = 12000，level = 18  

**输出**（`rewrite + balance` 后）：

```text
Nodes: 8500 (-29%)   Level: 14
```

| Pass | 典型报告字段 |
|------|----------------|
| strash | 重复节点合并数 |
| rewrite | 替换窗口次数、节点 delta |

---

## 6. 与 ABC 流程对照（开源参考）

```text
read_aiger / strash
  → rewrite / refactor / balance
  → map -K 6 -lib ...   # 属 04 章映射
```

商业 DC/Genus **不暴露** ABC 命令，但 **语义等价** pass 存在于 `compile` 中期。

### 输入/输出案例

**Yosys 路径**：`abc -g AND -K 6` 后网表 AND 门数量 vs RTL `assign` 行数 — 用于理解 **粗优化幅度**。

---

## 7. 时序与面积代价（映射前）

粗优化使用 **线负载模型（WLM）** 或 **单位延时** 估算 level，**非** 真实 STA：

| 用途 | 精度 |
|------|------|
| 选 rewrite 方案 | 粗估算 |
| 签核 | 必须在 **06 章** mapped + SDC |

### 输入/输出案例

**输入**：SDC `create_clock 500MHz`（2ns）

**输出**：优化器倾向 **balance** 减 level；若仅面积模式，倾向 **rewrite** 减节点。

---

## 8. 寄存器边界与 Sequential 优化（简述）

| 类型 | 归属 |
|------|------|
| 纯组合 AIG 优化 | **本章** |
| 寄存器 **搬移**（retiming） | 06 或工具专用 pass；跨章 |
| 时钟门控插入 | [02 推断 ICG](./02-inference.md)、[08 低功耗](./08-low-power-synthesis.md) |

不在本章对 **DFF 之间** 做 retiming 展开，避免与 STA 闭环冲突。

### 输入/输出案例

**输入**：两级 REG 夹大组合锥

**输出**：组合锥 AIG 被优化；**REG 数量不变**（除非启用 retiming 属性）。

---

## 9. 常见问题

| 现象 | 原因 |
|------|------|
| 节点数反增 | balance 换深度为面积 |
| 优化后映射变差 | 算术边界被破坏 → 检查 `dont_touch` 乘法器 |
| 与仿真不一致 | 组合环或未初始化；非 AIG 独有 |

---

## 10. 小结

| 概念 | 要点 |
|------|------|
| **粗粒度** | 映射前、AIG、技术无关 |
| **strash** | 子图共享 |
| **rewrite/balance** | 面积 vs 深度权衡 |
| **下一章** | [04 映射](./04-technology-mapping.md) 消费优化后 AIG |

---

## 下一节

- [04 工艺映射](./04-technology-mapping.md)
- [06 细粒度优化](./06-timing-driven-optimization.md)
- [README §9 粗/细粒度](./README.md#9-粗粒度优化-vs-细粒度优化写在哪一章)
