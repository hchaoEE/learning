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

**输入**：Elaborate 后 Design DB

**输出**：组合段 **GTECH_MUX、GTECH_AND** 计数 >0；尚无 `.lib` 单元名。

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

**AIG 输出**（`!` = 边反相）。OR 经德摩根改写：`y = (a∧b) ∨ c = ¬(¬(a∧b) ∧ ¬c)`：

```text
        a ──┐
            AND──!──┐
        b ──┘       AND──!── y
        c ──────!───┘
```

| 步骤 | 你看到的「形状」 |
|------|------------------|
| 输入 | 2 种门类型（AND、OR） |
| 输出 | 仅 2 个 AND；OR 被改写为「两输入取反 AND 再取反输出」的反相拓扑 |

### 输入/输出案例 2.2 — 德摩根（理解反相边）

**RTL**：`assign y = ~(a & b);`

**AIG**：取反不建单独的 `NOT` 节点，而是 **输出边带 inv**：

```text
a ──┐
    AND ──inv── y   （AND(a,b) 输出边反相 = ~(a&b)）
b ──┘
```

> 对照德摩根 `~(a&b) = !a | !b`：两种写法在 AIG 中是 **同一个节点**（AND(a,b)），区别只在引用它的那条边是否带 inv —— 若错画成「a、b 入边各带 inv、输出无 inv」，得到的是 `!a & !b ≠ ~(a&b)`。

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

粗优化 pass 在 **同一 AIG IR** 上循环，直到 node/level 收敛或达到 effort 上限。常见顺序（与 ABC 同类）：

```text
strash → rewrite → refactor → balance → (重复)
```

### 5.1 Strash（结构性哈希）

**动作**：对每个 `(AND, left, right)` 三元组查 hash 表；已存在则 **复用节点**，合并 fanout。

