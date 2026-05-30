# 1.4 时序逻辑：寄存器、复位与使能

## 1. D 触发器模板

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        q <= '0;
    else
        q <= d;
end
```

综合工具会映射为工艺库中的 **D 触发器单元**（如 `DFFRX1` 等，名称因 Foundry 而异），其 **setup/hold、recovery/removal** 由 .lib 描述并在 STA 中检查。

## 2. 异步复位 vs 同步复位

### 异步复位（Asynchronous Reset）

敏感列表含复位沿；复位 **立即** 清零/置位，不等待时钟。

```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        cnt <= '0;
    else if (en)
        cnt <= cnt + 1'b1;
end
```

- 优点：上电/故障时快速进入已知状态。
- 缺点：复位释放（deassert）若靠近时钟沿可能 **恢复时间（recovery/removal）** 违例；常需 **异步复位、同步释放**。

### 同步复位（Synchronous Reset）

复位只在时钟沿判断：

```verilog
always @(posedge clk) begin
    if (!rst_n)
        cnt <= '0;
    else if (en)
        cnt <= cnt + 1'b1;
end
```

- 优点：时序分析简单，无 removal 问题。
- 缺点：复位有效期间需等待时钟；复位脉宽不足可能扫不干净。

**工程约定**：项目内统一一种；若用异步复位，对跨时钟域复位用同步器释放。

## 3. 异步复位同步释放（推荐结构）

```verilog
logic rst_sync_1, rst_sync_2;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rst_sync_1 <= 1'b0;
        rst_sync_2 <= 1'b0;
    end else begin
        rst_sync_1 <= 1'b1;
        rst_sync_2 <= rst_sync_1;
    end
end

wire rst_sync_n = rst_sync_2;  // 用于块内逻辑复位
```

## 4. 使能（Clock Enable）

```verilog
always @(posedge clk) begin
    if (!rst_n)
        acc <= '0;
    else if (ce)
        acc <= acc + din;
end
```

- 综合为 **带 CE 的寄存器**，而非门控时钟（除非显式做 ICG，需工艺与流程支持）。
- **禁止**在 RTL 中随意写 `assign gclk = clk & en` 作为功能时钟（毛刺风险）；应使用使能寄存器或经认可的时钟门控单元。

## 5. 流水线寄存

```verilog
always @(posedge clk) begin
    if (!rst_n) begin
        stage1 <= '0;
        stage2 <= '0;
    end else begin
        stage1 <= in;
        stage2 <= stage1;
    end
end
```

- 每级寄存器切断组合路径，改善 **Fmax**。
- 流水线深度与吞吐、延时的权衡在架构阶段决定；综合负责映射与优化。

## 6. 寄存器推断规则（综合器视角）

综合工具从 `always` 时序块推断寄存器，典型条件：

- 在时钟沿使用非阻塞赋值更新。
- 变量在块外未被连续赋值驱动。

若缺少时钟或用了阻塞赋值，可能推断为 **组合 + 锁存器** 或报错。

## 7. 小结

- 时序块：**posedge clk + 非阻塞 `<=`**。
- 复位策略项目级统一；异步复位建议 **同步释放**。
- 用 **使能** 代替门控时钟实现“不更新”。

## 下一节

[05 有限状态机](./05-fsm.md)
