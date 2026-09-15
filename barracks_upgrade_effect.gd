class_name BarracksUpgradeEffect
extends Node2D

const DURATION := 0.62 / 1.5

var barracks_level := 1
var elapsed := 0.0

func setup(world_position: Vector2, level: int) -> void:
	position = world_position
	barracks_level = clampi(level, 1, 4)
	elapsed = 0.0
	z_index = 30
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= DURATION:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var progress := clampf(elapsed / DURATION, 0.0, 1.0)
	var flash := sin(progress * PI)
	var fade := 1.0 - progress
	var level_strength := 0.85 + float(barracks_level - 1) * 0.05

	# A larger, heavier golden burst keeps the upgrade readable at board scale.
	var ring_radius := 22.0 + progress * 42.0
	draw_circle(Vector2.ZERO, 15.0 + flash * 12.0, Color(1.0, 0.84, 0.24, 0.20 * flash * level_strength))
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 32, Color(1.0, 0.83, 0.22, 0.95 * flash * fade), 5.0, true)
	draw_arc(Vector2.ZERO, ring_radius + 7.0, -PI * 0.2, PI * 0.8, 18, Color(1.0, 0.96, 0.62, 0.82 * flash * fade), 3.0, true)

	var ray_count := 8
	for index in range(ray_count):
		var angle := TAU * float(index) / float(ray_count) + progress * 0.8
		var direction := Vector2.RIGHT.rotated(angle)
		var inner := direction * (15.0 + progress * 6.0)
		var outer := direction * (30.0 + progress * 27.0)
		draw_line(inner, outer, Color(1.0, 0.88, 0.35, 0.9 * flash * fade), 4.0, true)

	var star_size := 7.0 + flash * 5.0
	var star := PackedVector2Array([
		Vector2(0.0, -star_size),
		Vector2(star_size * 0.38, -star_size * 0.38),
		Vector2(star_size, 0.0),
		Vector2(star_size * 0.38, star_size * 0.38),
		Vector2(0.0, star_size),
		Vector2(-star_size * 0.38, star_size * 0.38),
		Vector2(-star_size, 0.0),
		Vector2(-star_size * 0.38, -star_size * 0.38)
	])
	draw_colored_polygon(star, Color(1.0, 0.98, 0.78, 0.95 * flash * level_strength))
