# 2.4 工艺映射（Technology Mapping）

在 **[03 粗粒度优化](./03-optimization.md)** 之后，**工艺映射（technology mapping）** 把 **AIG 上的每个逻辑锥** 和 **已推断的时序/宏资源**，换成工艺库 **`.lib` 里真实存在的标准单元**（`ND2D1`、`DFFRX1`、`CKLNQD`…）。

> 映射 = **「选哪些门、怎么拼」**；映射后网表才有 **单元延时弧**，[06](./06-timing-driven-optimization.md) 才能做 **sizing/buffer**。  
> **配套 RTL**：`examples/mapping_walkthrough/`。

---

## 1. 在流程中的位置

```text
03 优化后 AIG（AND+INV 边）
        │
        ▼
【本章】cut → cover → 选单元 → 绑定 .lib
        │
        ▼
Mapped 门级网表 + 初始 STA（WLM）
        │
        ▼
06 细粒度优化（在同一批单元上继续换型号）
```

| 阶段 | 输入 | 输出 |
|------|------|------|
| 本章 | AIG + SEQGEN 标签 + `.lib` | `*.mapped.v`、单元延时模型 |
| 06 | mapped 网表 + SDC | 换驱动/插 buffer |

### 输入/输出案例

**输入**：AIG 节点 8500；`.lib` 含 800 种组合单元

**输出**：门级实例 6200；`report_reference` 出现 `ND2D1`、`INVX1`、`MUX2D1` 等 **库名**。

---

## 2. Mapping 在解决什么问题

| 问题 | 映射器的回答 |
|------|----------------|
| 一个 4 输入布尔函数怎么实现？ | 在库里找 **面积最小** 或 **延时最小** 的 **cover** |
| AIG 节点谁映射、谁不映射？ | 从 **PO 向 PI** 覆盖，每个节点属于某个 **cut** |
| DFF 用哪一种？ | 按 [02 推断](./02-inference.md) 选 `DFFRX*` / `DFFEQ*` |
| 乘法器呢？ | **不拆 AIG**，直接绑 `DW02_mult` 或宏 |

**核心**：组合逻辑 = **库单元覆盖布尔函数**；时序逻辑 = **查表绑单元族**。

---

## 3. Liberty（.lib）— 映射的「菜单」

```text
library (slow) {
  cell (ND2D1) { area: 1.2; pin(A) ... pin(B) ... pin(Z) ... timing(...) }
  cell (INVX1) { ... }
  cell (DFFRX1) { ... ff pins ... }
}
```

| 字段 | 映射用 | STA 用 |
|------|--------|--------|
| `area` | 面积驱动 | 面积报告 |
| `cell_rise/fall` | 估 delay 选 cover | 精确时序 |
| `pin capacitance` | 负载估算 | 签核 |
| `dont_use` / `dont_touch` | 过滤候选 | — |

### 输入/输出案例

**输入**：`set_dont_use [get_lib_cells {*XL* *SDF*}]`

**输出**：映射 **从不选** 被禁单元；若导致无法 cover → **mapping 报错** 或降级 cover。

---

## 4. 组合逻辑映射：算法骨架（内部）

整体是 **基于 cut 的 technology mapping**（与 ABC `map` 同类）：

```text
FOR 每个 AIG 节点 n（拓扑序，从 PO 往 PI）:
    1. 枚举 n 的 K-feasible cuts（K 常 = 4~6）
    2. 对每个 cut，计算 fanin 的 2^|cut| 真值表（或 canonical form）
    3. 在 .lib 中查 **匹配 cover**（单单元或多单元级联）
    4. 为每个 cut 计算 cost = f(area, delay, arrival_time)
    5. 选 **局部最优 cut**（或全局 DP 覆盖整图）
    6. 实例化标准单元，连接 pin
```

```mermaid
flowchart TB
  AIG[AIG 节点 n] --> CUT[枚举 cuts 大小≤K]
  CUT --> TT[真值表 / NPN 类]
  TT --> COV[查 .lib cover]
  COV --> COST[面积/延时代价]
  COST --> SEL[选中 cover]
  SEL --> CELL[实例化 ND2/MUX/...]
```

