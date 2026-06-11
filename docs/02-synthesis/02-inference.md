# 2.2 推断（Inference）：从 GTECH 到「该用什么硬件」

Elaboration / lowering 之后，网表里已有 **GTECH_FD*、GTECH_MUX、GTECH_MULT、GTECH_RAM** 等抽象节点，但工具尚未决定：这是 **工艺库里的哪种 DFF**、要不要 **SRAM 宏**、乘法器用 **硬宏还是门级阵列**、组合缺口是否 **Latch**。

**推断** 就是综合器在 **映射（mapping）之前或与之交织** 的阶段，对网表做 **模式识别 + 绑定策略**，把「行为等价的 GTECH 子图」归类为 **寄存器 / 锁存器 / 存储器 / 算术块 / 三态** 等 **架构级资源**，并附上 **时序弧、功耗、面积模型** 的来源（.lib 或 .lib + 宏 LEFr）。

> **范围**：ASIC；推断结果决定 **mapping 的候选单元集合**。本章不讲 SDC 如何修时序，讲 **内部认出了什么结构**。

**示例 RTL**：`examples/inference_walkthrough/`（与下文案例对应）。

---

## 1. 在综合流程中的位置

```text
GTECH 网表（elab / compile 早期）
        │
        ▼
┌───────────────────────────────────────┐
│  INFERENCE（本章）                     │
│  寄存器 / Latch / RAM / 乘除 / 三态   │
│  识别 + 约束检查 + 宏/单元策略         │
└───────────────────────────────────────┘
        │
        ▼
  AIG / 布尔优化（组合部分，见 [03 优化](./03-optimization.md)）
        │
        ▼
  工艺映射（绑定 .lib 单元或 DesignWare / 宏）
```

| 阶段 | 输入 | 输出 |
|------|------|------|
| Lowering（01 章） | RTL | `GTECH_SEQGEN`、`GTECH_LAT`、`GTECH_RAM` 等 **候选** |
| **推断（本章）** | GTECH + 属性 + 工艺策略 | **带资源类型标签** 的网表 + 推断报告 |
| Mapping（04 章） | 标签 + .lib | `DFFRX1`、`ram256x32`、`DW02_mult` 等 |

**与 Elaboration 的边界**：Elaboration 已可能标 `LATCH_INFER`；**推断** 做 **二次确认**、与工艺 **latch 单元是否允许**、**RAM 模板是否匹配** 联动。

---

## 2. 推断引擎在做什么（内部模型）

综合器维护一张 **模式库（inference rule set）**，对 Design DB 做 **子图同构 / 特征匹配**：

```text
遍历 cell / netlist
  对每个 GTECH_SEQGEN → 匹配 clock/reset/enable 拓扑 → 标 REGISTER
  对每个 GTECH_LAT   → 检查 enable 方程 → 标 LATCH（或强制改 MUX）
  对每个 GTECH_RAM   → 读/写端口时序 → 标 RAM_1R1W / 2P / ROM ...
  对每个 GTECH_MULT  → 位宽 + 流水线寄存 → 标 MULTIPLIER_IMPL
  对三态驱动        → 标 TRI_ENABLE
```

| 机制 | 说明 |
|------|------|
| **结构模式** | 如「MUX 反馈到自身 + 使能」→ latch |
| **过程语义回溯** | 保留 RTL 属性 `rtl_always_style` 等（工具私有） |
| **用户/策略约束** | 指定寄存器类型、RAM 实现、禁用 latch 单元等 DB 策略 |
| **工艺策略** | .lib 无 latch 单元 → 报错或自动改逻辑 |

推断 **一般不改变功能**，但可能 **插入硬件**（如读端口寄存器、时钟门控 ICG）——属 **推断 + 实现选择**，需在报告中可见。

### 输入/输出案例

**输入**（GTECH 片段）：

```text
GTECH_SEQGEN U1: .CK(clk) .D(d) .Q(q)
```

**输出**（推断后内部标签）：

```text
Cell U1: resource_type=REGISTER
         ff_style=DFF
         async_reset=none
         clock_enable=none
         mapped_candidate_cells={DFFX1, DFFRX1, ...}
```

| 输入 | 输出 |
|------|------|
| 未标注的 GTECH 原语 | 带 **resource_type** 与 **mapping 候选** 的 cell 属性 |

---

