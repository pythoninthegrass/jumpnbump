class_name SfxEventCoalescer
extends RefCounted

## Pure coalescing policy for Main's per-frame event drain (TASK-014.06
## AC#3): catch-up after a hitch can make one _process() call drive several
## ticks through TickDriver.advance_frame / SimWorld.pump, and
## core/game_loop.zig's step() pushes one independent sfx event per tick
## that triggered one -- so a naive "play() per drained event" loop fires a
## cue once per tick, not once per frame. This is presentation policy, not
## simulation policy (core/*.zig never knows audio exists); given one
## frame's drained events, decide which one-shot cues fire at most once.
## No Node/SfxPlayer dependency, so it's directly headlessly testable with
## a synthetic event array standing in for a real multi-tick drain.

## core/steer.zig's sfx ids, packed into event.a by core/game_loop.zig's
## `.sfx` push (packed_val div 100000). Jump and splash are unambiguous;
## id 2 is genuinely overloaded between core/steer.zig's own sfx_spring and
## core/collision.zig's sfx_death (both write into the shared sfx_trace_z
## the port's differential-checksum machinery established, see steer.zig's
## sfxDrop/sfxRecordZ) -- see _resolve_ambiguous_id below for how this
## drain-side code tells them apart instead.
const SFX_ID_JUMP := 1
const SFX_ID_SPRING_OR_DEATH := 2
const SFX_ID_SPLASH := 3

## The fly swarm's continuous buzz lives on a dedicated sfx channel (main.c
## channel 4, core/flies.zig's volume_trace_channel) rather than a one-shot
## cue: main.c's own dj_play_sfx(SFX_FLY, ...) spawn-time ding has no
## corresponding core event (core/flies.zig's spawn_flies() doc comment:
## "is pure audio and stays outside the core" -- TASK-011.06 never ported
## an event for it), so there is nothing for this coalescer to fire a
## one-shot "fly" cue from. What the core DOES emit every tick the swarm's
## proximity changes is a JNB_EVENT_SFX_VOLUME event carrying (channel,
## volume) for that same channel -- SfxPlayer.apply_fly_volume drives the
## looping buzz cue directly off of that, so cues_for() intentionally
## leaves fly out of its one-shot cue set; see fly_volume_events_in below.
const FLY_CHANNEL := 4

## events is an Array of Dictionaries shaped like SimWorld.event_drain's
## "events" entries (each with an int "kind" matching SimWorld.EVENT_SFX/
## PLAYER_DEATH/etc. and int a/b/c/d payload fields). Returns an Array of
## unique cue names ("jump"/"spring"/"death"/"splash") that should play at
## most once this frame.
static func cues_for(events: Array) -> Array:
	var cues := {}
	for i in range(events.size()):
		var event: Dictionary = events[i]
		if int(event.get("kind", 0)) != SfxKind.SFX:
			continue
		var cue := _cue_for_sfx_id(int(event.get("a", 0)), events, i)
		if cue != "":
			cues[cue] = true
	return cues.keys()

## Extracts the fly-swarm's per-frame channel-volume events, in drain order,
## as an Array of {"channel": int, "volume": int} -- SfxPlayer.apply_fly_volume
## only cares about the last one per frame (the swarm's volume as of the end
## of this frame's catch-up), but every entry is returned so a caller can
## also just take the tail itself.
static func fly_volume_events_in(events: Array) -> Array:
	var out := []
	for event: Dictionary in events:
		if int(event.get("kind", 0)) == SfxKind.SFX_VOLUME and int(event.get("a", 0)) == FLY_CHANNEL:
			out.append({"channel": int(event.get("a", 0)), "volume": int(event.get("b", 0))})
	return out


static func _cue_for_sfx_id(id: int, events: Array, index: int) -> String:
	match id:
		SFX_ID_JUMP:
			return "jump"
		SFX_ID_SPLASH:
			return "splash"
		SFX_ID_SPRING_OR_DEATH:
			return "death" if _is_death(events, index) else "spring"
		_:
			return ""


## core/game_loop.zig's step() pushes a tick's sfx events first, then that
## same tick's player_death event (if any), before the next tick's own sfx
## events begin -- so scanning forward from one ambiguous sfx entry until
## either a player_death (same tick: it's the death cue) or another sfx
## entry (next tick started: it's a spring) correctly disambiguates the
## common case. Known limitation, documented rather than special-cased: a
## single tick that pushes more than one sfx event AND a death (e.g. a
## simultaneous jump and a fatal bump in the same physics tick) can cause
## an earlier same-tick sfx entry to see the next sfx entry before it sees
## the death and misclassify id 2 as a spring -- this requires two
## independent sfx triggers to land in the exact same tick as a death,
## which the corpus has not been observed to produce.
static func _is_death(events: Array, index: int) -> bool:
	var j := index + 1
	while j < events.size():
		var kind := int(events[j].get("kind", 0))
		if kind == SfxKind.SFX:
			return false
		if kind == SfxKind.PLAYER_DEATH:
			return true
		j += 1
	return false


## Mirrors SimWorld's re-exported jnb_* event-kind constants without
## requiring a live SimWorld instance (SimWorld wraps JumpnbumpWorld, which
## this pure RefCounted must not reference directly -- TASK-014.01's
## boundary check only exempts game/simulation/). The numeric values are
## the frozen include/jumpnbump.h ABI (JNB_EVENT_SFX=1, ..._PLAYER_DEATH=3,
## ..._SFX_VOLUME=6), duplicated here rather than imported so this file has
## zero dependency on the simulation layer at all.
class SfxKind:
	const SFX := 1
	const PLAYER_DEATH := 3
	const SFX_VOLUME := 6
