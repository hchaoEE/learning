#!/usr/bin/env python3
"""Renumber bare '### 输入/输出案例' headers using parent ## section number."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "docs" / "02-synthesis"

for fname in ["01-rtl-parsing-and-elaboration.md", "02-inference.md"]:
    path = ROOT / fname
    lines = path.read_text(encoding="utf-8").splitlines()
    current_sec = "0"
    counters = {}
    out = []
    for line in lines:
        m = re.match(r"^## (\d+)\.", line)
        if m:
            current_sec = m.group(1)
            counters[current_sec] = 0
        if re.match(r"^### 输入/输出案例\s*$", line):
            counters[current_sec] = counters.get(current_sec, 0) + 1
            n = counters[current_sec]
            line = f"### 输入/输出案例 {current_sec}.{n}"
        elif re.match(r"^### 输入/输出案例（", line):
            # keep parenthetical titles but add number prefix
            counters[current_sec] = counters.get(current_sec, 0) + 1
            n = counters[current_sec]
            rest = line.replace("### 输入/输出案例", "").strip()
            line = f"### 输入/输出案例 {current_sec}.{n} {rest}"
        out.append(line)
    path.write_text("\n".join(out) + "\n", encoding="utf-8")
    print(f"renumbered {fname}")