## 3. 寄存器（Flip-Flop）推断

### 3.1 识别来源

| 来源 | 内部路径 |
|------|----------|
| `always_ff` / 时序 `always` | Lowering → `GTECH_SEQGEN` / `GTECH_FD*` |
| 显式实例化 | `DFF` 仿真模型 → 直接映射（少见于 RTL） |

推断器读取 **SEQGEN 引脚拓扑**：

| 引脚模式 | 推断结果 |
|----------|----------|
| 仅 `.CK` + `.D` + `.Q` | 基本 DFF |
| `.CLR` / `.PRE` 异步有效 | 异步复位/置位 DFF |
| `.EN` 或 `.E` | 带 clock enable |
| `.SCD` / scan 相关 | 扫描链 DFF（DFT 流程） |

### 3.2 异步复位、使能、扫描

```systemverilog
always_ff @(posedge clk or negedge rst_n)
  if (!rst_n) q <= '0;
  else if (en) q <= d;
```

**推断输出**（概念）：

```text
REGISTER: async_reset=active_low, reset_pin=rst_n
          clock_enable=en, enable_polarity=active_high
```

**.lib 绑定**：只选带 **recovery/removal** 弧的 `DFFRX*`；STA 用 **异步复位路径** 单独约束。

### 3.3 多比特与总线

- **逐位推断** 或 **bus-FF 原语**：工具依位宽、扇出、功耗选 **bit-blast DFF** 或 **集成 bus 寄存器**。  
- **移位寄存器链**：若识别 SISO 链，可能合并为 **SRL**（部分 FPGA 流程；ASIC 多为 DFF 链）。

### 输入/输出案例

**输入**（`inference_walkthrough/reg_en.sv`）：

```systemverilog
always_ff @(posedge clk) begin
    if (en) cnt <= cnt + 1'b1;
end
```

**推断输出**（DB 字段示意）：

```text
Inferred register: cnt[7:0] (8 bits)
  Clock: clk
  Clock enable: en (integrated in cell CE pin)
  Cell candidates: DFFEQX*
```

| 输入 | 输出 |
|------|------|
| GTECH 带 EN 的 SEQGEN | 带 **CE pin** 的寄存器单元类，而非门控时钟 |

---

## 4. 锁存器（Latch）推断

### 4.1 何时产生

| RTL / GTECH 特征 | 推断 |
|------------------|------|
| `always_comb` 不完整 `if`/`case` | `GTECH_LAT` 或 MUX-feedback |
| 显式 `always_latch` | 直接 LATCH |
| 组合环 + 使能保持 | 可能报错而非 latch |

### 4.2 内部结构（组合缺口 → 电平敏感）

```systemverilog
always_comb
  if (en) q = d;
```

**GTECH / 推断示意**：

```text
en ──► GTECH_MUX2 ──► q
       ▲            │
       └── q (feedback) when !en
→ resource_type=LATCH, transparent_level=high|low
```

### 4.3 ASIC 策略

| 工艺库 | 推断行为 |
|--------|----------|
| 提供 `LH*` / `TLAT*` | 映射为 latch 单元；STA **time borrowing** |
| **禁止 latch**（常见高性能数字块） | 策略 `latch_inference=none` → **报错** 或强制 RTL 改 MUX+FF |
| 误推断 latch | 改 RTL 补 `else`；或前端 **full_case** 语义 |

### 输入/输出案例

**输入**（`inference_walkthrough/latch_infer.sv`）：

```systemverilog
always_comb begin
    if (hold) data_hold = bus_in;
end
```

**输出**：

```text
Warning: Inferred latch on signal data_hold[7:0]
  Enable: hold
  Avoid: use register if target library has no latch
```

| 输入 | 输出 |
|------|------|
| 不完整分支组合逻辑 | **LATCH** 标签 + 映射到 latch 单元或 **Error** |

---

## 5. 存储器（RAM / ROM）推断

### 5.1 从 RTL 到 GTECH_RAM

推断器不读「变量名」，而读 **端口图（port schedule）**：

| 行为 | 典型 GTECH 端口 |
|------|-----------------|
| 同步写 | `CLK`, `WA`, `DI`, `WE` |
| 同步读 | `CLK`, `RA`, `DO` |
| 异步读（组合读） | `RA` → `DO` 同周期组合路径 |

