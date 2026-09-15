class_name DivinationTargetDisplay
extends Control

const Config := preload("res://game_config.gd")

var faction := 0
var faction_name := ""
var target_visible := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_target(next_faction: int, next_name: String) -> void:
	faction = next_faction
	faction_name = next_name
	target_visible = true
	queue_redraw()

func clear_target() -> void:
	target_visible = false
	queue_redraw()

func _draw() -> void:
	if not target_visible:
		return
	var color := Color(str(Config.FACTION_COLORS.get(faction, "#94a3b8")))
	var center := Vector2(28.0, size.y * 0.5)
	var outline := Color("#020617")
	draw_circle(center + Vector2(0.0, -8.0), 9.0, outline)
	draw_circle(center + Vector2(0.0, -8.0), 6.5, color.lightened(0.14))
	draw_rect(Rect2(center + Vector2(-12.0, 2.0), Vector2(24.0, 18.0)), outline, true)
	draw_rect(Rect2(center + Vector2(-8.5, 5.0), Vector2(17.0, 13.0)), color, true)
	draw_line(center + Vector2(-9.0, 5.0), center + Vector2(-15.0, 14.0), outline, 2.0, true)
	draw_line(center + Vector2(9.0, 5.0), center + Vector2(15.0, 14.0), outline, 2.0, true)
	draw_string(ThemeDB.fallback_font, Vector2(52.0, size.y * 0.5 + 6.0), faction_name, HORIZONTAL_ALIGNMENT_LEFT, size.x - 52.0, 20, Color("#f8fafc"))
