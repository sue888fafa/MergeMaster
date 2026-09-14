class_name FactionStatsDisplay
extends Control

const Config := preload("res://game_config.gd")

var faction_ids: Array[int] = []
var territory_counts: Dictionary = {}
var army_counts: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_faction_data(ids: Array, territories: Dictionary, armies: Dictionary) -> void:
	faction_ids.clear()
	for faction in ids:
		faction_ids.append(int(faction))
	territory_counts = territories.duplicate()
	army_counts = armies.duplicate()
	queue_redraw()

func _draw() -> void:
	if faction_ids.is_empty():
		return
	var label_color := Color("#cbd5e1")
	draw_string(ThemeDB.fallback_font, Vector2(0.0, 22.0), "领地", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, label_color)
	draw_string(ThemeDB.fallback_font, Vector2(0.0, 62.0), "士兵", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, label_color)
	var start_x := 42.0
	var step := 48.0
	for index in range(faction_ids.size()):
		var faction := faction_ids[index]
		var color := Color(str(Config.FACTION_COLORS.get(faction, "#94a3b8")))
		var center := Vector2(start_x + float(index) * step, 17.0)
		_draw_territory_hex(center, color, int(territory_counts.get(faction, 0)))
		_draw_soldier_avatar(Vector2(center.x, 57.0), color, int(army_counts.get(faction, 0)))

func _draw_territory_hex(center: Vector2, color: Color, amount: int) -> void:
	var outline := Color("#0b1220")
	var points := PackedVector2Array()
	for index in range(6):
		var angle := PI / 6.0 + TAU * float(index) / 6.0
		points.append(center + Vector2(cos(angle), sin(angle)) * 15.0)
	draw_colored_polygon(points, outline)
	var inner_points := PackedVector2Array()
	for point in points:
		inner_points.append(center + (point - center) * 0.82)
	draw_colored_polygon(inner_points, color.darkened(0.08))
	draw_string(ThemeDB.fallback_font, center + Vector2(-12.0, 5.0), str(amount), HORIZONTAL_ALIGNMENT_CENTER, 24, 13, Color("#ffffff"))

func _draw_soldier_avatar(center: Vector2, color: Color, amount: int) -> void:
	var outline := Color("#0b1220")
	# Compact head-and-body silhouette; the count is printed on the torso.
	draw_circle(center + Vector2(0.0, -7.0), 6.5, outline)
	draw_circle(center + Vector2(0.0, -7.0), 4.5, color.lightened(0.12))
	draw_rect(Rect2(center + Vector2(-8.0, 0.0), Vector2(16.0, 14.0)), outline, true)
	draw_rect(Rect2(center + Vector2(-5.5, 1.5), Vector2(11.0, 10.5)), color, true)
	draw_line(center + Vector2(-6.0, 3.0), center + Vector2(-11.0, 9.0), outline, 2.0, true)
	draw_line(center + Vector2(6.0, 3.0), center + Vector2(11.0, 9.0), outline, 2.0, true)
	draw_string(ThemeDB.fallback_font, center + Vector2(-12.0, 10.0), str(amount), HORIZONTAL_ALIGNMENT_CENTER, 24, 11, Color("#ffffff"))
