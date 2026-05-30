# 2.4 工艺映射（Technology Mapping）

在 **[03 粗粒度优化](./03-optimization.md)** 之后，将 **AIG / 布尔网表** 与时序元件 **绑定到工艺库（.lib）中的标准单元**，得到 **mapped 门级网表**。

> 映射是 **「绑定」**，不是细粒度修时序；**sizing / buffer** 在 [06](./06-timing-driven-optimization.md)。

---

## 1. 在流程中的位置

```text
03 优化后 AIG + 02 推断标签（REG/RAM/MULT）
        │
        ▼
【本章】technology mapping + 时序元件绑定
        │
        ▼
门级网表（ND2D1, DFFRX1, SRAM macro, …）
        │
        ▼
06 细粒度时序优化
```

| 输入 | 输出 |
|------|------|
| AIG、GTECH SEQGEN、RAM 壳、.lib | 带单元名的 netlist + 初始延时估算 |

---

## 2. Liberty（.lib）里有什么

| 对象 | 用途 |
|------|------|
| `cell` | 单元名、面积、功耗 |
| `pin` | 方向、电容 |
| `timing` | 弧：`cell_rise/fall`、`setup/hold` |
| `wire_load` / CCS | 线负载或电流源模型（STA 用） |

映射器读 **延时/面积/功耗** 表，在 **候选单元集合** 中选 cover。

### 输入/输出案例

**输入**：`.lib` 中 `INVX1` delay=0.05ns，`INVX4` delay=0.03ns（驱动强）

**输出**：高扇出 net 映射倾向 **大驱动** inverter（映射阶段初版，06 再细调）。

---

## 3. 组合逻辑：基于 AIG 的 Mapping

### 3.1 Cut enumeration

对每个 AIG 节点，枚举 **k 输入**（常 4–6）的 **fanin cone**（cut）：

```text
cut = {a, b, c, d}  →  真值表 16 位  →  匹配 .lib 中 NAND/NOR/AND 组合
```

### 3.2 Cover

一个 cut 对应 **一个标准单元** 或 **2–3 个单元级联**（cover）：

| 策略 | 说明 |
|------|------|
| 面积优先 | 少单元、可能路径深 |
| 延时优先 | 浅 cover、可能单元多 |
| 负载感知 | 结合 fanout 估算 |

### 3.3 映射后

AIG 节点消失，变为 `U123 (ND2D1)` 等实例。

### 输入/输出案例

**输入**：AIG 4 输入锥，节点数 20

**输出**：门级 12 个标准单元，`report_cell` 可见 `ND2D1`、`INVX1`。

| 输入 | 输出 |
|------|------|
| 优化后 AIG | Verilog 中 `module` 内全是库单元实例 |

---

## 4. 时序元件映射

| 推断标签 | 映射结果 |
|----------|----------|
| REGISTER + async reset | `DFFRX1` 等 |
| REGISTER + CE | `DFFEQ*` |
| LATCH | `LH*` / `TLAT*`（若允许） |
| ICG | `CKLNQD` 等 |

**扫描链**：DFT 属性影响选 `SDFF*`。

### 输入/输出案例

**输入**：`GTECH_SEQGEN` + `resource_type=REGISTER, CE=en`

**输出**：`DFFRX2` 带 `.E(en)` 或工具映射为 **MUX+FF** 结构（依 .lib）。

---

## 5. 宏与 IP

| 资源 | 映射方式 |
|------|----------|
| 推断 RAM | Memory Compiler **.lib/.lef** 黑盒或 pin 模型 |
| MULT | DesignWare `DW02_mult` 或门级阵列 |
| 模拟 IP | `.lib` interface timing |

`set_dont_touch [get_cells u_ram]` → 保持宏边界。

### 输入/输出案例

**输入**：`sync_ram` 1024×32 推断为 register array，策略改为 macro

**输出**：网表顶层 `SRAM1024X32 u_ram (...)`，无 32768 个 DFF。

---

## 6. 约束与映射交互

[05 SDC](./05-constraints-sdc.md) 在 `compile` 时已读入：

- `create_clock` → 映射选 **快单元** 还是 **小单元**  
- `set_max_area` → 面积权重  
- `set_dont_use` → 禁止某些 cell  

映射 **第一次** 用 WLM 估算；**真实** 闭环在 06 + PrimeTime。

### 输入/输出案例

**输入**：`set_dont_use [get_lib_cells *XL*]`（禁用慢单元）

**输出**：映射报告仅出现 `*R*` / `*L*` VT 单元。

---

## 7. 与 03、06 的边界

| 不做 | 章节 |
|------|------|
| AIG rewrite | 03 |
| 大量 buffer 插入迭代 | 06 |
| SDC 语法详解 | 05 |

---

## 8. 小结

映射 = **AIG/SEQGEN → .lib 单元**；组合靠 **cut/cover**，时序靠 **推断标签 + 单元族**。

---

## 下一节

- [05 SDC](./05-constraints-sdc.md)
- [06 细粒度优化](./06-timing-driven-optimization.md)
