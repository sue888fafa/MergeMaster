class_name IntelligenceBuildingDropEffect
extends Node2D

const Config := preload("res://game_config.gd")

var building := 0
var level := 1
var elapsed := 0.0

func setup(world_position: Vector2, next_building: int, next_level: int) -> void:
	position = world_position
	building = next_building
	level = next_level
	elapsed = 0.0
	z_index = 26
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= Config.INTELLIGENCE_BUILDING_DROP_DURATION:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var progress := clampf(elapsed / Config.INTELLIGENCE_BUILDING_DROP_DURATION, 0.0, 1.0)
	var landing := clampf((progress - 0.72) / 0.28, 0.0, 1.0)
	var fade := 1.0 - landing
	var size_scale := 1.0 + float(clampi(level, 1, 4) - 1) * 0.08
	var shadow_width := 18.0 * size_scale + landing * 9.0 * size_scale
	var shadow_height := 4.0 * size_scale + landing * 2.0
	var shadow_points := PackedVector2Array()
	for index in range(18):
		var angle := TAU * float(index) / 18.0
		shadow_points.append(Vector2(cos(angle) * shadow_width, 14.0 + sin(angle) * shadow_height))
	draw_colored_polygon(shadow_points, Color(0.0, 0.0, 0.0, 0.28))
	if landing > 0.0:
		draw_arc(Vector2(0.0, 8.0), 20.0 + landing * 22.0, 0.0, TAU, 28, Color(1.0, 0.86, 0.32, 0.62 * fade), 2.0, true)
		for index in range(6):
			var angle := TAU * float(index) / 6.0
			var direction := Vector2.RIGHT.rotated(angle)
			draw_line(direction * 13.0 + Vector2(0.0, 8.0), direction * (22.0 + landing * 8.0) + Vector2(0.0, 8.0), Color(1.0, 0.78, 0.24, 0.55 * fade), 2.0, true)
