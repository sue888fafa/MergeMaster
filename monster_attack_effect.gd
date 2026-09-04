class_name MonsterAttackEffect
extends Node2D

const DURATION := 0.28

var start_position := Vector2.ZERO
var target_position := Vector2.ZERO
var elapsed := 0.0

func setup(from_position: Vector2, to_position: Vector2) -> void:
	start_position = from_position
	target_position = to_position
	elapsed = 0.0
	position = Vector2.ZERO
	z_index = 20
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= DURATION:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var progress := clampf(elapsed / DURATION, 0.0, 1.0)
	var alpha := 1.0 - progress
	var travel := start_position.lerp(target_position, ease(progress, 0.8))
	var direction := target_position - start_position
	if direction.length_squared() < 0.01:
		direction = Vector2.RIGHT
	else:
		direction = direction.normalized()
	var tail := travel - direction * 18.0
	var side := Vector2(-direction.y, direction.x)
	draw_line(tail, travel, Color(0.55, 0.16, 0.95, 0.35 * alpha), 7.0, true)
	draw_line(tail, travel, Color(0.86, 0.55, 1.0, 0.90 * alpha), 2.5, true)
	draw_circle(travel, 7.0, Color(0.40, 0.08, 0.72, 0.75 * alpha))
	draw_circle(travel, 3.5, Color(0.94, 0.80, 1.0, 0.95 * alpha))
	var impact_radius := 5.0 + progress * 15.0
	draw_circle(target_position, impact_radius, Color(0.70, 0.20, 1.0, 0.12 * alpha))
	draw_arc(target_position, impact_radius, -PI * 0.75, PI * 0.5, 16, Color(0.88, 0.55, 1.0, 0.85 * alpha), 2.0, true)
	draw_line(target_position - side * 8.0, target_position + side * 8.0, Color(0.95, 0.75, 1.0, 0.75 * alpha), 2.0, true)
