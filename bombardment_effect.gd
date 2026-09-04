class_name BombardmentEffect
extends Node2D

const Config := preload("res://game_config.gd")

var target_positions: Array[Vector2] = []
var elapsed := 0.0

func setup(next_positions: Array[Vector2]) -> void:
	target_positions = next_positions
	elapsed = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= Config.BOMBARDMENT_EFFECT_DURATION:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var progress := clampf(elapsed / Config.BOMBARDMENT_EFFECT_DURATION, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(progress * TAU * 2.0)
	for target in target_positions:
		var tile_points := _hex_points(target, 47.0)
		draw_colored_polygon(tile_points, Color(0.95, 0.12, 0.12, 0.10 + pulse * 0.08))
		var outline := PackedVector2Array(tile_points)
		outline.append(tile_points[0])
		draw_polyline(outline, Color(1.0, 0.25, 0.15, 0.72), 2.0, true)
		var ring_radius := 12.0 + progress * 34.0
		draw_arc(target, ring_radius, 0.0, TAU, 24, Color(1.0, 0.36, 0.12, 0.78 - progress * 0.45), 3.0, true)
		if progress > 0.28:
			var impact_progress := (progress - 0.28) / 0.72
			draw_circle(target, 9.0 + impact_progress * 22.0, Color(1.0, 0.55, 0.10, 0.18 * (1.0 - impact_progress)))
			draw_circle(target, 6.0, Color(0.16, 0.04, 0.02, 0.72))

func _hex_points(center: Vector2, size: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(6):
		var angle := deg_to_rad(60.0 * index - 30.0)
		points.append(center + Vector2(cos(angle), sin(angle)) * size)
	return points
