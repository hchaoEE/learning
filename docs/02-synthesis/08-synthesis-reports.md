# 2.8 综合报告解读与内部量索引

`compile` 各阶段在 Design DB 上留下 **可观测的内部量**；报告只是这些量的 **格式化输出**。本章讲两件事：**「看到什么变化 → 对应哪条 pass / 哪一章」** 的索引（§1–§3），以及 **报告的内部解剖** — 时序路径行、面积分项、功耗分项分别由 DB 里哪些数据聚合而来（§4–§6）。**不是** 工具报告命令教程。

> 时序量的 **产生机制**（timing graph、AT/RT、QoR 聚合）见 [07 内部 STA](./07-internal-sta-and-qor.md)；约束语义见 [05](./05-constraints-sdc.md)；transform 见 [06](./06-timing-driven-optimization.md)。  
> 签核仍依赖 STA/LEC 等外部工具；此处只说明 **综合器内部在优化什么**。

---

## 1. 内部量 ↔ 章节 ↔ pass 阶段

| 内部量（概念） | 典型变化时机 | 章节 | 说明 |
|----------------|--------------|------|------|
| GTECH 节点数 | elaboration 后、03 粗优化后 | 01、03 | 仍无 `.lib` 单元名 |
| AIG node / level | 03 strash、rewrite、balance | 03 | 映射前布尔 IR |
| `resource_type` 计数 | 02 推断 | 02 | REG/LATCH/RAM/MULT 标签 |
| Mapped instance 数 | 04 cover 绑定 | 04 | 出现 `ND2D*`、`DFF*` 等 |
| Buffer/INV 占比 | 06 插 buffer、hold 修 | 06 | 细粒度指纹 |
| **WNS / TNS** | 04 初 STA、06 迭代 | **07 §6** | endpoint slack 聚合 |
| Hold worst slack / THS | 06 min corner | 07 §6、06 §4 | 与 setup 可能冲突 |
| Unconstrained endpoint 数 | 05 约束读入后 | 07 §5、05 §8 | 不进 WNS 桶的沉默漏洞 |
| Transition/cap 违例数 | 06 DRC 修复 | 05 §7、06 §5 | 电气 limit |
| ICG 实例数 | 02 推断 + 09 意图 | 02 §9、09 | `CKLN*` 等 |
| LS/ISO 实例数 | 09 UPF 标注后映射 | 09 | 跨电压边界 |
| Compare point 数（LEC） | 10 签核 | 10 | 非 compile pass 产物 |

---

## 2. 用内部量判断「还在哪一阶段」

| 观测 | 推断阶段 | 下一步读 |
|------|----------|----------|
| 网表仅有 `GTECH_*` | elaboration 后、未映射 | 01、02 |
| 有 AIG 统计、无 lib 单元 | 03 中、未 04 | 03 |
| 出现库单元名，WNS 很粗 | 04 刚结束 | 04、05 |
| buffer 数激增、slack 阶梯改善 | 06 迭代中 | 06 |
| 寄存器数变、组合段变短 | 06 retiming | 06 §8 |
| LATCH 标签存在 | 02 推断 | 02、RTL |

### 输入/输出案例 2.1 — 三个 DB 快照定位阶段

**输入**（同一设计的三个内部量快照）：

| 快照 | GTECH 组合 | AIG node | 库单元 | buffer 占比 | WNS |
|------|-----------|----------|--------|-------------|-----|
| S1 | 9,400 | — | 0 | — | — |
| S2 | 0 | 8,500 | 0 | — | — |
| S3 | 0 | — | 6,800 | 11% | −0.04 |

**输出（判断）**：S1 = 01/02 之后、03 之前；S2 = 03 进行中（已布尔化、未绑库）；S3 = 06 迭代中（buffer 占比已升、WNS 接近闭合）。

---

## 3. 违例诊断：决策树 + 引擎分支索引

```text
                    内部违例标签
                          │
        ┌─────────────────┼─────────────────┐
        ▼                 ▼                 ▼
   setup_violation   hold_violation    no_clock
        │                 │                 │
        ▼                 ▼                 ▼
     06 §3 sizing     06 §4 delay      05 §2 clock
     buffer/retime    capture前delay   对象解析
        │                 │
        └────────┬────────┘
                 ▼
        仍负？→ 05 period/IO budget
                 或 RTL 架构
```

