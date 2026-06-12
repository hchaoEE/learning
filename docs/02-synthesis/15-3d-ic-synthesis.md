# 2.15 三维集成电路综合 — 跨 Die 时序与 transform

> **本章回答**：3D/Chiplet 设计中，综合器如何把「跨 die 路径」纳入 timing graph 与 transform 闭环。  
> **读完应能**：① 区分 TSV/凸点/interposer 弧 ② 说清跨 die 路径为何不能单靠 upsize ③ 列出分 die 交付物  
> **先修**：[06](./06-timing-driven-optimization.md)、[07](./07-internal-sta-and-qor.md)、[11](./11-hierarchical-block-synthesis.md) · **难度**：★★★★☆ · **walkthrough**：[3dic_walkthrough](./examples/3dic_walkthrough/)

本章讲 **Design DB / timing graph / 06 transform** 在 **多 die 集成** 下的扩展语义，不是 3D 封装布线或 Tcl flow 教程。TSV 物理实现、叠 die 真布线见 [03-pnr](../03-pnr/)。

> 配套案例：[examples/3dic_walkthrough/](./examples/3dic_walkthrough/)（两 die chiplet：RTL → DB 对象 → 跨 die slack → 06 决策）

---

## 1. 在流程中的位置
> **一句话**：映射与 06 迭代中，在物理分区已知时叠加跨 die 延时层，形成「每 die 局部闭环 + 顶层 inter-die STA」。
> **类比**：像多机分布式系统：每台机器内部调度（单 die 06），机间 RPC 延时固定（TSV/凸点弧）不可靠本地加 CPU 消除。

### 1.1 三种集成形态（综合视角）

| 形态 | 连接方式 | 综合主要建模 |
|------|----------|--------------|
| **真 3D（TSV stack）** | 上下 die 垂直 TSV | `tsv_port` 弧 + 各 die 独立 floorplan |
| **2.5D（interposer）** | 硅中介层 + microbump | `interposer_net` 弧（线长估计） |
| **Chiplet MCM** | 基板/封装上多 die | `bump_pin` + 封装 RC 表；常等同 2.5D 建模 |

三种形态在 DB 里 **统一为 inter-die 弧**；差别在延时表来源与是否允许 interposer repeater。

### 1.2 在 compile 时间线中的位置

```text
单 die（主链）:
  04 映射 → 06 transform ⇄ 07 STA → 收敛

多 die（概念叠加）:
  每 die: 04 → 06_die_i ⇄ 07_die_i
  顶层 glue: 读 die abstract + inter-die 弧 → 07_top → 06_top（仅 glue + 接口 cell）
```

跨 die 延时层通常在 **映射后、06 迭代中/后** 启用：需要 **die 分区**（或粗 floorplan）才能标注 TSV/凸点 RC。分区未知时，综合只能用 **保守固定延时** 占位，PnR 后再收紧。

### 1.3 单 die vs 多 die 闭环（ASCII）

```text
┌─── die0 ───────────────────┐     ┌─── die1 ───────────────────┐
│  FF → comb → [bump_out]    │     │  [bump_in] → comb → FF     │
│       ↑ 06 可改 cell/net   │     │       ↑ 06 可改 cell/net   │
└────────────┬───────────────┘     └──────────────┬─────────────┘
             │  inter-die arc（TSV/bump/interposer）│
             │  06 一般不可改 delay，仅可插 interface repeater
             └──────────────────────────────────────┘
```

### 输入/输出案例 1.1 — 形态选型对 STA 的影响

**输入**：同一 RTL glue，两种物理方案。

| 方案 | 关键弧 | 初算 WNS | 06 首选手段 |
|------|--------|----------|-------------|
| TSV 3D stack | `tsv_arc` = 0.15 ns 固定 | −0.08 | retime / 降频；upsize 无效 |
| 2.5D interposer | `interposer_net` = f(length) | −0.05 | 缩短估计线长 + glue upsize |

**输出**：形态不同 → **瓶颈弧类型不同** → 06 日志分支不同（见 §5）。

---

## 2. Design DB 扩展：Die / 接口对象
> **一句话**：在 Design DB 上为 die、凸点、TSV 与跨 die 网表对象打标签，并与 11 章 block shell 对齐。

读表前须知：下列为 **概念字段**（工具名各异），用于理解 timing graph 如何绑定物理分区。

### 2.1 核心 DB 对象

