class_name HexBoard
extends Node2D

const Config := preload("res://game_config.gd")
const Art := preload("res://art_theme.gd")
const MERCHANT_ART := preload("res://assets/generated/merchant.png")
const VISIBLE_GOLD_MINE_ART := preload("res://assets/generated/visible_landmarks/visible_gold_mine.png")
const TILE_UNCLAIMED_ART := preload("res://assets/generated/tiles/tile_unclaimed.png")
const TILE_GREEN_ART := preload("res://assets/generated/tiles/tile_green.png")
const TILE_BLUE_ART := preload("res://assets/generated/tiles/tile_blue.png")
const TILE_RED_ART := preload("res://assets/generated/tiles/tile_red.png")
const TILE_PURPLE_ART := preload("res://assets/generated/tiles/tile_purple.png")
const BARRACKS_ART_PLAYER := preload("res://assets/generated/barracks/barracks_classes_player.png")
const BARRACKS_ART_RED := preload("res://assets/generated/barracks/barracks_classes_red.png")
const BARRACKS_ART_PURPLE := preload("res://assets/generated/barracks/barracks_classes_purple.png")
const BARRACKS_ART_GREEN := preload("res://assets/generated/barracks/barracks_classes_green.png")
const BARRACKS_ART_REGIONS: Array[Rect2] = [
	Rect2(0.0, 70.0, 370.0, 420.0),
	Rect2(370.0, 70.0, 320.0, 420.0),
	Rect2(90.0, 470.0, 430.0, 490.0),
	Rect2(510.0, 500.0, 490.0, 490.0),
	Rect2(670.0, 60.0, 354.0, 440.0)
]
const TILE_ART_SCALE_X := 0.90
const TILE_ART_SCALE_Y := 1.083

signal tile_clicked(cell: Vector2i)
signal tile_dragged(from_cell: Vector2i, to_cell: Vector2i)
signal tile_drag_started(cell: Vector2i)
signal tile_reveal_midpoint(cell: Vector2i)
signal tile_reveal_finished(cell: Vector2i)
signal intelligence_building_drop_finished(cell: Vector2i)
signal building_changed(cell: Vector2i, building: int)

const UNKNOWN := 0
const PLAYER := Config.FACTION_PLAYER
const AI := Config.FACTION_RED
const FACTIONS: Array[int] = Config.FACTION_IDS
const EMPTY := 0
const MINE := 1
const BARRACKS := 2
const TOWER := 3
const MERCHANT := 4
const STEEL_BARRIER := 5
const FATE := Config.FATE_TILE_TYPE
const BARRACKS_2 := Config.BARRACKS_2_TILE_TYPE
const MINE_TILE := Config.MINE_TILE_TYPE
const WILD_MONSTER := Config.WILD_MONSTER_TILE_TYPE
const LONG_PRESS_DURATION := 0.35
const CAMERA_PAN_THRESHOLD := 8.0
const DIRECTIONS := [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]
const PLAYER_HQ := Config.PLAYER_HQ
const AI_HQ := Config.AI_HQ
const HQ_CELLS: Array[Vector2i] = [
	Config.PLAYER_HQ,
	Config.AI_HQ,
	Config.PURPLE_HQ,
	Config.GREEN_HQ
]

var radius := Config.BOARD_RADIUS
var tile_size := 50.0
var board_origin := Vector2(640.0, 430.0)
var tiles: Dictionary = {}
var draw_cells: Array[Vector2i] = []
var map_min_world := Vector2.ZERO
var map_max_world := Vector2.ZERO
var buildable_cells: Array[Vector2i] = []
var mergeable_cells: Array[Vector2i] = []
var merge_effect_cells: Array[Vector2i] = []
var purchasable_cells: Array[Vector2i] = []
var buildable_cell_set: Dictionary = {}
var mergeable_cell_set: Dictionary = {}
var merge_effect_cell_set: Dictionary = {}
var purchasable_cell_set: Dictionary = {}
var building_cells: Dictionary = {}
var player_gold := 0.0
var drag_start_cell := Vector2i(999, 999)
var drag_active := false
var camera_drag_active := false
var long_press_timer := 0.0
var long_press_active := false
var drag_preview_world := Vector2.ZERO
var pointer_down_screen_position := Vector2.ZERO
var barracks_range_cell := Vector2i(999, 999)
var reveal_animations: Dictionary = {}
var barracks_merge_animations: Dictionary = {}
var intelligence_building_drop_animations: Dictionary = {}
var merchant_presentation_animations: Dictionary = {}
var bombardment_cells: Array[Vector2i] = []
var bombardment_warning_cells: Array[Vector2i] = []
var bombardment_warning_elapsed := 0.0
var mergeable_effect_elapsed := 0.0
var merge_effect_refresh_timer := 0.0
var tile_material_elapsed := 0.0
var tile_material_redraw_timer := 0.0
var card_land_loss_cell := Vector2i(999, 999)
var card_land_loss_elapsed := 0.0
var camera_focus_tween: Tween
var cells_within_detection_range: Dictionary = {}
var building_visual_dirty := true
var has_animated_building_progress := false
var animated_building_progress_cells: Dictionary = {}
var last_draw_canvas_transform := Transform2D.IDENTITY
var last_draw_viewport_size := Vector2(-1.0, -1.0)
@onready var camera: Camera2D = get_parent().get_node_or_null("Camera2D")

func _ready() -> void:
	_build_map()
	_clamp_camera_position()
	queue_redraw()

func _build_map() -> void:
	tiles.clear()
	draw_cells.clear()
	animated_building_progress_cells.clear()
	building_cells.clear()
	has_animated_building_progress = false
	building_visual_dirty = true
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			if abs(q + r) <= radius:
				var cell := Vector2i(q, r)
				tiles[cell] = {
					"tile_type": Config.BARRACKS_TILE_TYPE,
					"visible_tile_result": -1,
					"visible_monster_level": Config.WILD_MONSTER_LEVEL_ONE,
					"unit_class": -1,
					"owner": UNKNOWN,
					"revealed": false,
					"building": EMPTY,
					"building_level": 0,
					"building_hp": 0.0,
					"building_max_hp": 0.0,
					"production_count": 0,
					"build_timer": 0.0,
					"barracks_visual_timer": 0.0,
					"intelligence_free_claim": false,
					"chest_reward": false,
					"chest_reward_amount": 0,
					"fate_event_active": false,
					"monster_active": false,
					"merchant_active": false,
					"merchant_stock": [],
					"ground_item_id": "",
					"rebuildable": false
				}
				draw_cells.append(cell)

	# Assign the three map categories as one map-level distribution. This keeps
	# question tiles reliable instead of allowing a visually empty random roll.
	_assign_tile_types()

	# Only the HQs are owned at the start; their six neighbors are the initial purchase frontier.
	for owner in FACTIONS:
		set_tile_owner(_hq_cell_for_owner(owner), owner, true)
	draw_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return axial_to_world(a).y < axial_to_world(b).y
	)
	_recalculate_map_bounds()
	_build_detection_range_cache()

func _hq_cell_for_owner(owner: int) -> Vector2i:
	return Config.FACTION_HQ_CELLS.get(owner, Vector2i(999, 999))

func _build_detection_range_cache() -> void:
	cells_within_detection_range.clear()
	var detection_range := int(Config.BARRACKS_DETECTION_RANGE)
	for cell in tiles:
		var nearby: Array[Vector2i] = []
		# Enumerate the local hexagon in the same q/r order as the board
		# dictionary, avoiding a full-board comparison for every cell.
		for delta_q in range(-detection_range, detection_range + 1):
			for delta_r in range(-detection_range, detection_range + 1):
				if abs(delta_q) + abs(delta_r) + abs(delta_q + delta_r) > detection_range * 2:
					continue
				var other_cell: Vector2i = cell + Vector2i(delta_q, delta_r)
				if tiles.has(other_cell):
					nearby.append(other_cell)
		cells_within_detection_range[cell] = nearby

func get_cells_within_detection_range(cell: Vector2i) -> Array[Vector2i]:
	return cells_within_detection_range.get(cell, [cell])

func _assign_tile_types() -> void:
	var candidates: Array[Vector2i] = []
	for cell in tiles:
		var typed_cell: Vector2i = cell
		if not HQ_CELLS.has(typed_cell):
			candidates.append(typed_cell)
	if candidates.is_empty():
		return

	var question_count: int = clampi(roundi(float(candidates.size()) * Config.QUESTION_TILE_TYPE_WEIGHT), 2, candidates.size())
	var visible_count: int = clampi(roundi(float(candidates.size()) * Config.VISIBLE_TILE_TYPE_WEIGHT), 0, candidates.size() - question_count)
	var forced_questions: Array[Vector2i] = []
	for hq in HQ_CELLS:
		var nearby: Array[Vector2i] = neighbors(hq)
		nearby.shuffle()
		for cell in nearby:
			if candidates.has(cell) and not forced_questions.has(cell):
				forced_questions.append(cell)
				break

	var question_cells: Array[Vector2i] = forced_questions.duplicate()
	for cell in forced_questions:
		candidates.erase(cell)
	candidates.shuffle()
	while question_cells.size() < question_count and not candidates.is_empty():
		question_cells.append(candidates.pop_back())

	for cell in question_cells:
		tiles[cell]["tile_type"] = Config.QUESTION_TILE_TYPE
		tiles[cell]["visible_tile_result"] = -1

	candidates.shuffle()
	for index in range(visible_count):
		if candidates.is_empty():
			break
		var visible_cell: Vector2i = candidates.pop_back()
		tiles[visible_cell]["tile_type"] = Config.VISIBLE_TILE_TYPE
		var visible_result := _roll_visible_tile_result()
		tiles[visible_cell]["visible_tile_result"] = visible_result
		if visible_result == Config.VISIBLE_WILD_MONSTER:
			tiles[visible_cell]["visible_monster_level"] = _roll_visible_monster_level()

	for cell in candidates:
		tiles[cell]["tile_type"] = Config.BARRACKS_TILE_TYPE
		tiles[cell]["visible_tile_result"] = -1

func _roll_visible_tile_result() -> int:
	var roll := randf()
	if roll < Config.VISIBLE_WILD_MONSTER_WEIGHT:
		return Config.VISIBLE_WILD_MONSTER
	if roll < Config.VISIBLE_WILD_MONSTER_WEIGHT + Config.VISIBLE_MINE_WEIGHT:
		return Config.VISIBLE_MINE
	return Config.VISIBLE_FATE

func reset() -> void:
	_build_map()
	reveal_animations.clear()
	barracks_merge_animations.clear()
	intelligence_building_drop_animations.clear()
	merchant_presentation_animations.clear()
	buildable_cells.clear()
	mergeable_cells.clear()
	merge_effect_cells.clear()
	purchasable_cells.clear()
	buildable_cell_set.clear()
	mergeable_cell_set.clear()
	merge_effect_cell_set.clear()
	purchasable_cell_set.clear()
	bombardment_cells.clear()
	bombardment_warning_cells.clear()
	bombardment_warning_elapsed = 0.0
	mergeable_effect_elapsed = 0.0
	merge_effect_refresh_timer = 0.0
	tile_material_elapsed = 0.0
	tile_material_redraw_timer = 0.0
	clear_card_land_loss_cell()
	has_animated_building_progress = false
	drag_start_cell = Vector2i(999, 999)
	drag_active = false
	camera_drag_active = false
	long_press_timer = 0.0
	long_press_active = false
	drag_preview_world = Vector2.ZERO
	pointer_down_screen_position = Vector2.ZERO
	barracks_range_cell = Vector2i(999, 999)
	_clamp_camera_position()
	queue_redraw()

func has_cell(cell: Vector2i) -> bool:
	return tiles.has(cell)

func get_tile(cell: Vector2i) -> Dictionary:
	return tiles.get(cell, {})

func start_tile_reveal(cell: Vector2i) -> bool:
	if not tiles.has(cell) or reveal_animations.has(cell) or bool(tiles[cell]["revealed"]):
		return false
	reveal_animations[cell] = {
		"elapsed": 0.0,
		"committed": false
	}
	queue_redraw()
	return true

func is_tile_reveal_active(cell: Vector2i) -> bool:
	return reveal_animations.has(cell)

func start_barracks_merge(cell: Vector2i) -> bool:
	if not tiles.has(cell) or barracks_merge_animations.has(cell):
		return false
	if int(tiles[cell]["building"]) != BARRACKS:
		return false
	barracks_merge_animations[cell] = {"elapsed": 0.0}
	queue_redraw()
	return true

func is_barracks_merge_active(cell: Vector2i) -> bool:
	return barracks_merge_animations.has(cell)

func start_intelligence_building_drop(cell: Vector2i) -> bool:
	if not tiles.has(cell) or intelligence_building_drop_animations.has(cell):
		return false
	if int(tiles[cell].get("building", EMPTY)) == EMPTY:
		return false
	intelligence_building_drop_animations[cell] = {"elapsed": 0.0}
	queue_redraw()
	return true

func is_intelligence_building_drop_active(cell: Vector2i) -> bool:
	return intelligence_building_drop_animations.has(cell)

func get_intelligence_building_drop_offset(cell: Vector2i) -> Vector2:
	if not intelligence_building_drop_animations.has(cell):
		return Vector2.ZERO
	var state: Dictionary = intelligence_building_drop_animations[cell]
	var progress := clampf(float(state["elapsed"]) / Config.INTELLIGENCE_BUILDING_DROP_DURATION, 0.0, 1.0)
	var eased_drop := 1.0 - pow(1.0 - progress, 3.0)
	var offset_y := -Config.INTELLIGENCE_BUILDING_DROP_HEIGHT * (1.0 - eased_drop)
	if progress > 0.82:
		var bounce_progress := (progress - 0.82) / 0.18
		offset_y += sin(bounce_progress * PI) * 8.0
	return Vector2(0.0, offset_y)

func get_barracks_merge_offset(cell: Vector2i) -> Vector2:
	if not barracks_merge_animations.has(cell):
		return Vector2.ZERO
	var state: Dictionary = barracks_merge_animations[cell]
	var progress := clampf(float(state["elapsed"]) / Config.BARRACKS_MERGE_DURATION, 0.0, 1.0)
	# Ease out from a high drop, then add a small downward bounce at the landing.
	var eased_drop := 1.0 - pow(1.0 - progress, 3.0)
	var offset_y := -Config.BARRACKS_MERGE_HEIGHT * (1.0 - eased_drop)
	if progress > 0.82:
		var bounce_progress := (progress - 0.82) / 0.18
		offset_y += sin(bounce_progress * PI) * Config.BARRACKS_MERGE_BOUNCE_HEIGHT
	return Vector2(0.0, offset_y)

