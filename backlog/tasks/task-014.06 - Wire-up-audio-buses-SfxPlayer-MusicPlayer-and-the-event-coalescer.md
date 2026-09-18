---
id: TASK-014.06
title: 'Wire up audio buses, SfxPlayer/MusicPlayer, and the event coalescer'
status: Done
assignee: []
created_date: '2026-09-15 19:16'
updated_date: '2026-09-18 00:37'
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
- [x] #1 Sfx cues (jump, land, death, spring, splash, fly) play correctly in response to core events, using the WAV assets from the audio pipeline
- [x] #2 Music plays and loops correctly using the OGG assets, with independently adjustable bus volumes persisted to user://
- [x] #3 A frame that advances multiple ticks (e.g. after a hitch) plays at most one cue per event kind, not one per tick
- [x] #4 Quitting the app does not leak audio playback objects
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
AC#1 caveat: main.c's one-shot SFX_FLY spawn-ding has no corresponding core event -- core/flies.zig's spawn_flies() (TASK-011.06) deliberately dropped it as pure audio outside the core. The swarm's continuous buzz-loop volume (JNB_EVENT_SFX_VOLUME) is genuinely core-event-driven and implemented; the discrete spawn ding is not reachable without a core/flies.zig change, out of TASK-014.06's scope. Also noted: core/steer.zig's sfx_spring and core/collision.zig's sfx_death share numeric id 2 on the wire; disambiguated via game_loop.zig's documented per-tick push order in event_coalescer.gd.
<!-- SECTION:NOTES:END -->