| 内部违例标签 | 根因（机制） | 引擎分支 / 先读 |
|--------------|--------------|------------------|
| `setup_violation` | 数据路径太慢（max corner）：组合过深、驱动弱 | 06 §3 sizing/buffer；§8 retiming |
| `hold_violation` | 数据太快（min corner）、过强驱动 | 06 §4 delay |
| `transition_violation` | slew 超限：fanout 过大、弱驱动 | 06 §5 buffer tree |
| `cap_violation` | 负载电容超限 | 06 §5 |
| `no_clock` | SDC 未绑 clock | 05 §2、§8 |
| `unconstrained_path` | 例外缺失、CDC 无 groups、SDC 对象未解析 | 05 §4、§8；[07 §5](./07-internal-sta-and-qor.md#5-路径分组与-endpoint-桶) |

机制细节以 [06 §3–§5](./06-timing-driven-optimization.md) 为准，本表仅作索引。→ 与 [00 §7 pass 表](./00-synthesis-overview.md#7-compile-内部-pass-时间线全景) 对照。

**读违例数字前先分桶**：全局 WNS 可能来自 IO 桶（预算假设值），与 reg2reg 桶的真实瓶颈是两回事 — 桶语义见 [07 §5](./07-internal-sta-and-qor.md#5-路径分组与-endpoint-桶)。

### 输入/输出案例 3.1 — 从标签到分支

**输入**（违例扫描器输出，概念）：

```text
endpoint reg_q/D : setup_violation  slack=−0.10  (slow_max)
net n123         : transition_violation  slew=0.42 > limit 0.30
```

**输出（引擎排队）**：先修 `n123` DRC（slew 超限时 delay 表外推不可信，见 06 §5.1），再进 06 §3 sizing 修 setup。

---

## 4. 关键路径报告解剖

时序报告的「一条路径」是 [07 §3](./07-internal-sta-and-qor.md#3-at--rt-传播算法) 传播结果的 **切片回放**：从违例 endpoint 沿 **AT 最大的入边** 反向回溯到 launch 点，再把每段弧的 delay 逐行打印。

```text
  launch 段           data path（逐弧累加 = AT）         capture 段（算 required）
┌────────────┐   ┌──────────────────────────────┐   ┌──────────────────────────┐
│ clk 沿 0.00 │──►│ reg_a CK→Q   +0.12  AT=0.12  │   │ clk 下一沿        1.00   │
│ (ideal: 网络 │   │ u1 A→ZN     +0.18  AT=0.30  │   │ − setup           −0.08  │
│  延时 = 0)  │   │ …            …               │   │ − uncertainty     −0.05  │
└────────────┘   │ net→reg_q/D +0.05  AT=1.02  │   │ required        = 0.87   │
                 └──────────────────────────────┘   └──────────────────────────┘
                          slack = required − AT = 0.87 − 1.02 = −0.15
```

| 报告字段（概念） | DB 来源 | 章节 |
|-------------------|---------|------|
| 每行 cell delay | NLDM 查表结果（含当时 slew/load） | 04 §3.1 |
| 每行 net delay | WLM / 物理估计 | 06 §2.2 |
| clock 网络延时 = 0 | ideal clock | 05 §2.2、07 §4.3 |
| uncertainty 扣减 | SDC 属性，落在 required | 05 §9.2 |
| path group 归属 | endpoint 桶 | 07 §5 |

**读报告的机制要点**：

- 报告只展示 **worst 一条**；同 endpoint 可能有多条接近路径 — 06 修掉这条后下一条「浮上来」，slack 改善呈阶梯状
- 每行 delay 依赖 **上一行的输出 slew** — 单独换某一级单元，下游所有行的数字都会变（07 §8 slew 扩散）
- launch/capture 用 **不同 corner 数据**（OCV 模式）时两段不能直接相加对比

### 输入/输出案例 4.1

**输入**：06 案例 2.1 的 5 级 ND2 链（WNS = −0.10）。

**输出（路径报告，概念格式）**：

| 行 | 点 | incr | AT |
|----|----|------|-----|
| 1 | clk（launch 沿） | 0.00 | 0.00 |
| 2 | reg_a/Q（CK→Q） | +0.12 | 0.12 |
| 3–7 | u1–u5/ZN | +0.18×5 | 1.02 |
| 8 | reg_q/D（net 并入） | +0.00 | 1.02 |
| — | required（1.00 − 0.08 setup） | | 0.92 |
| — | **slack** | | **−0.10** |

逐行与 06 §2 的 delay 表一一对应 — 报告不产生新信息，只是 graph 标注的投影。

---

## 5. 面积报告内部构成

面积不是单一数字；DB 按 **单元角色** 分项累加（`.lib` 的 cell area × instance 数）：

| 分项 | 内容 | 主要产生 pass |
|------|------|----------------|
| Combinational | 普通组合单元 | 03/04 |
| Sequential | FF/latch（含 multibit、retention） | 02 推断 → 04 映射 |
| Buffer/INV | 修时序/DRC 插入 | **06**（指纹） |
| Clock network | ICG、clock buffer（综合期少量） | 02 §9、09 |
| 特殊单元 | ISO/LS/PSW/retention | 09 UPF |
| 黑盒/宏 | RAM、IP 硬宏（面积来自 LEF/lib） | 02 §5 |

**Pass 指纹**（版本间面积突变的反推）：

| 观测 | 推断 |
|------|------|
| Buffer/INV 占比 5% → 15% | 06 大量修 hold/DRC（或 WLM 悲观） |
| Sequential ↑ 组合 ↓ | retiming（06 §8）或流水插入 |
| Sequential ↓ | 寄存器级优化（02 §10）或 multibit banking（06 §2.7） |
| 特殊单元从 0 → N | UPF 首次生效（09） |
| Combinational 骤降、功能不变 | 03 粗优化生效或 `dont_use` 放开 |

### 输入/输出案例 5.1

**输入**：两版 compile 面积分项（μm²，示意）：

| 分项 | v1 | v2 |
|------|----|----|
| Combinational | 5,200 | 5,150 |
| Sequential | 1,800 | **1,560** |
| Buffer/INV | 410 | 395 |
| Clock network | 220 | **150** |

**输出（指纹判读）**：Sequential 与 clock network 同时下降、组合几乎不变 → **multibit banking**（06 §2.7：FF 合并 + CK pin 减少），而非寄存器删除（那会连带组合锥变化）。

---

## 6. 功耗报告聚合与可信度

综合期功耗报告 = 对每个 net/cell 求和（机制见 [09 §6](./09-low-power-synthesis.md#6-早期功耗估计内部量)）：

```text
P_dynamic = Σ_net ( toggle_rate × C_net × V² ) + Σ_cell internal_power(slew, load)
P_leakage = Σ_cell leakage(VT, state)
```

| 分项 | 来源 | 可信度（综合期） |
|------|------|------------------|
| 动态-clock network | clock toggle = 确定（每周期 2 翻转） | **较高** — ICG 收益评估可用 |
| 动态-data | toggle 来自 **默认活动度或传播估计**（09 §6） | **低** — 无 SAIF 时仅相对比较 |
| Internal power | NLDM power 表查表 | 中 |
| Leakage | `.lib` 每 cell 常数（按 VT/state） | **较高** — VT 分布决策可用 |

**误读陷阱**：

- 无仿真活动度（SAIF）时，**绝对值不可签核**；只用于 **同一假设下的版本对比**（ICG 前后、VT 重分布前后）
- 动态功耗对 corner 电压平方敏感 — 跨 corner 对比必须同电压
- ICG 收益体现在 **clock network 分项**下降 + 被门控 FF 的 internal power 下降，data toggle 分项基本不动

### 输入/输出案例 6.1

**输入**：09 案例 3.x 的 ICG 改造前后（默认活动度）。

| 分项（相对值） | ICG 前 | ICG 后 |
|----------------|--------|--------|
| Clock network 动态 | 1.00 | **0.45** |
| FF internal | 1.00 | 0.62 |
| 组合 data 动态 | 1.00 | 0.98 |
| Leakage | 1.00 | 1.01（ICG 单元自身） |

**输出（判读）**：收益集中在 clock 分项 — 与机制一致，可信；若报告显示 data 动态大幅下降，先怀疑活动度假设变了而非优化生效。

---

## 7. QoR 对比（版本间）注意

对比两次 compile 内部结果时，须 **对齐**：

| 须一致 | 否则内部量不可比 |
|--------|------------------|
| SDC 语义（period、例外） | WNS/TNS 假变 |
| MCMM corner 集 | setup/hold 各看不同 corner |
| `.lib` / dont_use | 单元集变 |
| RTL 功能 | 非同一设计 |

---

## 8. 内部量与 LEC 的关系

| 内部量 | 含义 |
|--------|------|
| WNS ≥ 0 | **不保证** RTL↔网表等价 |
| 无意外 LATCH | **不保证** LEC pass（复位/常数/X） |
| 推断 RAM→macro | LEC 需 **memory 映射** 对齐 compare point |

签核：**时序（05–07 内部量）+ 本章报告 + [10 LEC](./10-logical-equivalence-checking.md)**。

---

## 9. 小结

本章 = **compile 仪表盘**：§1–§3 索引「量 → pass」，§4–§6 解剖「报告行 → DB 数据」。深入机制读 **07（STA 引擎）**、**05（约束图）**、**06（transform）**、对应 **walkthrough**。

---

## 下一节

- [05 SDC 内部](./05-constraints-sdc.md)
- [06 细粒度优化](./06-timing-driven-optimization.md)
- [10 LEC](./10-logical-equivalence-checking.md)
- [13 交付](./13-deliverables-and-handoff.md)