func get_building_unit_class(cell: Vector2i) -> int:
	return int(tiles.get(cell, {}).get("unit_class", -1))

func get_tile_cost(cell: Vector2i) -> int:
	var tile: Dictionary = tiles.get(cell, {})
	return 0 if bool(tile.get("intelligence_free_claim", false)) else Config.RANDOM_TILE_COST

func set_tile_owner(cell: Vector2i, owner: int, revealed := true) -> void:
	if not tiles.has(cell):
		return
	tiles[cell]["owner"] = owner
	tiles[cell]["revealed"] = revealed
	building_visual_dirty = true

func set_building(cell: Vector2i, building: int, level: int = 1, unit_class: int = -1, revealed: bool = true) -> void:
	if tiles.has(cell):
		tiles[cell]["building"] = building
		# A normal placement or merge-consumed slot is no longer a destroyed-building slot.
		tiles[cell]["rebuildable"] = false
		tiles[cell]["building_level"] = clampi(level, 1, 4) if building == BARRACKS else 0
		if building == BARRACKS:
			tiles[cell]["unit_class"] = clampi(unit_class, 0, Config.UNIT_CLASS_COUNT - 1)
			tiles[cell]["barracks_visual_timer"] = 0.0
			var owner := int(tiles[cell].get("owner", UNKNOWN))
			var base_max := Config.BARRACKS_BASE_HP * float(int(tiles[cell]["building_level"]))
			if get_parent() != null and get_parent().has_method("get_building_max_hp"):
				base_max = float(get_parent().call("get_building_max_hp", owner, BARRACKS)) * float(int(tiles[cell]["building_level"]))
			tiles[cell]["building_max_hp"] = base_max
			tiles[cell]["building_hp"] = tiles[cell]["building_max_hp"]
		elif building == MINE or building == TOWER:
			var owner := int(tiles[cell].get("owner", UNKNOWN))
			tiles[cell]["building_max_hp"] = Config.MINE_MAX_HP if building == MINE else Config.TOWER_MAX_HP
			if get_parent() != null and get_parent().has_method("get_building_max_hp"):
				tiles[cell]["building_max_hp"] = float(get_parent().call("get_building_max_hp", owner, building))
			tiles[cell]["building_hp"] = tiles[cell]["building_max_hp"]
		elif building == STEEL_BARRIER:
			tiles[cell]["unit_class"] = -1
			tiles[cell]["building_max_hp"] = Config.STEEL_BARRIER_MAX_HP
			var owner := int(tiles[cell].get("owner", UNKNOWN))
			if get_parent() != null and get_parent().has_method("get_building_max_hp"):
				tiles[cell]["building_max_hp"] = float(get_parent().call("get_building_max_hp", owner, building))
			tiles[cell]["building_hp"] = tiles[cell]["building_max_hp"]
		else:
			tiles[cell]["unit_class"] = -1
			tiles[cell]["building_max_hp"] = 0.0
			tiles[cell]["building_hp"] = 0.0
		tiles[cell]["revealed"] = revealed
		if building != BARRACKS:
			tiles[cell]["production_count"] = 0
			tiles[cell]["build_timer"] = 0.0
			tiles[cell]["barracks_visual_timer"] = 0.0
		if building != MERCHANT:
			tiles[cell]["merchant_active"] = false
			tiles[cell]["merchant_stock"] = []
		if building == EMPTY:
			building_cells.erase(cell)
		else:
			building_cells[cell] = true
		_update_building_progress_state(cell)
		building_visual_dirty = true
		building_changed.emit(cell, building)

func destroy_building(cell: Vector2i) -> bool:
	if not tiles.has(cell):
		return false
	var building := int(tiles[cell]["building"])
	if building == EMPTY:
		return false
	set_building(cell, EMPTY)
	tiles[cell]["merchant_active"] = false
	tiles[cell]["merchant_stock"] = []
	tiles[cell]["rebuildable"] = true
	return true

func is_rebuildable(cell: Vector2i) -> bool:
	return bool(tiles.get(cell, {}).get("rebuildable", false))

func set_buildable_cells(cells: Array[Vector2i]) -> void:
	buildable_cells = cells.duplicate()
	buildable_cell_set.clear()
	for cell in buildable_cells:
		buildable_cell_set[cell] = true
	queue_redraw()

func clear_buildable_cells() -> void:
	buildable_cells.clear()
	buildable_cell_set.clear()
	queue_redraw()

func set_mergeable_cells(cells: Array[Vector2i]) -> void:
	mergeable_cells = cells.duplicate()
	mergeable_cell_set.clear()
	for cell in mergeable_cells:
		mergeable_cell_set[cell] = true
	queue_redraw()

func clear_mergeable_cells() -> void:
	mergeable_cells.clear()
	mergeable_cell_set.clear()
	queue_redraw()

func _refresh_merge_effect_cells() -> void:
	var groups: Dictionary = {}
	var controller := get_parent()
	for cell in draw_cells:
		var tile: Dictionary = tiles[cell]
		if not bool(tile["revealed"]) or int(tile["owner"]) != PLAYER or int(tile["building"]) != BARRACKS:
			continue
		var level := int(tile["building_level"])
		if level < 1 or level >= 4 or is_barracks_merge_active(cell):
			continue
		if controller != null and controller.has_method("is_bombardment_locked") and bool(controller.call("is_bombardment_locked", cell)):
			continue
		var unit_class := int(tile["unit_class"])
		var group_key := "%d:%d:%d" % [int(tile["owner"]), level, unit_class]
		var group: Array = groups.get(group_key, [])
		group.append(cell)
		groups[group_key] = group

	var eligible_cells: Array[Vector2i] = []
	for raw_group in groups.values():
		var group: Array = raw_group
		if group.size() < 2:
			continue
		for raw_cell in group:
			eligible_cells.append(raw_cell)
	if eligible_cells != merge_effect_cells:
		merge_effect_cells = eligible_cells
		merge_effect_cell_set.clear()
		for cell in merge_effect_cells:
			merge_effect_cell_set[cell] = true
		queue_redraw()

func set_barracks_range_cell(cell: Vector2i) -> void:
	barracks_range_cell = cell
	queue_redraw()

func clear_barracks_range_cell() -> void:
	barracks_range_cell = Vector2i(999, 999)
	queue_redraw()

func set_purchasable_cells(cells: Array[Vector2i]) -> void:
	purchasable_cells = cells.duplicate()
	purchasable_cell_set.clear()
	for cell in purchasable_cells:
		purchasable_cell_set[cell] = true
	queue_redraw()

func set_player_gold(value: float) -> void:
	if is_equal_approx(player_gold, value):
		return
	player_gold = value
	queue_redraw()

func set_bombardment_cells(cells: Array[Vector2i]) -> void:
	if bombardment_cells == cells:
		return
	bombardment_cells = cells.duplicate()
	queue_redraw()

func clear_bombardment_cells() -> void:
	if bombardment_cells.is_empty():
		return
	bombardment_cells.clear()
	queue_redraw()

func set_bombardment_warning_cells(cells: Array[Vector2i]) -> void:
	bombardment_warning_cells = cells.duplicate()
	bombardment_warning_elapsed = 0.0
	queue_redraw()

func clear_bombardment_warning_cells() -> void:
	if bombardment_warning_cells.is_empty():
		return
	bombardment_warning_cells.clear()
	bombardment_warning_elapsed = 0.0
	queue_redraw()

func set_card_land_loss_cell(cell: Vector2i) -> void:
	card_land_loss_cell = cell
	card_land_loss_elapsed = 0.0
	queue_redraw()

func clear_card_land_loss_cell() -> void:
	card_land_loss_cell = Vector2i(999, 999)
	card_land_loss_elapsed = 0.0
	queue_redraw()

func reveal(cell: Vector2i, building: int, level: int = 1, unit_class: int = -1) -> void:
	if not tiles.has(cell):
		return
	set_building(cell, building, level, unit_class)
	queue_redraw()

func get_building_level(cell: Vector2i) -> int:
	return int(tiles.get(cell, {}).get("building_level", 0))

func get_production_count(cell: Vector2i) -> int:
	return int(tiles.get(cell, {}).get("production_count", 0))

func get_barracks_visual_timer(cell: Vector2i) -> float:
	return float(tiles.get(cell, {}).get("barracks_visual_timer", 0.0))

func update_barracks_visual_timer(cell: Vector2i, value: float) -> void:
	if tiles.has(cell):
		tiles[cell]["barracks_visual_timer"] = maxf(0.0, value)

func set_production_count(cell: Vector2i, value: int) -> void:
	if tiles.has(cell):
		tiles[cell]["production_count"] = maxi(0, value)

func get_building_hp(cell: Vector2i) -> float:
	return float(tiles.get(cell, {}).get("building_hp", 0.0))

func get_building_max_hp(cell: Vector2i) -> float:
	return float(tiles.get(cell, {}).get("building_max_hp", 0.0))

func set_building_hp(cell: Vector2i, value: float) -> void:
	if tiles.has(cell):
		tiles[cell]["building_hp"] = clampf(value, 0.0, get_building_max_hp(cell))
		building_visual_dirty = true

func update_build_timer(cell: Vector2i, value: float, visual_dirty := true) -> void:
	if tiles.has(cell):
		tiles[cell]["build_timer"] = value
		_update_building_progress_state(cell)
		if visual_dirty:
			building_visual_dirty = true

func _update_building_progress_state(cell: Vector2i) -> void:
	if not tiles.has(cell):
		return
	var tile: Dictionary = tiles[cell]
	var timer := float(tile.get("build_timer", 0.0))
	var building := int(tile.get("building", EMPTY))
	var production_interval := Config.BARRACKS_PRODUCTION_INTERVAL
	if building == BARRACKS and get_parent() != null and get_parent().has_method("get_barracks_production_interval"):
		production_interval = float(get_parent().call("get_barracks_production_interval", int(tile.get("owner", UNKNOWN))))
	if building == BARRACKS and timer > 0.0 and timer < production_interval:
		animated_building_progress_cells[cell] = true
	else:
		animated_building_progress_cells.erase(cell)
	has_animated_building_progress = not animated_building_progress_cells.is_empty()

func mark_building_visual_dirty() -> void:
	building_visual_dirty = true

func get_build_timer(cell: Vector2i) -> float:
	return float(tiles.get(cell, {}).get("build_timer", 0.0))

func are_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return a.distance_to(b) > 0.0 and cube_distance(a, b) == 1

func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction in DIRECTIONS:
		var next_cell: Vector2i = cell + direction
		if tiles.has(next_cell):
			result.append(next_cell)
	return result

func cube_distance(a: Vector2i, b: Vector2i) -> int:
	return int((abs(a.x - b.x) + abs(a.y - b.y) + abs((a.x + a.y) - (b.x + b.y))) / 2)

func axial_to_world(cell: Vector2i) -> Vector2:
	return board_origin + Vector2(sqrt(3.0) * tile_size * (cell.x + cell.y * 0.5), tile_size * 1.5 * cell.y)

func get_cell_world_center(cell: Vector2i) -> Vector2:
	return axial_to_world(cell)

func get_cell_surface_anchor(cell: Vector2i) -> Vector2:
	return get_cell_world_center(cell) + Config.TILE_SURFACE_ANCHOR

func get_building_visual_anchor(cell: Vector2i, level: int, unit_class: int) -> Dictionary:
	var surface := get_cell_surface_anchor(cell)
	var faction := int(tiles.get(cell, {}).get("owner", UNKNOWN))
	var tier := clampi(level, 1, 4)
	var model_scale := float(Config.BARRACKS_LEVEL_SCALE[tier - 1])
	var model_center := surface + Vector2(0.0, Config.BARRACKS_MODEL_LIFT)
	var ground_local := 17.0 * model_scale
	var top_local := -25.0 * model_scale
	if _has_barracks_art(unit_class, faction):
		ground_local = 18.0 * model_scale
		var source_region: Rect2 = BARRACKS_ART_REGIONS[clampi(unit_class, 0, BARRACKS_ART_REGIONS.size() - 1)]
		var art_width := Config.BARRACKS_ART_BASE_WIDTH * Config.BARRACKS_ART_DISPLAY_SCALE * model_scale
		var art_height := art_width * source_region.size.y / maxf(1.0, source_region.size.x)
		top_local = ground_local - art_height
	else:
		var silhouette_top := -25.0
		match unit_class:
			Config.UNIT_CLASS_MAGE:
				silhouette_top = -39.0
			Config.UNIT_CLASS_ASSASSIN:
				silhouette_top = -33.0
			Config.UNIT_CLASS_ARCHER:
				silhouette_top = -36.0
		if tier >= 3:
			silhouette_top = minf(silhouette_top, -47.0)
		if tier >= 4:
			silhouette_top = minf(silhouette_top, -58.0)
		top_local = silhouette_top * model_scale
	var progress_radius := 14.0 * Config.BARRACKS_PROGRESS_VISUAL_SCALE
	return {
		"cell_center": get_cell_world_center(cell),
		"surface": surface,
		"center": model_center,
		"ground": model_center + Vector2(0.0, ground_local),
		"top": model_center.y + top_local,
		"progress_center": Vector2(model_center.x, model_center.y + top_local - progress_radius + 9.0),
		"badge_center": model_center + Vector2(19.0, 14.0) * model_scale,
		"scale": model_scale
	}

func world_to_axial(position: Vector2) -> Vector2i:
	var local := position - board_origin
	var q := (sqrt(3.0) / 3.0 * local.x - 1.0 / 3.0 * local.y) / tile_size
	var r := (2.0 / 3.0 * local.y) / tile_size
	return _cube_round(q, -q - r, r)