```systemverilog
logic [7:0] mem [0:255];
always_ff @(posedge clk) begin
    if (we) mem[wa] <= di;
    rdo <= mem[ra];
end
```

Lowering 后 → **1R1W RAM** 模板；推断判断 **读写是否同址同周期**（写优先 / 读旧 / 读新）。

### 5.2 推断分类（内部枚举）

| 类型 | 含义 | ASIC 常见去向 |
|------|------|----------------|
| `RAM_1P` | 单端口读写互斥 | SRAM 宏或 latch-array |
| `RAM_1R1W` | 独立读写口 | 双口 SRAM / register file |
| `RAM_2P` | 真双口 | 双口宏 |
| `ROM` | 只读、常数表 | ROM 宏或逻辑锥 |
| `REGISTER_ARRAY` | 深度小、位宽小 | 触发器阵列（非宏） |

### 5.3 与 Memory Compiler / 宏

| 步骤 | 输入 | 输出 |
|------|------|------|
| 推断 | GTECH_RAM 深度/宽度/端口 | `ram_block` 属性 |
| 策略 | 条件 | 结果 |
|------|------|------|
| Memory Compiler / 硬宏 | 深度×宽度 > 阈值、有宏 .lib | `implementation_target=sram_macro` |
| 寄存器阵列 | 深度小、位宽小 | `register_array` |
| 失败降级 | 异步读 + 无匹配宏 | 拆 FF + 组合读（area↑） |

### 5.4 RAM 实现决策树（内部）

```text
GTECH_RAM 推断完成
    │
    ├─ depth×width > T_macro ? ──Yes──► 绑 SRAM 宏（.lib 硬宏）
    │
    ├─ depth ≤ T_reg && sync 1R1W ? ──Yes──► register_array
    │
    ├─ 异步读 ? ──Yes──► 无宏则 拆寄存器+组合 或 报错
    │
    └─ ROM / 常量表 ? ──► logic cone 或 ROM 宏
```

### 输入/输出案例 5.4

**输入**：1024×32 sync 1R1W，`T_macro` 阈值 512×16

**DB**：`implementation_target=sram_macro`（或 register_array 若策略偏面积且 depth 可接受）。

---

### 输入/输出案例 5.5 — sync_ram.sv

**输入**（`inference_walkthrough/sync_ram.sv`）：

```systemverilog
logic [31:0] ram [0:1023];
always_ff @(posedge clk) begin
    if (we) ram[addr] <= wdata;
    if (re) rdata <= ram[addr];
end
```

**DB 快照**：

```text
Memory ram: depth=1024 width=32 ports=1R1W
  collision=write-first
  implementation_target=register_array | sram_macro
```

| 输入 | 输出 |
|------|------|
| 同步读写 always 块 | **深度×宽度** + **端口类型** + **碰撞语义** |

---

## 6. 乘法器 / 除法器 / 移位器推断

### 6.1 识别

| RTL | GTECH | 推断标签 |
|-----|-------|----------|
| `assign p = a * b` | `GTECH_MULT` | `MULTIPLIER` |
| `assign q = a / b` | `GTECH_DIV` | `DIVIDER`（常数除 → 移位树） |
| `assign s = a << 3` | shifter / rewiring | `CONST_SHIFTER` |

### 6.2 实现选择（推断 + mapping 交界）

| 策略 | 条件 | 结果 |
|------|------|------|
| DesignWare / 厂商 IP | 宽位、高性能 | `DW02_mult` 等 |
| 门级阵列 | 小位宽、面积优先 | AND-CSA 树映射到标准单元 |
| 流水线 | 多级 REG 包围 MULT | 推断 **pipeline_depth**，影响时序 |

### 输入/输出案例

**输入**（`inference_walkthrough/mult_16x16.sv`）：

```systemverilog
assign prod = a * b;   // a,b 为 16 位
```

**DB 快照**：

```text
Multiplier: 16x16 → 32b
  implementation: DW02_mult | generic_wallace
  estimated_area: (from IP model or gate count)
```

| 输入 | 输出 |
|------|------|
| `GTECH_MULT` + 位宽 | **乘法器实现类** + IP/门阵绑定 |

### 6.3 乘法器实现决策树（内部）

