class_name FateEvent
extends Node2D

signal finished

const Config := preload("res://game_config.gd")

var event_type := Config.RANDOM_EVENT_BOMB
var start_position := Vector2.ZERO
var target_position := Vector2.ZERO
var completed := false

func setup(next_event_type: int, from_position: Vector2, to_position: Vector2) -> void:
	event_type = next_event_type
	start_position = from_position
	target_position = to_position
	position = from_position
	if event_type == Config.RANDOM_EVENT_BOMB:
		var bomb_tween := create_tween()
		bomb_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		bomb_tween.tween_property(self, "scale", Vector2(1.35, 1.35), Config.RANDOM_EVENT_ANIMATION_DURATION)
		bomb_tween.tween_callback(_finish)
	else:
		var travel_tween := create_tween()
		travel_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		var travel_duration := Config.RANDOM_EVENT_ANIMATION_DURATION
		if event_type == Config.RANDOM_EVENT_CHEST_MONSTER:
			travel_duration /= Config.CHEST_MONSTER_SPEED_SCALE
		travel_tween.tween_property(self, "position", target_position, travel_duration)
		travel_tween.tween_callback(_finish)
	queue_redraw()

func _finish() -> void:
	if completed:
		return
	completed = true
	finished.emit()
	queue_free()

func _draw() -> void:
	match event_type:
		Config.RANDOM_EVENT_BOMB:
			_draw_bomb()
		Config.RANDOM_EVENT_PLANE:
			_draw_plane()
		Config.RANDOM_EVENT_CHEST_MONSTER:
			_draw_chest_monster()

func _draw_bomb() -> void:
	draw_circle(Vector2.ZERO, 26.0, Color(0.96, 0.45, 0.1, 0.22))
	draw_circle(Vector2.ZERO, 12.0, Color("#292524"))
	draw_circle(Vector2.ZERO, 8.0, Color("#f97316"))
	draw_line(Vector2(7, -8), Vector2(16, -20), Color("#facc15"), 3.0, true)

func _draw_plane() -> void:
	var points := PackedVector2Array([Vector2(-18, -5), Vector2(18, 0), Vector2(-5, 8), Vector2(-2, 1)])
	draw_colored_polygon(points, Color("#f8fafc"))
	draw_polyline(PackedVector2Array([Vector2(-18, -5), Vector2(18, 0), Vector2(-5, 8), Vector2(-18, -5)]), Color("#38bdf8"), 2.0, true)
	draw_line(Vector2(-5, -1), Vector2(9, 0), Color("#94a3b8"), 2.0, true)

func _draw_chest_monster() -> void:
	draw_circle(Vector2(0, 4), 12.0, Color("#a855f7"))
	draw_circle(Vector2(-5, 0), 2.0, Color("#fef08a"))
	draw_circle(Vector2(5, 0), 2.0, Color("#fef08a"))
	draw_rect(Rect2(-13, -18, 26, 13), Color("#92400e"), true)
	draw_rect(Rect2(-13, -18, 26, 13), Color("#fbbf24"), false, 2.0)
	draw_rect(Rect2(-2, -18, 4, 13), Color("#facc15"), true)
