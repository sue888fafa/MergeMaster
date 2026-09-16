class_name ChestOpenEffect
extends Node2D

const Config := preload("res://game_config.gd")

signal finished

var reward_amount := 0
var elapsed := 0.0
var completed := false

func setup(world_position: Vector2, amount: int) -> void:
	position = world_position
	reward_amount = amount
	elapsed = 0.0
	completed = false
	queue_redraw()

func _process(delta: float) -> void:
	if completed:
		return
	elapsed += delta
	queue_redraw()
	if elapsed >= Config.QUESTION_CHEST_EFFECT_DURATION:
		completed = true
		finished.emit()
		queue_free()

func _draw() -> void:
	var progress := clampf(elapsed / Config.QUESTION_CHEST_EFFECT_DURATION, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - progress, 2.0)
	var fade := 1.0 - maxf(0.0, (progress - 0.68) / 0.32)
	var pulse := sin(progress * PI)

	draw_circle(Vector2(0.0, -7.0), 26.0 + pulse * 8.0, Color(1.0, 0.78, 0.16, 0.12 * fade))
	for index in range(6):
		var angle := TAU * float(index) / 6.0 - progress * 1.8
		var ray_start := Vector2(cos(angle), sin(angle)) * 17.0
		var ray_end := Vector2(cos(angle), sin(angle)) * (29.0 + pulse * 7.0)
		draw_line(ray_start + Vector2(0.0, -7.0), ray_end + Vector2(0.0, -7.0), Color(1.0, 0.83, 0.24, 0.55 * fade), 2.0, true)

	var chest_width := 30.0
	var chest_height := 18.0
	_draw_shadow_ellipse(Vector2(0.0, 22.0), Vector2(17.0, 5.0), Color(0.0, 0.0, 0.0, 0.30 * fade))
	draw_rect(Rect2(-chest_width * 0.5, 3.0, chest_width, chest_height), Color(0.55, 0.25, 0.07, fade), true)
	draw_rect(Rect2(-chest_width * 0.5, 3.0, chest_width, chest_height), Color(1.0, 0.76, 0.16, fade), false, 2.0, true)
	draw_rect(Rect2(-2.0, 3.0, 4.0, chest_height), Color(1.0, 0.82, 0.24, fade), true)
	draw_circle(Vector2(0.0, 12.0), 2.5, Color(1.0, 0.91, 0.45, fade))

	var lid_lift := 13.0 * eased
	var lid_angle := -0.42 * eased
	var lid_center := Vector2(0.0, 2.0 - lid_lift)
	var lid_points := PackedVector2Array([
		Vector2(-chest_width * 0.5, -3.0),
		Vector2(chest_width * 0.5, -3.0),
		Vector2(chest_width * 0.5, 7.0),
		Vector2(-chest_width * 0.5, 7.0)
	])
	var rotated_lid := PackedVector2Array()
	for point in lid_points:
		rotated_lid.append(lid_center + (point - lid_center).rotated(lid_angle))
	draw_colored_polygon(rotated_lid, Color(0.66, 0.32, 0.08, fade))
	draw_polyline(PackedVector2Array([rotated_lid[0], rotated_lid[1], rotated_lid[2], rotated_lid[3], rotated_lid[0]]), Color(1.0, 0.80, 0.22, fade), 2.0, true)

	for index in range(4):
		var coin_progress := clampf((progress - float(index) * 0.08) / 0.72, 0.0, 1.0)
		if coin_progress <= 0.0:
			continue
		var coin_position := Vector2(-12.0 + float(index) * 8.0, 2.0).lerp(Vector2(-17.0 + float(index) * 11.0, -28.0 - float(index % 2) * 8.0), coin_progress)
		coin_position.y -= sin(coin_progress * PI) * 5.0
		draw_circle(coin_position, 4.0, Color(1.0, 0.82, 0.20, (1.0 - coin_progress * 0.55) * fade))
		draw_arc(coin_position, 4.0, 0.0, TAU, 16, Color(0.64, 0.36, 0.04, fade), 1.0, true)

	if progress > 0.18:
		var text_alpha := clampf((progress - 0.18) / 0.2, 0.0, 1.0) * fade
		draw_string(ThemeDB.fallback_font, Vector2(-15.0, -36.0 - eased * 7.0), "+%d" % reward_amount, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.88, 0.32, text_alpha))

func _draw_shadow_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(24):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
