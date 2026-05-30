# 2.3 粗粒度优化：技术无关布尔优化与 AIG

> **本章 = 粗粒度优化主章**（映射前、技术无关）。**细粒度**见 [06](./06-timing-driven-optimization.md)。

Elaboration 与 [推断](./02-inference.md) 之后，组合逻辑仍以 **GTECH 运算节点 / MUX 树** 存在；**粗粒度优化** 把它们收成 **AIG（And-Inverter Graph）**，在 **不绑定 .lib 单元** 的前提下做全局化简，再交给 [04 工艺映射](./04-technology-mapping.md)。

**配套 RTL**：`examples/aig_walkthrough/`（与 **§11 案例集锦** 逐条对应）。

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
| **本章** | 组合逻辑锥 | **优化后 AIG**（节点/depth 变化） |
| 映射 | AIG + .lib | 门级网表 |

### 输入/输出案例

**输入**：`compile` 前 Elaborate 后 `report_cell` 见 `GTECH_MUX`、`GTECH_AND`。

**输出**：`compile` 中期（pre_map）同一设计 **GTECH 组合节点减少**、或映射前 AIG 统计 **node count** 下降（工具报告名因厂商而异）。

---

## 2. 为何用 AIG

| 对比 | 结构网表（GTECH） | AIG |
|------|-------------------|-----|
| 节点类型 | 多种（MUX、ADD…） | 仅 **AND + 反相边** |
| 优化算法 | 分散、难统一 | **rewrite / strash** 成熟（ABC 体系） |
| 映射接口 | 需先布尔化 | 直接 **cut enumeration** |

**时序元件、硬宏** 不进入 AIG；边界保留 **PI/PO** 与寄存器 D/Q。

### 输入/输出案例 2.1 — 与或非表达式

**RTL 输入**：

```systemverilog
assign y = (a & b) | c;
```

**GTECH（概念）**：`GTECH_AND` → `GTECH_OR` → y

**AIG 输出**（`!` = 边反相）：

```text
        a ──┐
            AND──!──┐
        b ──┘       AND── y
        c ──────────┘
```

| 步骤 | 你看到的「形状」 |
|------|------------------|
| 输入 | 2 种门类型（AND、OR） |
| 输出 | 仅 AND，OR 被吸收进反相拓扑 |

### 输入/输出案例 2.2 — 德摩根（理解反相边）

**RTL**：`assign y = ~(a & b);`

**AIG**：等价于 `!a | !b` 的 AND 结构 — 常表现为 **子节点带 inv 边**，而不是单独 `NOT` 门节点。

```text
a ──inv──┐
         AND ── y   （输出边无 inv 时即 ~（a&b））
b ──inv──┘
```

---

## 3. GTECH 组合云 → AIG（Lowering）

```text
1. 提取组合逻辑锥（跳过 REG、RAM 时序壳）
2. MUX/XOR/OR → AND/INV 分解
3. 建 AIG 节点
4. strash
```

| GTECH | 常见 AIG 化 |
|-------|-------------|
| `GTECH_MUX2` | AND/INV 展开（或暂保留 MUX 边界） |
| `GTECH_XOR` | 固定 3-AND 分解式 |
| `GTECH_ADD` | 常 **保留算术边界** |

### 输入/输出案例 3.1 — 2:1 MUX（`comb_mux.sv`）

**RTL 输入**：

```systemverilog
unique case (sel)
    1'b0: y = a;
    1'b1: y = b;
    default: y = '0;
endcase
```

**Lowering 后（4 位总线每位独立，概念图）**：

```text
sel ──► 控制 AND 树 ──► y[i]
a[i] ─┘
b[i] ─┘
```

| 阶段 | 节点趋势 |
|------|----------|
| 刚 lowering | AIG 节点 **可能多于** 一行 `assign y = sel ? b : a` 的直觉 |
| 经 rewrite | 常 **下降** 20%–40%（视位宽与 sel 扇出） |

### 输入/输出案例 3.2 — XOR

**RTL**：`assign p = a ^ b;`

**AIG（经典 3-AND 分解，示意）**：

```text
a ──┐     ┌── AND ──!
    XOR分解 ── AND ── p
b ──┘     └── AND ──!
```

| 输入 | 输出 |
|------|------|
| 1 个 GTECH_XOR | 多个 AND + inv 边（**节点变多** 是正常现象） |

### 输入/输出案例 3.3 — 不进 AIG 的算术（`reg_comb_boundary.sv`）

**RTL**：

```systemverilog
assign sum = a ^ b;
always_ff @(posedge clk) q <= sum + 1'b1;
```

**内部切分**：

```text
[组合锥 AIG 化]  a,b ──► XOR ──► sum
                              │
[算术边界]                    ▼
                         GTECH_ADD (+1)
                              │
[时序]                        ▼
                            DFF q
```

