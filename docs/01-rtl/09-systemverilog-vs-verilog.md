# 1.9 SystemVerilog 与 Verilog 对比（ASIC 可综合视角）

## 1. 二者关系

| | Verilog | SystemVerilog (SV) |
|---|---------|---------------------|
| 标准 | IEEE 1364（常用 **Verilog-2001**） | IEEE 1800（SV-2005/2009/2012/2017…） |
| 定位 | 传统 RTL 与仿真语言 | **Verilog 的超集**，新增结构、验证与断言 |
| ASIC 现状 | 存量项目、老 IP 仍大量存在 | **新 ASIC 项目主流**：Design Compiler、Genus 等对 SV 可综合子集支持成熟 |

**结论（工程建议）**：新模块优先用 **SystemVerilog 可综合子集** 编写；维护老 Verilog IP 时保持风格一致，跨语言例化时注意端口类型与位宽。

---

## 2. 总体对比一览

| 特性 | Verilog-2001 | SystemVerilog（可综合 RTL） |
|------|----------------|-----------------------------|
| 默认网类型 | 需 `wire` 或 `` `default_nettype none`` | 推荐 `logic`（单驱动） |
| 过程块 | `always @(posedge clk)` / `always @(*)` | `always_ff` / `always_comb` / `always_latch` |
| 状态机状态 | `parameter` / `` `define `` 魔数 | `typedef enum` |
| 总线/分组 | 靠拼接与命名约定 | `struct`、`union`（慎用 union 综合） |
| 分支完整性 | 靠人工检查 | `unique` / `priority case` |
| 常量填充 | `8'b0` | `8'b0` 或 `'0`（自动位宽填充） |
| 包与命名空间 | 无 | `package` / `import` |
| 接口 | 无 | `interface`（**多用于 TB**，综合支持有限） |
| 断言 | 无（或 Verilog 伪断言） | **SVA**（仿真 / 形式验证，综合通常忽略） |
| 类 / 随机 | 无 | `class`、`constraint`（**验证专用**） |

---

## 3. 数据类型：`wire` / `reg` vs `logic`

### Verilog

```verilog
wire [7:0] bus;
reg  [7:0] r;   // 在 always 中赋值

always @(posedge clk)
    r <= r + 1;  // reg → 综合为寄存器
```

- `wire`：连续赋值、`assign`、模块端口连接。
- `reg`：在 `always` 中赋值；**名字含 reg 不一定是寄存器**（组合 `always` 里仍是组合逻辑）。

### SystemVerilog

```systemverilog
logic [7:0] bus;  // 既可 assign 又可在 always 中赋值（单驱动）
logic [7:0] r;

always_ff @(posedge clk)
    r <= r + 1;
```

| 要点 | 说明 |
|------|------|
| `logic` | ASIC RTL **首选**；替代 `wire`+`reg` 混用，减少类型混乱 |
| 多驱动 | `logic` 仍禁止多驱动；三态总线需 `wire` 或显式三态协议 |
| 端口 | 模块端口可用 `input logic`、`output logic` |

**ASIC 建议**：RTL 统一 `logic`；顶层与 IP 边界保持位宽显式；开启 `` `default_nettype none`` 防止隐式 wire。

---

## 4. 过程块：`always` vs `always_ff` / `always_comb`

### 时序逻辑

**Verilog**

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        q <= 1'b0;
    else
        q <= d;
end
```

**SystemVerilog**

```systemverilog
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        q <= '0;
    else
        q <= d;
end
```

| | Verilog `always` | SV `always_ff` |
|---|------------------|----------------|
| 语义 | 通用，易与组合混写 | **仅时序**，工具可检查非法组合逻辑 |
| 赋值 | 必须非阻塞 `<=` | 同左 |
| 敏感列表 | 手写 | 手写；部分团队用 `always_ff @(posedge clk)` + 同步复位 |

### 组合逻辑

**Verilog**

```verilog
always @(*) begin
    y = a & b;
end
```

**SystemVerilog**

```systemverilog
always_comb begin
    y = a & b;  // 自动推断完整敏感列表，禁止 `#delay`
