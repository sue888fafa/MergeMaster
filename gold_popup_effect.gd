class_name GoldPopupEffect
extends Node2D

const Config := preload("res://game_config.gd")

var amount := 5
var elapsed := 0.0

func setup(world_position: Vector2, value: int) -> void:
	position = world_position
	amount = value
	elapsed = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= Config.GOLD_POPUP_DURATION:
		queue_free()

func _draw() -> void:
	var progress := clampf(elapsed / Config.GOLD_POPUP_DURATION, 0.0, 1.0)
	var alpha := 1.0 - progress
	var offset := Vector2(0.0, -34.0 * progress)
	draw_circle(offset + Vector2(-26.0, -3.0), 10.0, Color(0.98, 0.78, 0.14, alpha))
	draw_arc(offset + Vector2(-26.0, -3.0), 10.0, 0.0, TAU, 24, Color(0.55, 0.32, 0.04, alpha), 2.0, true)
	draw_string(ThemeDB.fallback_font, offset + Vector2(-31.0, 1.0), "金", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.55, 0.32, 0.04, alpha))
	draw_string(ThemeDB.fallback_font, offset + Vector2(-10.0, 4.0), "+%d" % amount, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.91, 0.35, alpha))
