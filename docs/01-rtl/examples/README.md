# RTL 示例

本目录提供与文档配套的可综合示例，便于仿真与综合实验。

| 文件 | 对应章节 | 说明 |
|------|----------|------|
| `dff_async_rst.sv` | 04 | 异步复位 D 触发器 |
| `fsm_three_stage.sv` | 05 | 三段式状态机 |
| `sync_reset_release.sv` | 04 | 复位同步释放 |

## 使用建议

1. 用仿真器（Verilator / VCS / Xcelium 等）做功能验证。
2. 用综合工具（Design Compiler / Yosys / Vivado synthesis 等）查看推断网表与报告。
3. 对比修改 `if` 分支不完整时的 **latch 推断** 警告。
