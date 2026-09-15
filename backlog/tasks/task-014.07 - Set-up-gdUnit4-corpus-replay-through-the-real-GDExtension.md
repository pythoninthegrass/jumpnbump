---
id: TASK-014.07
title: Set up gdUnit4 corpus replay through the real GDExtension
status: To Do
assignee: []
created_date: '2026-09-15 19:16'
labels: []
milestone: m-5
dependencies: []
parent_task_id: TASK-014
priority: high
type: task
ordinal: 49000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Bootstrap gdUnit4 (matching neo_snake's tools/bootstrap.py pattern, gitignored and pinned by SHA256 rather than vendored) and write a Tier-D test suite that replays the Phase 1 JSONL corpus through the real GDExtension (not a mock), diffing canonical state/checksums frame-for-frame. Add a test_gdextension_present canary asserting the GDExtension class actually loaded, so a broken build fails fast and legibly rather than every other test failing mysteriously.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 task game:test runs headlessly via godot --headless and passes
- [ ] #2 test_gdextension_present fails clearly if the GDExtension fails to load
- [ ] #3 Every trace in the Phase 1 corpus replays through the real GDExtension with matching checksums frame-for-frame
<!-- AC:END -->
