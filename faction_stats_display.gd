@tool
class_name FactionStatsDisplay
extends Control

const Config := preload("res://game_config.gd")
const HeroAvatarCatalogScript := preload("res://hero_avatar_catalog.gd")
const RANK_ART := {
	1: preload("res://assets/generated/ui/rank_icons/rank_1.png"),
	2: preload("res://assets/generated/ui/rank_icons/rank_2.png"),
	3: preload("res://assets/generated/ui/rank_icons/rank_3.png"),
	4: preload("res://assets/generated/ui/rank_icons/rank_4.png"),
	5: preload("res://assets/generated/ui/rank_icons/rank_5.png"),
	6: preload("res://assets/generated/ui/rank_icons/rank_6.png")
}
const TILE_ART := {
	Config.FACTION_PLAYER: preload("res://assets/generated/tiles/tile_blue.png"),
	Config.FACTION_RED: preload("res://assets/generated/tiles/tile_red.png"),
	Config.FACTION_PURPLE: preload("res://assets/generated/tiles/tile_purple.png"),
	Config.FACTION_GREEN: preload("res://assets/generated/tiles/tile_green.png")
}

var ui_config: UIEditorConfig
var faction_ids: Array[int] = []
var territory_counts: Dictionary = {}
var army_counts: Dictionary = {}
var eliminated_factions: Dictionary = {}
var authored_layout: Dictionary = {}
var displayed_territory_counts: Dictionary = {}
var displayed_army_counts: Dictionary = {}
var displayed_eliminated_factions: Dictionary = {}
var displayed_order: Array[int] = []
var target_order: Array[int] = []
var visual_slots: Dictionary = {}
var visual_scales: Dictionary = {}
var animation_start_slots: Dictionary = {}
var animation_target_slots: Dictionary = {}
var animation_start_scales: Dictionary = {}
var animation_target_scales: Dictionary = {}
var pending_territory_counts: Dictionary = {}
var pending_army_counts: Dictionary = {}
var pending_eliminated_factions: Dictionary = {}
var ranking_animation_time := 0.0
var ranking_animation_duration := 0.35
var ranking_animation_active := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func configure_ui(config: UIEditorConfig) -> void:
	ui_config = config
	ranking_animation_duration = maxf(0.05, _config_float("faction_stats_animation_duration", 0.35))
	queue_redraw()

func configure_authored_layout(layout: Dictionary) -> void:
	authored_layout = layout.duplicate(true)
	queue_redraw()

func reset_ranking_animation() -> void:
	ranking_animation_active = false
	ranking_animation_time = 0.0
	displayed_order.clear()
	target_order.clear()
	visual_slots.clear()
	visual_scales.clear()
	displayed_territory_counts.clear()
	displayed_army_counts.clear()
	displayed_eliminated_factions.clear()
	queue_redraw()

func set_faction_data(ids: Array, territories: Dictionary, armies: Dictionary, eliminated: Dictionary = {}) -> void:
	faction_ids.clear()
	for faction in ids:
		faction_ids.append(int(faction))
	territory_counts = territories.duplicate()
	army_counts = armies.duplicate()
	eliminated_factions = eliminated.duplicate()
	var new_order := _rank_factions(faction_ids, territory_counts)
	if displayed_order.is_empty():
		displayed_order = new_order.duplicate()
		target_order = new_order.duplicate()
		displayed_territory_counts = territory_counts.duplicate()
		displayed_army_counts = army_counts.duplicate()
		displayed_eliminated_factions = eliminated_factions.duplicate()
		for index in range(new_order.size()):
			visual_slots[new_order[index]] = float(index)
			visual_scales[new_order[index]] = _scale_for_rank(index)
		ranking_animation_duration = maxf(0.05, _config_float("faction_stats_animation_duration", 0.35))
		queue_redraw()
		return
	var comparison_order: Array[int] = target_order if ranking_animation_active else displayed_order
	if new_order == comparison_order:
		pending_territory_counts = territory_counts.duplicate()
		pending_army_counts = army_counts.duplicate()
		pending_eliminated_factions = eliminated_factions.duplicate()
		if not ranking_animation_active:
			displayed_territory_counts = pending_territory_counts.duplicate()
			displayed_army_counts = pending_army_counts.duplicate()
			displayed_eliminated_factions = pending_eliminated_factions.duplicate()
		queue_redraw()
		return
	_start_ranking_animation(new_order)
	queue_redraw()

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not ranking_animation_active:
		return
	ranking_animation_time = minf(ranking_animation_duration, ranking_animation_time + delta)
	var progress := ranking_animation_time / ranking_animation_duration
	var eased := 1.0 - pow(1.0 - progress, 2.0)
	for faction in animation_target_slots.keys():
		var faction_id := int(faction)
		visual_slots[faction_id] = lerpf(float(animation_start_slots.get(faction_id, 0.0)), float(animation_target_slots[faction_id]), eased)
		visual_scales[faction_id] = lerpf(float(animation_start_scales.get(faction_id, 1.0)), float(animation_target_scales[faction_id]), eased)
	queue_redraw()
	if progress >= 1.0:
		ranking_animation_active = false
		displayed_order = target_order.duplicate()
		displayed_territory_counts = pending_territory_counts.duplicate()
		displayed_army_counts = pending_army_counts.duplicate()
		displayed_eliminated_factions = pending_eliminated_factions.duplicate()
		for index in range(displayed_order.size()):
			visual_slots[displayed_order[index]] = float(index)
			visual_scales[displayed_order[index]] = _scale_for_rank(index)
		queue_redraw()

