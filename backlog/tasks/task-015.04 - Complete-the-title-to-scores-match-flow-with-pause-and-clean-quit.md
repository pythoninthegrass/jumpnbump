---
id: TASK-015.04
title: Complete the title-to-scores match flow with pause and clean quit
status: To Do
assignee: []
created_date: '2026-09-15 19:16'
labels: []
milestone: m-6
dependencies: []
parent_task_id: TASK-015
priority: high
type: task
ordinal: 53000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Wire together the full match flow: title screen to menu to gameplay to scoreboard, with restart back to the menu. Add pause (gating the TickDriver, not the core) and ensure clean quit stops music before the app closes to avoid leaking audio playback objects, per the neo_snake gotcha already noted in the audio task.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A full match can be played start to finish: title, menu, gameplay, scoreboard, and back to menu, with no manual intervention required between screens
- [ ] #2 Pausing during gameplay freezes the simulation and resumes correctly
- [ ] #3 Quitting from any screen stops music cleanly with no leaked audio objects
<!-- AC:END -->