### 4.1 Cut（切割）是什么

**Cut** = 实现节点 `n` 所需的一组 **直接输入信号**（来自 PI 或已映射子节点的输出）。

```text
        a ────┐
        b ──┐ │
              AND1 ──┐
        c ──┘      │
                   AND2 ── n   ← 对 n 的一个 cut 可能是 {AND1_out, c}
        d ─────────┘           ← 另一个 cut 可能是 {a,b,c,d} 若 K 够大
```

| 参数 | 含义 |
|------|------|
| **K** | cut 最多 **K** 个输入（`map -K 6`） |
| 小 K | cover 简单，可能 **单元多、级数多** |
| 大 K | 可用 **复杂 AOI/OAI** 单单元 cover，**级数少** |

### 输入/输出案例 4.1

**AIG 节点** `n = a & b & c`（两个 AND 级联）

| cut 方案 | 输入 | 可能 cover |
|----------|------|------------|
| cut1 | `{a,b,c}` 若 K≥3 | 一个 3-input AND（若库有）或 **AND+AND** |
| cut2 | `{t_ab, c}`，`t_ab=a&b` | `ND2` + `ND2` 两级 |

**工具选**：delay 模式可能选 **单单元 3-input**；area 模式可能选 **两个 2-input ND2**（更小面积）。

---

### 4.2 真值表与 NPN 等价

4 输入 cut → **16 位** 真值表 → 映射到 **NPN 规范形式**（Negation-Permutation-N）：

```text
任意 4-input 函数 ──► 等价类 representative ──► 预存最优 cover 模板
```

| 好处 | 说明 |
|------|------|
| 查表快 | 库中 4-input 组合有限类 |
| 共享 | 相同类用同一 cover 模式 |

### 输入/输出案例 4.2

**函数**：`f = a ^ b`（2 输入）

**真值表**：`4'b0110`

**映射**：库中 `XOR2D1` 或 **4 个 NAND** 分解（依库与策略）。

---

### 4.3 Cover：单单元 vs 多单元

| 类型 | 例子 | 特点 |
|------|------|------|
| **单单元** | `OAI21D1` 实现 `!(a&b)|c` | 级数少、面积可能大 |
| **多单元** | 两个 `ND2D1` 级联 | 级数多、单元小 |
| **反相** | 用 INV 或 **带反相输入的 AOI** | 吸收 AIG 的 inv 边 |

**AIG 的 inv 边**：常映射到 **引脚极性** 或 **嵌入 OAI/NAND**，而不是显式 INV。

### 输入/输出案例 4.3 — `map_and_or.sv`

**RTL**：

```systemverilog
assign y = (a & b) | c;
```

**AIG（示意）**：AND → OR 结构（或 DeMorgan 全 AND）

**映射后网表（示意，工艺相关）**：

```verilog
ND2D1 U1 ( .A1(a), .A2(b), .ZN(t1) );
INVX1 U2 ( .A(t1), .Y(t2) );
OR2D1 U3 ( .A1(t2), .A2(c), .Y(y) );
// 或一个 OAI22 / 其他 cover
```

| 步骤 | 你看到的 |
|------|----------|
| `report_reference` | `ND2`、`INV`、`OR2` 计数 |
| 无 AIG 名 | 只剩库单元 |

---

### 4.4 延时驱动 vs 面积驱动

映射阶段为每个 cut 算 **arrival time**（到达时间）：

```text
arrival(n) = max( arrival(inputs) ) + cell_delay(cover)
```

| 模式 | 优化目标 |
|------|----------|
| **-timing** | 最小化 **PO 到达时间**（关键路径） |
| **-area** | 最小化 **单元总面积** |
| **-balance** | 折中 |

### 输入/输出案例 4.4

**同一 AIG 锥**，两种策略：

| 模式 | 单元数 | 估算 level | 关键路径 delay |
|------|--------|------------|----------------|
| area | 8 | 5 | 1.2ns |
| timing | 11 | 3 | 0.85ns |

