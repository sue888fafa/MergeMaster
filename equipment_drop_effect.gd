class_name EquipmentDropEffect
extends Node2D

const EquipmentDataScript := preload("res://equipment_data.gd")

signal landed

var item_id := ""
var item_name := ""
var icon: Texture2D
var landing_position := Vector2.ZERO
var elapsed := 0.0
var duration := 0.85

func setup(next_item_id: String, next_landing_position: Vector2) -> void:
	item_id = next_item_id
	landing_position = next_landing_position
	var item: Dictionary = EquipmentDataScript.get_item(item_id)
	item_name = str(item.get("name", "装备"))
	icon = load(str(item.get("icon", ""))) as Texture2D
	position = landing_position + Vector2(0.0, -112.0)
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	var fall_progress := 1.0 - pow(1.0 - progress, 3.0)
	position = landing_position + Vector2(0.0, -112.0 * (1.0 - fall_progress))
	rotation = sin(progress * PI * 2.0) * 0.08 * (1.0 - progress)
	queue_redraw()
	if progress >= 1.0:
		landed.emit()
		queue_free()

func _draw() -> void:
	var bounce := sin(clampf(elapsed / duration, 0.0, 1.0) * PI) * 3.0
	_draw_drop_ellipse(Vector2(0.0, 24.0), Vector2(25.0, 7.0), Color(0.0, 0.0, 0.0, 0.30))
	draw_circle(Vector2.ZERO, 28.0 + bounce, Color(0.98, 0.78, 0.22, 0.12))
	draw_rect(Rect2(-23.0, -23.0, 46.0, 46.0), Color("#111827"), true)
	draw_rect(Rect2(-21.0, -21.0, 42.0, 42.0), Color("#fbbf24"), false, 2.0)
	if icon != null:
		draw_texture_rect(icon, Rect2(-18.0, -18.0, 36.0, 36.0), false)
	else:
		draw_circle(Vector2.ZERO, 12.0, Color("#fbbf24"))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-42.0, 48.0), item_name, HORIZONTAL_ALIGNMENT_CENTER, 84.0, 12, Color("#fef3c7"))

func _draw_drop_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(20):
		var angle := TAU * float(index) / 20.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
