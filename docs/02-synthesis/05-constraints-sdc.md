# 2.5 时序约束（SDC）

**SDC（Synopsys Design Constraints）** 是综合与 STA 的 **共同输入**：告诉工具 **时钟多快、IO 何时有效、哪些路径可放松**。无 SDC 的 `compile` 只做 **结构映射**，时序结果 **无意义**。

> 建议 **04 映射前** 通读本章；**06 修违例** 前精读例外路径。

---

## 1. 在流程中的位置

```text
        RTL + .lib
              │
    05 SDC ───┼──► compile（03/04/06 的目标函数）
              │
              └──► PrimeTime 签核（同一套约束）
```

| 阶段 | SDC 作用 |
|------|----------|
| 映射 | 驱动选单元快慢 |
| 06 优化 | 以 slack 为目标插 buffer / sizing |
| 签核 | 判定 setup/hold 是否满足 |

---

## 2. 时钟

```tcl
create_clock -name clk -period 2.0 [get_ports clk]
```

| 概念 | 说明 |
|------|------|
| `period` | 目标时钟周期（ns） |
| `waveform` | 默认 `{0 50%}` 占空比 |
| 生成时钟 | `create_generated_clock`（分频、PLL 输出） |

综合用时钟定义 **launch/capture** 关系；**理想时钟** 在综合早期，** propagated** 在 CTS 后 STA。

### 输入/输出案例

**输入**：`create_clock -period 1.0 [get_ports clk]`（1GHz 目标）

**输出**：`report_timing` 中 `clk` 为基准；WNS 相对 1ns 计算。

| 输入 | 输出 |
|------|------|
| 未定义时钟的 port | `Error: no clock defined for register clock pin` |

---

## 3. IO 延时

```tcl
set_input_delay  0.3 -clock clk [get_ports data_in]
set_output_delay 0.2 -clock clk [get_ports data_out]
set_drive 0.1 [get_ports data_in]
set_load  0.05 [get_ports data_out]
```

| 命令 | 含义 |
|------|------|
| `set_input_delay` | 外部 **相对时钟** 驱动到 port 的延时 |
| `set_output_delay` | port 到外部采样的剩余时间预算 |
| `set_drive` / `set_load` | 驱动强度、负载电容（影响 transition） |

### 输入/输出案例

**输入**：`set_input_delay 0.5 -clock clk [get_ports din]`，周期 2ns

**输出**：内部路径预算 ≈ 2 - 0.5 - setup = …（组合逻辑可用 slack 减少）。

---

## 4. 例外路径

```tcl
set_false_path -from [get_ports async_rst] -to [all_registers]
set_multicycle_path 2 -setup -from [get_clocks clk_a] -to [get_clocks clk_b]
set_max_delay 5.0 -from [get_cells u_slow] -to [get_cells u_out]
```

| 类型 | 用途 |
|------|------|
| `false_path` | 异步复位、测试模式、静态配置 |
| `multicycle_path` | 故意多周期数据路径 |
| `max_delay` / `min_delay` | 组合路径、IO 特殊要求 |

**CDC**：应用 **false_path** 或 **clock_groups**；RTL 需同步器，SDC 不替代 CDC 设计。

### 输入/输出案例

**输入**：跨时钟域 `clk_a → clk_b` 无同步器，未约束

**输出**：STA 报 **虚假违例** 或 **虚假满足**；应 `set_clock_groups -asynchronous`。

---

## 5. 环境与线负载

```tcl
set_operating_conditions -max slow -min fast
set_wire_load_mode top
set_wire_load_model -name 5k_hvratio_1_1
```

| 项 | 综合 vs 签核 |
|----|----------------|
| `set_operating_conditions` | max 修 setup，min 修 hold |
| Wire load | 综合估算；签核用 **SPEF** 更准 |

### 输入/输出案例

**输入**：仅 `slow` corner，未设 `fast`

**输出**：hold 修可能 **欠约束**；应 MCMM 双 corner。

---

## 6. 与 Design DB 的命名

SDC 对象必须 **解析到真实 pin/port**：

```tcl
[get_ports clk]
[get_pins u_cpu/u_alu/U_reg/D]
[get_clocks clk]
```

Elaboration 后层次名须与 RTL 一致（见 [01 章](./01-rtl-parsing-and-elaboration.md)）。

### 输入/输出案例

**输入**：`get_cells u_child` 但 generate 路径为 `g_slice[0].u_child`

**输出**：`Warning: can't find cell u_child` → 用通配或完整路径。

---

## 7. 综合常用派生约束

| 场景 | 命令 |
|------|------|
| 禁止路径优化 | `set_false_path` |
| 固定单元 | `set_dont_touch` |
| 禁止单元类型 | `set_dont_use` |
| 最大转换 | `set_max_transition` |
| 最大电容 | `set_max_capacitance` |

---

## 8. 小结

SDC 贯穿 **04–06**；先 **时钟 + IO**，再 **例外**；与 PrimeTime **同源** 交付。

---

## 下一节

- [04 映射](./04-technology-mapping.md)
- [06 细粒度优化](./06-timing-driven-optimization.md)
- [07 报告](./07-synthesis-reports.md)
