@tool
extends Control

const Config := preload("res://game_config.gd")
const HeroAvatarCatalogScript := preload("res://hero_avatar_catalog.gd")

var faction := Config.FACTION_PLAYER

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func setup(value: int) -> void:
	faction = value
	queue_redraw()

func _draw() -> void:
	if not Config.FACTION_COLORS.has(faction):
		return
	var avatar := HeroAvatarCatalogScript.get_for_faction(faction)
	if avatar == null:
		return
	var draw_size := size
	var draw_position := (size - draw_size) * 0.5
	draw_texture_rect(avatar, Rect2(draw_position, draw_size), false)
