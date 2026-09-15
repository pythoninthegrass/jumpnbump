---
id: TASK-015.03
title: 'Add persisted settings: sound, music, gore, flies, mirror, player count'
status: To Do
assignee: []
created_date: '2026-09-15 19:16'
labels: []
milestone: m-6
dependencies: []
parent_task_id: TASK-015
priority: medium
type: task
ordinal: 52000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Surface the original CLI-flag-controlled options (-nosound, -musicnosound, -nogore, -noflies, -mirror, player count) as an in-game settings UI, persisted to user://. Deliberately drop -scaleup, -fullscreen, and -mouse as obsolete — Godot's display handling and gamepad support supersede them.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Sound, music, gore, flies, and mirror-mode settings are all toggleable in-game and persist across restarts
- [ ] #2 Player count (1-4) is configurable and persists
- [ ] #3 No -scaleup/-fullscreen/-mouse equivalents are exposed; this omission is noted in the settings UI's implementation notes
<!-- AC:END -->