func _cube_round(x: float, y: float, z: float) -> Vector2i:
	var rx: float = round(x)
	var ry: float = round(y)
	var rz: float = round(z)
	var dx: float = abs(rx - x)
	var dy: float = abs(ry - y)
	var dz: float = abs(rz - z)
	if dx > dy and dx > dz:
		rx = -ry - rz
	elif dy > dz:
		ry = -rx - rz
	else:
		rz = -rx - ry
	return Vector2i(int(rx), int(rz))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		if event.pressed:
			camera_drag_active = true
		else:
			camera_drag_active = false
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_zoom_camera(1.15, event.position)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_zoom_camera(1.0 / 1.15, event.position)
		return
	if event is InputEventMouseMotion:
		if drag_active and not long_press_active and event.position.distance_to(pointer_down_screen_position) >= CAMERA_PAN_THRESHOLD:
			if _can_start_merge_drag(drag_start_cell):
				_start_barracks_drag()
			else:
				camera_drag_active = true
				drag_active = false
				long_press_timer = 0.0
				drag_start_cell = Vector2i(999, 999)
		if camera_drag_active and camera != null:
			camera.position -= event.relative / camera.zoom.x
			_clamp_camera_position()
		if drag_active and long_press_active:
			drag_preview_world = _mouse_world_position()
			queue_redraw()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var candidate := world_to_axial(_mouse_world_position())
		if event.pressed:
			if tiles.has(candidate):
				drag_start_cell = candidate
				drag_active = true
				long_press_timer = 0.0
				long_press_active = false
				drag_preview_world = _mouse_world_position()
				pointer_down_screen_position = event.position
				queue_redraw()
			else:
				camera_drag_active = true
		elif drag_active:
			drag_active = false
			var was_long_press := long_press_active
			long_press_active = false
			long_press_timer = 0.0
			var start_cell := drag_start_cell
			drag_start_cell = Vector2i(999, 999)
			if was_long_press and tiles.has(candidate) and candidate != start_cell:
				tile_dragged.emit(start_cell, candidate)
			elif not was_long_press and tiles.has(start_cell) and candidate == start_cell:
				tile_clicked.emit(start_cell)
			queue_redraw()
		elif camera_drag_active:
			camera_drag_active = false

func _process(delta: float) -> void:
	var current_canvas_transform := get_viewport().get_canvas_transform()
	var current_viewport_size := get_viewport().get_visible_rect().size
	if current_canvas_transform != last_draw_canvas_transform or current_viewport_size != last_draw_viewport_size:
		last_draw_canvas_transform = current_canvas_transform
		last_draw_viewport_size = current_viewport_size
		queue_redraw()
	_process_reveal_animations(delta)
	_process_barracks_merge_animations(delta)
	_process_intelligence_building_drop_animations(delta)
	_process_merchant_presentation_animations(delta)
	merge_effect_refresh_timer -= delta
	if merge_effect_refresh_timer <= 0.0:
		_refresh_merge_effect_cells()
		merge_effect_refresh_timer = 0.2
	if not merge_effect_cells.is_empty():
		mergeable_effect_elapsed += delta
	if not purchasable_cell_set.is_empty() or not buildable_cell_set.is_empty() or not mergeable_cell_set.is_empty() or tiles.has(barracks_range_cell):
		tile_material_elapsed += delta
		tile_material_redraw_timer -= delta
		if tile_material_redraw_timer <= 0.0:
			tile_material_redraw_timer = 0.08
			queue_redraw()
	else:
		tile_material_redraw_timer = 0.0
	if not bombardment_warning_cells.is_empty():
		bombardment_warning_elapsed += delta
		queue_redraw()
	if card_land_loss_cell != Vector2i(999, 999):
		card_land_loss_elapsed += delta
		queue_redraw()
	if not drag_active or long_press_active:
		return
	long_press_timer += delta
	if long_press_timer < LONG_PRESS_DURATION or not _can_start_merge_drag(drag_start_cell):
		return
	_start_barracks_drag()

func _start_barracks_drag() -> void:
	if long_press_active or not _can_start_merge_drag(drag_start_cell):
		return
	long_press_active = true
	drag_preview_world = _mouse_world_position()
	tile_drag_started.emit(drag_start_cell)
	queue_redraw()

func _process_reveal_animations(delta: float) -> void:
	if reveal_animations.is_empty():
		return
	var completed_cells: Array[Vector2i] = []
	for cell in reveal_animations.keys():
		var state: Dictionary = reveal_animations[cell]
		state["elapsed"] = float(state["elapsed"]) + delta
		if not bool(state["committed"]) and float(state["elapsed"]) >= Config.TILE_REVEAL_DURATION * 0.5:
			state["committed"] = true
			tile_reveal_midpoint.emit(cell)
		if float(state["elapsed"]) >= Config.TILE_REVEAL_DURATION:
			completed_cells.append(cell)
	for cell in completed_cells:
		reveal_animations.erase(cell)
		tile_reveal_finished.emit(cell)
	queue_redraw()

func _process_barracks_merge_animations(delta: float) -> void:
	if barracks_merge_animations.is_empty():
		return
	var completed_cells: Array[Vector2i] = []
	for cell in barracks_merge_animations.keys():
		var state: Dictionary = barracks_merge_animations[cell]
		state["elapsed"] = float(state["elapsed"]) + delta
		if float(state["elapsed"]) >= Config.BARRACKS_MERGE_DURATION:
			completed_cells.append(cell)
	for cell in completed_cells:
		barracks_merge_animations.erase(cell)
	queue_redraw()

func _process_intelligence_building_drop_animations(delta: float) -> void:
	if intelligence_building_drop_animations.is_empty():
		return
	var completed_cells: Array[Vector2i] = []
	for cell in intelligence_building_drop_animations.keys():
		var state: Dictionary = intelligence_building_drop_animations[cell]
		state["elapsed"] = float(state["elapsed"]) + delta
		if float(state["elapsed"]) >= Config.INTELLIGENCE_BUILDING_DROP_DURATION:
			completed_cells.append(cell)
	for cell in completed_cells:
		intelligence_building_drop_animations.erase(cell)
		intelligence_building_drop_finished.emit(cell)
	queue_redraw()

func start_merchant_presentation(cell: Vector2i) -> void:
	if not tiles.has(cell) or not bool(tiles[cell].get("merchant_active", false)):
		return
	merchant_presentation_animations[cell] = 0.0
	queue_redraw()

func stop_merchant_presentation(cell: Vector2i) -> void:
	if merchant_presentation_animations.erase(cell):
		queue_redraw()

func is_merchant_presenting(cell: Vector2i) -> bool:
	return merchant_presentation_animations.has(cell)

func clear_merchant_presentations() -> void:
	if not merchant_presentation_animations.is_empty():
		merchant_presentation_animations.clear()
		queue_redraw()

func _process_merchant_presentation_animations(delta: float) -> void:
	if merchant_presentation_animations.is_empty():
		return
	for cell in merchant_presentation_animations.keys():
		if not tiles.has(cell) or not bool(tiles[cell].get("merchant_active", false)):
			merchant_presentation_animations.erase(cell)
			continue
		merchant_presentation_animations[cell] = minf(
			float(merchant_presentation_animations[cell]) + delta,
			Config.MERCHANT_PRESENTATION_DURATION
		)
	queue_redraw()

func _can_start_merge_drag(cell: Vector2i) -> bool:
	if not tiles.has(cell):
		return false
	var tile: Dictionary = tiles[cell]
	if not bool(tile["revealed"]) or int(tile["owner"]) != PLAYER or int(tile["building"]) != BARRACKS:
		return false
	var main_ref := get_parent()
	if main_ref != null and main_ref.has_method("is_card_land_loss_locked") and bool(main_ref.call("is_card_land_loss_locked", cell)):
		return false
	if is_barracks_merge_active(cell):
		return false
	if main_ref == null or not main_ref.has_method("get_merge_targets"):
		return false
	var targets: Array[Vector2i] = main_ref.get_merge_targets(cell, PLAYER)
	return not targets.is_empty()

func reset_camera() -> void:
	if camera == null:
		return
	if camera_focus_tween != null and camera_focus_tween.is_valid():
		camera_focus_tween.kill()
	camera.position = axial_to_world(Config.PLAYER_HQ)
	camera.zoom = Vector2(Config.INITIAL_CAMERA_ZOOM, Config.INITIAL_CAMERA_ZOOM)
	camera_drag_active = false
	_clamp_camera_position()

func get_camera_position() -> Vector2:
	if camera == null:
		return Vector2.ZERO
	return camera.position

func focus_camera_on_cell(cell: Vector2i, duration: float = 0.0) -> void:
	if camera == null or not tiles.has(cell):
		return
	focus_camera_on_position(axial_to_world(cell), duration)

func focus_camera_on_position(target_position: Vector2, duration: float = 0.0) -> void:
	if camera == null:
		return
	if camera_focus_tween != null and camera_focus_tween.is_valid():
		camera_focus_tween.kill()
	if duration <= 0.0:
		camera.position = target_position
		_clamp_camera_position()
		return
	camera_focus_tween = create_tween()
	camera_focus_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	camera_focus_tween.tween_property(camera, "position", target_position, duration)
	camera_focus_tween.tween_callback(_clamp_camera_position)

func _zoom_camera(factor: float, _screen_position: Vector2) -> void:
	if camera == null:
		return
	var before := get_global_mouse_position()
	var next_zoom := clampf(camera.zoom.x * factor, Config.MIN_CAMERA_ZOOM, Config.MAX_CAMERA_ZOOM)
	camera.zoom = Vector2(next_zoom, next_zoom)
	var after := get_global_mouse_position()
	camera.position += before - after
	_clamp_camera_position()
	queue_redraw()

func _mouse_world_position() -> Vector2:
	return to_local(get_global_mouse_position())

func _clamp_camera_position() -> void:
	if camera == null or tiles.is_empty():
		return
	var min_world := map_min_world
	var max_world := map_max_world
	min_world -= Vector2(tile_size + Config.CAMERA_MAP_PADDING, tile_size + Config.CAMERA_MAP_PADDING)
	max_world += Vector2(tile_size + Config.CAMERA_MAP_PADDING, tile_size + Config.CAMERA_MAP_PADDING)
	var viewport_size := get_viewport_rect().size
	var half_view := viewport_size / (2.0 * camera.zoom.x)
	var min_hq_x := INF
	var max_hq_x := -INF
	for hq in HQ_CELLS:
		var hq_x := axial_to_world(hq).x
		min_hq_x = minf(min_hq_x, hq_x)
		max_hq_x = maxf(max_hq_x, hq_x)
	var camera_min_x := minf(min_world.x + half_view.x, min_hq_x)
	var camera_max_x := maxf(max_world.x - half_view.x, max_hq_x)
	camera.position.x = _clamp_camera_axis(camera.position.x, camera_min_x, camera_max_x)
	camera.position.y = _clamp_camera_axis(camera.position.y, min_world.y + half_view.y, max_world.y - half_view.y)

func _clamp_camera_axis(value: float, lower: float, upper: float) -> float:
	if lower > upper:
		return (lower + upper) * 0.5
	return clampf(value, lower, upper)

func _recalculate_map_bounds() -> void:
	map_min_world = Vector2(INF, INF)
	map_max_world = Vector2(-INF, -INF)
	for cell in draw_cells:
		var center := axial_to_world(cell)
		map_min_world.x = minf(map_min_world.x, center.x)
		map_min_world.y = minf(map_min_world.y, center.y)
		map_max_world.x = maxf(map_max_world.x, center.x)
		map_max_world.y = maxf(map_max_world.y, center.y)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_clamp_camera_position()

func _draw() -> void:
	var material := Art.tile_material()
	var extrusion_depth := float(material.get("extrusion_depth", Config.TILE_EXTRUSION_DEPTH)) + 2.0
	var visible_world_rect := _get_visible_world_rect().grow(tile_size * 2.0 + extrusion_depth + Config.TILE_SHADOW_OFFSET_Y)
	# Draw rear rows first so the extruded lower edge sits behind the next row.
	for cell in draw_cells:
		if not visible_world_rect.has_point(axial_to_world(cell)):
			continue
		_draw_tile(cell)
	# The dragged barracks must be drawn after every tile. Drawing it from
	# _draw_tile() lets a later tile row cover the preview while it is moving.
	if long_press_active and tiles.has(drag_start_cell):
		_draw_drag_source_preview(drag_start_cell)
	if Config.DEBUG_DRAW_VISUAL_ANCHORS:
		_draw_visual_anchor_debug()

func _get_visible_world_rect() -> Rect2:
	var viewport_rect := get_viewport().get_visible_rect()
	var inverse_canvas := get_viewport().get_canvas_transform().affine_inverse()
	var top_left := inverse_canvas * viewport_rect.position
	var bottom_right := inverse_canvas * (viewport_rect.position + viewport_rect.size)
	return Rect2(top_left, bottom_right - top_left)