| 输入 | 输出 |
|------|------|
| `+` 在 always_ff 内 | **加法器** 保持 GTECH_ADD；**不** 把加法器拆成万级 AND |

---

## 4. AIG 数据结构（内部）

```text
AigNode: left, right, left_inv, right_inv  → 2-input AND
```

| 概念 | 说明 |
|------|------|
| **strash** | 相同 (L,R,inv) 只存一份 |
| **level** | 逻辑深度，供 balance |

### 输入/输出案例 4.1 — strash（`comb_dup.sv`）

**RTL 输入**：

```systemverilog
assign y = a & b;
assign z = (a & b) | c;
```

**未 strash（概念）**：

```text
AND1: a,b → y
AND2: a,b → … → OR → z    （两个 AND2）
```

**strash 后**：

```text
AND_shared: a,b ──┬──► y
                  └──► OR ──► z
```

| 指标 | 前 | 后 |
|------|----|----|
| AND 节点 | 2 | 1 |
| 扇出 | — | `AND_shared` fanout=2 |

### 输入/输出案例 4.2 — 常量传播（`comb_const.sv`）

**RTL 输入**：

```systemverilog
assign y    = din & 4'b1010;
assign flag = din[0] & 1'b0;
```

**优化后**：

```text
y[3] = din[3] & 1'b1 → din[3]
y[2] = din[2] & 1'b0 → 0
y[1] = din[1] & 1'b1 → din[1]
y[0] = din[0] & 1'b0 → 0
flag = 0              → PO 可接 tie-0，AIG 中 flag 锥 **被删**
```

| 输入 | 输出 |
|------|------|
| 与常数运算 | 部分位 **折叠**；恒 0/1 锥 **DCE** |

---

## 5. 典型粗粒度 Pass

### 5.1 Rewriting

在 **4–6 输入** 窗口内，用 **更小** 等价 AIG 替换。

### 输入/输出案例 5.1 — 4 输入真值函数

**输入**：某 4 输入锥，原 AIG **节点=8, level=5**

**rewrite 后**：**节点=6, level=4**（查 NPN 等价类表得到更小实现）

| 目标 | 典型效果 |
|------|----------|
| 面积 | 节点数 ↓ |
| 时序（映射前） | level ↓ |

### 5.2 Balancing

**输入** — 链状 AND（深而窄）：

```text
a ──AND──AND──AND──AND── y   level=4
```

**balance 后** — 树状（浅而宽）：

```text
        AND──AND── y   level=2
       /  \  /  \
      a  b  c  d
```

| 指标 | 前 | 后 |
|------|----|----|
| level | 4 | 2 |
| 节点数 | 3 | 3（可能 +1） |

**权衡**：balance 常 **增节点、减 depth** — 与 5.1 rewrite **相反方向**，工具按 **面积/时序权重** 折中。

### 5.3 常量 / 冗余

见 **§4.2**；另：**死 PO**（无 fanout）整锥删除。

### 5.4 算术边界

**输入**：`set_dont_touch [get_cells u_mult]`

**输出**：`u_mult` 周围组合锥仍 AIG 化；**乘法器内部** 不拆。

### 输入/输出案例 5.5 — 整模块优化前后（示意数据）

| 指标 | Elaborate 后 | 粗优化后 |
|------|----------------|----------|
| AIG nodes | 12,000 | 8,500 |
| AIG level | 18 | 14 |
| GTECH_MUX | 200 | 0（已布尔化） |

*数值为教学示意；请以实际 `compile` 日志为准。*

---

## 6. 与 ABC 流程对照

```text
strash → rewrite → refactor → balance → map
```

### 输入/输出案例 6.1 — Yosys + ABC（可复现）

```bash
yosys -p "read_verilog comb_dup.sv; hierarchy -top comb_dup; proc; opt; abc -g AND -K 6"
```

| 步骤 | 观察 |
|------|------|
| `proc` 后 | 见 `$and`、`$or` 通用门 |
| `abc -g AND` 后 | 仅剩 `$_AND_`、`$_NOT_` — **与 AIG 同构** |
| 统计 | `comb_dup` 中 `a&b` **只出现 1 次** AND 链（strash） |

### 输入/输出案例 6.2 — 与 04 映射分界

| ABC 命令 | 归属 |
|----------|------|
| `rewrite`, `balance` | **本章 03** |
| `map -K 6 -lib` | **[04 映射](./04-technology-mapping.md)** |

---

## 7. 时序与面积代价（映射前）

| 模式 | 粗优化倾向 |
|------|------------|
| `compile_ultra` 默认 | rewrite + balance 混合 |
| 强调 `max_area` | 偏重 rewrite 减节点 |
| 紧 `create_clock` | 偏重 balance 减 level |

