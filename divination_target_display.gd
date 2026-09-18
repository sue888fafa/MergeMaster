class_name DivinationTargetDisplay
extends Control

const Config := preload("res://game_config.gd")
const HeroAvatarCatalogScript := preload("res://hero_avatar_catalog.gd")

var faction := 0
var faction_name := ""
var target_visible := false
var avatar: Texture2D

@export_category("水晶球目标布局")
@export var avatar_center := Vector2(85.0, 125.0)
@export_range(16.0, 96.0, 1.0) var avatar_size := 42.0
@export_range(0.0, 260.0, 1.0) var name_baseline := 173.0
@export var target_clip_rect := Rect2(0.0, 0.0, 170.0, 115.0)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_target(next_faction: int, next_name: String) -> void:
	faction = next_faction
	faction_name = next_name
	avatar = HeroAvatarCatalogScript.get_for_faction(faction)
	target_visible = true
	queue_redraw()

func clear_target() -> void:
	target_visible = false
	avatar = null
	queue_redraw()

func _draw() -> void:
	if not target_visible:
		return
	var color := Color(str(Config.FACTION_COLORS.get(faction, "#94a3b8")))
	var center := avatar_center
	var outline := Color("#020617")
	draw_circle(center, 22.0, Color(color, 0.20))
	draw_arc(center, 22.0, 0.0, TAU, 32, color.lightened(0.25), 3.0, true)
	draw_circle(center, 15.0, outline)
	draw_circle(center, 12.0, color.lightened(0.16))
	draw_circle(center + Vector2(-4.0, -4.0), 3.0, Color(1.0, 1.0, 1.0, 0.75))
	if avatar != null:
		var half_size := avatar_size * 0.5
		var avatar_rect := Rect2(center - Vector2(half_size, half_size), Vector2(avatar_size, avatar_size))
		draw_texture_rect(avatar, avatar_rect, false, Color(1, 1, 1, 0.95))
	draw_string(ThemeDB.fallback_font, Vector2(0.0, name_baseline), faction_name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color("#f8fafc"))