func _draw_tile(cell: Vector2i) -> void:
	var tile: Dictionary = tiles[cell]
	var center := get_cell_world_center(cell)
	var surface_anchor := get_cell_surface_anchor(cell)
	var reveal_active := reveal_animations.has(cell)
	if reveal_active:
		var reveal_state: Dictionary = reveal_animations[cell]
		var reveal_progress := clampf(float(reveal_state["elapsed"]) / Config.TILE_REVEAL_DURATION, 0.0, 1.0)
		# Overshoot on the way down gives the chunky tile a playful toy-like pop.
		var jump_offset := sin(reveal_progress * PI) * Config.TILE_REVEAL_JUMP_HEIGHT
		jump_offset += sin(reveal_progress * PI * 3.0) * 3.0 * (1.0 - reveal_progress)
		var flip_scale := maxf(abs(cos(reveal_progress * PI)), Config.TILE_REVEAL_MIN_SCALE_X)
		# Transform absolute world coordinates around this tile's center.
		draw_set_transform(Vector2(center.x * (1.0 - flip_scale), -jump_offset), 0.0, Vector2(flip_scale, 1.0))
	var tile_radius := tile_size - 2.0
	var points := _hex_points(center, tile_radius)
	var owner: int = int(tile["owner"])
	var revealed: bool = bool(tile["revealed"])
	var tile_type: int = int(tile["tile_type"])
	var material := Art.tile_material()
	var extrusion_depth := float(material.get("extrusion_depth", Config.TILE_EXTRUSION_DEPTH)) + 2.0
	_draw_tile_shadows(center, tile_radius, extrusion_depth, material)
	_draw_tile_art(surface_anchor, _tile_art_for(revealed, owner))
	_draw_tile_state_glow(cell, points)

	# Danger layers are deliberately last so gameplay warnings always outrank
	# the decorative candy highlights and interaction glows.
	if cell in bombardment_cells:
		draw_colored_polygon(points, Color(0.92, 0.08, 0.08, 0.24))
		draw_polyline(_closed_polygon(points), Color(1.0, 0.25, 0.18, 0.88), 3.0, true)
	if cell in bombardment_warning_cells:
		var warning_pulse := 0.5 + 0.5 * sin(bombardment_warning_elapsed * 10.0)
		draw_colored_polygon(points, Color(1.0, 0.04, 0.04, 0.12 + warning_pulse * 0.22))
		draw_polyline(_closed_polygon(points), Color(1.0, 0.12, 0.08, 0.55 + warning_pulse * 0.45), 4.0, true)
	if cell == card_land_loss_cell:
		var loss_pulse := 0.5 + 0.5 * sin(card_land_loss_elapsed * 16.0)
		draw_colored_polygon(points, Color(1.0, 0.03, 0.03, 0.18 + loss_pulse * 0.22))
		draw_polyline(_closed_polygon(points), Color(1.0, 0.08, 0.04, 0.72 + loss_pulse * 0.26), 4.0, true)

	if not revealed:
		if int(tile["building"]) != EMPTY:
			var landmark_center := surface_anchor
			if is_intelligence_building_drop_active(cell):
				landmark_center += get_intelligence_building_drop_offset(cell)
			_draw_hidden_building_landmark(landmark_center, int(tile["building"]), int(tile["building_level"]), int(tile["unit_class"]))
		elif tile_type == Config.BARRACKS_TILE_TYPE and purchasable_cell_set.has(cell):
			_draw_barracks_tile_landmark(surface_anchor, not reveal_active)
		elif tile_type == Config.QUESTION_TILE_TYPE and purchasable_cell_set.has(cell):
			_draw_question_tile_landmark(surface_anchor, not reveal_active)
		elif _is_visible_tile_type(tile_type):
			_draw_visible_landmark(
				int(tile.get("visible_tile_result", Config.VISIBLE_FATE)),
				surface_anchor,
				not reveal_active,
				int(tile.get("visible_monster_level", Config.WILD_MONSTER_LEVEL_ONE))
			)
		if purchasable_cell_set.has(cell):
			var tile_cost := get_tile_cost(cell)
			var price_color := Color("#d83f52") if player_gold < tile_cost else Art.INK
			# Keep the price row below the landmark: a small coin sits just left of the number.
			_draw_coin_icon(surface_anchor + Vector2(-11.0, 18.0), 0.55)
			draw_string(ThemeDB.fallback_font, surface_anchor + Vector2(-1.0, 24.0), str(tile_cost), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, price_color)
	else:
		if not (cell == drag_start_cell and long_press_active):
			var building_center := surface_anchor
			if int(tile["building"]) == BARRACKS:
				building_center += get_barracks_merge_offset(cell)
			_draw_building(cell, building_center, int(tile["building"]), int(tile["building_level"]), int(tile["unit_class"]))
			var ground_item_id := str(tile.get("ground_item_id", ""))
			if not ground_item_id.is_empty():
				_draw_ground_item_icon(surface_anchor + Vector2(0.0, -24.0), ground_item_id)
			if bool(tile.get("chest_reward", false)):
				draw_string(ThemeDB.fallback_font, surface_anchor + Vector2(-13, -25), "宝箱", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#fbbf24"))

	if reveal_active:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _offset_points(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(point + offset)
	return result

func _tile_art_for(revealed: bool, owner: int) -> Texture2D:
	if not revealed or owner == UNKNOWN:
		return TILE_UNCLAIMED_ART
	match owner:
		Config.FACTION_GREEN:
			return TILE_GREEN_ART
		Config.FACTION_PLAYER:
			return TILE_BLUE_ART
		Config.FACTION_RED:
			return TILE_RED_ART
		Config.FACTION_PURPLE:
			return TILE_PURPLE_ART
		_:
			return TILE_UNCLAIMED_ART

func _draw_tile_art(center: Vector2, texture: Texture2D) -> void:
	if texture == null:
		return
	var width := 104.0 * TILE_ART_SCALE_X
	var height := width * texture.get_height() / maxf(1.0, texture.get_width())
	# Apply the vertical calibration independently so the top surface fills
	# the row spacing without changing the logical hex-grid coordinates.
	height *= TILE_ART_SCALE_Y / maxf(TILE_ART_SCALE_X, 0.001)
	var top_offset := -54.0 * TILE_ART_SCALE_Y
	draw_texture_rect(texture, Rect2(center + Vector2(-width * 0.5, top_offset), Vector2(width, height)), false)

func _draw_visual_anchor_debug() -> void:
	for cell in draw_cells:
		if not tiles.has(cell):
			continue
		var center := get_cell_world_center(cell)
		var surface := get_cell_surface_anchor(cell)
		draw_line(center + Vector2(-5.0, 0.0), center + Vector2(5.0, 0.0), Color("#f43f5e"), 1.5, true)
		draw_line(center + Vector2(0.0, -5.0), center + Vector2(0.0, 5.0), Color("#f43f5e"), 1.5, true)
		draw_circle(surface, 2.5, Color("#facc15"))
		var tile: Dictionary = tiles[cell]
		if bool(tile.get("revealed", false)) and int(tile.get("building", EMPTY)) == BARRACKS:
			var anchor := get_building_visual_anchor(cell, int(tile.get("building_level", 1)), int(tile.get("unit_class", -1)))
			draw_circle(Vector2(anchor["ground"]), 3.0, Color("#22c55e"))
			draw_circle(Vector2(anchor["progress_center"]), 3.0, Color("#f59e0b"))

func _closed_polygon(points: PackedVector2Array) -> PackedVector2Array:
	var closed := PackedVector2Array(points)
	if not points.is_empty():
		closed.append(points[0])
	return closed

func _draw_tile_shadows(center: Vector2, radius: float, extrusion_depth: float, material: Dictionary) -> void:
	# Two warm, offset silhouettes approximate a soft mobile-friendly shadow
	# without adding a shader or texture lookup per tile.
	var far_shadow := _hex_points(
		center + Vector2(3.0, extrusion_depth + Config.TILE_SHADOW_OFFSET_Y + 3.0),
		radius + 3.0
	)
	var near_shadow := _hex_points(
		center + Vector2(1.0, extrusion_depth + Config.TILE_SHADOW_OFFSET_Y),
		radius + 1.0
	)
	draw_colored_polygon(far_shadow, Color(0.35, 0.22, 0.28, float(material["shadow_far_alpha"])))
	draw_colored_polygon(near_shadow, Color(0.26, 0.17, 0.22, float(material["shadow_near_alpha"])))

func _draw_tile_sides(top_points: PackedVector2Array, bottom_points: PackedVector2Array, fill: Color, material: Dictionary) -> void:
	# Separate values for each visible face make the light direction readable.
	var side_darkness: Array = material["side_darkness"]
	var visible_edges := [1, 2, 3]
	for slot in range(visible_edges.size()):
		var index: int = int(visible_edges[slot])
		var next_index: int = (index + 1) % top_points.size()
		var side_points := PackedVector2Array([
			top_points[index],
			top_points[next_index],
			bottom_points[next_index],
			bottom_points[index]
		])
		var side_color := fill.darkened(float(side_darkness[slot]))
		draw_colored_polygon(side_points, side_color)
		draw_line(bottom_points[index], bottom_points[next_index], fill.darkened(0.52), 1.2, true)
		if slot == 0:
			draw_line(
				top_points[index],
				top_points[next_index],
				Color(1.0, 1.0, 1.0, float(material["side_highlight_alpha"])),
				1.4,
				true
			)

func _draw_tile_top(cell: Vector2i, center: Vector2, radius: float, outer_points: PackedVector2Array, fill: Color, outline: Color, revealed: bool, material: Dictionary) -> void:
	# Dark outer shell, bright bevel and inset face create a rounded candy edge.
	draw_colored_polygon(outer_points, fill.darkened(float(material["rim_darkness"])))
	var bevel_points := _hex_points(center + Vector2(-0.5, -0.8), radius - 2.8)
	draw_colored_polygon(bevel_points, fill.lightened(float(material["bevel_lighten"])))
	var face_center := center + Vector2(-0.7, -1.2)
	var face_points := _hex_points(face_center, radius - 6.2)
	var face_color := fill.lightened(float(material["face_lighten"]))
	draw_colored_polygon(face_points, face_color)

	# A broad cool shade on the lower-right and a bright upper-left plane make
	# the illumination directional instead of looking like a white wash.
	var lower_shade := PackedVector2Array([
		face_center + Vector2(35.0, -10.0),
		face_center + Vector2(35.0, 17.0),
		face_center + Vector2(0.0, 39.0),
		face_center + Vector2(-5.0, 30.0),
		face_center + Vector2(22.0, 10.0),
	])
	draw_colored_polygon(lower_shade, Color(face_color.darkened(0.42), float(material["lower_shade_alpha"])))
	var light_facet := PackedVector2Array([
		face_center + Vector2(-34.0, -17.0),
		face_center + Vector2(-2.0, -39.0),
		face_center + Vector2(22.0, -23.0),
		face_center + Vector2(10.0, -13.0),
		face_center + Vector2(-27.0, -2.0),
	])
	draw_colored_polygon(light_facet, Color(1.0, 1.0, 1.0, float(material["facet_alpha"])))

	var face_loop := _closed_polygon(face_points)
	draw_polyline(face_loop, Color(1.0, 1.0, 1.0, float(material["inner_glow_alpha"])), 1.5, true)
	_draw_tile_texture(cell, face_center, face_color, revealed, material)
	_draw_tile_specular(face_center, material)
	draw_polyline(_closed_polygon(outer_points), outline, float(material["outline_width"]), true)

func _draw_tile_specular(center: Vector2, material: Dictionary) -> void:
	var alpha := float(material["specular_alpha"])
	draw_line(center + Vector2(-25.0, -17.0), center + Vector2(-12.0, -28.0), Color(1.0, 1.0, 1.0, alpha), 3.3, true)
	draw_line(center + Vector2(-9.0, -29.5), center + Vector2(-4.0, -31.0), Color(1.0, 1.0, 1.0, alpha * 0.80), 2.3, true)
	draw_circle(center + Vector2(1.0, -30.5), 1.7, Color(1.0, 1.0, 1.0, alpha * 0.64))

func _draw_tile_texture(cell: Vector2i, center: Vector2, face_color: Color, revealed: bool, material: Dictionary) -> void:
	var seed := absi(cell.x * 92821 + cell.y * 68917 + cell.x * cell.y * 37)
	var count := int(material["texture_count"])
	var alpha := float(material["texture_alpha"]) * (1.0 if revealed else 0.72)
	var texture_style := int(material["texture_style"])
	for index in range(count):
		var point_seed := seed + index * 7919
		var point := center + Vector2(
			float(point_seed % 43) - 21.0,
			float(int(point_seed / 43) % 29) - 13.0
		)
		match texture_style:
			0:
				# Tiny trapped highlights suggest clear hard-candy depth.
				draw_circle(point + Vector2(0.5, 0.8), 1.5, Color(face_color.darkened(0.40), alpha * 0.35))
				draw_circle(point, 1.0, Color(1.0, 1.0, 1.0, alpha))
			1:
				# Wider translucent bubbles suit the softer gummy preset.
				draw_circle(point, 2.2, Color(face_color.darkened(0.32), alpha * 0.50))
				draw_circle(point + Vector2(-0.4, -0.5), 1.4, Color(1.0, 1.0, 1.0, alpha * 0.70))
			2:
				# Fine irregular sugar grains keep the cream finish matte.
				var grain_radius := 0.65 + float(point_seed % 3) * 0.25
				draw_circle(point, grain_radius, Color(1.0, 0.98, 0.90, alpha))

func _draw_tile_state_glow(cell: Vector2i, points: PackedVector2Array) -> void:
	var glow_color := Color.TRANSPARENT
	if _is_in_barracks_range(cell):
		glow_color = Color("#ffd34e")
	if buildable_cell_set.has(cell):
		glow_color = Color("#65e887")
	if mergeable_cell_set.has(cell):
		glow_color = Color("#d795ff")
	if glow_color.a <= 0.0:
		return
	var phase := float(absi(cell.x * 11 + cell.y * 7) % 13) * 0.12
	var pulse := 0.5 + 0.5 * sin(tile_material_elapsed * 3.8 + phase)
	var outline_points := _closed_polygon(points)
	draw_polyline(outline_points, Color(glow_color, 0.13 + pulse * 0.12), 6.5, true)
	draw_polyline(outline_points, Color(glow_color, 0.72 + pulse * 0.24), 2.5, true)

func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(16):
		var angle := TAU * float(index) / 16.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)

func _is_visible_tile_type(tile_type: int) -> bool:
	return tile_type == Config.VISIBLE_TILE_TYPE

func _draw_visible_landmark(visible_result: int, center: Vector2, use_local_transform := true, monster_level := Config.WILD_MONSTER_LEVEL_ONE) -> void:
	var landmark_origin := center + Config.VISIBLE_LANDMARK_OFFSET
	# Visible-tile landmarks share one display multiplier so the model,
	# outline and visible monster level marker remain aligned when resized.
	var landmark_scale := Config.VISIBLE_LANDMARK_SCALE * Config.VISIBLE_LANDMARK_DISPLAY_SCALE
	if visible_result == Config.VISIBLE_WILD_MONSTER:
		landmark_scale *= Config.VISIBLE_WILD_LANDMARK_SCALE
	if use_local_transform:
		draw_set_transform(landmark_origin, 0.0, Vector2(landmark_scale, landmark_scale))
	var landmark_center := Vector2.ZERO if use_local_transform else landmark_origin
	match visible_result:
		Config.VISIBLE_FATE:
			_draw_fate_crystal_ball_landmark(landmark_center)
		Config.VISIBLE_WILD_MONSTER:
			_draw_wild_landmark(landmark_center, monster_level)
		Config.VISIBLE_MINE:
			_draw_mine_landmark(landmark_center)
	if use_local_transform:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_visible_landmark_art(center: Vector2, texture: Texture2D, width: float, top_ratio: float) -> void:
	if texture == null:
		return
	var height := width * texture.get_height() / maxf(1.0, texture.get_width())
	draw_texture_rect(texture, Rect2(center + Vector2(-width * 0.5, -height * top_ratio), Vector2(width, height)), false)

func _draw_visible_wild_level(center: Vector2, monster_level: int) -> void:
	var level := clampi(monster_level, Config.WILD_MONSTER_LEVEL_ONE, Config.WILD_MONSTER_LEVEL_THREE)
	var level_center := center + Vector2(45.0, -45.0)
	draw_circle(level_center + Vector2(1.0, 1.0), 8.0, Color(0.0, 0.0, 0.0, 0.48))
	draw_circle(level_center, 7.0, Color("#facc15"))
	draw_string(ThemeDB.fallback_font, level_center + Vector2(-3.0, 3.5), str(level), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#111827"))

func _draw_barracks_tile_landmark(center: Vector2, use_local_transform := true) -> void:
	var landmark_origin := center + Config.VISIBLE_LANDMARK_OFFSET
	var landmark_center := landmark_origin
	if use_local_transform:
		draw_set_transform(landmark_origin, 0.0, Vector2(Config.VISIBLE_LANDMARK_SCALE, Config.VISIBLE_LANDMARK_SCALE))
		landmark_center = Vector2.ZERO
	_draw_gladiator_helmet(landmark_center, 0.76)
	if use_local_transform:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_question_tile_landmark(center: Vector2, use_local_transform := true) -> void:
	var landmark_origin := center + Config.VISIBLE_LANDMARK_OFFSET
	var landmark_center := landmark_origin
	if use_local_transform:
		draw_set_transform(landmark_origin, 0.0, Vector2(Config.VISIBLE_LANDMARK_SCALE, Config.VISIBLE_LANDMARK_SCALE))
		landmark_center = Vector2.ZERO
	var question := "?"
	var question_position := landmark_center + Vector2(-10.5, 11.0)
	# Use a large white glyph with a heavy dark outline; no colored badge surrounds it.
	for offset in [
		Vector2(-2.0, 0.0), Vector2(2.0, 0.0), Vector2(0.0, -2.0), Vector2(0.0, 2.0),
		Vector2(-1.5, -1.5), Vector2(1.5, -1.5), Vector2(-1.5, 1.5), Vector2(1.5, 1.5)
	]:
		draw_string(ThemeDB.fallback_font, question_position + offset, question, HORIZONTAL_ALIGNMENT_LEFT, -1, 31, Color("#111827"))
	draw_string(ThemeDB.fallback_font, question_position, question, HORIZONTAL_ALIGNMENT_LEFT, -1, 31, Color("#f8fafc"))
	if use_local_transform:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_soldier_avatar(center: Vector2) -> void:
	var black := Color("#111827")
	var white := Color("#f8fafc")
	# Keep the helmet centered on the tile and use a new open-face war helmet silhouette.
	var helmet_center := center + Vector2(0.0, 7.0)
	# Raised central ridge and side wings.
	draw_colored_polygon(PackedVector2Array([
		helmet_center + Vector2(-3.0, -21.0), helmet_center + Vector2(0.0, -28.0),
		helmet_center + Vector2(3.0, -21.0), helmet_center + Vector2(7.0, -16.0),
		helmet_center + Vector2(-7.0, -16.0)
	]), black)
	var dome := PackedVector2Array([
		helmet_center + Vector2(-15.0, -5.0), helmet_center + Vector2(-13.0, -14.0),
		helmet_center + Vector2(-7.0, -21.0), helmet_center + Vector2(0.0, -23.0),
		helmet_center + Vector2(7.0, -21.0), helmet_center + Vector2(13.0, -14.0),
		helmet_center + Vector2(15.0, -5.0), helmet_center + Vector2(11.0, -1.0),
		helmet_center + Vector2(-11.0, -1.0)
	])
	draw_colored_polygon(dome, white)
	draw_polyline(PackedVector2Array([
		helmet_center + Vector2(-15.0, -5.0), helmet_center + Vector2(-13.0, -14.0), helmet_center + Vector2(-7.0, -21.0),
		helmet_center + Vector2(0.0, -23.0), helmet_center + Vector2(7.0, -21.0), helmet_center + Vector2(13.0, -14.0),
		helmet_center + Vector2(15.0, -5.0)
	]), black, 2.2, true)
	# Open-face side guards and a broad brow distinguish this helmet from the prior Spartan design.
	draw_colored_polygon(PackedVector2Array([
		helmet_center + Vector2(-14.0, -4.0), helmet_center + Vector2(-7.0, -1.0),
		helmet_center + Vector2(-8.0, 10.0), helmet_center + Vector2(-15.0, 7.0)
	]), black)
	draw_colored_polygon(PackedVector2Array([
		helmet_center + Vector2(7.0, -1.0), helmet_center + Vector2(14.0, -4.0),
		helmet_center + Vector2(15.0, 7.0), helmet_center + Vector2(8.0, 10.0)
	]), black)
	draw_line(helmet_center + Vector2(-12.0, -3.0), helmet_center + Vector2(12.0, -3.0), black, 3.0, true)
	draw_line(helmet_center + Vector2(-8.0, 11.0), helmet_center + Vector2(8.0, 11.0), black, 2.5, true)

func _draw_gladiator_helmet(center: Vector2, scale := 0.76) -> void:
	var black := Color("#0b1220")
	var metal := Color("#d7dde5")
	var metal_dark := Color("#8b98a8")
	var c := center + Vector2(0.0, 5.0) * scale
	var p := func(offset: Vector2) -> Vector2: return c + offset * scale
	# Compact arena helmet: crest, rounded dome, brow and cheek guards.
	var crest := PackedVector2Array([
		p.call(Vector2(-3.0, -17.0)), p.call(Vector2(0.0, -25.0)), p.call(Vector2(3.0, -17.0)),
		p.call(Vector2(6.0, -13.0)), p.call(Vector2(-6.0, -13.0))
	])
	draw_colored_polygon(crest, black)
	var dome := PackedVector2Array([
		p.call(Vector2(-14.0, -4.0)), p.call(Vector2(-12.0, -13.0)), p.call(Vector2(-6.0, -20.0)),
		p.call(Vector2(0.0, -22.0)), p.call(Vector2(6.0, -20.0)), p.call(Vector2(12.0, -13.0)),
		p.call(Vector2(14.0, -4.0)), p.call(Vector2(9.0, 0.0)), p.call(Vector2(-9.0, 0.0))
	])
	draw_colored_polygon(dome, metal)
	draw_polyline(PackedVector2Array([dome[0], dome[1], dome[2], dome[3], dome[4], dome[5], dome[6], dome[7], dome[8], dome[0]]), black, maxf(1.0, 2.2 * scale), true)
	var left_guard := PackedVector2Array([p.call(Vector2(-13.0, -3.0)), p.call(Vector2(-6.0, 0.0)), p.call(Vector2(-8.0, 10.0)), p.call(Vector2(-14.0, 7.0))])
	var right_guard := PackedVector2Array([p.call(Vector2(6.0, 0.0)), p.call(Vector2(13.0, -3.0)), p.call(Vector2(14.0, 7.0)), p.call(Vector2(8.0, 10.0))])
	draw_colored_polygon(left_guard, metal_dark)
	draw_colored_polygon(right_guard, metal_dark)
	draw_polyline(PackedVector2Array([left_guard[0], left_guard[1], left_guard[2], left_guard[3], left_guard[0]]), black, maxf(1.0, 1.8 * scale), true)
	draw_polyline(PackedVector2Array([right_guard[0], right_guard[1], right_guard[2], right_guard[3], right_guard[0]]), black, maxf(1.0, 1.8 * scale), true)
	draw_line(p.call(Vector2(-12.0, -2.0)), p.call(Vector2(12.0, -2.0)), black, maxf(1.0, 2.8 * scale), true)
	draw_line(p.call(Vector2(-8.0, 11.0)), p.call(Vector2(8.0, 11.0)), black, maxf(1.0, 2.2 * scale), true)

func _draw_hidden_building_landmark(center: Vector2, building: int, level: int, unit_class: int) -> void:
	var landmark_origin := center + Config.VISIBLE_LANDMARK_OFFSET
	draw_set_transform(landmark_origin, 0.0, Vector2(Config.VISIBLE_LANDMARK_SCALE, Config.VISIBLE_LANDMARK_SCALE))
	match building:
		MINE:
			_draw_mine_landmark(Vector2.ZERO)
		BARRACKS:
			_draw_barracks_model(Vector2.ZERO, level, unit_class, false, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_wild_landmark(center: Vector2, monster_level := Config.WILD_MONSTER_LEVEL_ONE) -> void:
	var outline := Color("#111827")
	var fur := Color("#9ca3af")
	var fur_dark := Color("#4b5563")
	var muzzle := Color("#e5e7eb")
	var eye_color := Color("#111827")
	# Geometric wolf totem: a compact, front-facing emblem with carved planes.
	var silhouette := PackedVector2Array([
		center + Vector2(-17.0, 11.0), center + Vector2(-19.0, -5.0),
		center + Vector2(-14.0, -13.0), center + Vector2(-16.0, -28.0),
		center + Vector2(-4.0, -21.0), center + Vector2(0.0, -25.0),
		center + Vector2(4.0, -21.0), center + Vector2(16.0, -28.0),
		center + Vector2(14.0, -13.0), center + Vector2(19.0, -5.0),
		center + Vector2(17.0, 11.0), center + Vector2(8.0, 19.0),
		center + Vector2(0.0, 23.0), center + Vector2(-8.0, 19.0)
	])
	draw_colored_polygon(silhouette, fur)
	draw_polyline(PackedVector2Array([
		silhouette[0], silhouette[1], silhouette[2], silhouette[3], silhouette[4],
		silhouette[5], silhouette[6], silhouette[7], silhouette[8], silhouette[9],
		silhouette[10], silhouette[11], silhouette[12], silhouette[13], silhouette[0]
	]), outline, 2.8, true)
	# Dark ear interiors and cheek planes create the carved totem silhouette.
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-14.0, -14.0), center + Vector2(-16.0, -28.0),
		center + Vector2(-4.0, -21.0), center + Vector2(-8.0, -10.0)
	]), fur_dark)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(14.0, -14.0), center + Vector2(16.0, -28.0),
		center + Vector2(4.0, -21.0), center + Vector2(8.0, -10.0)
	]), fur_dark)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-17.0, 5.0), center + Vector2(-8.0, -3.0),
		center + Vector2(-7.0, 14.0), center + Vector2(-12.0, 17.0)
	]), fur_dark)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(17.0, 5.0), center + Vector2(8.0, -3.0),
		center + Vector2(7.0, 14.0), center + Vector2(12.0, 17.0)
	]), fur_dark)
	# Central forehead ridge and slanted eyes give the emblem an aggressive expression.
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0.0, -21.0), center + Vector2(-5.0, -8.0),
		center + Vector2(0.0, -3.0), center + Vector2(5.0, -8.0)
	]), Color("#d1d5db"))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-12.0, -7.0), center + Vector2(-3.0, -10.0),
		center + Vector2(-5.0, -4.0), center + Vector2(-12.0, -3.0)
	]), outline)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(12.0, -7.0), center + Vector2(3.0, -10.0),
		center + Vector2(5.0, -4.0), center + Vector2(12.0, -3.0)
	]), outline)
	draw_circle(center + Vector2(-7.0, -6.0), 1.8, eye_color)
	draw_circle(center + Vector2(7.0, -6.0), 1.8, eye_color)
	# Angular muzzle, nose and fangs finish the wolf-totem mark.
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-8.0, 1.0), center + Vector2(0.0, -3.0),
		center + Vector2(8.0, 1.0), center + Vector2(5.0, 14.0),
		center + Vector2(0.0, 21.0), center + Vector2(-5.0, 14.0)
	]), muzzle)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-4.0, 1.0), center + Vector2(4.0, 1.0), center + Vector2(0.0, 6.0)
	]), outline)
	draw_line(center + Vector2(-5.0, 9.0), center + Vector2(0.0, 12.0), outline, 1.6, true)
	draw_line(center + Vector2(5.0, 9.0), center + Vector2(0.0, 12.0), outline, 1.6, true)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-7.0, 9.0), center + Vector2(-4.0, 9.0), center + Vector2(-5.5, 16.0)
	]), Color("#ffffff"))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(4.0, 9.0), center + Vector2(7.0, 9.0), center + Vector2(5.5, 16.0)
	]), Color("#ffffff"))
	var level := clampi(monster_level, Config.WILD_MONSTER_LEVEL_ONE, Config.WILD_MONSTER_LEVEL_THREE)
	var level_center := center + Vector2(17.0, -21.0)
	draw_circle(level_center + Vector2(1.0, 1.0), 8.0, Color(0.0, 0.0, 0.0, 0.48))
	draw_circle(level_center, 7.0, Color("#facc15"))
	draw_string(ThemeDB.fallback_font, level_center + Vector2(-3.0, 3.5), str(level), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#111827"))

func _roll_visible_monster_level() -> int:
	var roll := randf()
	if roll < Config.WILD_MONSTER_VISIBLE_LEVEL_ONE_WEIGHT:
		return Config.WILD_MONSTER_LEVEL_ONE
	if roll < Config.WILD_MONSTER_VISIBLE_LEVEL_ONE_WEIGHT + Config.WILD_MONSTER_VISIBLE_LEVEL_TWO_WEIGHT:
		return Config.WILD_MONSTER_LEVEL_TWO
	return Config.WILD_MONSTER_LEVEL_THREE

func _draw_fate_crystal_ball_landmark(center: Vector2) -> void:
	var outline := Color("#0b1220")
	var glass := Color("#d1d5db")
	var glass_dark := Color("#6b7280")
	var highlight := Color("#f9fafb")
	var ball_center := center + Vector2(0.0, -1.0)
	var cloth := Color("#6b7280")
	var cloth_dark := Color("#374151")
	var cloth_trim := Color("#9ca3af")
	# A compact crystal ball sits on a draped velvet cloth stand.
	_draw_ellipse(ball_center + Vector2(0.0, 22.0), Vector2(19.0, 4.0), Color(0.0, 0.0, 0.0, 0.28))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-13.0, 10.0), center + Vector2(0.0, 10.0),
		center + Vector2(-4.0, 24.0), center + Vector2(-12.0, 21.0)
	]), cloth_dark)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-5.0, 10.0), center + Vector2(5.0, 10.0),
		center + Vector2(10.0, 23.0), center + Vector2(0.0, 21.0)
	]), cloth)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0.0, 10.0), center + Vector2(13.0, 10.0),
		center + Vector2(12.0, 21.0), center + Vector2(4.0, 24.0)
	]), cloth_dark)
	draw_polyline(PackedVector2Array([
		center + Vector2(-13.0, 10.0), center + Vector2(13.0, 10.0),
		center + Vector2(12.0, 21.0)
	]), outline, 2.0, true)
	draw_line(center + Vector2(-11.0, 12.0), center + Vector2(11.0, 12.0), cloth_trim, 2.0, true)
	draw_circle(ball_center + Vector2(1.5, 2.0), 17.0, outline)
	draw_circle(ball_center, 14.5, glass_dark)
	draw_circle(ball_center + Vector2(-2.0, -2.0), 12.0, glass)
	draw_arc(ball_center + Vector2(1.0, 1.0), 8.0, -2.55, 0.75, 16, highlight, 2.2, true)
	draw_circle(ball_center + Vector2(-5.0, -6.0), 3.0, Color(0.93, 0.95, 1.0, 0.85))
	draw_circle(ball_center + Vector2(5.0, 4.0), 1.8, Color("#f9fafb"))

