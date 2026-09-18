class_name SpriteRenderer
extends Node2D

## Draws players, particles/objects, flies, and gore/leftovers off the
## per-frame JumpnbumpWorld state (TASK-014.03) via immediate-mode
## draw_texture_rect_region() calls -- there are deliberately no Sprite2D
## nodes, since the object/fly/gore population is dynamic and unbounded per
## frame (up to jnb's fixed object-slot count). All position/frame math is
## pure and lives in sprite_geometry.gd; this file only reads world state,
## loads the atlas resources, and issues the actual draw calls.
##
## Sits between a background layer and the masked foreground layer in the
## scene tree (game/presentation/main.gd) so CanvasItem's default
## siblings-draw-in-tree-order behavior gives the correct back-to-front
## layering (TASK-014.03 AC#2) without any manual z_index bookkeeping.

const MAX_PLAYERS := 4

var world: SimWorld

var _rabbit_texture: Texture2D
var _objects_texture: Texture2D
var _rabbit_frames: Array = []
var _objects_frames: Array = []

func setup(p_world: SimWorld) -> void:
	world = p_world
	_rabbit_texture = load("res://content/sprites/rabbit_atlas.png")
	_objects_texture = load("res://content/sprites/objects_atlas.png")
	_rabbit_frames = _load_frames("res://content/sprites/rabbit_atlas.json")
	_objects_frames = _load_frames("res://content/sprites/objects_atlas.json")

func _load_frames(path: String) -> Array:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return []
	var data = JSON.parse_string(text)
	if data == null:
		return []
	return data.get("frames", [])

func _process(_delta: float) -> void:
	if world != null:
		queue_redraw()

func _draw() -> void:
	if world == null:
		return

	var player_views := []
	for slot in range(MAX_PLAYERS):
		player_views.append(world.player_view_get(slot))

	var objects_result := world.objects_copy()
	var objects: Array = objects_result.get("objects", [])

	var commands := SpriteGeometry.build_player_draw_commands(player_views, _rabbit_frames)
	commands.append_array(SpriteGeometry.build_object_draw_commands(objects, _objects_frames))

	for command in commands:
		var texture := _rabbit_texture if command["category"] == SpriteGeometry.CATEGORY_PLAYER else _objects_texture
		if texture == null:
			continue
		var size := Vector2(command["width"], command["height"])
		var src_rect := Rect2(command["src_x"], command["src_y"], size.x, size.y)
		var dst_rect := Rect2(command["position"], size)
		draw_texture_rect_region(texture, dst_rect, src_rect)
