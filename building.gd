class_name BuildingLayer
extends Node2D

const Config := preload("res://game_config.gd")

const MINE := 1
const BARRACKS := 2
const TOWER := 3
const BARRACKS_PRODUCTION_INTERVAL := Config.BARRACKS_PRODUCTION_INTERVAL
const HQ_MAX_HP := Config.HQ_MAX_HP

var board: HexBoard
var main_ref: Node
var redraw_timer := 0.0
const REDRAW_INTERVAL := 1.0 / 30.0

func setup(next_board: HexBoard) -> void:
	board = next_board
	main_ref = get_parent()
	board.building_visual_dirty = true
	queue_redraw()

func _process(delta: float) -> void:
	if board == null:
		return
	redraw_timer -= delta
	if board.building_visual_dirty:
		redraw_timer = REDRAW_INTERVAL
		board.building_visual_dirty = false
		queue_redraw()
	elif not board.merge_effect_cells.is_empty():
		# The pulsing merge indicator is drawn only for buildings, so keep its
		# animation alive without redrawing the whole board.
		queue_redraw()

func _draw() -> void:
	if board == null:
		return
	for raw_cell in board.building_cells:
		var cell: Vector2i = raw_cell
		var tile: Dictionary = board.tiles[cell]
		if not bool(tile["revealed"]):
			continue
		if board.long_press_active and cell == board.drag_start_cell:
			continue
		var building: int = int(tile["building"])
		var center := board.axial_to_world(cell)
		if building == BARRACKS:
			center += board.get_barracks_merge_offset(cell)
		if main_ref != null and main_ref.has_method("is_hq_cell") and bool(main_ref.call("is_hq_cell", cell)):
			continue
		if building == 0:
			continue
		var owner_color := _faction_color(int(tile["owner"]), Color("#94a3b8"))
		_draw_building_health(center, tile)
		if building == BARRACKS:
			var progress := board.get_build_timer(cell)
			var production_interval := _get_barracks_production_interval(int(tile.get("owner", board.UNKNOWN if board != null else 0)))
			var progress_ratio := clampf(1.0 - progress / production_interval, 0.0, 1.0)
			_draw_barracks_production_progress(center, progress_ratio, owner_color)
			if board.merge_effect_cell_set.has(cell):
				_draw_merge_indicator(center, int(tile.get("building_level", 1)))
	if main_ref != null and main_ref.has_method("get_faction_ids"):
		for owner in main_ref.get_faction_ids():
			var hq_cell: Vector2i = main_ref.get_hq_cell(owner)
			if board.has_cell(hq_cell):
				_draw_hq_health(hq_cell, board.axial_to_world(hq_cell))

func _draw_barracks_production_progress(center: Vector2, progress_ratio: float, owner_color: Color) -> void:
	var ring_center := center + Vector2(0.0, 1.0)
	var ring_radius := 14.0
	draw_arc(ring_center, ring_radius, 0.0, TAU, 24, Color(0.03, 0.07, 0.13, 0.78), 2.0, true)
	if progress_ratio > 0.0:
		draw_arc(ring_center, ring_radius, -PI * 0.5, -PI * 0.5 + TAU * progress_ratio, 24, owner_color, 2.0, true)

func _draw_merge_indicator(center: Vector2, level: int) -> void:
	var tier := clampi(level, 1, 4)
	var scale := float(Config.BARRACKS_LEVEL_SCALE[tier - 1])
	var model_center := center + Vector2(0.0, Config.BARRACKS_MODEL_LIFT)
	var pulse := 0.5 + 0.5 * sin(board.mergeable_effect_elapsed * 5.0)
	draw_circle(model_center + Vector2(0.0, -5.0), 27.0 * scale, Color(1.0, 0.78, 0.22, 0.045 + pulse * 0.035))
	draw_arc(model_center + Vector2(0.0, -5.0), 25.0 * scale, -PI * 0.5, TAU - PI * 0.5, 32, Color(1.0, 0.78, 0.22, 0.30 + pulse * 0.30), 2.0, true)

func _draw_building_health(center: Vector2, tile: Dictionary) -> void:
	var max_hp: float = float(tile["building_max_hp"])
	var hp: float = float(tile["building_hp"])
	if max_hp <= 0.0 or hp >= max_hp:
		return
	var owner_color := _faction_color(int(tile["owner"]), Color("#94a3b8"))
	draw_rect(Rect2(center + Vector2(-15, 20), Vector2(30, 3)), Color("#0f172a"), true)
	draw_rect(Rect2(center + Vector2(-15, 20), Vector2(30.0 * clampf(hp / max_hp, 0.0, 1.0), 3)), owner_color, true)

func _draw_hq_health(cell: Vector2i, center: Vector2) -> void:
	if main_ref == null:
		return
	if not main_ref.has_method("get_hq_owner") or not main_ref.has_method("is_hq_destroyed"):
		return
	if bool(main_ref.call("is_hq_destroyed", cell)):
		return
	var owner := int(main_ref.call("get_hq_owner", cell))
	if owner <= 0:
		return
	var hp: float = float(main_ref.base_hp[owner])
	var max_hp: float = float(main_ref.call("get_hq_max_hp", owner)) if main_ref.has_method("get_hq_max_hp") else HQ_MAX_HP
	if hp >= max_hp:
		return
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	draw_rect(Rect2(center + Vector2(-18, -53), Vector2(36, 4)), Color("#0f172a"), true)
	draw_rect(Rect2(center + Vector2(-18, -53), Vector2(36.0 * ratio, 4)), _faction_color(owner, Color("#f87171")), true)

func _faction_color(owner: int, fallback: Color) -> Color:
	if main_ref != null and main_ref.has_method("get_faction_color"):
		return main_ref.call("get_faction_color", owner)
	return fallback

func _get_barracks_production_interval(owner: int) -> float:
	if main_ref != null and main_ref.has_method("get_barracks_production_interval"):
		return maxf(0.01, float(main_ref.call("get_barracks_production_interval", owner)))
	return BARRACKS_PRODUCTION_INTERVAL