**06 章** 还会在 mapped 结果上 **继续换大号单元**，进一步降 delay。

---

### 4.5 全局映射 vs 贪心

| 算法 | 行为 |
|------|------|
| **贪心** | 每个节点独立选最优 cut，快 |
| **全局 DP** | 考虑 cut 之间 **共享** 子图，面积更优 |

商业工具多 **混合**；ABC `map` 支持多种 `-a` 选项。

### 输入/输出案例

**共享子图** `t = a & b`，驱动 `y1`、`y2`

**全局映射**：`t` 只映射 **一次** `ND2D1`，fanout=2 — 与 AIG strash 一致。

---

## 5. MUX 与复杂门的映射

### 5.1 MUX

**RTL**（`map_mux.sv`）：

```systemverilog
assign y = sel ? b : a;
```

| 映射选项 | 单元 |
|----------|------|
| 专用 `MUX2D1` | 2 数据 + select |
| AND/OR 网络 | 无 MUX 单元时 |
| 来自 AIG | 先布尔化再映射 |

### 输入/输出案例

**输入**：4 位 `y`，1 位 `sel`

**输出**：4 个 `MUX2D1` 或 4 组 NAND 网络（`report_cell` 统计）。

---

### 5.2 XOR 链（`map_xor_chain.sv`）

**RTL**：`p = a^b; q = p^c;`

| 阶段 | 结构 |
|------|------|
| AIG | 两层 XOR 分解为 AND/INV |
| 映射 | 2×`XOR2D1` **或** 8~12 个 NAND（依库） |

### 输入/输出案例

**输入**：库无 XOR 单元

**输出**：XOR 函数用 **NAND 仅** 实现 — 面积↑、级数↑。

---

### 5.3 AOI / OAI / OA：为何工艺库爱用「复杂门」

标准单元库不只有 `AND2`、`ND2`，还有大量 **复合门**，把多级逻辑 **压进一个物理单元**：

| 类型 | 布尔形式（示意） | 典型单元名 |
|------|------------------|------------|
| **AOI** | `!(A & B & … \| C & …)` | `AOI21`、`AOI222` |
| **OAI** | `!(A \| B \| … & C & …)` | `OAI21`、`OAI22` |
| **OA** | `(A & B) \| C` | `OA21` |
| **AO** | `(A \| B) & C` | `AO21` |

数字 `21`、`222` 表示 **输入分组**（如 `OAI21` = 2 个 OR 输入 + 1 个 AND 输入）。

#### DeMorgan 与 AIG 反相边

AIG 只有 AND + **反相边**。映射器常把反相 **吃进** 复合门引脚，而不是单独挂 `INVX1`：

```text
RTL:  y = !(a & b) | c

朴素映射:  ND2(a,b) → INV → OR2(·,c)     → 3 个单元

吸收反相:  OAI21( a, b, c )             → 1 个单元（极性在引脚定义里）
```

| 步骤 | 输入 | 输出 |
|------|------|------|
| AIG | `n` 带 inv 边连 `a` | 映射器查 **带反相输入** 的 OAI/AOI |
| 结果 | 同功能 | **少 1～2 个单元、少 1 级** |

#### 输入/输出案例 5.3 — `f = !(a&b)|c`

**真值表**（3 输入，8 行）→ NPN 类 → 库中匹配 `OAI21D1`：

```verilog
OAI21D1 U1 ( .A1(a), .A2(b), .B(c), .Y(y) );
// 引脚极性以 .lib 为准；Y 已实现所需反相
```

**对比 NAND 分解**：可能需 `ND2`+`INV`+`OR2` — **面积与延时** 在映射代价函数中劣于单 OAI。

#### 输入/输出案例 5.3b — MUX 与 OAI

`y = sel ? b : a` 可写成 `!(sel & !a | !sel & b)` 一类形式 → 有时 **一个 OAI22/AOI22** 覆盖一位，比 4 门 AND/OR 更省。

---

### 5.4 手写 genlib + ABC `map`（理解 cover 从哪来）

工业用 **Liberty .lib**；教学常用 **genlib**（文本门库）配合 ABC：