func _start_ranking_animation(new_order: Array[int]) -> void:
	animation_start_slots = visual_slots.duplicate()
	animation_start_scales = visual_scales.duplicate()
	animation_target_slots.clear()
	animation_target_scales.clear()
	for index in range(new_order.size()):
		var faction := int(new_order[index])
		animation_target_slots[faction] = float(index)
		animation_target_scales[faction] = _scale_for_rank(index)
		if not animation_start_slots.has(faction):
			animation_start_slots[faction] = float(index)
		if not animation_start_scales.has(faction):
			animation_start_scales[faction] = _scale_for_rank(index)
	target_order = new_order.duplicate()
	pending_territory_counts = territory_counts.duplicate()
	pending_army_counts = army_counts.duplicate()
	pending_eliminated_factions = eliminated_factions.duplicate()
	ranking_animation_time = 0.0
	ranking_animation_active = true

func _rank_factions(ids: Array[int], counts: Dictionary) -> Array[int]:
	var ranked := ids.duplicate()
	ranked.sort_custom(func(a: int, b: int) -> bool:
		var a_tiles := int(counts.get(a, 0))
		var b_tiles := int(counts.get(b, 0))
		return a_tiles > b_tiles if a_tiles != b_tiles else a < b
	)
	return ranked

func _scale_for_rank(rank: int) -> float:
	return _config_float("faction_stats_first_card_scale", 1.2) if rank == 0 else 1.0
	queue_redraw()

func _draw() -> void:
	if faction_ids.is_empty() and Engine.is_editor_hint():
		# Keep the authoring preview useful even before runtime data is supplied.
		faction_ids = Config.FACTION_IDS.duplicate()
		territory_counts = {
			Config.FACTION_PLAYER: 24,
			Config.FACTION_RED: 18,
			Config.FACTION_PURPLE: 12,
			Config.FACTION_GREEN: 9
		}
		army_counts = {
			Config.FACTION_PLAYER: 12,
			Config.FACTION_RED: 9,
			Config.FACTION_PURPLE: 7,
			Config.FACTION_GREEN: 5
		}
		if displayed_order.is_empty():
			displayed_order = _rank_factions(Config.FACTION_IDS, territory_counts)
			target_order = displayed_order.duplicate()
			displayed_territory_counts = territory_counts.duplicate()
			displayed_army_counts = army_counts.duplicate()
			for index in range(displayed_order.size()):
				visual_slots[displayed_order[index]] = float(index)
				visual_scales[displayed_order[index]] = _scale_for_rank(index)
	if faction_ids.is_empty():
		return
	var ranked := displayed_order if not displayed_order.is_empty() else _rank_factions(faction_ids, territory_counts)
	var configured_card_size := _config_vector2("faction_stats_card_size", Vector2(104.0, 92.0))
	var configured_spacing := _config_float("faction_stats_card_spacing", 4.0)
	var authored_cards: Dictionary = authored_layout.get("cards", {})
	if authored_cards.has("PlayerCard"):
		var authored_player: Dictionary = authored_cards["PlayerCard"]
		var authored_rect: Rect2 = authored_player.get("rect", Rect2())
		if authored_rect.size.x > 0.0 and authored_rect.size.y > 0.0:
			configured_card_size = authored_rect.size
		if authored_cards.has("RedCard"):
			var authored_red: Dictionary = authored_cards["RedCard"]
			var red_rect: Rect2 = authored_red.get("rect", Rect2())
			configured_spacing = red_rect.position.x - authored_rect.position.x - configured_card_size.x
	var card_width := minf(configured_card_size.x, (size.x - configured_spacing * float(ranked.size() - 1)) / maxf(1.0, float(ranked.size())))
	var step := card_width + configured_spacing
	var base_y := configured_card_size.y * 0.5
	for rank in range(ranked.size()):
		var faction := int(ranked[rank])
		var eliminated := bool(displayed_eliminated_factions.get(faction, eliminated_factions.get(faction, false)))
		var visual_slot := float(visual_slots.get(faction, rank))
		var visual_scale := float(visual_scales.get(faction, _scale_for_rank(rank)))
		var center := Vector2(card_width * 0.5 + visual_slot * step, base_y)
		_draw_ranked_card(center, faction, rank + 1, visual_scale, eliminated)
		if eliminated:
			draw_string(ThemeDB.fallback_font, center + Vector2(-30.0, 43.0), "已淘汰", HORIZONTAL_ALIGNMENT_LEFT, 60.0, 10, Color("#d1d5db"))

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

