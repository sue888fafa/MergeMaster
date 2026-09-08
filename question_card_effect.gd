class_name QuestionCardEffect
extends Node2D

const Config := preload("res://game_config.gd")

signal finished

var elapsed := 0.0

func setup(world_position: Vector2) -> void:
	position = world_position
	elapsed = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= Config.RANDOM_EVENT_ANIMATION_DURATION:
		finished.emit()
		queue_free()

func _draw() -> void:
	var progress := clampf(elapsed / Config.RANDOM_EVENT_ANIMATION_DURATION, 0.0, 1.0)
	var jump := sin(progress * PI) * 42.0
	var fade := 1.0 if progress < 0.82 else 1.0 - (progress - 0.82) / 0.18
	var card_center := Vector2(0.0, -jump - 8.0)
	var shadow_scale := 1.0 - sin(progress * PI) * 0.35
	_draw_ellipse(Vector2(0.0, 8.0), Vector2(18.0 * shadow_scale, 5.0 * shadow_scale), Color(0.0, 0.0, 0.0, 0.24 * fade))
	var card_points := PackedVector2Array([
		card_center + Vector2(-16.0, -23.0), card_center + Vector2(12.0, -23.0),
		card_center + Vector2(16.0, -19.0), card_center + Vector2(16.0, 23.0),
		card_center + Vector2(-16.0, 23.0)
	])
	draw_colored_polygon(card_points, Color(0.15, 0.12, 0.35, fade))
	draw_polyline(PackedVector2Array([card_points[0], card_points[1], card_points[2], card_points[3], card_points[4], card_points[0]]), Color(0.76, 0.70, 1.0, fade), 2.5, true)
	draw_circle(card_center + Vector2(0.0, -1.0), 10.0, Color(0.30, 0.24, 0.60, fade))
	draw_string(ThemeDB.fallback_font, card_center + Vector2(-5.5, 7.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.93, 0.55, fade))

func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(20):
		var angle := TAU * float(index) / 20.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
