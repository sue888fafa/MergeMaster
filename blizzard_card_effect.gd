class_name BlizzardCardEffect
extends Node2D

const Config := preload("res://game_config.gd")

var elapsed := 0.0

func setup(world_position: Vector2) -> void:
	position = world_position
	elapsed = 0.0
	z_index = 39
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= Config.MERCHANT_STORM_DURATION:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var duration := Config.MERCHANT_STORM_DURATION
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	var fade_in := clampf(progress / 0.18, 0.0, 1.0)
	var fade_out := clampf((1.0 - progress) / 0.22, 0.0, 1.0)
	var alpha := minf(fade_in, fade_out)
	var radius := 38.0 + sin(progress * PI) * 34.0
	var rotation := progress * TAU * 2.4
	var storm_color := Color(0.38, 0.86, 1.0, alpha)
	var pale := Color(0.86, 0.98, 1.0, alpha)

	draw_circle(Vector2.ZERO, radius, Color(0.25, 0.70, 1.0, 0.08 * alpha))
	for ring in range(3):
		var ring_radius := radius * (0.48 + float(ring) * 0.20)
		var start_angle := rotation + float(ring) * 1.8
		draw_arc(Vector2.ZERO, ring_radius, start_angle, start_angle + PI * 1.35, 24, storm_color, 3.0, true)
		draw_arc(Vector2.ZERO, ring_radius + 7.0, start_angle + PI, start_angle + PI * 1.78, 18, Color(0.68, 0.94, 1.0, 0.60 * alpha), 1.5, true)

	# A small deterministic snow field keeps the effect stable instead of
	# allocating particle nodes for every card use.
	for index in range(12):
		var angle := rotation * 0.7 + float(index) * TAU / 12.0
		var distance := radius * (0.35 + float((index * 17) % 7) / 10.0)
		var snow_center := Vector2(cos(angle), sin(angle)) * distance
		var size := 2.0 + float(index % 3)
		draw_line(snow_center - Vector2(size, 0.0).rotated(angle), snow_center + Vector2(size, 0.0).rotated(angle), pale, 1.8, true)
		draw_line(snow_center - Vector2(size, 0.0).rotated(angle + PI * 0.5), snow_center + Vector2(size, 0.0).rotated(angle + PI * 0.5), pale, 1.8, true)

	draw_arc(Vector2.ZERO, 24.0 + sin(progress * PI) * 9.0, 0.0, TAU, 28, Color(0.75, 0.96, 1.0, 0.75 * alpha), 2.0, true)
