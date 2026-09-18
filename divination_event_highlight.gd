class_name DivinationEventHighlight
extends Control

@export_category("事件图标高光布局")
@export var event_centers: Array[Vector2] = [
	Vector2(171.0, 455.0), Vector2(222.0, 422.0), Vector2(403.5, 425.5),
	Vector2(449.5, 455.5), Vector2(362.0, 464.0), Vector2(256.5, 460.5)
]
@export var event_radii: Array[Vector2] = [
	Vector2(24.0, 24.0), Vector2(34.0, 34.0), Vector2(39.0, 39.0),
	Vector2(28.0, 28.0), Vector2(34.0, 34.0), Vector2(35.0, 35.0)
]
@export var normal_glow_color := Color("d8a7ff")
@export var final_glow_color := Color("f8c84e")
@export_range(1.0, 8.0, 0.5) var outline_width := 3.5

var active_index := -1
var final_index := -1
var pulse_time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func set_active(index: int, final := false) -> void:
	visible = index >= 0
	active_index = clampi(index, -1, event_centers.size() - 1)
	final_index = active_index if final else -1
	pulse_time = 0.0
	queue_redraw()

func clear_active() -> void:
	visible = false
	active_index = -1
	final_index = -1
	pulse_time = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if active_index < 0:
		return
	pulse_time += delta
	queue_redraw()

func _draw() -> void:
	if active_index < 0 or active_index >= event_centers.size() or active_index >= event_radii.size():
		return
	var center: Vector2 = event_centers[active_index]
	var radii: Vector2 = event_radii[active_index]
	var is_final := active_index == final_index
	var pulse := (sin(pulse_time * (10.0 if is_final else 14.0)) + 1.0) * 0.5
	var glow_alpha := 0.26 + pulse * (0.22 if is_final else 0.14)
	var glow_color := final_glow_color if is_final else normal_glow_color

	for ring in range(3):
		var ring_scale := 1.0 + float(ring) * 0.20 + pulse * 0.08
		_draw_highlight_ellipse(center, radii * ring_scale, Color(glow_color, glow_alpha / float(ring + 1)))
	draw_arc(center, maxf(radii.x, radii.y) * (1.05 + pulse * 0.10), 0.0, TAU, 32, Color(glow_color, 0.86), outline_width + (1.0 if is_final else 0.0), true)
	if is_final:
		var flash_alpha := 0.20 + pulse * 0.25
		draw_circle(center, 10.0 + pulse * 7.0, Color(1.0, 0.94, 0.62, flash_alpha))

func _draw_highlight_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(24):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
