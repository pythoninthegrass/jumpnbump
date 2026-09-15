---
id: m-2
title: "Phase 2: Asset codecs in Zig"
---

## Description

Port the .dat archive format, .gob sprite format, 8-bit PCX, and levelmap.txt parsing to Zig, preserving format quirks (prefix-match lookup, row-16 floor fill) bug-for-bug. Reimplement jnbpack/jnbunpack/gobpack as Zig CLIs verified byte-identical to the C tools' output.