end
```

| | `@(*)` | `always_comb` |
|---|--------|----------------|
| 锁存器推断 | 遗漏分支 → latch | 同左；部分工具对 `always_comb` 检查更严 |
| 多次执行 | 仿真可能因事件重复触发 | `always_comb` 在 0 时刻自动触发一次，仿真更一致 |

### 锁存器（仅当工艺/风格需要）

```systemverilog
always_latch begin
    if (en)
        q = d;
end
```

Verilog 无对应关键字，由不完整 `if` 隐式推断；**ASIC 数字逻辑通常应主动避免 latch**。

---

## 5. 常量、位宽与填充

| 写法 | Verilog | SystemVerilog |
|------|---------|----------------|
| 全零填充 | `32'b0` | `'0`（按左值位宽扩展） |
| 全一填充 | `8'hFF` | `'1` |
| 未知/高阻 | `1'bx`, `1'bz` | `'x`, `'z` |
| 参数化位宽 | `parameter W=8` | `parameter int W = 8` |

```systemverilog
logic [31:0] mask;
mask = '0;           // 32'b0
mask = '1;           // 32'hFFFFFFFF（无符号填充语义需注意仿真）
```

**ASIC 注意**：签核前仍应对 **端口与算术表达式** 做位宽 review；`'0` 不能替代显式端口声明。

---

## 6. 状态机与类型定义

### Verilog（传统）

```verilog
parameter S_IDLE = 2'd0;
parameter S_RUN  = 2'd1;
reg [1:0] state, next_state;
```

### SystemVerilog（推荐）

```systemverilog
typedef enum logic [1:0] {
    S_IDLE = 2'b00,
    S_RUN  = 2'b01,
    S_DONE = 2'b10
} state_e;

state_e state, next_state;
```

| 优势 | 说明 |
|------|------|
| 类型安全 | 赋值错误状态易在编译期报错 |
| 可读性 | 波形中显示枚举名（视工具而定） |
| 综合 | DC/Genus 支持 `enum` 映射到二进制状态 |

---

## 7. `case`：`unique` 与 `priority`

```systemverilog
always_comb begin
    unique case (sel)
        2'b00: out = a;
        2'b01: out = b;
        default: out = '0;
    endcase
end
```

| 修饰符 | 语义 | ASIC 综合影响 |
|--------|------|----------------|
| `unique` | 分支互斥，可有 default | 利于综合为 **并行 MUX**，避免优先级链 |
| `priority` | 按书写顺序优先级 | 可能生成 **级联 MUX**，面积/延时较差 |
| （无） | Verilog 兼容 | 工具按默认策略推断 |

**Verilog** 无 `unique`/`priority`；需靠完整 `case` + 编码规范保证。

---

## 8. 结构体、包与接口

### `struct`（可综合，常用）

```systemverilog
typedef struct packed {
    logic [7:0] data;
    logic       valid;
} beat_t;

beat_t beat;
assign beat.data  = din;
assign beat.valid = vld;
```

`packed struct` 可整体赋值、切片，适合 **AXI 风格字段分组**；综合一般展开为扁平向量。

### `package`（可综合，推荐大型 SoC）

```systemverilog
package my_defs;
    parameter int ADDR_W = 32;
    typedef logic [ADDR_W-1:0] addr_t;
endpackage

import my_defs::*;
```

集中管理 **参数、类型、函数声明**；避免 `` `define `` 全局宏污染。

### `interface`（主要用于 Testbench）

```systemverilog
interface axi_if (input logic clk);
    logic [31:0] awaddr;
    modport master (output awaddr);
    modport slave  (input  awaddr);
