class_name CameraGuideIcon
extends Control

signal clicked

const AVATAR_PLAYER := 0
const AVATAR_ENEMY := 1

var icon_color := Color.WHITE
var avatar_type := AVATAR_PLAYER

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(64.0, 64.0)

func setup(color: Color, type: int) -> void:
	icon_color = color
	avatar_type = type
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit()
		accept_event()

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.38
	# Outer ring and badge shadow make the small screen-space control easy to find.
	draw_circle(center + Vector2(0.0, 3.0), radius + 3.0, Color(0.0, 0.0, 0.0, 0.55))
	draw_circle(center, radius + 4.0, Color(0.02, 0.04, 0.08, 0.95))
	draw_circle(center, radius, icon_color)
	draw_arc(center, radius + 1.0, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.9), 2.0, true)

	var face := Color("#dbeafe") if avatar_type == AVATAR_PLAYER else Color("#fee2e2")
	var face_dark := Color("#14532d") if avatar_type == AVATAR_PLAYER else Color("#7f1d1d")
	draw_circle(center + Vector2(0.0, 4.0), radius * 0.55, face)
	if avatar_type == AVATAR_ENEMY:
		var horn_color := face_dark
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(-radius * 0.42, -radius * 0.18),
			center + Vector2(-radius * 0.70, -radius * 0.78),
			center + Vector2(-radius * 0.04, -radius * 0.48)
		]), horn_color)
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(radius * 0.42, -radius * 0.18),
			center + Vector2(radius * 0.70, -radius * 0.78),
			center + Vector2(radius * 0.04, -radius * 0.48)
		]), horn_color)
	else:
		draw_circle(center + Vector2(0.0, -radius * 0.50), radius * 0.20, Color("#fbbf24"))

	var eye_color := face_dark
	draw_circle(center + Vector2(-radius * 0.22, 1.0), radius * 0.08, eye_color)
	draw_circle(center + Vector2(radius * 0.22, 1.0), radius * 0.08, eye_color)
	draw_arc(center + Vector2(0.0, radius * 0.08), radius * 0.22, 0.2, PI - 0.2, 12, eye_color, 2.0, true)
