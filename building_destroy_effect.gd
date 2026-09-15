class_name BuildingDestroyEffect
extends Node2D

const DURATION := 0.90

var building_type := 0
var building_level := 1
var elapsed := 0.0
var debris: Array[Dictionary] = []

func setup(world_position: Vector2, destroyed_building: int, level: int) -> void:
	position = world_position
	building_type = destroyed_building
	building_level = clampi(level, 1, 4)
	elapsed = 0.0
	debris.clear()
	var seed := absi(int(world_position.x) * 31 + int(world_position.y) * 17 + destroyed_building * 13)
	for index in range(10):
		var angle := TAU * float(index) / 10.0 + float(seed % 7) * 0.08
		var speed := 18.0 + float((seed + index * 19) % 24)
		debris.append({
			"velocity": Vector2(cos(angle), sin(angle) - 0.9) * speed,
			"size": 2.0 + float((seed + index * 7) % 4),
			"rotation": float((seed + index * 23) % 20) * 0.2,
			"spin": -4.0 + float((seed + index * 11) % 9),
			"color": Color("#64748b") if index % 3 == 0 else Color("#a16207")
		})
	z_index = 35
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= DURATION:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var progress := clampf(elapsed / DURATION, 0.0, 1.0)
	var fade := 1.0 - progress
	var smoke_phase := progress * TAU * 1.4
	# A few overlapping soft puffs create readable smoke without requiring a
	# texture or particle material, and the upward drift separates it from the tile.
	for index in range(5):
		var puff_progress := clampf(progress + float(index) * 0.08, 0.0, 1.0)
		var puff_center := Vector2(
			(sin(smoke_phase + float(index) * 1.7) * 8.0) * puff_progress,
			-5.0 - puff_progress * (22.0 + float(index) * 3.0)
		)
		var radius := (7.0 + float(index) * 1.8) * (0.75 + puff_progress * 0.55)
		draw_circle(puff_center, radius, Color(0.24, 0.27, 0.31, 0.24 * fade))
		draw_circle(puff_center + Vector2(-2.0, -2.0), radius * 0.62, Color(0.72, 0.74, 0.76, 0.12 * fade))

	for debris_piece in debris:
		var velocity: Vector2 = debris_piece["velocity"]
		var piece_position := velocity * elapsed + Vector2(0.0, 34.0 * elapsed * elapsed)
		var size := float(debris_piece["size"]) * (1.0 - progress * 0.25)
		var points := PackedVector2Array([
			piece_position + Vector2(-size, -size * 0.6),
			piece_position + Vector2(size, -size),
			piece_position + Vector2(size * 0.65, size),
			piece_position + Vector2(-size * 0.8, size * 0.7)
		])
		draw_set_transform(piece_position, float(debris_piece["rotation"]) + float(debris_piece["spin"]) * elapsed, Vector2.ONE)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-size, -size * 0.6), Vector2(size, -size),
			Vector2(size * 0.65, size), Vector2(-size * 0.8, size * 0.7)
		]), Color(debris_piece["color"], 0.88 * fade))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