func _draw_mine_landmark(center: Vector2) -> void:
	var outline := Color("#0b1220")
	var gold := Color("#d1d5db")
	var gold_dark := Color("#6b7280")
	var shine := Color("#f9fafb")
	var body := PackedVector2Array([
		center + Vector2(-16.0, 8.0), center + Vector2(-12.0, -6.0),
		center + Vector2(-3.0, -14.0), center + Vector2(10.0, -8.0),
		center + Vector2(16.0, 7.0), center + Vector2(6.0, 15.0),
		center + Vector2(-8.0, 14.0)
	])
	# A compact outlined gold ore icon replaces the larger mountain model.
	draw_colored_polygon(body, gold)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-12.0, -4.0), center + Vector2(-3.0, -14.0),
		center + Vector2(2.0, 0.0), center + Vector2(-5.0, 7.0)
	]), shine)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(2.0, 0.0), center + Vector2(10.0, -8.0),
		center + Vector2(16.0, 7.0), center + Vector2(6.0, 15.0)
	]), gold_dark)
	draw_polyline(PackedVector2Array([body[0], body[1], body[2], body[3], body[4], body[5], body[6], body[0]]), outline, 2.5, true)
	draw_line(center + Vector2(-4.0, -2.0), center + Vector2(5.0, 7.0), outline, 2.0, true)
	draw_circle(center + Vector2(11.0, -14.0), 3.0, outline)
	draw_circle(center + Vector2(11.0, -14.0), 1.7, shine)

