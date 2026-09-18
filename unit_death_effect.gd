class_name UnitDeathEffect
extends Node2D

signal finished

const DURATION := 0.72

var elapsed := 0.0
var effect_scale := 1.0

func setup(world_position: Vector2, visual_scale: float = 1.0) -> void:
	position = world_position
	effect_scale = clampf(visual_scale, 0.55, 1.35)
	z_index = 30
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= DURATION:
		finished.emit()
		queue_free()

func _draw() -> void:
	var progress := clampf(elapsed / DURATION, 0.0, 1.0)
	var alpha := 1.0 - progress
	var rise := -10.0 * progress
	var s := effect_scale
	var grave_center := Vector2(0.0, 7.0 + rise) * s
	var grave_color := Color(0.34, 0.38, 0.48, alpha)
	var grave_edge := Color(0.10, 0.13, 0.21, alpha)
	var highlight := Color(0.64, 0.69, 0.80, alpha * 0.9)

	# Small tombstone silhouette with a rounded top.
	var stone := PackedVector2Array([
		grave_center + Vector2(-11.0, 13.0) * s,
		grave_center + Vector2(-11.0, -4.0) * s,
		grave_center + Vector2(-8.0, -11.0) * s,
		grave_center + Vector2(0.0, -15.0) * s,
		grave_center + Vector2(8.0, -11.0) * s,
		grave_center + Vector2(11.0, -4.0) * s,
		grave_center + Vector2(11.0, 13.0) * s
	])
	draw_colored_polygon(stone, grave_color)
	draw_polyline(stone, grave_edge, 2.0 * s, true)
	draw_line(grave_center + Vector2(-7.0, 13.0) * s, grave_center + Vector2(7.0, 13.0) * s, grave_edge, 2.0 * s, true)

	# Skull mark above the stone keeps the effect readable at small zoom.
	var skull_center := grave_center + Vector2(0.0, -2.0) * s
	draw_circle(skull_center, 5.5 * s, Color(0.86, 0.88, 0.92, alpha))
	draw_rect(Rect2(skull_center + Vector2(-4.0, 3.0) * s, Vector2(8.0, 4.0) * s), Color(0.86, 0.88, 0.92, alpha), true)
	draw_circle(skull_center + Vector2(-2.0, -0.5) * s, 1.35 * s, grave_edge)
	draw_circle(skull_center + Vector2(2.0, -0.5) * s, 1.35 * s, grave_edge)
	draw_colored_polygon(PackedVector2Array([
		skull_center + Vector2(-1.5, 4.0) * s,
		skull_center + Vector2(1.5, 4.0) * s,
		skull_center + Vector2(0.0, 1.5) * s
	]), grave_edge)

	# Brief purple-white sparkle gives the removal moment a readable finish.
	var sparkle_alpha := (1.0 - progress) * 0.65
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var direction := Vector2(cos(angle), sin(angle))
		draw_line(skull_center + direction * 12.0 * s, skull_center + direction * 17.0 * s, Color(0.80, 0.72, 1.0, sparkle_alpha), 1.5 * s, true)