endinterface
```

| 用途 | ASIC 说明 |
|------|-----------|
| TB 连接 DUT | **强烈推荐**，减少端口线网 |
| RTL 内部互连 | 部分工具支持有限；量产 RTL 常用 **显式端口 + struct** 更稳妥 |

---

## 9. 函数、任务与 DPI

| | Verilog | SystemVerilog |
|---|---------|----------------|
| `function` | 可综合（无延时） | 可加 `automatic`、`return`、更多类型 |
| `task` | 仿真常用 | TB 驱动；**可综合 task 慎用** |
| DPI | 无 | C 互联，**仅仿真/加速** |

**ASIC RTL**：组合逻辑用 **无延时 `function automatic`** 或内联 `assign`；避免在可综合 `function` 中使用动态数组、类。

---

## 10. 断言与验证扩展（非 RTL 综合主体）

| 特性 | 用途 | 综合 |
|------|------|------|
| SVA `assert property` | 协议、时序检查 | 通常 **不综合** 到网表 |
| `class` / `constraint` | UVM、随机验证 | 不综合 |
| `program` | 仿真调度 | 不综合 |
| `covergroup` | 功能覆盖率 | 不综合 |

**ASIC 流程**：RTL 文件与 **ASSERTIONS** 可分离；形式验证（VC Formal 等）使用 SVA；综合仅读 `synopsys_translate_off` 或文件列表排除。

---

## 11. 仍兼容的 Verilog 写法（SV 中继续有效）

以下在 SV 项目中 **仍常见**，无需强行改写：

- `module` / `endmodule`、实例化 `#()`、`` `include ``
- `generate` / `genvar` / `parameter`
- `assign`、三态（IO pad 建模）
- `` `ifdef `` / `` `ifndef `` 条件编译

---

## 12. 文件扩展名与综合脚本

| 扩展名 | 含义 |
|--------|------|
| `.v` | 可为 Verilog 或 SV 子集（由工具选项决定） |
| `.sv` | 明确 SystemVerilog |
| `.vh` / `.svh` | 头文件 |

**Design Compiler / Genus** 常见做法：

```tcl
# 示例：Design Compiler
analyze -format sverilog {file1.sv file2.sv}
elaborate top_module
```

filelist 中建议 **显式区分** `.v` 与 `.sv`，并统一 `+define+` 与 `` `default_nettype none``。

---

## 13. 选型与迁移建议（ASIC 项目）

| 场景 | 建议 |
|------|------|
| 新 block / 新 SoC | **SystemVerilog** + `logic` + `always_ff`/`always_comb` + `enum` |
| 老 Verilog IP | 保持不动；边界用 wrapper 转 `logic` 端口 |
| 混合仿真 | 编译器需同时支持 1364/1800；TB 用 SV，DUT 可仍为 `.v` |
| 编码规范 | 团队一份 **可综合 SV 子集** 白名单（禁止 class、program 进入 RTL 目录） |
| LINT | 使用 SpyGlass / AscentLint 等按 **SV RTL** 规则检查 |

### 最小迁移清单（Verilog → SV）

1. 文件改 `.sv` 或在工具中开启 `sverilog` 模式  
2. `wire`/`reg` → `logic`（三态 net 除外）  
3. `always @(posedge clk)` → `always_ff`；`always @(*)` → `always_comb`  
4. FSM 魔数 → `typedef enum`  
5. 全局 `` `define `` → `package` + `import`（逐步）  

---

## 14. 对照示例：同一 DFF

**Verilog-2001**

```verilog
module dff_v (
    input  wire clk,
    input  wire rst_n,
    input  wire d,
    output reg  q
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) q <= 1'b0;
        else        q <= d;
    end
endmodule
```

**SystemVerilog**

```systemverilog
module dff_sv (
    input  logic clk,
    input  logic rst_n,
    input  logic d,
    output logic q
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) q <= '0;
        else        q <= d;
    end
endmodule
```

二者综合后目标网表一致（同工艺库、同约束）；差异在 **可维护性与工具检查能力**。

---

## 15. 小结

| 维度 | Verilog | SystemVerilog |
|------|---------|----------------|
| ASIC 新设计 | 兼容维护 | **推荐** |
| 类型与过程块 | 经典但易混 | `logic`、`always_ff/comb` 语义更清晰 |
| 验证 | 基础 | SVA、class、interface 强化验证 |
| 综合 | 成熟 | 可综合子集与 Verilog 等价，需遵守团队白名单 |

---

**延伸阅读**

- 本目录：[02 数据类型](./02-data-types-and-operators.md)、[03 过程块](./03-continuous-and-procedural.md)、[07 可综合子集](./07-synthesizable-subset.md)
- IEEE 1800 标准中 *Synthesizable Subset* 相关章节；Foundry/EDA 厂商 *RTL Coding Style* 文档
