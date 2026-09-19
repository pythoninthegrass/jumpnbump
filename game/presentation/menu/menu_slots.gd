class_name MenuSlots
extends RefCounted

## Pure per-slot menu data (TASK-015.02), split out from menu_screen.gd so
## the bitmask math is unit-testable without instancing any Control node.
##
## Each of the 4 player slots has a fixed name and rabbit colour already
## baked into rabbit_atlas.png at slot*18 (sprite_geometry.gd's
## rabbit_frame_index, main.c's own per-slot i*18 palette offset) --
## jnb_config carries no separate colour field, so "colour choice" for a
## human player is which slot they occupy, shown here as that slot's
## fixed swatch colour, not a runtime colour cycle.

const MAX_PLAYERS := 4
const PLAYER_LABELS := ["DOTT", "JIFFY", "FIZZ", "MIJJI"]
const PLAYER_COLORS := [
	Color(0.82, 0.14, 0.14), # DOTT: red
	Color(0.16, 0.35, 0.82), # JIFFY: blue
	Color(0.22, 0.7, 0.24),  # FIZZ: green
	Color(0.85, 0.74, 0.12), # MIJJI: yellow
]


## Bit i of ai_mask set means player i is AI-controlled, matching
## jnb_config.player_ai_mask exactly (include/jumpnbump.h).
static func toggle_ai(ai_mask: int, slot: int) -> int:
	return ai_mask ^ (1 << slot)


static func is_ai(ai_mask: int, slot: int) -> bool:
	return (ai_mask & (1 << slot)) != 0
