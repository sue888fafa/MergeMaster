extends Control

const Config := preload("res://game_config.gd")

var faction := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func setup(value: int) -> void:
	faction = value
	queue_redraw()

func _draw() -> void:
	if not Config.FACTION_COLORS.has(faction):
		return
	var color := Color(str(Config.FACTION_COLORS.get(faction, "#94a3b8")))
	var center := size * 0.5
	var scale := minf(size.x / 32.0, size.y / 32.0)
	var outline := Color("#0b1220")
	# Compact portrait matching the colored soldier avatars in the faction HUD.
	draw_circle(center + Vector2(0.0, -7.0) * scale, 7.0 * scale, outline)
	draw_circle(center + Vector2(0.0, -7.0) * scale, 5.0 * scale, color.lightened(0.12))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-10.0, -9.0) * scale,
		center + Vector2(10.0, -9.0) * scale,
		center + Vector2(7.0, -5.0) * scale,
		center + Vector2(-7.0, -5.0) * scale
	]), outline)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-8.0, -8.0) * scale,
		center + Vector2(8.0, -8.0) * scale,
		center + Vector2(6.0, -5.0) * scale,
		center + Vector2(-6.0, -5.0) * scale
	]), color.darkened(0.12))
	draw_rect(Rect2(center + Vector2(-9.0, 0.0) * scale, Vector2(18.0, 14.0) * scale), outline, true)
	draw_rect(Rect2(center + Vector2(-6.0, 2.0) * scale, Vector2(12.0, 10.0) * scale), color, true)
	draw_line(center + Vector2(-7.0, 3.0) * scale, center + Vector2(-12.0, 10.0) * scale, outline, maxf(1.0, 2.0 * scale), true)
	draw_line(center + Vector2(7.0, 3.0) * scale, center + Vector2(12.0, 10.0) * scale, outline, maxf(1.0, 2.0 * scale), true)