**案例** — 见 [§4.1](./03-optimization.md#输入输出案例-41--strashcomb_dupsv)、`aig_walkthrough/comb_dup.sv`。

### 5.2 Rewriting

**动作**：在 **4–6 输入** 窗口内，查 **NPN 等价类表**，用 **更小** 等价 AIG 替换整窗。

### 输入/输出案例 5.1 — 4 输入真值函数

**输入**：某 4 输入锥，原 AIG **节点=8, level=5**

**rewrite 后**：**节点=6, level=4**（查 NPN 等价类表得到更小实现）

| 目标 | 典型效果 |
|------|----------|
| 面积 | 节点数 ↓ |
| 时序（映射前） | level ↓ |

### 5.3 Refactoring

**动作**：与 rewrite **不同** — 将 **多个** AIG 节点 **合并** 成更大窗口再分解，打破局部最优；常降低 **depth** 或 **共享** 子表达式。

```text
rewrite：  小窗 → 查表替换（局部最优）
refactor： 大窗 → 重新分解结构（跳出局部最优）
```

### 输入/输出案例 5.3 — 深链 refactor

**输入**（链状 AND，level=6）：

```text
a─AND─AND─AND─AND─AND─AND─y
```

**refactor 后**（示意，level=3）：

```text
      AND──AND──y
     /  \ /  \
    AND AND  e f
   / \
  a b c d
```

| 指标 | 前 | 后 |
|------|----|----|
| level | 6 | 3 |
| 节点 | 5 | 7（可能略增） |

### 5.4 Balancing

**动作**：在 **不改变布尔功能** 前提下，将链状 AND/OR **拉宽成树**，降低 level、可能增节点。

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

**权衡**：balance 常 **增节点、减 depth** — 与 rewrite **相反方向**，引擎按 **面积/level 权重** 折中。

### 5.5 常量 / 冗余 / DCE

**动作**：

1. 常量传播：PI 或 FF 输出已知 → 子锥折叠  
2. 死 PO：无 fanout 的锥 **整段删除**  
3. 见 **§4.2** strash 后的 0/1 锥消除  

### 5.6 算术与宏边界

**动作**：带 `dont_touch` 或 `MULT`/`RAM` 标签的 instance **不进入** AIG 拆解；仅其 **端口组合锥** 布尔化。

### 输入/输出案例 5.6

**DB 属性**：`u_mult.dont_touch = true`

**内部**：`u_mult` 周围组合锥仍 AIG 化；**乘法器内部** 不拆成 AND 阵列。

### 5.7 算术共享与 CSE（内部）

**动作**：识别 **同一子表达式** 多次使用（如 `a*b` 出现在两个 assign），在 GTECH/AIG 层 **共享节点** 而非重复 MULT/AND 锥。

```text
assign p = a * b;
assign q = (a * b) + c;

Lowering 后（未 CSE）：两个 GTECH_MULT 或两个乘法锥
CSE 后：一个 MULT 输出 fanout→2
```

### 输入/输出案例 5.7

| 状态 | AIG/MULT 节点 |
|------|---------------|
| CSE 前 | 2 份乘法锥 |
| CSE 后 | 1 份，fanout=2 |

**边界**：`dont_touch` 乘法宏 **不参与** 跨实例 CSE。

### 5.8 Datapath 重组（技术无关）

在 **算术壳层**（不进 AIG 拆解，与 §5.6 边界一致）还有两类粗粒度重组：

**① CSA 树提取（carry-save）**：多操作数加法链改为「进位暂存 + 末级一次进位传播」。

```text
sum = a + b + c;

重组前：  ADD(a,b) ──► ADD(·,c)        — 2 次完整进位传播（2 个慢加法器串联）
重组后：  CSA(a,b,c) ──► ADD(carry,save) — 1 级 3:2 压缩（快）+ 1 次进位传播
```

**② Operator merging**：相邻运算融合为单一 datapath 块，让 CSA/Booth 在 **更大窗口** 内全局重组（如 `a*b + c` 融合为 MAC——部分积与 c 一起进压缩树，省一次独立进位传播）。

| 重组 | 输入形态 | 输出形态 | 收益 |
|------|----------|----------|------|
| CSA 提取 | ADD 链（≥3 操作数） | CSA 树 + 1 个末级 ADD | 进位传播次数 N−1 → 1 |
| Operator merging | `* 后跟 +/−` 等模式 | 单一 MAC/融合块 | 消除中间完整结果 |

**与 §5.7 CSE 的关系**：CSE 是「**少算**几份相同子式」，datapath 重组是「同一份算式 **换更快的算法结构**」— 两者都在算术壳层、都先于 04 的门级拆解（拆成具体 AND/XOR 门属 [04](./04-technology-mapping.md)/[02 §6](./02-inference.md#6-乘法器--除法器--移位器推断) 实现选择）。

### 输入/输出案例 5.8 — `a+b+c` 的 CSA 重组

| 指标 | 重组前（2 级 ADD） | 重组后（CSA + ADD） |
|------|---------------------|----------------------|
| 进位传播次数 | 2 | 1 |
| 关键路径（32 位，示意） | ~2×T_add | ~T_csa + T_add ≈ 1.1×T_add |
| 面积 | 2 个加法器 | CSA 阵列 + 1 个加法器（略小或相当） |

**触发条件**：操作数 ≥3、同一表达式树内、无中间结果被外部引用（否则需保留可观测点，LEC 注意）。

### 输入/输出案例 5.8 — 整模块优化前后（示意）

| 指标 | Elaborate 后 | 粗优化后 |
|------|----------------|----------|
| AIG nodes | 12,000 | 8,500 |
| AIG level | 18 | 14 |
| GTECH_MUX | 200 | 0（已布尔化） |

---

## 6. 与 ABC 流程对照

```text
strash → rewrite → refactor → balance → map
```

### 输入/输出案例 6.1 — ABC pass 对照

| ABC pass | 综合器内部（概念） |
|----------|-------------------|
| `strash` | 结构性 dedup |
| `rewrite` | 小窗 NPN 替换 |
| `refactor` | 大窗重组 |
| `balance` | depth 平衡 |
| `map` | [04](./04-technology-mapping.md) technology mapping |

**开源对照**：ABC 的 `strash/rewrite/…/map` 与上表 pass **同名或等价**；用于验证算法理解，非综合 flow 必需。

### 输入/输出案例 6.1b — strash 可观测

`comb_dup.sv` 经 strash 后，`(a&b)` 在 AIG 中 **仅 1 个 AND 节点**，fanout=2。

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
| AIG+strash | 2×AND + inv 边（`(a&b)` 共享 fanout=2；OR 为反相 AND） |
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

### 案例 H：粗优化在 DB 上的「指纹」

| 内部量 | 粗优化前 | 粗优化后 | 含义 |
|--------|----------|----------|------|
| AIG node count | 12k | 8.5k | strash/rewrite 生效 |
| AIG max level | 18 | 14 | balance/refactor 生效 |
| GTECH_MUX 实例 | 200 | 0 | 已布尔化进 AIG |
| 映射前 area 估计 | — | ↓ | 尚未 bind 单元，但结构已瘦 |

→ 索引见 [07 章](./07-synthesis-reports.md#2-用内部量判断还在哪一阶段)。

---

## 12. 案例自测（内部对照）

对照 `examples/aig_walkthrough/`，在纸上追踪 **IR 变化**（无需跑工具）：

| 文件 | 应观察到 |
|------|----------|
| `comb_dup.sv` | strash 后 AND 节点 **减半**（§4.1） |
| `comb_const.sv` | 常量传播后子锥 **折叠为 tie**（§4.2） |
| `comb_mux.sv` | MUX lowering 为 AND+OR 结构（§3.1） |
| `reg_comb_boundary.sv` | 加法器保持 **算术壳**，不进 AIG 拆解（§3.3） |

---

## 下一节

- [04 工艺映射](./04-technology-mapping.md)
- [06 细粒度优化](./06-timing-driven-optimization.md)
- [examples/aig_walkthrough/](./examples/aig_walkthrough/)