func _draw_ranked_avatar(center: Vector2, faction: int, avatar_scale: float, eliminated := false) -> void:
	var radius := _config_float("faction_stats_avatar_size", 44.0) * 0.5 * avatar_scale
	var avatar := HeroAvatarCatalogScript.get_for_faction(faction)
	if avatar == null:
		return
	var draw_size := Vector2(radius * 2.0, radius * 2.0)
	var tint := Color(0.48, 0.48, 0.48, 1.0) if eliminated else Color.WHITE
	draw_texture_rect(avatar, Rect2(center - draw_size * 0.5 + Vector2(0.0, 2.0), draw_size), false, tint)

func _draw_ranked_card(center: Vector2, faction: int, rank: int, avatar_scale: float, eliminated: bool) -> void:
	var color := Color("#6b7280") if eliminated else Color(str(Config.FACTION_COLORS.get(faction, "#94a3b8")))
	var authored_card := _authored_card_for_faction(faction)
	if not authored_card.is_empty():
		_draw_authored_ranked_card(center, faction, rank, color, eliminated, authored_card)
		return
	var scale := avatar_scale
	var base_avatar_center := center + _config_vector2("faction_stats_avatar_offset", Vector2(-22.0, -3.0))
	var avatar_center := center + (base_avatar_center - center) * scale
	_draw_ranked_avatar(avatar_center, faction, scale, eliminated)
	var rank_icon: Texture2D = RANK_ART.get(rank, null)
	if rank_icon != null:
		var rank_size := _config_vector2("faction_stats_rank_icon_size", Vector2(34.0, 34.0))
		var rank_offset := _config_vector2("faction_stats_rank_icon_offset", Vector2(-25.0, -29.0))
		draw_texture_rect(rank_icon, Rect2(avatar_center + rank_offset * scale, rank_size * scale), false)
	var name := str(Config.FACTION_NAMES.get(faction, "玩家"))
	var name_color := Color("#9ca3af") if eliminated else Color("#ffffff")
	var name_rect := _config_rect2("faction_stats_name_rect", Rect2(8.0, -7.0, 80.0, 20.0))
	draw_string(
		ThemeDB.fallback_font,
		center + name_rect.position * scale,
		name,
		HORIZONTAL_ALIGNMENT_LEFT,
		name_rect.size.x * scale,
		roundi(_config_int("faction_stats_name_font_size", 12) * scale),
		name_color
	)
	var tile_art: Texture2D = TILE_ART.get(faction, null)
	if tile_art != null:
		var tile_rect_config := _config_rect2("faction_stats_tile_rect", Rect2(2.0, 7.0, 45.0, 34.0))
		var tile_rect := Rect2(center + tile_rect_config.position * scale, tile_rect_config.size * scale)
		_draw_texture_rect_keep_aspect(tile_art, tile_rect, Color(0.48, 0.48, 0.48, 1.0) if eliminated else Color.WHITE)
		var count_offset := _config_vector2("faction_stats_tile_count_offset", Vector2(9.0, 24.0))
		draw_string(
			ThemeDB.fallback_font,
			tile_rect.position + count_offset * scale,
			str(int(displayed_territory_counts.get(faction, 0))),
			HORIZONTAL_ALIGNMENT_CENTER,
			maxf(1.0, tile_rect.size.x - count_offset.x * 2.0 * scale),
			roundi(_config_int("faction_stats_tile_count_font_size", 16) * scale),
			Color.WHITE
		)

func _authored_card_for_faction(faction: int) -> Dictionary:
	var cards: Dictionary = authored_layout.get("cards", {})
	var card_name := "PlayerCard" if faction == Config.FACTION_PLAYER else "RedCard" if faction == Config.FACTION_RED else "PurpleCard" if faction == Config.FACTION_PURPLE else "GreenCard"
	var value: Variant = cards.get(card_name, {})
	return value if value is Dictionary else {}

