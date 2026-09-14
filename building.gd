class_name BuildingLayer
extends Node2D

const Config := preload("res://game_config.gd")
const Art := preload("res://art_theme.gd")

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
	var barracks_progress_changed := _update_barracks_visual_progress(delta)
	if board.building_visual_dirty:
		redraw_timer = REDRAW_INTERVAL
		board.building_visual_dirty = false
		queue_redraw()
	elif (_has_active_mines() or barracks_progress_changed) and redraw_timer <= 0.0:
		redraw_timer = REDRAW_INTERVAL
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
		var center := board.get_cell_surface_anchor(cell) if board.has_method("get_cell_surface_anchor") else board.axial_to_world(cell)
		var barracks_anchor: Dictionary = {}
		if building == BARRACKS and board.has_method("get_building_visual_anchor"):
			barracks_anchor = board.get_building_visual_anchor(cell, int(tile.get("building_level", 1)), int(tile.get("unit_class", -1)))
			barracks_anchor = _offset_barracks_anchor(barracks_anchor, board.get_barracks_merge_offset(cell))
			center = Vector2(barracks_anchor["surface"])
		if main_ref != null and main_ref.has_method("is_hq_cell") and bool(main_ref.call("is_hq_cell", cell)):
			continue
		if building == 0:
			continue
		_draw_building_health(center, tile)
		if building == BARRACKS:
			var progress := board.get_build_timer(cell)
			var production_interval := _get_barracks_production_interval(int(tile.get("owner", board.UNKNOWN if board != null else 0)))
			var has_soldier := board.get_production_count(cell) >= 1
			var barracks_level := clampi(int(tile.get("building_level", 1)), 1, 4)
			var barracks_unit_class := int(tile.get("unit_class", -1))
			var progress_ratio := clampf(
				board.get_barracks_visual_timer(cell) / production_interval,
				0.0,
				1.0
			) if has_soldier else clampf(1.0 - progress / production_interval, 0.0, 1.0)
			_draw_barracks_production_progress(barracks_anchor, progress_ratio)
			if board.merge_effect_cell_set.has(cell):
				_draw_merge_indicator(barracks_anchor, int(tile.get("building_level", 1)))
		elif building == MINE and main_ref != null and main_ref.has_method("get_mine_income_progress"):
			_draw_mine_income_progress(center, float(main_ref.call("get_mine_income_progress")))
	if main_ref != null and main_ref.has_method("get_faction_ids"):
		for owner in main_ref.get_faction_ids():
			var hq_cell: Vector2i = main_ref.get_hq_cell(owner)
			if board.has_cell(hq_cell):
				_draw_hq_health(hq_cell, board.get_cell_world_center(hq_cell) if board.has_method("get_cell_world_center") else board.axial_to_world(hq_cell))

func _draw_barracks_production_progress(anchor: Dictionary, progress_ratio: float) -> void:
	var visual_scale := Config.BARRACKS_PROGRESS_VISUAL_SCALE
	var ring_radius := 14.0 * visual_scale
	var ring_center := Vector2(anchor["progress_center"])
	var progress_width := Config.BARRACKS_PROGRESS_LINE_WIDTH * visual_scale
	var progress_color := Color(Config.BUILDING_PROGRESS_COLOR)
	draw_arc(ring_center, ring_radius, 0.0, TAU, 24, Art.INK, progress_width, true)
	if progress_ratio > 0.0:
		draw_arc(ring_center, ring_radius, -PI * 0.5, -PI * 0.5 + TAU * progress_ratio, 24, progress_color, progress_width, true)

func _draw_mine_income_progress(center: Vector2, progress_ratio: float) -> void:
	var visual_scale := Config.BUILDING_PROGRESS_VISUAL_SCALE
	var ring_center := center
	var ring_radius := 14.0 * visual_scale
	var progress_width := Config.BUILDING_PROGRESS_LINE_WIDTH * visual_scale
	var progress_color := Color(Config.BUILDING_PROGRESS_COLOR)
	draw_arc(ring_center, ring_radius, 0.0, TAU, 24, Art.INK, progress_width, true)
	if progress_ratio > 0.0:
		draw_arc(ring_center, ring_radius, -PI * 0.5, -PI * 0.5 + TAU * progress_ratio, 24, progress_color, progress_width, true)

func _has_active_mines() -> bool:
	if board == null:
		return false
	for raw_cell in board.building_cells:
		var tile: Dictionary = board.tiles[raw_cell]
		if bool(tile.get("revealed", false)) and int(tile.get("building", 0)) == MINE:
			return true
	return false