| 字段 / 对象 | 含义 | 与 11 章关系 |
|-------------|------|--------------|
| `die_id` | 实例/网所属 die | 类似 **partition id**；可与 block 1:1 |
| `region` | die 内粗 floorplan 区 | 影响 on-die 物理估计（[06 §6](./06-timing-driven-optimization.md#6-物理感知内部)） |
| `bump_pin` | 凸点电气连接点 | 块 **边界 pin** 的物理实现 |
| `tsv_port` | 垂直穿透连接 | 仅真 3D；常 **不可插普通 buffer** |
| `inter_die_net` | 跨 die 逻辑网 | 在 timing graph 上拆成 **多段弧** |

### 2.2 Block 与 Die 的映射规则

| 情况 | 综合策略 |
|------|----------|
| 1 block → 1 die | **推荐**；与 [11 bottom-up](./11-hierarchical-block-synthesis.md#2-两种策略的内部差异) 一致 |
| 1 block 跨 2 die | 综合常 **报错或强制切分**；需 RTL/人工 partition |
| 顶层 glue only | 仅含 **接口逻辑 + repeater**；主体在各 die DB |

### 输入/输出案例 2.1 — RTL glue → DB 对象表

**输入**（见 [chiplet_top.sv](./examples/3dic_walkthrough/chiplet_top.sv)）：`die0_compute` 与 `die1_mem` 经 `die_bus` 连接。

**输出（DB 片段，概念）**：

| RTL 层次 | die_id | 边界对象 |
|----------|--------|----------|
| `u_compute/*` | `D0` | `bump_out[15:0]` |
| `u_mem/*` | `D1` | `bump_in[15:0]` |
| `die_bus[*]` | — | `inter_die_net` + `tsv_arc` / `bump_arc` |

---

## 3. 跨 Die Timing Graph
> **一句话**：在 [07 §2](./07-internal-sta-and-qor.md#2-timing-graph-数据结构) 的 pin/arc 模型上增加 inter-die 弧，AT/RT 传播规则与 on-die 不同。
> **类比**：像跨数据中心链路：本机网卡队列可调（on-die 06），光缆时延（TSV）是常数项。

### 3.1 弧类型扩展

| 弧类型 | 延时来源 | 06 可改性 |
|--------|----------|-----------|
| on-die cell arc | `.lib` NLDM | 同 [06 §2](./06-timing-driven-optimization.md#2-细粒度优化引擎内部) |
| on-die net arc | WLM / 物理估计 | buffer、upsize driver |
| microbump / C4 | 封装/凸点 RC 表 | **否**（工艺/封装给定） |
| TSV | 工艺 TSV 模型（R,C, 耦合） | **否** |
| interposer 线 | 2.5D 线长 + 层 RC | **有限**（仅 interface repeater 行） |

### 3.2 传播规则要点

- **跨 die 边不使用单 die WLM**：`inter_die_net` 的 delay 来自 **独立表或 SPEF 占位**，与 fanout 无简单线性关系。
- **Clock**：各 die 可挂 **独立 propagated skew**；跨 die 路径上的 clock **uncertainty** 常更大（见 [05 §2](./05-constraints-sdc.md) 消费语义）。
- **MCMM**：每 die 可有 **不同 .lib / corner**；顶层 STA 须在 **对齐的 corner 名** 下合并 QoR（指针 [05 §6](./05-constraints-sdc.md)、[13 §2](./13-deliverables-and-handoff.md)）。

### 输入/输出案例 3.1 — 5 节点跨 die 小图推演

**路径**：`reg_a/Q (D0) → u1/Z → bump_out → [TSV] → bump_in → u2/Z → reg_b/D (D1)`

| pin / 弧 | delay (ns) | AT（forward, max） |
|----------|------------|---------------------|
| clk→reg_a/Q | 0.10 | 0.10 @ reg_a/Q |
| u1/Z | 0.20 | 0.30 |
| bump_out→bump_in (TSV) | **0.18** | 0.48 |
| u2/Z | 0.15 | 0.63 |
| reg_b/D | setup 0.08, period 1.0 | RT = 0.92 |

**slack_setup @ reg_b/D** = 0.92 − 0.63 = **+0.29**（示意满足）。

若 TSV 增至 0.35 ns：AT = 0.80 → slack = **+0.12**；再增则变负 — **瓶颈在固定弧**，非 u2。

---

## 4. SDC 语义（消费视角）
> **一句话**：跨 die 端口按特殊 IO 消费 SDC；约束编译后落在 bump/TSV pin 的 check 上。
> **类比**：像 k8s Ingress：对外仍用 `set_input_delay`，但后端 endpoint 是 bump 而非 package pin。

本章 **不重复** [05](./05-constraints-sdc.md) 语法；只写综合器 **内部绑定**。

| SDC 构造 | 跨 die 用法 |
|----------|-------------|
| `set_input_delay` / `set_output_delay` | 绑定到 **bump_pin**（相对 die 内 clock） |
| `create_clock` | 每 die 独立 clock 定义；顶层 glue 用 **generated / propagated** |
| `set_clock_groups -asynchronous` | die 间异步域（含测试模式） |
| `set_false_path` | die 间 **非功能路径**（JTAG、扫描旁路） |
| `set_max_delay` | chiplet **纯组合捷径** 跨 die |

**初学者易错**：把 die 间 reg2reg 当普通 on-die 路径狂 upsize — 瓶颈常在 **TSV/interposer 固定弧**；日志应显示「transform 对 inter-die arc 无效应」，应转 retime、架构切分或降频。

### 输入/输出案例 4.1 — bump 上的 input_delay

**输入**（见 [inter_die.sdc](./examples/3dic_walkthrough/inter_die.sdc)）：

```tcl
create_clock -name clk_d0 -period 1.0 [get_ports clk_d0]
set_input_delay 0.25 -clock clk_d1 [get_pins u_mem/bump_in[*]]
```

**输出（内部）**：`bump_in` 上绑定 **required** 壳；与 die1 内 `reg_b` setup 共同决定跨 die 路径 check。

---

## 5. 06 Transform 在 3D 上下文中的约束
> **一句话**：跨 die 关键路径上，upsize/buffer 无法消减 TSV 固定延时；引擎转 retime、接口 repeater 或人工。
> **类比**：像修网络延迟：加本机 CPU 救不了跨洋光缆 RTT。

### 5.1 失效与仍有效的 transform

| Transform | on-die | 跨 die 瓶颈在 TSV |
|-----------|--------|-------------------|
| upsize / VT swap | ✓ | **对 TSV 弧无效应** |
| buffer insert | ✓（net 拓扑） | 仅 **interface cell 行** 合法 |
| retiming | ✓（见 [06 §8](./06-timing-driven-optimization.md#8-retiming寄存器搬移--流水线重平衡)） | ✓ 若未 `dont_retime` |
| remap（04 局部） | ✓ | 不改变 TSV 延时 |

### 5.2 Die 边界 repeater 规则

```text
允许：在 bump_in 前一级 **专用 interface BUF**（工艺库中 repeater cell）
禁止：在 TSV 模型内部「虚拟插 buffer」
```

FIFO / 握手接口应标 **`dont_retime` + `dont_touch`**，避免 retime 破坏跨 die 协议（与 [06 §8.3](./06-timing-driven-optimization.md#83-内部控制属性) 一致）。

### 5.3 与 06 §6 物理感知

物理感知在 3D 场景增加 **die 间线长/拥塞权重**：

| 估计量 | 影响 |
|--------|------|
| interposer 线长 | 更新 `interposer_net` delay |
| bump 密度 | 限制 interface repeater 数量 |
| die 厚度/TSV 计数 | 更新 TSV RC（仍不可 sizing） |

仍为 **估计**；签核以封装/PnR 后寄生为准。

### 输入/输出案例 5.1 — TSV 弧导致 sizing 无效

**输入**：WNS = −0.12 ns；路径分解：on-die = −0.02，**TSV = −0.10**。

| 轮次 | Transform | ΔWNS | 引擎判定 |
|------|-----------|------|----------|
| 1 | upsize u2 | +0.02 | 接受，仍负 |
| 2 | upsize u1 | +0.02 | 接受，仍负 |
| 3 | upsize driver on TSV | **0** | **skip：arc 不可改** |
| 4 | retime 插入 FF | +0.15 | 接受，WNS +0.05 |

**输出日志（概念）**：`bottleneck arc type=TSV non_transformable → try retime`。

---

## 6. 分 Die 综合与 Interface Abstract
> **一句话**：每 die 独立 compile 并 characterize abstract，顶层 glue 读壳 + inter-die 弧闭时序。
> **类比**：像 11 章 budget 借贷，但「借 slack」要付 **物理距离利息**（inter-die 弧计入 borrow 成本）。

### 6.1 推荐流程

```text
1. die0: elaborate → compile → export netlist_d0 + abstract_d0 + block_sdc_d0
2. die1: 同上 → netlist_d1 + abstract_d1 + ...
3. top glue DB: 实例化 die0_shell, die1_shell + inter-die 弧注解
4. top compile: 仅优化 glue + interface repeater；读各 die abstract
5. 若顶层 WNS 负 → 迭代：回 die_i 收紧 budget 或改 RTL 切分
```

机制细节见 [11 §3](./11-hierarchical-block-synthesis.md#3-子块交付的内部产物)、[11 §4](./11-hierarchical-block-synthesis.md#4-时序预算budget传播)。

### 6.2 MCMM 与多工艺 die

| 场景 | 内部处理 |
|------|----------|
| 同工艺两 die | 共享 corner 名，inter-die 表按 corner 缩放 |
| 异工艺（logic + memory die） | **分 .lib**；顶层 MCMM = die0_corners × die1_corners 的 **合法子集** |
| 签核 | [13 §2](./13-deliverables-and-handoff.md) corner 锁步 + stack manifest |

### 输入/输出案例 6.1 — abstract 更新驱动顶层 WNS

**输入**：die0 `abstract_d0` 中 `bump_out` max_delay 自 0.30 → **0.38 ns**（die0 内路径恶化）。

| 视角 | WNS 变化 |
|------|----------|
| die0 单 die STA | −0.08（本地违例） |
| 顶层（读新 abstract） | **−0.10**（跨 die 路径更长） |
| 顶层 06 | 仅能修 glue；需 **回 die0 重 compile** 或放宽 budget 谈判 |

---

## 7. 交付与签核（3D 增项）
> **一句话**：在 [13 §1](./13-deliverables-and-handoff.md#1-标准交付清单) 最小包上，增加 per-die 网表、bump 映射与 stack manifest。

| 增项 | 内容 | 消费方 |
|------|------|--------|
| **per-die netlist + SDC** | 各 die 独立 mapped 网表 | 各 die PnR |
| **bump/TSV 映射** | logical net ↔ bump 坐标/编号 | 封装、物理验证 |
| **stack manifest** | die 顺序、朝向、revision 锁步 | 全流程版本对齐 |
| **inter-die timing abstract** | 块边界 + inter-die 弧参数 | 顶层 STA / 系统签核 |

### 7.1 与 09 UPF、12 DFT 的指针

| 主题 | 本章边界 |
|------|----------|
| **多 die 电压域** | isolation 插入见 [09 §2](./09-low-power-synthesis.md)；综合仅见 **UPF 绑到 die 边界 pin** |
| **Scan 跨 die** | 链顺序、lockup 见 [12 §3](./12-dft-and-scan.md)；die 间路径常需 **额外 lockup FF** |

### 输入/输出案例 7.1 — stack manifest 片段

**输入**：`release/chip_v2.0/stack_manifest.yaml`（概念）

```yaml
dies:
  - id: D0
    netlist: blocks/die0/chip_d0.mapped.v
    sdc: blocks/die0/chip_d0.sdc
    revision: die0@abc123
  - id: D1
    netlist: blocks/die1/chip_d1.mapped.v
    revision: die1@def456
stack_order: [D0, D1]
bump_map: bump_map.tsv
```

**输出**：PnR/封装用 manifest 校验 **revision 一致**；缺 `bump_map` → 物理与逻辑 **无法对齐**。

---

## 知识点清单（自检）

- [ ] 能区分 TSV / microbump / interposer 三类弧（[§3.1](#31-弧类型扩展)）
- [ ] 能解释为何 TSV 弧上 upsize 无效（[§5.1](#51-失效与仍有效的-transform)）
- [ ] 能画单 die vs 多 die 06 闭环（[§1.3](#13-单-die-vs-多-die-闭环ascii)）
- [ ] 知道 `die_id` / `bump_pin` / `inter_die_net` 含义（[§2.1](#21-核心-db-对象)）
- [ ] 能说明跨 die SDC 绑定到 bump 而非 package pin（[§4](#4-sdc-语义消费视角)）
- [ ] 能复述 per-die compile → abstract → top glue 流程（[§6.1](#61-推荐流程)）
- [ ] 能列出 3D 交付增项四类（[§7](#7-交付与签核3d-增项)）
- [ ] 完成 [3dic_walkthrough](./examples/3dic_walkthrough/README.md) 对照表

---

## 8. 小结
> **一句话**：3D IC 综合 = 在 06/07 闭环上叠加不可随意改变的 inter-die 弧，并用 11 式分 die abstract 交付。

跨 die 时序的本质是：**on-die 仍可 transform，die 间多为固定延时**。综合器职责是 **正确标注、正确闭时序、正确分包**；TSV 物理实现与叠 die 布线不属于本章。

---

## 下一节

- [11 层次化分块](./11-hierarchical-block-synthesis.md)
- [13 交付](./13-deliverables-and-handoff.md)
- [06 细粒度优化](./06-timing-driven-optimization.md)
- [00 总览](./00-synthesis-overview.md)