### 输入/输出案例

**输入**：`create_clock -period 1.0`（1ns），当前估算 level=20 > 允许

**输出**：工具 **提高 balance 权重**；节点可能 +5%，level 20→15。

---

## 8. 寄存器边界

| 类型 | 归属 |
|------|------|
| 组合 AIG | 本章 |
| retiming | 06 / 专用 pass |
| ICG | 02 / 08 |

### 输入/输出案例

**输入**：`reg_comb_boundary` — 组合仅 `a^b`，寄存器在 `q<=sum+1`

**输出**：AIG 优化 **只改写** `sum` 锥；**DFF 与 ADD 不变**。

---

## 9. 常见问题

| 现象 | 原因 |
|------|------|
| 节点数反增 | XOR/MUX 刚展开；或 balance |
| 映射后更慢 | 算术边界被破坏；检查 `dont_touch` |
| 与仿真不一致 | 组合环/X 传播；非 AIG 独有 |

---

## 10. 小结

| 概念 | 要点 |
|------|------|
| **AIG** | 仅 AND + inv 边 |
| **strash** | 共享子表达式 |
| **rewrite / balance** | 面积 vs 深度 |
| **边界** | REG/宏 不拆 |

---

## 11. 案例集锦（逐步理解）

以下用 **同一套思维**：RTL → 组合锥 → AIG → pass → 交给映射。

### 案例 A：从 RTL 数「组合锥」

| RTL | 几个组合锥？ | 进 AIG？ |
|-----|--------------|----------|
| `assign y=a&b;` | 1 | 是 |
| `always_ff q<=a+b;` | 加法器块 + 可能无独立 assign 锥 | 加法器块否 |
| `assign o=en?a:b;` | 1（含 MUX） | 是 |

### 案例 B：`comb_dup` 端到端

| 步骤 | 内容 |
|------|------|
| RTL | `y=a&b`, `z=(a&b)\|c` |
| GTECH | 2×AND + 1×OR |
| AIG+strash | 1×AND + OR 链 |
| 映射后 | 约 2–3 个标准单元（视库） |

### 案例 C：`comb_mux` — 为何先胀后缩

| 阶段 | 4 位 y 的 AIG 节点（示意） |
|------|---------------------------|
| 刚 lowering | ~40（每位 MUX 展开） |
| rewrite 后 | ~28 |
| map 后 | 12–16 个标准单元 |

### 案例 D：恒 0 输出 `flag`（`comb_const`）

| 优化前 | 优化后 |
|--------|--------|
| `din[0] & 0` 仍占 AIG 节点 | 锥消掉，`flag` tie 0 |

### 案例 E：对比「粗」与「细」

| 操作 | 03 粗粒度 | 06 细粒度 |
|------|-----------|-----------|
| 合并重复 AND | strash ✓ | 不再做 |
| 换 ND2D4 驱动 | ✗ | sizing ✓ |
| 插 BUFFER | ✗ | ✓ |

**同一设计**：03 改 **节点个数**；06 改 **单元型号**。

### 案例 F：手算 2 输入 AND 真值 → AIG

| a | b | a&b |
|---|---|-----|
| 0 | 0 | 0 |
| 0 | 1 | 0 |
| 1 | 0 | 0 |
| 1 | 1 | 1 |

AIG 中 **一个** 2-input AND 节点即可；映射时 **一个** `ND2` 或 `AND2` cover。

### 案例 G：何时 **不要** 指望 AIG 优化

| 情况 | 原因 |
|------|------|
| 已 `dont_touch` | 跳过优化 |
| 黑盒 SRAM | 无组合锥 |
| 纯寄存器打拍 | 无组合逻辑 |

### 案例 H：工具里怎么「看见」粗优化（DC 概念）

```tcl
compile_ultra -no_autoungroup
# 或分段：
compile -stage logic_opt
report_qor    ;# 面积/时序摘要变化
```

| 输入 | 输出 |
|------|------|
| `compile` 前后 QoR | Cell count、Area 在 **映射前** 已有变化 → 含 03 效果 |

---

## 12. 动手练习

1. 综合 `examples/aig_walkthrough/comb_dup.sv`，对照 **案例 B** 看 strash。  
2. 将 `comb_mux.sv` 中 `unique case` 改为 `if/else`，对比 AIG 节点（部分工具会有差异）。  
3. 对 `reg_comb_boundary.sv` 在 schematic 中确认 **加法器未拆成与门阵列**。

---

## 下一节

- [04 工艺映射](./04-technology-mapping.md)
- [06 细粒度优化](./06-timing-driven-optimization.md)
- [examples/aig_walkthrough/](./examples/aig_walkthrough/)
