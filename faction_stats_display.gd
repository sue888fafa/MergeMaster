@tool
class_name FactionStatsDisplay
extends Control

const Config := preload("res://game_config.gd")

var ui_config: UIEditorConfig
var faction_ids: Array[int] = []
var territory_counts: Dictionary = {}
var army_counts: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func configure_ui(config: UIEditorConfig) -> void:
	ui_config = config
	queue_redraw()

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
	var label_color := _config_color("faction_stats_label_color", Color("#cbd5e1"))
	var font_size := _config_int("faction_stats_font_size", 13)
	draw_string(ThemeDB.fallback_font, Vector2(0.0, 22.0), "领地", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, label_color)
	draw_string(ThemeDB.fallback_font, Vector2(0.0, 62.0), "士兵", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, label_color)
	var start_x := 42.0
	var step := _config_float("faction_stats_column_spacing", 48.0)
	for index in range(faction_ids.size()):
		var faction := faction_ids[index]
		var color := Color(str(Config.FACTION_COLORS.get(faction, "#94a3b8")))
		var center := Vector2(start_x + float(index) * step, 17.0)
		_draw_territory_hex(center, color, int(territory_counts.get(faction, 0)))
		_draw_soldier_avatar(Vector2(center.x, 57.0), color, int(army_counts.get(faction, 0)))

func _draw_territory_hex(center: Vector2, color: Color, amount: int) -> void:
	var outline := _config_color("faction_stats_outline_color", Color("#0b1220"))
	var radius := _config_float("faction_stats_icon_radius", 15.0)
	var points := PackedVector2Array()
	for index in range(6):
		var angle := PI / 6.0 + TAU * float(index) / 6.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, outline)
	var inner_points := PackedVector2Array()
	for point in points:
		inner_points.append(center + (point - center) * 0.82)
	draw_colored_polygon(inner_points, color.darkened(0.08))
	draw_string(ThemeDB.fallback_font, center + Vector2(-12.0, 5.0), str(amount), HORIZONTAL_ALIGNMENT_CENTER, 24, _config_int("faction_stats_font_size", 13), Color("#ffffff"))

func _draw_soldier_avatar(center: Vector2, color: Color, amount: int) -> void:
	var outline := _config_color("faction_stats_outline_color", Color("#0b1220"))
	var scale := _config_float("faction_stats_soldier_scale", 1.0)
	var avatar_center := center
	# Compact head-and-body silhouette; the count is printed on the torso.
	var head_radius := maxf(2.0, 6.5 * scale)
	draw_circle(avatar_center + Vector2(0.0, -7.0) * scale, head_radius, outline)
	draw_circle(avatar_center + Vector2(0.0, -7.0) * scale, maxf(1.5, 4.5 * scale), color.lightened(0.12))
	draw_rect(Rect2(avatar_center + Vector2(-8.0, 0.0) * scale, Vector2(16.0, 14.0) * scale), outline, true)
	draw_rect(Rect2(avatar_center + Vector2(-5.5, 1.5) * scale, Vector2(11.0, 10.5) * scale), color, true)
	draw_line(avatar_center + Vector2(-6.0, 3.0) * scale, avatar_center + Vector2(-11.0, 9.0) * scale, outline, maxf(1.0, 2.0 * scale), true)
	draw_line(avatar_center + Vector2(6.0, 3.0) * scale, avatar_center + Vector2(11.0, 9.0) * scale, outline, maxf(1.0, 2.0 * scale), true)
	draw_string(ThemeDB.fallback_font, avatar_center + Vector2(-12.0, 10.0) * scale, str(amount), HORIZONTAL_ALIGNMENT_CENTER, 24.0 * scale, _config_int("faction_stats_font_size", 13) - 2, Color("#ffffff"))

func _config_color(property_name: String, fallback: Color) -> Color:
	if ui_config != null:
		var value: Variant = ui_config.get(property_name)
		if value is Color:
			return value
	return fallback

func _config_float(property_name: String, fallback: float) -> float:
	if ui_config != null:
		var value: Variant = ui_config.get(property_name)
		if value is float or value is int:
			return float(value)
	return fallback

func _config_int(property_name: String, fallback: int) -> int:
	return maxi(1, roundi(_config_float(property_name, float(fallback))))
