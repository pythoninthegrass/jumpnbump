# Fixtures

`headless-smoke.jsonl` is a minimal scripted-input trace for smoke-testing
`-headless` mode (TASK-008.01). It is not the differential-test corpus —
that's `tests/corpus/`, built by TASK-008.03 with per-frame checksums.

Format: one JSON object per line, `{"frame": N, "keys": [...]}`, where `keys`
lists which of the 12 player key slots are held that frame:
`p1_left`/`p1_right`/`p1_jump` through `p4_left`/`p4_right`/`p4_jump`. Omitted
keys are up. An exhausted or missing trace ends the run (equivalent to
pressing ESC).

Run it against a headless build:

```sh
./jumpnbump -headless -seed 42 -input tests/fixtures/headless-smoke.jsonl -dat data/jumpbump.dat
```