func _draw_mine_building_model(center: Vector2) -> void:
	var outline := Color("#111827")
	var rock := Color("#6b7280")
	var rock_light := Color("#d1d5db")
	var rock_dark := Color("#374151")
	var gold := Color("#f9fafb")
	_draw_ellipse(center + Vector2(0.0, 16.0), Vector2(21.0, 6.0), Color(0.0, 0.0, 0.0, 0.36))
	# Layered rock faces keep the opened mine recognizable instead of reading as a coin.
	var left_face := PackedVector2Array([
		center + Vector2(-20.0, 10.0), center + Vector2(-11.0, -10.0),
		center + Vector2(-1.0, 5.0), center + Vector2(-6.0, 16.0)
	])
	var right_face := PackedVector2Array([
		center + Vector2(-1.0, 5.0), center + Vector2(9.0, -16.0),
		center + Vector2(20.0, 10.0), center + Vector2(-6.0, 16.0)
	])
	var center_face := PackedVector2Array([
		center + Vector2(-11.0, -10.0), center + Vector2(9.0, -16.0),
		center + Vector2(12.0, 8.0), center + Vector2(-1.0, 16.0),
		center + Vector2(-6.0, 16.0), center + Vector2(-1.0, 5.0)
	])
	draw_colored_polygon(left_face, rock_dark)
	draw_colored_polygon(right_face, rock)
	draw_colored_polygon(center_face, rock_light)
	draw_polyline(PackedVector2Array([left_face[0], left_face[1], left_face[2], left_face[3], left_face[0]]), outline, 2.3, true)
	draw_polyline(PackedVector2Array([right_face[0], right_face[1], right_face[2], right_face[3], right_face[0]]), outline, 2.3, true)
	draw_polyline(PackedVector2Array([center_face[0], center_face[1], center_face[2], center_face[3], center_face[4], center_face[5], center_face[0]]), outline, 2.3, true)
	# Dark cave opening and a few bright gold veins complete the mine silhouette.
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-7.0, 14.0), center + Vector2(-3.0, 5.0),
		center + Vector2(5.0, 5.0), center + Vector2(9.0, 14.0)
	]), rock_dark)
	draw_line(center + Vector2(-5.0, -3.0), center + Vector2(-1.0, 8.0), gold, 2.0, true)
	draw_line(center + Vector2(3.0, -7.0), center + Vector2(7.0, 3.0), gold, 2.0, true)
	draw_circle(center + Vector2(12.0, -17.0), 3.0, outline)
	draw_circle(center + Vector2(12.0, -17.0), 1.6, gold)

func _draw_merchant_landmark(center: Vector2, presenting := false, presentation_progress := 0.0) -> void:
	_draw_ellipse(center + Vector2(0.0, 14.0), Vector2(19.0, 5.0), Color(0.0, 0.0, 0.0, 0.25))
	if presenting:
		_draw_merchant_presented_cards(center, presentation_progress)
	draw_texture_rect(MERCHANT_ART, Rect2(center + Vector2(-25.0, -33.0), Vector2(50.0, 50.0)), false)

func _draw_merchant_presented_cards(center: Vector2, presentation_progress: float) -> void:
	var progress := clampf(presentation_progress / Config.MERCHANT_PRESENTATION_DURATION, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - progress, 2.0)
	var card_y := lerpf(-10.0, -42.0, eased)
	var card_scale := lerpf(0.72, 1.0, eased)
	var card_offsets := [-22.0, 0.0, 22.0]
	for index in range(card_offsets.size()):
		var card_center := center + Vector2(float(card_offsets[index]), card_y - absf(float(index - 1)) * 2.0)
		_draw_merchant_presented_card(card_center, card_scale, index)
	# The hands rise with the cards so the animation reads as a world-space action.
	var hand_lift := lerpf(0.0, -12.0, eased)
	draw_line(center + Vector2(-9.0, 2.0), center + Vector2(-20.0, -13.0 + hand_lift), Color("#f3c6a5"), 3.0, true)
	draw_line(center + Vector2(9.0, 2.0), center + Vector2(20.0, -13.0 + hand_lift), Color("#f3c6a5"), 3.0, true)
	draw_circle(center + Vector2(-20.0, -13.0 + hand_lift), 3.0, Color("#f3c6a5"))
	draw_circle(center + Vector2(20.0, -13.0 + hand_lift), 3.0, Color("#f3c6a5"))

func _draw_merchant_presented_card(card_center: Vector2, scale: float, index: int) -> void:
	var card_size := Vector2(13.0, 19.0) * scale
	var outline := Color("#0b1220")
	var paper := Color("#f8fafc")
	var accent: Color = [Color("#f59e0b"), Color("#a78bfa"), Color("#22d3ee")][index]
	draw_rect(Rect2(card_center - card_size * 0.5 + Vector2(1.0, 1.5), card_size), outline, true)
	draw_rect(Rect2(card_center - card_size * 0.5, card_size), paper, true)
	draw_rect(Rect2(card_center - card_size * 0.5, card_size), outline, false, maxf(1.0, 1.5 * scale))
	draw_circle(card_center, 3.2 * scale, accent)
	draw_string(ThemeDB.fallback_font, card_center + Vector2(-2.5, 2.8) * scale, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, int(8.0 * scale), outline)

func _draw_ground_item_icon(center: Vector2, item_id: String) -> void:
	var color := Color("#fbbf24")
	draw_circle(center + Vector2(0.0, 12.0), 15.0, Color(0.0, 0.0, 0.0, 0.25))
	match item_id:
		"dragon":
			color = Color("#ef4444")
			draw_colored_polygon(PackedVector2Array([center + Vector2(-13, 7), center + Vector2(0, -12), center + Vector2(13, 7)]), color)
			draw_circle(center + Vector2(0, -12), 4.0, Color("#fca5a5"))
			draw_line(center + Vector2(-9, 3), center + Vector2(-16, -5), color, 3.0, true)
			draw_line(center + Vector2(9, 3), center + Vector2(16, -5), color, 3.0, true)
		"upgrade":
			color = Color("#a78bfa")
			draw_circle(center, 13.0, Color(0.3, 0.2, 0.6, 0.45))
			draw_string(ThemeDB.fallback_font, center + Vector2(-7, 6), "+1", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
		"steel_barrier":
			color = Color("#94a3b8")
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -14), center + Vector2(13, -7), center + Vector2(10, 9), center + Vector2(0, 16), center + Vector2(-10, 9), center + Vector2(-13, -7)]), color)
			draw_line(center + Vector2(-6, 0), center + Vector2(6, 0), Color("#e2e8f0"), 2.0, true)
		"blizzard":
			color = Color("#67e8f9")
			draw_circle(center, 12.0, Color(0.1, 0.7, 0.9, 0.28))
			for angle in [0.0, PI / 3.0, 2.0 * PI / 3.0]:
				draw_line(center - Vector2(cos(angle), sin(angle)) * 12.0, center + Vector2(cos(angle), sin(angle)) * 12.0, color, 2.0, true)
		"transfer_certificate":
			color = Color("#f59e0b")
			draw_rect(Rect2(center + Vector2(-11, -14), Vector2(22, 28)), Color("#fef3c7"), true)
			draw_polyline(PackedVector2Array([center + Vector2(-11, -14), center + Vector2(11, -14), center + Vector2(11, 14), center + Vector2(-11, 14), center + Vector2(-11, -14)]), color, 2.0, true)
			draw_string(ThemeDB.fallback_font, center + Vector2(-5, 5), "权", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, color)
		_:
			draw_circle(center, 12.0, color)

func _draw_pickaxe_icon(center: Vector2, scale := 1.0) -> void:
	var handle_color := Color("#d6a85c")
	var head_color := Color("#e2e8f0")
	draw_line(center + Vector2(-8, 9) * scale, center + Vector2(6, -7) * scale, handle_color, 3.0 * scale, true)
	draw_line(center + Vector2(3, -10) * scale, center + Vector2(14, -5) * scale, head_color, 4.0 * scale, true)
	draw_line(center + Vector2(3, -10) * scale, center + Vector2(7, -1) * scale, head_color, 4.0 * scale, true)
	draw_circle(center + Vector2(-8, 9) * scale, 2.0 * scale, Color("#a16207"))

func _draw_coin_icon(center: Vector2, scale := 1.0) -> void:
	var outline := Color("#0b1220")
	var gold := Color("#facc15")
	var shine := Color("#fde68a")
	draw_circle(center + Vector2(1.5, 2.0) * scale, 11.0 * scale, outline)
	draw_circle(center, 9.0 * scale, gold)
	draw_circle(center + Vector2(-2.0, -2.0) * scale, 5.5 * scale, shine)
	draw_arc(center, 9.0 * scale, 0.0, TAU, 20, Color("#a16207"), maxf(1.0, 1.6 * scale), true)
	draw_string(ThemeDB.fallback_font, center + Vector2(-3.0, 4.0) * scale, "金", HORIZONTAL_ALIGNMENT_LEFT, -1, int(8.0 * scale), Color("#a16207"))

func _is_in_barracks_range(cell: Vector2i) -> bool:
	if not tiles.has(barracks_range_cell) or cell == barracks_range_cell:
		return false
	var dispatch_range := Config.BARRACKS_DETECTION_RANGE
	var selected_tile: Dictionary = tiles[barracks_range_cell]
	if int(selected_tile.get("building", EMPTY)) == BARRACKS:
		dispatch_range = Config.get_barracks_dispatch_range(int(selected_tile.get("building_level", 1)))
	return cube_distance(cell, barracks_range_cell) <= dispatch_range

func _draw_drag_source_preview(cell: Vector2i) -> void:
	var tile: Dictionary = tiles[cell]
	var preview_position := drag_preview_world + Vector2(0.0, -18.0)
	draw_line(axial_to_world(cell), preview_position, Color(0.94, 0.82, 0.35, 0.42), 2.0, true)
	draw_circle(preview_position + Vector2(0.0, 15.0), 22.0, Color(0.0, 0.0, 0.0, 0.28))
	_draw_building(cell, preview_position, int(tile["building"]), int(tile["building_level"]), int(tile["unit_class"]))

