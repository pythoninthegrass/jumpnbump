---
id: TASK-014.06
title: 'Wire up audio buses, SfxPlayer/MusicPlayer, and the event coalescer'
status: To Do
assignee: []
created_date: '2026-09-15 19:16'
labels: []
milestone: m-5
dependencies: []
parent_task_id: TASK-014
priority: medium
type: task
ordinal: 48000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Set up the Godot audio bus layout (Master/Music/SFX/UI), an SfxPlayer and MusicPlayer following neo_snake's pattern of one AudioStreamPlayer per cue, and an event coalescer that drains the step() event stream from Phase 3 and collapses multiple same-kind events per frame into a single cue so catch-up ticks don't machine-gun a sound. Music must stop cleanly on quit (NOTIFICATION_WM_CLOSE_REQUEST) to avoid leaking Ogg playback objects, per the neo_snake gotcha.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Sfx cues (jump, land, death, spring, splash, fly) play correctly in response to core events, using the WAV assets from the audio pipeline
- [ ] #2 Music plays and loops correctly using the OGG assets, with independently adjustable bus volumes persisted to user://
- [ ] #3 A frame that advances multiple ticks (e.g. after a hitch) plays at most one cue per event kind, not one per tick
- [ ] #4 Quitting the app does not leak audio playback objects
<!-- AC:END -->