```text
GATE  ND2   2  1.0  AND2:   A=a, B=b, Z=z
GATE  INV   1  0.5  INV:    A=a, Z=z
GATE  OAI21 3  1.4  OAI21:  A=a, B=b, C=c, Z=z
```

| 字段 | 含义 |
|------|------|
| 第 3 列 | 输入数 |
| 第 4 列 | **面积代价**（抽象单位） |
| 最后一列 | 引脚与 **布尔原语名** |

**流程**：

```text
read_aiger design.aig
strash
map -K 6 -lib my.genlib
write_verilog mapped.v
```

映射器对 cut 算真值表 → 在 genlib 里选 **面积和 ≤ 当前最优** 的 GATE 行。

#### 输入/输出案例 5.4

**genlib 只有** `ND2`、`INV`（无 OAI）时，映射 `!(a&b)|c`：

```text
→ ND2 + INV + OR2（若 OR 在库）或更多 NAND
→ 单元数 ≥ 3
```

**加入 `OAI21` 行** 后，同一函数：

```text
→ 1× OAI21
→ 单元数 = 1（面积可能仍优于 3 个小门之和）
```

配套文件：`examples/mapping_walkthrough/demo.genlib`、`run_abc_map.sh`。

#### 与 Liberty 的关系

| | genlib | .lib |
|---|--------|------|
| 用途 | ABC 教学、算法验证 | DC/Genus/PT 生产 |
| 延时 | 常仅面积或单位延时 | 全 PVT、弧、负载 |
| 复合门 | 手写几行即可 | Foundry 提供完整库 |

---

## 6. 时序元件映射（非 AIG 路径）

时序元件 **不经过 cut enumeration**，按 [02 推断](./02-inference.md) **查表**：

```text
GTECH_SEQGEN + 属性 ──► 选 DFF 族 ──► 连接 .CK .D .Q .RN .E
```

| 推断属性 | 典型单元 |
|----------|----------|
| async reset low | `DFFRX*` |
| sync only | `DFFX*` |
| clock enable | `DFFEQ*` / `EDFF*` |
| scan | `SDFFRQ*` |

### 输入/输出案例

**输入**：

```systemverilog
always_ff @(posedge clk or negedge rst_n)
  if (!rst_n) q <= '0;
  else if (en) q <= d;
```

**输出实例**：

```verilog
DFFRX2 u_reg (
  .CK(clk), .RN(rst_n), .D(d), .Q(q), .E(en)  // 引脚名随 .lib
);
```

| 若无 `.E` | 工具用 **MUX 在 D 端** 实现 enable |
|-----------|-------------------------------------|

---

## 7. 算术与宏：绕过组合 mapping

| 资源 | 映射方式 |
|------|----------|
| `GTECH_MULT` | `DW02_mult` / 门级 Wallace 树（策略） |
| `GTECH_RAM` | SRAM 宏 / 寄存器阵（02 策略） |
| 黑盒 | `.lib` interface only |

**原则**：宽乘法、RAM **不在 AIG 上做 cut**，避免爆炸。

### 输入/输出案例

**输入**：16×16 乘法，`set_implementation DW`

**输出**：网表一个 `DW02_mult` 实例，内部 **不展开** 给用户看。

---

## 8. ABC `map` 与商业工具对照

```text
abc 流程:
  strash → rewrite → balance → map -K 6 -lib genlib.lib
```

| ABC | DC / Genus |
|-----|------------|
| `map -K` | `compile` 内 mapping phase |
| `genlib` | `.lib` liberty |
| `*.aig` | 内部 DB |

### 输入/输出案例 — 可复现

```bash
yosys -p "read_verilog map_and_or.sv; hierarchy; proc; opt; abc -g AND -K 6; write_verilog out.v"
```

**输入**：`map_and_or.sv`

**输出**：`out.v` 仅含 `$_AND_`、`$_NOT_` 或映射后的 `AND`/`INV` — 对应 **K=6 cut mapping**。

---

## 9. 约束如何改变 mapping

