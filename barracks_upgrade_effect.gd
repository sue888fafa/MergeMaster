class_name BarracksUpgradeEffect
extends Node2D

const DURATION := 0.62

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

	# A short golden burst makes the upgrade readable without becoming a
	# persistent building highlight.
	var ring_radius := 18.0 + progress * 34.0
	draw_circle(Vector2.ZERO, 12.0 + flash * 10.0, Color(1.0, 0.84, 0.24, 0.16 * flash * level_strength))
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 32, Color(1.0, 0.83, 0.22, 0.9 * flash * fade), 3.0, true)
	draw_arc(Vector2.ZERO, ring_radius + 5.0, -PI * 0.2, PI * 0.8, 18, Color(1.0, 0.96, 0.62, 0.75 * flash * fade), 1.5, true)

	var ray_count := 8
	for index in range(ray_count):
		var angle := TAU * float(index) / float(ray_count) + progress * 0.8
		var direction := Vector2.RIGHT.rotated(angle)
		var inner := direction * (12.0 + progress * 5.0)
		var outer := direction * (25.0 + progress * 22.0)
		draw_line(inner, outer, Color(1.0, 0.88, 0.35, 0.8 * flash * fade), 2.5, true)

	var star_size := 5.0 + flash * 4.0
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
	draw_colored_polygon(star, Color(1.0, 0.98, 0.78, 0.88 * flash * level_strength))