func _draw_building(cell: Vector2i, center: Vector2, building: int, level: int, unit_class: int = -1) -> void:
	if HQ_CELLS.has(cell):
		var hq_owner := int(tiles.get(cell, {}).get("owner", UNKNOWN))
		var hq_color := _faction_color(hq_owner, Color("#94a3b8"))
		var hq_destroyed := false
		var main_ref := get_parent()
		if main_ref != null and main_ref.has_method("is_hq_destroyed"):
			hq_destroyed = bool(main_ref.call("is_hq_destroyed", cell))
		if hq_destroyed:
			_draw_destroyed_hq(center, hq_color)
			return
		var hq_dark := hq_color.darkened(0.42)
		_draw_ellipse(center + Vector2(0.0, 17.0), Vector2(26.0, 7.0), Color(0.0, 0.0, 0.0, 0.38))
		draw_rect(Rect2(center + Vector2(-15.0, -1.0), Vector2(30.0, 20.0)), hq_dark, true)
		draw_circle(center, 19.0, Color(hq_color, 0.25))
		# Castle base and roof.
		draw_rect(Rect2(center + Vector2(-15, -4), Vector2(30, 20)), hq_color, true)
		draw_rect(Rect2(center + Vector2(-18, -8), Vector2(7, 24)), hq_color.darkened(0.18), true)
		draw_rect(Rect2(center + Vector2(11, -8), Vector2(7, 24)), hq_color.darkened(0.18), true)
		draw_colored_polygon(PackedVector2Array([center + Vector2(-19, -7), center + Vector2(19, -7), center + Vector2(0, -25)]), hq_color.lightened(0.18))
		draw_rect(Rect2(center + Vector2(-4, 8), Vector2(8, 8)), Color("#08111f"), true)
		# Small lord standing on the roof.
		var lord_center := center + Vector2(0, -33)
		draw_circle(lord_center + Vector2(0, -5), 5.0, Color("#f5c7a9"))
		draw_rect(Rect2(lord_center + Vector2(-5, 1), Vector2(10, 11)), hq_color.lightened(0.28), true)
		draw_line(lord_center + Vector2(-5, 4), lord_center + Vector2(-10, 8), Color("#f5c7a9"), 2.0, true)
		draw_line(lord_center + Vector2(5, 4), lord_center + Vector2(10, 8), Color("#f5c7a9"), 2.0, true)
		draw_line(lord_center + Vector2(-3, 12), lord_center + Vector2(-4, 17), Color("#0f172a"), 2.0, true)
		draw_line(lord_center + Vector2(3, 12), lord_center + Vector2(4, 17), Color("#0f172a"), 2.0, true)
		return
	match building:
		MINE:
			var tile: Dictionary = tiles.get(cell, {})
			var is_visible_mine := int(tile.get("tile_type", -1)) == Config.VISIBLE_TILE_TYPE and int(tile.get("visible_tile_result", -1)) == Config.VISIBLE_MINE
			if is_visible_mine:
				_draw_visible_landmark_art(center, VISIBLE_GOLD_MINE_ART, 90.0, 0.62)
			else:
				_draw_mine_building_model(center)
		BARRACKS:
			_draw_barracks_model(center, level, unit_class, false, false, int(tiles.get(cell, {}).get("owner", UNKNOWN)))
		TOWER:
			var tower_color := _faction_building_color(int(tiles.get(cell, {}).get("owner", UNKNOWN)), Color("#94a3b8"))
			_draw_ellipse(center + Vector2(0.0, 15.0), Vector2(19.0, 6.0), Color(0.0, 0.0, 0.0, 0.36))
			draw_circle(center + Vector2(0.0, 5.0), 14.0, tower_color.darkened(0.42))
			draw_circle(center, 14.0, tower_color)
			draw_circle(center + Vector2(-2.0, -3.0), 7.0, tower_color.lightened(0.18))
			draw_line(center + Vector2(-4, -4), center + Vector2(13, -18), tower_color.lightened(0.36), 4.0)
			draw_line(center + Vector2(-8.0, -9.0), center + Vector2(1.0, -13.0), tower_color.lightened(0.44), 2.0, true)
		MERCHANT:
			var presentation_elapsed := float(merchant_presentation_animations.get(cell, -1.0))
			_draw_merchant_landmark(center, presentation_elapsed >= 0.0, maxf(0.0, presentation_elapsed))
		STEEL_BARRIER:
			_draw_steel_barrier(center, _faction_building_color(int(tiles.get(cell, {}).get("owner", UNKNOWN)), Color("#94a3b8")))

func _draw_destroyed_hq(center: Vector2, faction_color: Color) -> void:
	var rubble := faction_color.darkened(0.48).lerp(Color("#475569"), 0.45)
	var rubble_dark := rubble.darkened(0.28)
	var crack := Color("#111827")
	_draw_ellipse(center + Vector2(0.0, 16.0), Vector2(24.0, 6.0), Color(0.0, 0.0, 0.0, 0.34))
	# Broken castle walls and an uneven roof.
	draw_rect(Rect2(center + Vector2(-16.0, -2.0), Vector2(32.0, 20.0)), rubble, true)
	draw_rect(Rect2(center + Vector2(-19.0, -8.0), Vector2(8.0, 25.0)), rubble_dark, true)
	draw_rect(Rect2(center + Vector2(11.0, -5.0), Vector2(8.0, 22.0)), rubble_dark, true)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-19.0, -8.0), center + Vector2(-7.0, -8.0),
		center + Vector2(-2.0, -19.0), center + Vector2(6.0, -12.0),
		center + Vector2(12.0, -22.0), center + Vector2(19.0, -5.0)
	]), rubble.lightened(0.10))
	draw_rect(Rect2(center + Vector2(-5.0, 8.0), Vector2(10.0, 10.0)), crack, true)
	draw_line(center + Vector2(-13.0, -2.0), center + Vector2(-6.0, 5.0), crack, 2.0, true)
	draw_line(center + Vector2(-6.0, 5.0), center + Vector2(-10.0, 13.0), crack, 2.0, true)
	draw_line(center + Vector2(7.0, -5.0), center + Vector2(3.0, 3.0), crack, 2.0, true)
	draw_line(center + Vector2(3.0, 3.0), center + Vector2(10.0, 10.0), crack, 2.0, true)
	# A simple hanging corpse suspended from the broken roof.
	var corpse := center + Vector2(0.0, -34.0)
	draw_line(center + Vector2(0.0, -18.0), corpse + Vector2(0.0, -7.0), Color("#1f2937"), 2.0, true)
	draw_circle(corpse + Vector2(0.0, -3.0), 5.0, Color("#111827"))
	draw_line(corpse + Vector2(0.0, 2.0), corpse + Vector2(0.0, 14.0), Color("#111827"), 4.0, true)
	draw_line(corpse + Vector2(-2.0, 5.0), corpse + Vector2(-10.0, 10.0), Color("#111827"), 3.0, true)
	draw_line(corpse + Vector2(2.0, 5.0), corpse + Vector2(10.0, 10.0), Color("#111827"), 3.0, true)
	draw_line(corpse + Vector2(0.0, 14.0), corpse + Vector2(-6.0, 22.0), Color("#111827"), 3.0, true)
	draw_line(corpse + Vector2(0.0, 14.0), corpse + Vector2(6.0, 22.0), Color("#111827"), 3.0, true)
	draw_line(corpse + Vector2(-2.0, -5.0), corpse + Vector2(-1.0, -2.0), Color("#f87171"), 1.5, true)
	draw_line(corpse + Vector2(2.0, -5.0), corpse + Vector2(1.0, -2.0), Color("#f87171"), 1.5, true)

func _draw_steel_barrier(center: Vector2, color: Color) -> void:
	var dark := color.darkened(0.45)
	var light := color.lightened(0.28)
	_draw_ellipse(center + Vector2(0.0, 15.0), Vector2(23.0, 6.0), Color(0.0, 0.0, 0.0, 0.38))
	draw_rect(Rect2(center + Vector2(-20.0, -10.0), Vector2(40.0, 22.0)), dark, true)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-17.0, -14.0), center + Vector2(17.0, -14.0),
		center + Vector2(20.0, 10.0), center + Vector2(-20.0, 10.0)
	]), color)
	for x in [-12.0, 0.0, 12.0]:
		draw_rect(Rect2(center + Vector2(x - 2.0, -13.0), Vector2(4.0, 24.0)), light, true)
	draw_line(center + Vector2(-18.0, 0.0), center + Vector2(18.0, 0.0), dark, 2.0, true)

func _unit_class_short_name(unit_class: int) -> String:
	if unit_class < 0 or unit_class >= Config.UNIT_CLASS_COUNT:
		return "?"
	return str(Config.UNIT_CLASS_SHORT_NAMES[unit_class])

func _unit_class_color(unit_class: int) -> Color:
	match unit_class:
		Config.UNIT_CLASS_TANK:
			return Color("#64748b")
		Config.UNIT_CLASS_WARRIOR:
			return Color("#a78bfa")
		Config.UNIT_CLASS_MAGE:
			return Color("#f472b6")
		Config.UNIT_CLASS_ASSASSIN:
			return Color("#ef4444")
		Config.UNIT_CLASS_ARCHER:
			return Color("#22c55e")
	return Color("#a78bfa")

func _draw_barracks_model(center: Vector2, level: int, unit_class: int, can_merge := false, neutral := false, faction := UNKNOWN) -> void:
	var tier := clampi(level, 1, 4)
	var scale := float(Config.BARRACKS_LEVEL_SCALE[tier - 1])
	var base_color := _faction_building_color(faction, Color("#94a3b8")) if not neutral else Color("#94a3b8")
	var dark_color := base_color.darkened(0.42)
	var light_color := base_color.lightened(0.22)
	var accent_color := Color(Config.BARRACKS_LEVEL_ACCENT_COLORS[tier - 1]) if neutral else base_color.lightened(0.20 + 0.06 * float(tier - 1))
	var trim_color := accent_color.lightened(0.10)
	var model_center := center + Vector2(0.0, Config.BARRACKS_MODEL_LIFT)
	# Use the supplied profession artwork when available. The complete
	# procedural model below remains intact as the fallback renderer.
	if _has_barracks_art(unit_class, faction):
		if can_merge:
			var art_pulse := 0.5 + 0.5 * sin(mergeable_effect_elapsed * 5.0)
			draw_circle(model_center + Vector2(0.0, -5.0), 27.0 * scale, Color(1.0, 0.78, 0.22, 0.045 + art_pulse * 0.035))
			draw_arc(model_center + Vector2(0.0, -5.0), 25.0 * scale, -PI * 0.5, TAU - PI * 0.5, 32, Color(1.0, 0.78, 0.22, 0.30 + art_pulse * 0.30), 2.0, true)
		_draw_ellipse(model_center + Vector2(0.0, 17.0 * scale), Vector2(22.0, 5.0) * scale, Color(0.0, 0.0, 0.0, 0.30))
		_draw_barracks_art_model(model_center, scale, unit_class, faction)
		_draw_barracks_level_badge(model_center, scale, tier, accent_color, trim_color)
		return
	# High-contrast plinth separates the building from similarly colored candy
	# tiles. The dark rim and offset shadow establish a readable 2.5D footprint.
	var plinth := PackedVector2Array([
		model_center + Vector2(-30.0, 10.0) * scale,
		model_center + Vector2(-18.0, 20.0) * scale,
		model_center + Vector2(18.0, 20.0) * scale,
		model_center + Vector2(30.0, 10.0) * scale,
		model_center + Vector2(18.0, 2.0) * scale,
		model_center + Vector2(-18.0, 2.0) * scale
	])
	draw_colored_polygon(plinth, Color("#172033"))
	draw_polyline(PackedVector2Array([plinth[0], plinth[1], plinth[2], plinth[3], plinth[0]]), Color("#0b1220"), maxf(2.0, 3.0 * scale), true)
	var plinth_top := PackedVector2Array([
		model_center + Vector2(-25.0, 7.0) * scale,
		model_center + Vector2(-14.0, 14.0) * scale,
		model_center + Vector2(14.0, 14.0) * scale,
		model_center + Vector2(25.0, 7.0) * scale,
		model_center + Vector2(14.0, 1.0) * scale,
		model_center + Vector2(-14.0, 1.0) * scale
	])
	draw_colored_polygon(plinth_top, Color("#334155"))
	draw_polyline(PackedVector2Array([plinth_top[0], plinth_top[1], plinth_top[2], plinth_top[3], plinth_top[0]]), Color("#f8fafc", 0.72), maxf(1.5, 2.0 * scale), true)
	# A raised faction pennant gives the small model a vertical recognition cue.
	var pennant_x := model_center.x + 22.0 * scale
	var pennant_top := model_center.y - 38.0 * scale
	draw_line(Vector2(pennant_x, pennant_top), Vector2(pennant_x, model_center.y + 3.0 * scale), Color("#3b2418"), maxf(2.0, 3.0 * scale), true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(pennant_x, pennant_top + 2.0 * scale),
		Vector2(pennant_x + 17.0 * scale, pennant_top + 7.0 * scale),
		Vector2(pennant_x, pennant_top + 14.0 * scale)
	]), accent_color)
	draw_polyline(PackedVector2Array([
		Vector2(pennant_x, pennant_top + 2.0 * scale),
		Vector2(pennant_x + 17.0 * scale, pennant_top + 7.0 * scale),
		Vector2(pennant_x, pennant_top + 14.0 * scale)
	]), Color("#172033"), maxf(1.0, 1.5 * scale), true)

	if can_merge:
		var pulse := 0.5 + 0.5 * sin(mergeable_effect_elapsed * 5.0)
		draw_circle(model_center + Vector2(0.0, -5.0), 27.0 * scale, Color(1.0, 0.78, 0.22, 0.045 + pulse * 0.035))
		draw_arc(model_center + Vector2(0.0, -5.0), 25.0 * scale, -PI * 0.5, TAU - PI * 0.5, 32, Color(1.0, 0.78, 0.22, 0.30 + pulse * 0.30), 2.0, true)
	_draw_ellipse(model_center + Vector2(0.0, 17.0 * scale), Vector2(22.0, 5.0) * scale, Color(0.0, 0.0, 0.0, 0.30))
	match tier:
		1:
			_draw_barracks_level_one(model_center, scale, base_color, dark_color, light_color, accent_color)
		2:
			_draw_barracks_level_two(model_center, scale, base_color, dark_color, light_color, accent_color)
		3:
			_draw_barracks_level_three(model_center, scale, base_color, dark_color, light_color, accent_color)
		4:
			_draw_barracks_level_four(model_center, scale, base_color, dark_color, light_color, accent_color)
	_draw_barracks_class_signature(model_center, scale, unit_class, base_color, dark_color, light_color, accent_color)

	# A consistent crest ties the profession and building level together.
	draw_circle(model_center + Vector2(0.0, 11.0 * scale), 4.0 * scale, Color(0.0, 0.0, 0.0, 0.28))
	draw_circle(model_center + Vector2(0.0, 9.0 * scale), 3.0 * scale, trim_color)
	# A separate badge makes the building tier readable at a glance.
	var level_badge_center := model_center + Vector2(19.0, 14.0) * scale
	draw_circle(level_badge_center, 8.0 * scale, Color("#172033"))
	draw_circle(level_badge_center, 6.0 * scale, accent_color)
	draw_string(ThemeDB.fallback_font, level_badge_center + Vector2(-3.2 * scale, 3.5 * scale), str(tier), HORIZONTAL_ALIGNMENT_LEFT, -1, int(10.0 * scale), Color("#172033"))

func _barracks_art_for_faction(faction: int) -> Texture2D:
	match faction:
		Config.FACTION_PLAYER:
			return BARRACKS_ART_PLAYER
		Config.FACTION_RED:
			return BARRACKS_ART_RED
		Config.FACTION_PURPLE:
			return BARRACKS_ART_PURPLE
		Config.FACTION_GREEN:
			return BARRACKS_ART_GREEN
	return null

func _has_barracks_art(unit_class: int, faction: int) -> bool:
	return _barracks_art_for_faction(faction) != null and unit_class >= 0 and unit_class < BARRACKS_ART_REGIONS.size()

