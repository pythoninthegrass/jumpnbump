---
id: m-1
title: "Phase 1: The C oracle"
---

## Description

Turn the existing C build into a deterministic, scriptable oracle: headless fixed-tick mode, canonical state dump + checksum, a committed JSONL input-trace corpus, and a differential-test harness (compile the pre-port .c a second time with renamed symbols, diff against the Zig port). This gates every later porting phase.