func _draw_authored_ranked_card(center: Vector2, faction: int, rank: int, color: Color, eliminated: bool, card: Dictionary) -> void:
	var card_rect: Rect2 = card.get("rect", Rect2(Vector2.ZERO, Vector2(104.0, 92.0)))
	var origin := center - card_rect.size * 0.5
	var visual_scale := _current_scale_for_ranked_card(faction)
	var avatar_data: Dictionary = card.get("Avatar", {})
	var avatar_rect: Rect2 = avatar_data.get("rect", Rect2(3.0, 17.0, 44.0, 44.0))
	var avatar_texture: Texture2D = avatar_data.get("texture", HeroAvatarCatalogScript.get_for_faction(faction))
	if avatar_texture != null:
		draw_texture_rect(avatar_texture, _scaled_authored_rect(center, origin, avatar_rect, visual_scale), false, Color(0.48, 0.48, 0.48, 1.0) if eliminated else Color.WHITE)
	var rank_data: Dictionary = card.get("RankIcon", {})
	var rank_rect: Rect2 = rank_data.get("rect", Rect2(0.0, 0.0, 30.0, 30.0))
	var rank_icon: Texture2D = RANK_ART.get(rank, null)
	if rank_icon != null:
		draw_texture_rect(rank_icon, _scaled_authored_rect(center, origin, rank_rect, visual_scale), false)
	var name_data: Dictionary = card.get("Name", {})
	var name_rect: Rect2 = name_data.get("rect", Rect2(43.0, 17.0, 39.0, 21.0))
	draw_string(ThemeDB.fallback_font, _scaled_authored_point(center, origin + name_rect.position, visual_scale), str(Config.FACTION_NAMES.get(faction, "玩家")), HORIZONTAL_ALIGNMENT_CENTER, name_rect.size.x * visual_scale, roundi(_config_int("faction_stats_name_font_size", 12) * visual_scale), Color("#9ca3af") if eliminated else Color.WHITE)
	var tile_data: Dictionary = card.get("TileIcon", {})
	var tile_rect: Rect2 = tile_data.get("rect", Rect2(36.0, 56.0, 45.0, 34.0))
	var tile_texture: Texture2D = tile_data.get("texture", TILE_ART.get(faction, null))
	if tile_texture != null:
		_draw_texture_rect_keep_aspect(tile_texture, _scaled_authored_rect(center, origin, tile_rect, visual_scale), Color(0.48, 0.48, 0.48, 1.0) if eliminated else Color.WHITE)
	var count_data: Dictionary = card.get("TileCount", {})
	var count_rect: Rect2 = count_data.get("rect", Rect2(45.0, 61.0, 33.0, 24.0))
	draw_string(ThemeDB.fallback_font, _scaled_authored_point(center, origin + count_rect.position + Vector2(0.0, count_rect.size.y * 0.78), visual_scale), str(int(displayed_territory_counts.get(faction, 0))), HORIZONTAL_ALIGNMENT_CENTER, count_rect.size.x * visual_scale, roundi(_config_int("faction_stats_tile_count_font_size", 16) * visual_scale), Color.WHITE)

func _current_scale_for_ranked_card(faction: int) -> float:
	return float(visual_scales.get(faction, 1.0))

func _scaled_authored_point(center: Vector2, point: Vector2, scale: float) -> Vector2:
	return center + (point - center) * scale

func _scaled_authored_rect(center: Vector2, origin: Vector2, rect: Rect2, scale: float) -> Rect2:
	return Rect2(_scaled_authored_point(center, origin + rect.position, scale), rect.size * scale)

func _draw_texture_rect_keep_aspect(texture: Texture2D, target_rect: Rect2, modulate := Color.WHITE) -> void:
	if texture == null or target_rect.size.x <= 0.0 or target_rect.size.y <= 0.0:
		return
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var fit_scale := minf(target_rect.size.x / texture_size.x, target_rect.size.y / texture_size.y)
	var draw_size := texture_size * fit_scale
	var draw_rect := Rect2(target_rect.position + (target_rect.size - draw_size) * 0.5, draw_size)
	draw_texture_rect(texture, draw_rect, false, modulate)

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

func _config_vector2(property_name: String, fallback: Vector2) -> Vector2:
	if ui_config != null:
		var value: Variant = ui_config.get(property_name)
		if value is Vector2:
			return value
	return fallback

func _config_rect2(property_name: String, fallback: Rect2) -> Rect2:
	if ui_config != null:
		var value: Variant = ui_config.get(property_name)
		if value is Rect2:
			return value
	return fallback

func _config_int(property_name: String, fallback: int) -> int:
	return maxi(1, roundi(_config_float(property_name, float(fallback))))
