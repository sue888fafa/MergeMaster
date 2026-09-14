class_name DragonCardEffect
extends Node2D

const DURATION := 0.9

var elapsed := 0.0

func setup(world_position: Vector2) -> void:
	position = world_position
	elapsed = 0.0
	z_index = 40
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= DURATION:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var progress := clampf(elapsed / DURATION, 0.0, 1.0)
	var fade := 1.0 if progress < 0.72 else 1.0 - (progress - 0.72) / 0.28
	var flight_progress := clampf(progress / 0.55, 0.0, 1.0)
	var flight_eased := 1.0 - pow(1.0 - flight_progress, 2.0)
	var dragon_center := Vector2(lerpf(-72.0, 0.0, flight_eased), lerpf(-78.0, -47.0, flight_eased))
	var stomp_progress := clampf((progress - 0.42) / 0.24, 0.0, 1.0)
	var stomp_eased := 1.0 - pow(1.0 - stomp_progress, 3.0)
	var foot_y := lerpf(dragon_center.y + 22.0, 24.0, stomp_eased)
	var outline := Color(0.06, 0.03, 0.10, fade)
	var body := Color(0.72, 0.20, 0.20, fade)
	var body_light := Color(0.96, 0.38, 0.24, fade)
	var wing := Color(0.40, 0.08, 0.16, fade)
	var gold := Color(1.0, 0.76, 0.22, fade)

	# Impact shadow and cracks make the stomp readable over the building.
	var impact := clampf((progress - 0.48) / 0.42, 0.0, 1.0)
	if impact > 0.0:
		var impact_fade := (1.0 - impact) * fade
		draw_circle(Vector2.ZERO, 15.0 + impact * 25.0, Color(0.95, 0.28, 0.08, 0.16 * impact_fade))
		draw_arc(Vector2.ZERO, 19.0 + impact * 26.0, 0.0, TAU, 24, Color(1.0, 0.66, 0.20, 0.82 * impact_fade), 3.0, true)
		draw_line(Vector2(-4.0, 2.0), Vector2(-16.0, 16.0), Color(0.12, 0.04, 0.03, 0.8 * impact_fade), 2.0, true)
		draw_line(Vector2(4.0, 2.0), Vector2(15.0, 15.0), Color(0.12, 0.04, 0.03, 0.8 * impact_fade), 2.0, true)

	# Wings behind the body.
	var left_wing := PackedVector2Array([
		dragon_center + Vector2(-7.0, 0.0), dragon_center + Vector2(-39.0, -24.0),
		dragon_center + Vector2(-29.0, 10.0), dragon_center + Vector2(-12.0, 17.0)
	])
	var right_wing := PackedVector2Array([
		dragon_center + Vector2(7.0, 0.0), dragon_center + Vector2(39.0, -24.0),
		dragon_center + Vector2(29.0, 10.0), dragon_center + Vector2(12.0, 17.0)
	])
	draw_colored_polygon(left_wing, outline)
	draw_colored_polygon(right_wing, outline)
	draw_colored_polygon(PackedVector2Array([
		dragon_center + Vector2(-9.0, 1.0), dragon_center + Vector2(-34.0, -19.0),
		dragon_center + Vector2(-27.0, 7.0), dragon_center + Vector2(-12.0, 13.0)
	]), wing)
	draw_colored_polygon(PackedVector2Array([
		dragon_center + Vector2(9.0, 1.0), dragon_center + Vector2(34.0, -19.0),
		dragon_center + Vector2(27.0, 7.0), dragon_center + Vector2(12.0, 13.0)
	]), wing)

	# Body, neck and head.
	draw_circle(dragon_center + Vector2(0.0, 8.0), 19.0, outline)
	draw_circle(dragon_center + Vector2(0.0, 8.0), 16.0, body)
	draw_line(dragon_center + Vector2(0.0, -2.0), dragon_center + Vector2(0.0, 18.0), body_light, 4.0, true)
	draw_circle(dragon_center + Vector2(0.0, -15.0), 14.0, outline)
	draw_circle(dragon_center + Vector2(0.0, -15.0), 11.0, body_light)
	var snout := PackedVector2Array([
		dragon_center + Vector2(-8.0, -12.0), dragon_center + Vector2(-20.0, -7.0),
		dragon_center + Vector2(-8.0, -2.0), dragon_center + Vector2(8.0, -2.0),
		dragon_center + Vector2(20.0, -7.0), dragon_center + Vector2(8.0, -12.0)
	])
	draw_colored_polygon(snout, body_light)
	draw_polyline(PackedVector2Array([snout[0], snout[1], snout[2], snout[3], snout[4], snout[5], snout[0]]), outline, 2.0, true)
	draw_colored_polygon(PackedVector2Array([
		dragon_center + Vector2(-8.0, -23.0), dragon_center + Vector2(-5.0, -36.0), dragon_center + Vector2(0.0, -25.0)
	]), gold)
	draw_colored_polygon(PackedVector2Array([
		dragon_center + Vector2(8.0, -23.0), dragon_center + Vector2(5.0, -36.0), dragon_center + Vector2(0.0, -25.0)
	]), gold)
	draw_circle(dragon_center + Vector2(-5.0, -16.0), 2.5, Color("#fff7b2"))
	draw_circle(dragon_center + Vector2(5.0, -16.0), 2.5, Color("#fff7b2"))

	# Legs end at the target when the dragon lands.
	draw_line(dragon_center + Vector2(-11.0, 16.0), Vector2(-9.0, foot_y), outline, 7.0, true)
	draw_line(dragon_center + Vector2(11.0, 16.0), Vector2(9.0, foot_y), outline, 7.0, true)
	draw_line(dragon_center + Vector2(-11.0, 16.0), Vector2(-9.0, foot_y), body_light, 4.0, true)
	draw_line(dragon_center + Vector2(11.0, 16.0), Vector2(9.0, foot_y), body_light, 4.0, true)
	draw_line(Vector2(-15.0, foot_y), Vector2(-5.0, foot_y), gold, 3.0, true)
	draw_line(Vector2(5.0, foot_y), Vector2(15.0, foot_y), gold, 3.0, true)

