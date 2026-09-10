class_name MeleeAttackEffect
extends Node2D

const DURATION := 0.18

var start_position := Vector2.ZERO
var target_position := Vector2.ZERO
var elapsed := 0.0
var main_ref: Node

func setup(from_position: Vector2, to_position: Vector2, controller: Node = null) -> void:
	start_position = from_position
	target_position = to_position
	elapsed = 0.0
	main_ref = controller if controller != null else main_ref
	visible = true
	set_process(true)
	position = Vector2.ZERO
	z_index = 10
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= DURATION:
		if main_ref != null and main_ref.has_method("release_melee_attack_effect"):
			main_ref.release_melee_attack_effect(self)
		else:
			queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var progress := clampf(elapsed / DURATION, 0.0, 1.0)
	var alpha := 1.0 - progress
	var direction := target_position - start_position
	if direction.length_squared() < 0.01:
		direction = Vector2.RIGHT
	else:
		direction = direction.normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	var slash_center := start_position.lerp(target_position, 0.72)
	var sweep := lerpf(-0.9, 0.9, progress)
	var slash_direction := direction.rotated(sweep)
	var slash_perpendicular := Vector2(-slash_direction.y, slash_direction.x)
	var slash_start := slash_center - slash_perpendicular * 13.0 - slash_direction * 5.0
	var slash_end := slash_center + slash_perpendicular * 13.0 + slash_direction * 5.0
	draw_line(slash_start, slash_end, Color(1.0, 0.92, 0.55, 0.9 * alpha), 4.0, true)
	draw_line(slash_start, slash_end, Color(1.0, 1.0, 0.95, 0.95 * alpha), 1.5, true)
	var impact_radius := 4.0 + progress * 8.0
	draw_circle(target_position, impact_radius, Color(1.0, 0.72, 0.22, 0.30 * alpha))
	draw_arc(target_position, impact_radius + 3.0, -PI * 0.6, PI * 0.35, 14, Color(1.0, 0.9, 0.48, 0.8 * alpha), 2.0, true)