func _update_barracks_visual_progress(delta: float) -> bool:
	if board == null:
		return false
	var changed := false
	for raw_cell in board.building_cells:
		var cell: Vector2i = raw_cell
		var tile: Dictionary = board.tiles[cell]
		if int(tile.get("building", 0)) != BARRACKS:
			continue
		var current := board.get_barracks_visual_timer(cell)
		var has_soldier := board.get_production_count(cell) >= 1
		var interval := _get_barracks_production_interval(int(tile.get("owner", board.UNKNOWN if board != null else 0)))
		var next_value := minf(interval, current + delta) if has_soldier else 0.0
		if not is_equal_approx(current, next_value):
			board.update_barracks_visual_timer(cell, next_value)
			changed = true
	return changed

func _draw_merge_indicator(anchor: Dictionary, level: int) -> void:
	var tier := clampi(level, 1, 4)
	var scale := float(anchor.get("scale", Config.BARRACKS_LEVEL_SCALE[tier - 1]))
	var model_center := Vector2(anchor["center"])
	var cycle := fmod(board.mergeable_effect_elapsed * 0.45, 1.0)
	var arrow_color := Color(1.0, 0.78, 0.08, 0.56)
	var arrow_outline := Color(0.15, 0.09, 0.02, 0.46)
	var progress := cycle
	var alpha := 0.18 + (1.0 - progress) * 0.42
	var arrow_center := model_center + Vector2(0.0, -2.0 - progress * 12.0 * scale)
	var arrow_size := 6.5 * scale
	var shaft_start := arrow_center + Vector2(0.0, arrow_size * 1.20)
	var shaft_end := arrow_center + Vector2(0.0, -arrow_size * 0.55)
	var head_left := arrow_center + Vector2(-arrow_size, arrow_size * 0.50)
	var head_right := arrow_center + Vector2(arrow_size, arrow_size * 0.50)
	var outline_alpha := alpha * 0.80
	var outline_width := maxf(2.5, 5.0 * scale)
	var arrow_width := maxf(1.8, 3.2 * scale)
	draw_line(shaft_start, shaft_end, Color(arrow_outline, outline_alpha), outline_width, true)
	draw_line(shaft_start, shaft_end, Color(arrow_color, alpha), arrow_width, true)
	draw_line(head_left, shaft_end, Color(arrow_outline, outline_alpha), outline_width, true)
	draw_line(head_right, shaft_end, Color(arrow_outline, outline_alpha), outline_width, true)
	draw_line(head_left, shaft_end, Color(arrow_color, alpha), arrow_width, true)
	draw_line(head_right, shaft_end, Color(arrow_color, alpha), arrow_width, true)

func _offset_barracks_anchor(anchor: Dictionary, offset: Vector2) -> Dictionary:
	var result := anchor.duplicate()
	for key in ["surface", "center", "ground", "progress_center", "badge_center"]:
		if result.has(key):
			result[key] = Vector2(result[key]) + offset
	return result

func _draw_building_health(center: Vector2, tile: Dictionary) -> void:
	var max_hp: float = float(tile["building_max_hp"])
	var hp: float = float(tile["building_hp"])
	if max_hp <= 0.0 or hp >= max_hp:
		return
	var owner_color := _faction_color(int(tile["owner"]), Color("#94a3b8"))
	draw_rect(Rect2(center + Vector2(-17, 20), Vector2(34, 6)), Art.INK, true)
	draw_rect(Rect2(center + Vector2(-15, 22), Vector2(30.0 * clampf(hp / max_hp, 0.0, 1.0), 2)), owner_color.lightened(0.12), true)

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
	draw_rect(Rect2(center + Vector2(-20, -55), Vector2(40, 7)), Art.INK, true)
	draw_rect(Rect2(center + Vector2(-18, -53), Vector2(36.0 * ratio, 3)), _faction_color(owner, Art.CORAL).lightened(0.12), true)

func _faction_color(owner: int, fallback: Color) -> Color:
	if main_ref != null and main_ref.has_method("get_faction_color"):
		return main_ref.call("get_faction_color", owner)
	return fallback

func _get_barracks_production_interval(owner: int) -> float:
	if main_ref != null and main_ref.has_method("get_barracks_production_interval"):
		return maxf(0.01, float(main_ref.call("get_barracks_production_interval", owner)))
	return BARRACKS_PRODUCTION_INTERVAL