```text
GTECH_MULT (Wa × Wb)
    │
    ├─ Wa×Wb > T_ip ? ──Yes──► DesignWare / 厂商 MULT 宏
    │
    ├─ Wa×Wb ≤ T_gate ? ──Yes──► Booth/Wallace → 门级（03 不拆壳内）
    │
    ├─ 常数乘 ? ──Yes──► 移位+加法树（strength reduction）
    │
    └─ pipeline 标签 ? ──► 推断 pipeline_depth → 影响 04/06 时序
```

### 输入/输出案例 6.3

**输入**：16×16 无 pipeline

**DB**：`implementation=generic_wallace` 或 `DW02_mult`（依 `T_ip=8×8` 示意阈值）。

---

## 7. 三态与总线保持

| RTL | 推断 |
|-----|------|
| `assign pad = oe ? dout : 1'bz` | `TRI_STATE` → 映射 IO 单元 / 三态缓冲 |
| `inout` 端口 | 双向 pin + tristate enable |

ASIC **内核逻辑** 通常 **禁止三态**；三态多在 **PAD / 宏 IP** 边界。推断器对内核报 **Error** 或强制拆分方向。

### 输入/输出案例

**输入**：内核 `assign bus = en ? data : 'z;`

**输出**：`Error: Tristate not allowed in core logic` 或映射专用 `TBUF`（若库允许）。

---

## 8. 时钟门控（ICG）推断 — ASIC 低功耗

与 RTL 手写 `clk & en` 不同，**综合推断 ICG** 在 **register bank 的 clock 入口** 插入 **ICG 壳**（Integrated Clock Gating），再映射到 `.lib` 中的 `CKLN*` 等单元。

### 8.1 内部数据流

```text
02 推断识别 SEQGEN 簇（共享 clk、相似 enable 拓扑）
        │
        ▼
GTECH 层插入 ICG shell 节点
  输入：clk_in, enable（与 clock 同步的 gating 表达式）
  输出：clk_gated
        │
        ▼
SEQGEN[i].CK ← clk_gated（非原始 clk）
        │
        ▼
04 映射：ICG shell → CKLNQD* / 等效单元
```

| DB 字段（概念） | 含义 |
|-----------------|------|
| `gating_enable` | 从 D/EN 逻辑提取的 **同步** 使能 |
| `icg_candidate` | 满足 min_bits、拓扑检查的 bank |
| `clock_network` | 标记为 **不可门控** 的 network（如 async 控制） |

### 8.2 识别条件（启发式）

| 条件 | 原因 |
|------|------|
| 同一 `clk` 下 **多位寄存器** 共享 enable | 分摊 ICG 面积 |
| enable 仅来自 **同步逻辑**（同 domain FF 或 PI 同步采样） | 避免 clock 上 glitch |
| enable 在 clock **无效半周期** 稳定 | 工业 ICG cell 时序假设 |
| bank 位宽 ≥ 策略阈值 | 1-bit 门控常不划算 |

**不满足**：保持 **ungated clock** 接 SEQGEN；或 RTL 已用 `clock_enable` 风格仍由工具推断。

### 8.3 与 03/04/06 的边界

| 阶段 | ICG 相关 |
|------|----------|
| 03 AIG | **不处理** clock 网络（SEQ 边界外） |
| 04 映射 | bind ICG 壳到 **专用库单元** |
| 06 TDO | ICG→DFF 的 **setup/hold** 在 timing graph 上与普通 FF 相同 check |
| 08 UPF | 关断域内 **禁止门控** 或 **force ICG** 策略覆盖推断 |

### 输入/输出案例

**RTL**（`power_walkthrough/icg_bank.sv`）：

```systemverilog
always_ff @(posedge clk)
  if (en) q <= d;  // 32-bit bank
```

**推断后 GTECH**：

```text
clk ──► ICG(en) ──► clk_g ──► SEQGEN×32
```

**映射后**：1× `CKLNQD` + 32× `DFFX1`；无 ICG 时为 32× `DFFX1` 全接 `clk`。

**功耗模型（内部）**：`clk_g` net 的 toggle ∝ P(en) · toggle(clk)，非 100% 翻转。

→ 低功耗意图与多电压域见 [08 章](./08-low-power-synthesis.md)。

---

## 9. 推断与 Mapping 的交接

```text
推断结果 (cell attributes)
    ├── REGISTER  → map_to .lib DFF 族
    ├── LATCH     → map_to latch 或 transform
    ├── RAM       → map_to macro / registers
    ├── MULT      → map_to DW / gates
    └── COMB      → 进入 AIG 优化 + 标准单元映射
```