| SDC / 命令 | 映射影响 |
|------------|----------|
| `create_clock -period 1.0` | 倾向 **短 delay cover** |
| `set_max_area 0` | 倾向 **小面积 cover** |
| `set_dont_use` | 缩小菜单 |
| `set_max_transition` | 影响 **驱动强度** 初值 |

映射用 **WLM** 估 net 延时；**06 + PT** 用真实寄生。

### 输入/输出案例

**输入**：周期 0.5ns 极紧

**输出**：映射报告 **critical path** 上多用 **LVT、大驱动、浅 cover**。

---

## 10. 映射质量怎么查

```tcl
report_reference -hierarchy
report_cell -connections
report_timing -max_paths 5   # 映射后初版 STA
```

| 报告 | 看什么 |
|------|--------|
| `reference` | 是否出现 **非库** 原语（不应有 GTECH） |
| `cell` | 意外 `LAT`、`XL` |
| `timing` | 映射后 WNS 是否仍崩（需 06） |

### 输入/输出案例

**失败**：网表含 `GTECH_MUX` → mapping **未完成**

**成功**：仅 `library cell` 名。

---

## 11. 案例集锦（逐步理解 Mapping）

### 案例 A：`y = (a&b)|c` 端到端

| 步 | 形态 |
|----|------|
| RTL | 1 行 assign |
| 03 AIG | ~3–5 个 AND 节点 |
| 04 map | 2–4 个标准单元 |
| 06 | 可能 upsize `ND2` → `ND2D4` |

### 案例 B：K=4 vs K=6

| K | 对 `f(a,b,c,d,e)` 5 输入锥 |
|---|---------------------------|
| 4 | 必须 **分级**，更多级联 |
| 6 | 可能 **单 OAI** cover，1 级 |

### 案例 C：面积 vs 时序 cover 选择

```text
        ┌─ ND2 ─ ND2 ─ ND2 ─┐  area 优
  PO ───┤                  ├─
        └─ OAI222 ─────────┘  timing 优
```

### 案例 D：INV 边吸收

**AIG**：`n = !(a & b)` 带 inv 边

**映射**：一个 `OAI21`（输入极性）而非 `AND` + `INV` 两个单元 — **省面积**。

### 案例 E：寄存器不在 AIG 里

```text
[PI] ──► 组合 AIG ──► [DFF.D]
                         [DFF.Q] ──► 下一段组合 AIG
```

映射 **分段**：组合块 map；DFF **直接绑单元**。

### 案例 F：映射 vs 06

| 操作 | 章节 | 改变 |
|------|------|------|
| 换 cover 结构 | 04 | 单元 **类型** 变 |
| 同类型换驱动 | 06 | `ND2D1`→`ND2D4` |
| 插 buffer | 06 | 增实例 |

### 案例 G：常见失败

| 现象 | 原因 |
|------|------|
| 无 cover | 函数需 5 输入但 K=4 且库无大单元 |
| 用了禁用的单元 | `dont_use` 过严 |
| 映射后 area 爆炸 | XOR/乘法被拆成门阵 |

---

## 12. 动手练习

1. 用 `examples/mapping_walkthrough/` + Yosys `abc -K 4` 与 `-K 6` 对比 `out.v` 单元数。  
2. DC：`compile` 前后 `report_reference` 对比 GTECH → `ND2`。  
3. 对 `map_mux.sv` 查库是否有 `MUX2`，观察映射用 MUX 还是 NAND 网。

---

## 13. 小结

| 概念 | 要点 |
|------|------|
| **Cut** | K 个输入的 fanin 集合 |
| **Cover** | 库单元实现 cut 的真值函数 |
| **代价** | 面积 / 到达时间 |
| **组合** | AIG + cut + .lib |
| **时序** | 推断 + 单元族 |
| **算术/宏** | 不走 cut |

---

## 下一节

- [05 SDC](./05-constraints-sdc.md)
- [06 细粒度优化](./06-timing-driven-optimization.md)
- [03 AIG 优化](./03-optimization.md)
- [examples/mapping_walkthrough/](./examples/mapping_walkthrough/)
