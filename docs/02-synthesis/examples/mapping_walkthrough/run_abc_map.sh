#!/usr/bin/env bash
# 对比：仅 NAND/INV 库 vs 含 OAI21 的库（需本机 yosys）
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="${DIR}/_abc_out"
mkdir -p "$OUT"

yosys -q -p "
read_verilog ${DIR}/map_and_or.sv
hierarchy -top map_and_or
proc; opt
write_aiger ${OUT}/map_and_or.aig
"

# 仅 NAND/INV（无 OAI）— 用 ABC 内建 AND 映射模拟
yosys -q -p "
read_aiger ${OUT}/map_and_or.aig
abc -g AND -K 6
write_verilog ${OUT}/mapped_and_only.v
stat
"

echo "--- 若已安装 abc 且扩展了 genlib，可手动:"
echo "abc -c 'read_aiger ${OUT}/map_and_or.aig; strash; read_genlib ${DIR}/demo.genlib; map -K 6; write_verilog ${OUT}/mapped_genlib.v'"