**`dont_touch` / `size_only`**：在推断后、映射前挂在 cell 上，阻止推断 **拆分** 或 **合并** 该宏。

### 输入/输出案例

**DB 属性**：`u_sram_macro.dont_touch = true`

**内部**：推断仍标 `RAM`；mapping pass **跳过拆解**，边界 pin 直接连宏。

---

## 10. 推断结果：内部可观测属性

推断完成后，Design DB 上可直接查询（概念字段）：

| 属性 / 计数 | 含义 | 异常时 |
|-------------|------|--------|
| `resource_type=REGISTER` 数 | FF 总量 | 与 RTL 预期不符 → 时钟/复位写法 |
| `resource_type=LATCH` 列表 | 锁存器 | 高性能块 **不应出现** |
| `resource_type=RAM` + depth/width | 存储器推断 | 深度过大 → 应用宏非 register array |
| `resource_type=MULT` + bitwidth | 乘法器 | 位宽过大 → 应绑 IP |
| `icg_candidate` 簇 | 可门控 bank | 0 个 → enable 拓扑不满足 |

### 输入/输出案例 10.1 — sync_ram 推断后 DB

**RTL**：`inference_walkthrough/sync_ram.sv`

**DB 快照（示意）**：

```text
Memory ram: depth=1024 width=32 ports=1R1W
  implementation_target = register_array   // 或 sram_macro（若策略绑定）
  write_style = sync
  read_style  = sync
```

| 字段 | 若与预期不符 |
|------|--------------|
| `implementation_target` | 检查宏链接 / 深度阈值策略 |
| `ports` | 异步读 → 可能拆成 FF+MUX |

### 输入/输出案例 10.2 — latch_infer

**RTL**：`latch_infer.sv`（组合缺 else）

**DB**：`resource_type=LATCH` 出现在 `u_latch`；**无** `SEQGEN(FF)` 替代。

→ 索引 [07 §1](./07-synthesis-reports.md#1-内部量--章节--pass-阶段) `LATCH 计数`。

---

## 11. RTL 写法 → 推断结果对照表

| RTL 模式 | 推断结果 | 风险 |
|----------|----------|------|
| `always_ff` + `<=` | DFF（+CE/AR） | 混用阻塞赋值 |
| `always_comb` 缺 else | Latch | 工艺无 latch |
| 同步单端口 RAM 模板 | 1R1W / 1P RAM | 异步读 → 拆寄存器 |
| `a * b` 大位宽 | 乘法器 IP/阵列 | 面积/延时 |
| 多驱动 `sum` | **非推断**，check 报错 | — |

---

## 12. 贯穿示例：对 walkthrough 设计做推断

对 [01 章](./01-rtl-parsing-and-elaboration.md) 的 `top`（`N=2`）在 **修复多驱动后** 推断预期：

| 模块/信号 | 推断 |
|-----------|------|
| `child.dout` | 8× REGISTER |
| `top.data_out`（补全 else 后） | 组合 MUX，无 latch |
| `top.sum` | 若仍双驱动 | **推断前** check 失败 |

**DB 快照（示意，单 child N=1）**：

```text
REGISTER count = 8        (child.dout)
LATCH count    = 0
RAM/MULT       = 0
check_design   = clean
```

→ 各 walkthrough RTL 的逐项 DB 字段见 [inference_walkthrough/README.md](./examples/inference_walkthrough/README.md)。

---

## 13. 小结

| 概念 | 要点 |
|------|------|
| **时机** | GTECH 之后、映射/AIG 之前（与 compile 交织） |
| **本质** | 对 GTECH 子图 **分类 + 打标签 + 选实现策略** |
| **寄存器** | SEQGEN 引脚 → DFF 族 |
| **Latch** | 组合缺口 / GTECH_LAT → 工艺是否允许 |
| **RAM** | 端口图 + 深度宽度 → 宏或寄存器阵 |
| **乘法器** | GTECH_MULT → IP 或门级 |

---

## 下一节

- [03 优化（AIG）](./03-optimization.md)
- [04 工艺映射](./04-technology-mapping.md)
- 回顾：[01 RTL 解析与 Elaboration](./01-rtl-parsing-and-elaboration.md)