func _draw_barracks_art_model(center: Vector2, scale: float, unit_class: int, faction: int) -> void:
	var barracks_art := _barracks_art_for_faction(faction)
	if barracks_art == null:
		return
	var source_region: Rect2 = BARRACKS_ART_REGIONS[clampi(unit_class, 0, BARRACKS_ART_REGIONS.size() - 1)]
	var width := Config.BARRACKS_ART_BASE_WIDTH * Config.BARRACKS_ART_DISPLAY_SCALE * scale
	var height := width * source_region.size.y / maxf(1.0, source_region.size.x)
	var bottom := center + Vector2(0.0, 18.0 * scale)
	var destination := Rect2(
		Vector2(bottom.x - width * 0.5, bottom.y - height),
		Vector2(width, height)
	)
	draw_texture_rect_region(barracks_art, destination, source_region, Color.WHITE, false, true)

func _draw_barracks_level_badge(center: Vector2, scale: float, tier: int, accent_color: Color, trim_color: Color) -> void:
	# Keep the existing level marker and faction-colored upgrade feedback on
	# top of the new profession artwork.
	draw_circle(center + Vector2(0.0, 11.0 * scale), 4.0 * scale, Color(0.0, 0.0, 0.0, 0.28))
	draw_circle(center + Vector2(0.0, 9.0 * scale), 3.0 * scale, trim_color)
	var level_badge_center := center + Vector2(19.0, 14.0) * scale
	draw_circle(level_badge_center, 8.0 * scale, Color("#172033"))
	draw_circle(level_badge_center, 6.0 * scale, accent_color)
	draw_string(ThemeDB.fallback_font, level_badge_center + Vector2(-3.2 * scale, 3.5 * scale), str(tier), HORIZONTAL_ALIGNMENT_LEFT, -1, int(10.0 * scale), Color("#172033"))

func _draw_barracks_class_signature(center: Vector2, scale: float, unit_class: int, base: Color, dark: Color, light: Color, accent: Color) -> void:
	# Each profession gets a different structural silhouette. The colors still
	# come from the owning faction, so the shape is the profession cue.
	match unit_class:
		Config.UNIT_CLASS_TANK:
			# Broad armored side plates and a heavy central shield.
			draw_rect(Rect2(center + Vector2(-25.0, -1.0) * scale, Vector2(7.0, 13.0) * scale), dark, true)
			draw_rect(Rect2(center + Vector2(18.0, -1.0) * scale, Vector2(7.0, 13.0) * scale), dark, true)
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(-8.0, 2.0) * scale,
				center + Vector2(8.0, 2.0) * scale,
				center + Vector2(0.0, 15.0) * scale
			]), base)
			draw_line(center + Vector2(0.0, 5.0) * scale, center + Vector2(0.0, 12.0) * scale, light, maxf(1.0, 2.0 * scale), true)
			draw_line(center + Vector2(-4.0, 8.5) * scale, center + Vector2(4.0, 8.5) * scale, light, maxf(1.0, 2.0 * scale), true)
		Config.UNIT_CLASS_WARRIOR:
			# Twin blades form a clear crossed-sword roof ornament.
			draw_line(center + Vector2(-13.0, -19.0) * scale, center + Vector2(8.0, -2.0) * scale, light, maxf(1.0, 3.0 * scale), true)
			draw_line(center + Vector2(13.0, -19.0) * scale, center + Vector2(-8.0, -2.0) * scale, light, maxf(1.0, 3.0 * scale), true)
			draw_line(center + Vector2(-11.0, -13.0) * scale, center + Vector2(-16.0, -13.0) * scale, accent, maxf(1.0, 2.0 * scale), true)
			draw_line(center + Vector2(11.0, -13.0) * scale, center + Vector2(16.0, -13.0) * scale, accent, maxf(1.0, 2.0 * scale), true)
		Config.UNIT_CLASS_MAGE:
			# A tall arcane spire and orb make the mage building narrow and high.
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(-7.0, -16.0) * scale,
				center + Vector2(7.0, -16.0) * scale,
				center + Vector2(0.0, -39.0) * scale
			]), dark)
			draw_circle(center + Vector2(0.0, -39.0) * scale, 5.0 * scale, accent)
			draw_circle(center + Vector2(0.0, -39.0) * scale, 2.0 * scale, light)
			draw_arc(center + Vector2(0.0, -25.0) * scale, 11.0 * scale, PI * 0.15, PI * 0.85, 12, light, maxf(1.0, 1.5 * scale), true)
		Config.UNIT_CLASS_ASSASSIN:
			# A slim hood with asymmetric blades gives the assassin a sharp profile.
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(-8.0, -9.0) * scale,
				center + Vector2(8.0, -9.0) * scale,
				center + Vector2(0.0, -33.0) * scale
			]), dark)
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(-4.0, -13.0) * scale,
				center + Vector2(4.0, -13.0) * scale,
				center + Vector2(0.0, -27.0) * scale
			]), base)
			draw_line(center + Vector2(-12.0, 3.0) * scale, center + Vector2(-22.0, -8.0) * scale, accent, maxf(1.0, 2.0 * scale), true)
			draw_line(center + Vector2(12.0, 3.0) * scale, center + Vector2(22.0, -8.0) * scale, accent, maxf(1.0, 2.0 * scale), true)
		Config.UNIT_CLASS_ARCHER:
			# A bow-shaped arch and arrow tower distinguish the archer profile.
			draw_arc(center + Vector2(0.0, -13.0) * scale, 17.0 * scale, -PI * 0.78, PI * 0.78, 16, light, maxf(1.0, 2.5 * scale), true)
			draw_line(center + Vector2(-12.0, -22.0) * scale, center + Vector2(12.0, -22.0) * scale, accent, maxf(1.0, 2.0 * scale), true)
			draw_line(center + Vector2(0.0, -31.0) * scale, center + Vector2(0.0, -10.0) * scale, light, maxf(1.0, 2.0 * scale), true)
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0.0, -36.0) * scale,
				center + Vector2(-3.0, -30.0) * scale,
				center + Vector2(3.0, -30.0) * scale
			]), accent)

func _faction_building_color(owner: int, neutral_color: Color) -> Color:
	return _faction_color(owner, neutral_color)

func _faction_color(owner: int, neutral_color: Color) -> Color:
	if not Config.FACTION_COLORS.has(owner):
		return neutral_color
	return Color(str(Config.FACTION_COLORS[owner]))

func _draw_barracks_level_one(center: Vector2, scale: float, base: Color, dark: Color, light: Color, accent: Color) -> void:
	var body := Rect2(center + Vector2(-14.0, -6.0) * scale, Vector2(28.0, 19.0) * scale)
	draw_rect(Rect2(body.position + Vector2(0.0, 3.0 * scale), body.size), dark, true)
	draw_rect(body, base, true)
	draw_rect(Rect2(center + Vector2(-10.0, 0.0) * scale, Vector2(20.0, 3.0) * scale), light, true)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-17.0, -6.0) * scale,
		center + Vector2(17.0, -6.0) * scale,
		center + Vector2(0.0, -25.0) * scale
	]), light)
	draw_line(center + Vector2(-15.0, -5.0) * scale, center + Vector2(15.0, -5.0) * scale, accent, 2.0 * scale, true)
	draw_rect(Rect2(center + Vector2(-3.0, 5.0) * scale, Vector2(6.0, 8.0) * scale), accent.darkened(0.35), true)
	draw_rect(Rect2(center + Vector2(-9.0, -1.0) * scale, Vector2(4.0, 4.0) * scale), accent, true)
	draw_rect(Rect2(center + Vector2(5.0, -1.0) * scale, Vector2(4.0, 4.0) * scale), accent, true)

func _draw_barracks_level_two(center: Vector2, scale: float, base: Color, dark: Color, light: Color, accent: Color) -> void:
	var wall := Rect2(center + Vector2(-16.0, -7.0) * scale, Vector2(32.0, 21.0) * scale)
	draw_rect(Rect2(wall.position + Vector2(0.0, 3.0 * scale), wall.size), dark, true)
	draw_rect(wall, base, true)
	for tower_x in [-15.0, 7.0]:
		var tower := Rect2(center + Vector2(tower_x, -16.0) * scale, Vector2(8.0, 26.0) * scale)
		draw_rect(Rect2(tower.position + Vector2(0.0, 3.0 * scale), tower.size), dark, true)
		draw_rect(tower, light, true)
		draw_rect(Rect2(tower.position + Vector2(1.0, 2.0) * scale, Vector2(6.0, 3.0) * scale), accent, true)
		draw_rect(Rect2(tower.position + Vector2(1.0, 10.0) * scale, Vector2(6.0, 4.0) * scale), accent.darkened(0.25), true)
		_draw_battlement(center + Vector2(tower_x + 4.0, -17.0) * scale, scale, accent)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-17.0, -7.0) * scale,
		center + Vector2(17.0, -7.0) * scale,
		center + Vector2(0.0, -22.0) * scale
	]), light)
	draw_rect(Rect2(center + Vector2(-4.0, 5.0) * scale, Vector2(8.0, 9.0) * scale), accent.darkened(0.35), true)
	draw_line(center + Vector2(-13.0, -3.0) * scale, center + Vector2(13.0, -3.0) * scale, accent, 2.0 * scale, true)

func _draw_barracks_level_three(center: Vector2, scale: float, base: Color, dark: Color, light: Color, accent: Color) -> void:
	var wall := Rect2(center + Vector2(-19.0, -5.0) * scale, Vector2(38.0, 20.0) * scale)
	draw_rect(Rect2(wall.position + Vector2(0.0, 3.0 * scale), wall.size), dark, true)
	draw_rect(wall, base, true)
	for tower_x in [-19.0, 11.0]:
		var tower := Rect2(center + Vector2(tower_x, -19.0) * scale, Vector2(8.0, 29.0) * scale)
		draw_rect(Rect2(tower.position + Vector2(0.0, 3.0 * scale), tower.size), dark, true)
		draw_rect(tower, light, true)
		draw_rect(Rect2(tower.position + Vector2(1.0, 6.0) * scale, Vector2(6.0, 4.0) * scale), accent, true)
		_draw_battlement(center + Vector2(tower_x + 4.0, -20.0) * scale, scale, accent)
	var keep := Rect2(center + Vector2(-7.0, -28.0) * scale, Vector2(14.0, 35.0) * scale)
	draw_rect(Rect2(keep.position + Vector2(0.0, 3.0 * scale), keep.size), dark, true)
	draw_rect(keep, light, true)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-10.0, -28.0) * scale,
		center + Vector2(10.0, -28.0) * scale,
		center + Vector2(0.0, -42.0) * scale
	]), accent)
	draw_rect(Rect2(center + Vector2(-3.0, -1.0) * scale, Vector2(6.0, 8.0) * scale), accent.darkened(0.40), true)
	draw_rect(Rect2(center + Vector2(-4.0, -19.0) * scale, Vector2(8.0, 5.0) * scale), accent, true)
	_draw_flag(center + Vector2(0.0, -47.0) * scale, scale, accent)

func _draw_barracks_level_four(center: Vector2, scale: float, base: Color, dark: Color, light: Color, accent: Color) -> void:
	var foundation := Rect2(center + Vector2(-22.0, -2.0) * scale, Vector2(44.0, 18.0) * scale)
	draw_rect(Rect2(foundation.position + Vector2(0.0, 4.0 * scale), foundation.size), dark, true)
	draw_rect(foundation, base, true)
	draw_rect(Rect2(center + Vector2(-19.0, -5.0) * scale, Vector2(38.0, 5.0) * scale), accent.darkened(0.15), true)
	for tower_x in [-21.0, 13.0]:
		var tower := Rect2(center + Vector2(tower_x, -25.0) * scale, Vector2(8.0, 36.0) * scale)
		draw_rect(Rect2(tower.position + Vector2(0.0, 4.0 * scale), tower.size), dark, true)
		draw_rect(tower, light, true)
		draw_rect(Rect2(tower.position + Vector2(1.0, 7.0) * scale, Vector2(6.0, 4.0) * scale), accent, true)
		draw_rect(Rect2(tower.position + Vector2(1.0, 17.0) * scale, Vector2(6.0, 4.0) * scale), accent, true)
		_draw_battlement(center + Vector2(tower_x + 4.0, -26.0) * scale, scale, accent)
	var keep := Rect2(center + Vector2(-9.0, -34.0) * scale, Vector2(18.0, 43.0) * scale)
	draw_rect(Rect2(keep.position + Vector2(0.0, 4.0 * scale), keep.size), dark, true)
	draw_rect(keep, light, true)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-13.0, -34.0) * scale,
		center + Vector2(13.0, -34.0) * scale,
		center + Vector2(0.0, -51.0) * scale
	]), accent)
	draw_rect(Rect2(center + Vector2(-4.0, -3.0) * scale, Vector2(8.0, 12.0) * scale), accent.darkened(0.45), true)
	draw_rect(Rect2(center + Vector2(-5.0, -25.0) * scale, Vector2(10.0, 5.0) * scale), accent, true)
	_draw_flag(center + Vector2(0.0, -58.0) * scale, scale, accent)
	draw_line(center + Vector2(-16.0, -1.0) * scale, center + Vector2(16.0, -1.0) * scale, Color(accent, 0.78), 2.0 * scale, true)

func _draw_battlement(center: Vector2, scale: float, color: Color) -> void:
	draw_rect(Rect2(center + Vector2(-5.0, -2.0) * scale, Vector2(10.0, 4.0) * scale), color, true)
	for offset_x in [-4.0, 0.0, 4.0]:
		draw_rect(Rect2(center + Vector2(offset_x - 1.0, -5.0) * scale, Vector2(2.0, 4.0) * scale), color, true)

func _draw_flag(base: Vector2, scale: float, color: Color) -> void:
	draw_line(base, base + Vector2(0.0, 14.0) * scale, Color("#e2e8f0"), maxf(1.0, 1.5 * scale), true)
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(0.0, 1.0) * scale,
		base + Vector2(10.0, 4.0) * scale,
		base + Vector2(0.0, 8.0) * scale
	]), color)

func _hex_points(center: Vector2, size: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in range(6):
		var angle := deg_to_rad(60.0 * i - 30.0)
		result.append(center + Vector2(cos(angle), sin(angle)) * size)
	return result
