class_name HexBoard
extends Node2D

const Config := preload("res://game_config.gd")

signal tile_clicked(cell: Vector2i)
signal tile_dragged(from_cell: Vector2i, to_cell: Vector2i)
signal tile_drag_started(cell: Vector2i)
signal tile_reveal_midpoint(cell: Vector2i)
signal tile_reveal_finished(cell: Vector2i)
signal intelligence_building_drop_finished(cell: Vector2i)

const UNKNOWN := 0
const PLAYER := 1
const AI := 2
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

var radius := Config.BOARD_RADIUS
var tile_size := 50.0
var board_origin := Vector2(640.0, 430.0)
var tiles: Dictionary = {}
var draw_cells: Array[Vector2i] = []
var wild_monster_cells: Array[Vector2i] = []
var map_min_world := Vector2.ZERO
var map_max_world := Vector2.ZERO
var buildable_cells: Array[Vector2i] = []
var mergeable_cells: Array[Vector2i] = []
var merge_effect_cells: Array[Vector2i] = []
var purchasable_cells: Array[Vector2i] = []
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
var bombardment_cells: Array[Vector2i] = []
var bombardment_warning_cells: Array[Vector2i] = []
var bombardment_warning_elapsed := 0.0
var mergeable_effect_elapsed := 0.0
var merge_effect_refresh_timer := 0.0
var card_land_loss_cell := Vector2i(999, 999)
var card_land_loss_elapsed := 0.0
var camera_focus_tween: Tween
@onready var camera: Camera2D = get_parent().get_node_or_null("Camera2D")

func _ready() -> void:
	_build_map()
	_clamp_camera_position()
	queue_redraw()

func _build_map() -> void:
	tiles.clear()
	draw_cells.clear()
	wild_monster_cells.clear()
	_prepare_wild_monster_cells()
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			if abs(q + r) <= radius:
				var cell := Vector2i(q, r)
				tiles[cell] = {
					"tile_type": _roll_tile_type(cell),
					"unit_class": -1,
					"owner": UNKNOWN,
					"revealed": false,
					"building": EMPTY,
					"building_level": 0,
					"building_hp": 0.0,
					"building_max_hp": 0.0,
					"production_count": 0,
					"build_timer": 0.0,
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

	# Only the HQs are owned at the start; their six neighbors are the initial purchase frontier.
	set_tile_owner(PLAYER_HQ, PLAYER, true)
	set_tile_owner(AI_HQ, AI, true)
	draw_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return axial_to_world(a).y < axial_to_world(b).y
	)
	_recalculate_map_bounds()

func _prepare_wild_monster_cells() -> void:
	var candidates: Array[Vector2i] = []
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			if abs(q + r) > radius:
				continue
			var cell := Vector2i(q, r)
			if cell == PLAYER_HQ or cell == AI_HQ:
				continue
			if cube_distance(cell, PLAYER_HQ) < Config.VISIBLE_TILE_MIN_DISTANCE:
				continue
			candidates.append(cell)
	var target_count := randi_range(Config.WILD_MONSTER_MIN_COUNT, Config.WILD_MONSTER_MAX_COUNT)
	target_count = mini(target_count, candidates.size())
	while wild_monster_cells.size() < target_count and not candidates.is_empty():
		var candidate_index := randi_range(0, candidates.size() - 1)
		wild_monster_cells.append(candidates[candidate_index])
		candidates.remove_at(candidate_index)

func _roll_tile_type(cell: Vector2i) -> int:
	if wild_monster_cells.has(cell):
		return Config.WILD_MONSTER_TILE_TYPE
	var roll := randf()
	var visible_allowed := cube_distance(cell, PLAYER_HQ) >= Config.VISIBLE_TILE_MIN_DISTANCE
	if not visible_allowed:
		# Near the player's base, redistribute visible-tile probability across
		# the regular hidden/fate pool so the configured weights remain valid.
		var hidden_weight := Config.RANDOM_TILE_TYPE_WEIGHT + Config.FATE_TILE_TYPE_WEIGHT
		roll *= hidden_weight
		if roll < Config.RANDOM_TILE_TYPE_WEIGHT:
			return Config.RANDOM_TILE_TYPE
		return Config.FATE_TILE_TYPE

	# Wild monster positions are reserved once per map. Normalize the remaining
	# visible-tile weights so no additional monster can be rolled here.
	var visible_weight := Config.RANDOM_TILE_TYPE_WEIGHT + Config.FATE_TILE_TYPE_WEIGHT + Config.BARRACKS_2_TILE_TYPE_WEIGHT + Config.MINE_TILE_TYPE_WEIGHT + Config.MERCHANT_TILE_TYPE_WEIGHT
	roll *= visible_weight
	if roll < Config.RANDOM_TILE_TYPE_WEIGHT:
		return Config.RANDOM_TILE_TYPE
	if roll < Config.RANDOM_TILE_TYPE_WEIGHT + Config.FATE_TILE_TYPE_WEIGHT:
		return Config.FATE_TILE_TYPE
	if roll < Config.RANDOM_TILE_TYPE_WEIGHT + Config.FATE_TILE_TYPE_WEIGHT + Config.BARRACKS_2_TILE_TYPE_WEIGHT:
		return Config.BARRACKS_2_TILE_TYPE
	if roll < Config.RANDOM_TILE_TYPE_WEIGHT + Config.FATE_TILE_TYPE_WEIGHT + Config.BARRACKS_2_TILE_TYPE_WEIGHT + Config.MINE_TILE_TYPE_WEIGHT:
		return Config.MINE_TILE_TYPE
	return Config.MERCHANT_TILE_TYPE

func reset() -> void:
	_build_map()
	reveal_animations.clear()
	barracks_merge_animations.clear()
	intelligence_building_drop_animations.clear()
	buildable_cells.clear()
	mergeable_cells.clear()
	merge_effect_cells.clear()
	purchasable_cells.clear()
	bombardment_cells.clear()
	bombardment_warning_cells.clear()
	bombardment_warning_elapsed = 0.0
	mergeable_effect_elapsed = 0.0
	merge_effect_refresh_timer = 0.0
	clear_card_land_loss_cell()
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
	if bool(tile.get("intelligence_free_claim", false)):
		return 0
	match int(tile.get("tile_type", Config.RANDOM_TILE_TYPE)):
		Config.FATE_TILE_TYPE:
			return Config.FATE_TILE_COST
		Config.MINE_TILE_TYPE:
			return Config.MINE_TILE_COST
		Config.BARRACKS_2_TILE_TYPE, Config.WILD_MONSTER_TILE_TYPE, Config.MERCHANT_TILE_TYPE:
			return Config.VISIBLE_TILE_COST
	return Config.RANDOM_TILE_COST

func set_tile_owner(cell: Vector2i, owner: int, revealed := true) -> void:
	if not tiles.has(cell):
		return
	tiles[cell]["owner"] = owner
	tiles[cell]["revealed"] = revealed

func set_building(cell: Vector2i, building: int, level: int = 1, unit_class: int = -1, revealed: bool = true) -> void:
	if tiles.has(cell):
		tiles[cell]["building"] = building
		# A normal placement or merge-consumed slot is no longer a destroyed-building slot.
		tiles[cell]["rebuildable"] = false
		tiles[cell]["building_level"] = clampi(level, 1, 4) if building == BARRACKS else 0
		if building == BARRACKS:
			tiles[cell]["unit_class"] = clampi(unit_class, 0, Config.UNIT_CLASS_COUNT - 1)
			tiles[cell]["building_max_hp"] = Config.BARRACKS_BASE_HP * float(int(tiles[cell]["building_level"]))
			tiles[cell]["building_hp"] = tiles[cell]["building_max_hp"]
		elif building == MINE or building == TOWER:
			tiles[cell]["building_max_hp"] = Config.MINE_MAX_HP if building == MINE else Config.TOWER_MAX_HP
			tiles[cell]["building_hp"] = tiles[cell]["building_max_hp"]
		elif building == STEEL_BARRIER:
			tiles[cell]["unit_class"] = -1
			tiles[cell]["building_max_hp"] = Config.STEEL_BARRIER_MAX_HP
			tiles[cell]["building_hp"] = tiles[cell]["building_max_hp"]
		else:
			tiles[cell]["unit_class"] = -1
			tiles[cell]["building_max_hp"] = 0.0
			tiles[cell]["building_hp"] = 0.0
		tiles[cell]["revealed"] = revealed
		if building != BARRACKS:
			tiles[cell]["production_count"] = 0
			tiles[cell]["build_timer"] = 0.0
		if building != MERCHANT:
			tiles[cell]["merchant_active"] = false
			tiles[cell]["merchant_stock"] = []

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
	queue_redraw()

func clear_buildable_cells() -> void:
	buildable_cells.clear()
	queue_redraw()

func set_mergeable_cells(cells: Array[Vector2i]) -> void:
	mergeable_cells = cells.duplicate()
	queue_redraw()

func clear_mergeable_cells() -> void:
	mergeable_cells.clear()
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
		queue_redraw()

func set_barracks_range_cell(cell: Vector2i) -> void:
	barracks_range_cell = cell
	queue_redraw()

func clear_barracks_range_cell() -> void:
	barracks_range_cell = Vector2i(999, 999)
	queue_redraw()

func set_purchasable_cells(cells: Array[Vector2i]) -> void:
	purchasable_cells = cells.duplicate()
	queue_redraw()

func set_player_gold(value: float) -> void:
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

func update_build_timer(cell: Vector2i, value: float) -> void:
	if tiles.has(cell):
		tiles[cell]["build_timer"] = value

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
	_process_reveal_animations(delta)
	_process_barracks_merge_animations(delta)
	_process_intelligence_building_drop_animations(delta)
	merge_effect_refresh_timer -= delta
	if merge_effect_refresh_timer <= 0.0:
		_refresh_merge_effect_cells()
		merge_effect_refresh_timer = 0.2
	if not merge_effect_cells.is_empty():
		mergeable_effect_elapsed += delta
		queue_redraw()
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
	var player_hq_position := axial_to_world(Config.PLAYER_HQ).x
	var ai_hq_position := axial_to_world(Config.AI_HQ).x
	var camera_min_x := minf(min_world.x + half_view.x, player_hq_position)
	var camera_max_x := maxf(max_world.x - half_view.x, ai_hq_position)
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
	# Draw rear rows first so the extruded lower edge sits behind the next row.
	for cell in draw_cells:
		_draw_tile(cell)
	# The dragged barracks must be drawn after every tile. Drawing it from
	# _draw_tile() lets a later tile row cover the preview while it is moving.
	if long_press_active and tiles.has(drag_start_cell):
		_draw_drag_source_preview(drag_start_cell)

func _draw_tile(cell: Vector2i) -> void:
	var tile: Dictionary = tiles[cell]
	var center := axial_to_world(cell)
	var reveal_active := reveal_animations.has(cell)
	if reveal_active:
		var reveal_state: Dictionary = reveal_animations[cell]
		var reveal_progress := clampf(float(reveal_state["elapsed"]) / Config.TILE_REVEAL_DURATION, 0.0, 1.0)
		var jump_offset := sin(reveal_progress * PI) * Config.TILE_REVEAL_JUMP_HEIGHT
		var flip_scale := maxf(abs(cos(reveal_progress * PI)), Config.TILE_REVEAL_MIN_SCALE_X)
		# Transform absolute world coordinates around this tile's center.
		draw_set_transform(Vector2(center.x * (1.0 - flip_scale), -jump_offset), 0.0, Vector2(flip_scale, 1.0))
	var points := _hex_points(center, tile_size - 2.0)
	var owner: int = int(tile["owner"])
	var revealed: bool = bool(tile["revealed"])
	var tile_type: int = int(tile["tile_type"])
	var fill := Color("#1c2537")
	var outline := Color("#3d4d67")
	if not revealed:
		# Visible tiles keep the same neutral base as every other unopened tile;
		# their landmark alone communicates the revealed tile type.
		fill = Color("#111827")
		outline = Color("#475569")
	elif owner == PLAYER:
		fill = Color("#164e63")
		outline = Color("#38bdf8")
	elif owner == AI:
		fill = Color("#5f263b")
		outline = Color("#fb7185")
	else:
		fill = Color("#293447")
		outline = Color("#64748b")
	if cell in buildable_cells:
		outline = Color("#4ade80")
	if cell in mergeable_cells:
		outline = Color("#c084fc")
	# Layered polygons give each tile a small downward extrusion and shadow.
	var bottom_points := _offset_points(points, Vector2(0.0, Config.TILE_EXTRUSION_DEPTH))
	var shadow_points := _offset_points(bottom_points, Vector2(0.0, Config.TILE_SHADOW_OFFSET_Y))
	draw_colored_polygon(shadow_points, Color(0.0, 0.0, 0.0, Config.TILE_SHADOW_ALPHA))
	draw_colored_polygon(bottom_points, fill.darkened(0.32))
	_draw_tile_sides(points, bottom_points, fill)
	draw_colored_polygon(points, fill)
	if cell in bombardment_cells:
		draw_colored_polygon(points, Color(0.92, 0.08, 0.08, 0.18))
		draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[4], points[5], points[0]]), Color(1.0, 0.25, 0.18, 0.78), 2.0, true)
	if cell in bombardment_warning_cells:
		var warning_pulse := 0.5 + 0.5 * sin(bombardment_warning_elapsed * 10.0)
		draw_colored_polygon(points, Color(1.0, 0.04, 0.04, 0.10 + warning_pulse * 0.20))
		draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[4], points[5], points[0]]), Color(1.0, 0.12, 0.08, 0.45 + warning_pulse * 0.50), 3.0, true)
	if cell == card_land_loss_cell:
		var loss_pulse := 0.5 + 0.5 * sin(card_land_loss_elapsed * 16.0)
		draw_colored_polygon(points, Color(1.0, 0.03, 0.03, 0.18 + loss_pulse * 0.22))
		draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[4], points[5], points[0]]), Color(1.0, 0.08, 0.04, 0.70 + loss_pulse * 0.25), 3.0, true)
	var inner_points := _hex_points(center + Vector2(0.0, -1.0), tile_size - 7.0)
	draw_colored_polygon(inner_points, Color(1.0, 1.0, 1.0, Config.TILE_TOP_HIGHLIGHT_ALPHA))
	if cell in mergeable_cells:
		draw_colored_polygon(points, Color(0.75, 0.45, 1.0, 0.18))
	if _is_in_barracks_range(cell):
		draw_colored_polygon(points, Color(0.96, 0.82, 0.28, 0.10))
	var outline_points := PackedVector2Array(points)
	outline_points.append(points[0])
	draw_polyline(outline_points, outline, 2.0, true)

	if not revealed:
		if int(tile["building"]) != EMPTY:
			var landmark_center := center
			if is_intelligence_building_drop_active(cell):
				landmark_center += get_intelligence_building_drop_offset(cell)
			_draw_hidden_building_landmark(landmark_center, int(tile["building"]), int(tile["building_level"]), int(tile["unit_class"]))
		elif _is_visible_tile_type(tile_type):
			_draw_visible_landmark(tile_type, center, not reveal_active)
		if cell in purchasable_cells:
			var tile_cost := get_tile_cost(cell)
			var price_color := Color("#f87171") if player_gold < tile_cost else Color("#ffffff")
			_draw_pickaxe_icon(center + Vector2(0.0, -14.0))
			draw_string(ThemeDB.fallback_font, center + Vector2(-4, 16), str(tile_cost), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, price_color)
	else:
		if not (cell == drag_start_cell and long_press_active):
			var building_center := center
			if int(tile["building"]) == BARRACKS:
				building_center += get_barracks_merge_offset(cell)
			_draw_building(cell, building_center, int(tile["building"]), int(tile["building_level"]), int(tile["unit_class"]))
			var ground_item_id := str(tile.get("ground_item_id", ""))
			if not ground_item_id.is_empty():
				_draw_ground_item_icon(center + Vector2(0.0, -24.0), ground_item_id)
			if bool(tile.get("chest_reward", false)):
				draw_string(ThemeDB.fallback_font, center + Vector2(-13, -25), "宝箱", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#fbbf24"))

	if reveal_active:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _offset_points(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(point + offset)
	return result

func _draw_tile_sides(top_points: PackedVector2Array, bottom_points: PackedVector2Array, fill: Color) -> void:
	# Only the three downward-facing edges are visible in this top-down view.
	for raw_index in [1, 2, 3]:
		var index: int = int(raw_index)
		var next_index: int = (index + 1) % top_points.size()
		var side_points := PackedVector2Array([
			top_points[index],
			top_points[next_index],
			bottom_points[next_index],
			bottom_points[index]
		])
		var side_color := fill.darkened(0.23 + 0.07 * float(index - 1))
		draw_colored_polygon(side_points, side_color)
		if index == 2:
			draw_line(top_points[index], top_points[next_index], Color(1.0, 1.0, 1.0, Config.TILE_SIDE_HIGHLIGHT_ALPHA), 1.0, true)

func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(16):
		var angle := TAU * float(index) / 16.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)

func _is_visible_tile_type(tile_type: int) -> bool:
	return tile_type == FATE or tile_type == WILD_MONSTER or tile_type == BARRACKS_2 or tile_type == MINE_TILE or tile_type == Config.MERCHANT_TILE_TYPE

func _draw_visible_landmark(tile_type: int, center: Vector2, use_local_transform := true) -> void:
	var landmark_origin := center + Config.VISIBLE_LANDMARK_OFFSET
	var landmark_center := landmark_origin
	if use_local_transform:
		draw_set_transform(landmark_origin, 0.0, Vector2(Config.VISIBLE_LANDMARK_SCALE, Config.VISIBLE_LANDMARK_SCALE))
		landmark_center = Vector2.ZERO
	match tile_type:
		FATE:
			_draw_fate_card_landmark(landmark_center)
		WILD_MONSTER:
			_draw_wild_landmark(landmark_center)
		BARRACKS_2:
			_draw_level_two_city_landmark(landmark_center)
		MINE_TILE:
			_draw_mine_landmark(landmark_center)
		Config.MERCHANT_TILE_TYPE:
			_draw_merchant_landmark(landmark_center)
	if use_local_transform:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_hidden_building_landmark(center: Vector2, building: int, level: int, unit_class: int) -> void:
	var landmark_origin := center + Config.VISIBLE_LANDMARK_OFFSET
	draw_set_transform(landmark_origin, 0.0, Vector2(Config.VISIBLE_LANDMARK_SCALE, Config.VISIBLE_LANDMARK_SCALE))
	match building:
		MINE:
			_draw_mine_landmark(Vector2.ZERO)
		BARRACKS:
			_draw_barracks_model(Vector2.ZERO, level, unit_class, false, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_wild_landmark(center: Vector2) -> void:
	var body := Color(Config.VISIBLE_LANDMARK_COLOR)
	var dark := Color(Config.VISIBLE_LANDMARK_DARK_COLOR)
	draw_circle(center + Vector2(0, 13), 13.0, Color(0.0, 0.0, 0.0, 0.25))
	draw_circle(center + Vector2(0, 4), 12.0, dark)
	draw_circle(center + Vector2(0, -8), 10.0, body)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-9, -13), center + Vector2(-14, -22), center + Vector2(-3, -17)]), dark)
	draw_colored_polygon(PackedVector2Array([center + Vector2(9, -13), center + Vector2(14, -22), center + Vector2(3, -17)]), dark)
	draw_circle(center + Vector2(-4, -9), 2.2, Color("#1f2937"))
	draw_circle(center + Vector2(4, -9), 2.2, Color("#1f2937"))
	draw_circle(center + Vector2(-3.5, -9.5), 0.8, Color("#f8fafc"))
	draw_circle(center + Vector2(4.5, -9.5), 0.8, Color("#f8fafc"))
	draw_line(center + Vector2(-5, 1), center + Vector2(5, 1), Color("#374151"), 2.0, true)

func _draw_fate_card_landmark(center: Vector2) -> void:
	var card_center := center + Vector2(0, 2)
	draw_rect(Rect2(card_center + Vector2(-13, -16) + Vector2(3, 5), Vector2(26, 32)), Color(0.0, 0.0, 0.0, 0.28), true)
	var card_points := PackedVector2Array([card_center + Vector2(-13, -16), card_center + Vector2(8, -16), card_center + Vector2(13, -11), card_center + Vector2(13, 16), card_center + Vector2(-13, 16)])
	draw_colored_polygon(card_points, Color("#f8fafc"))
	draw_polyline(PackedVector2Array([card_points[0], card_points[1], card_points[2], card_points[3], card_points[4], card_points[0]]), Color("#f59e0b"), 2.0, true)
	draw_colored_polygon(PackedVector2Array([card_center + Vector2(8, -16), card_center + Vector2(8, -11), card_center + Vector2(13, -11)]), Color("#cbd5e1"))
	draw_circle(card_center, 6.0, Color("#fbbf24"))
	draw_string(ThemeDB.fallback_font, card_center + Vector2(-4, 4), "命", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#7c2d12"))

func _draw_level_two_city_landmark(center: Vector2) -> void:
	var body := Color(Config.VISIBLE_LANDMARK_COLOR)
	var dark := Color(Config.VISIBLE_LANDMARK_DARK_COLOR)
	_draw_ellipse(center + Vector2(0, 14), Vector2(19, 5), Color(0.0, 0.0, 0.0, 0.25))
	draw_rect(Rect2(center + Vector2(-15, -4), Vector2(30, 20)), dark, true)
	draw_rect(Rect2(center + Vector2(-11, -12), Vector2(8, 28)), body, true)
	draw_rect(Rect2(center + Vector2(3, -12), Vector2(8, 28)), body, true)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-15, -13), center + Vector2(-7, -21), center + Vector2(-3, -13)]), body.lightened(0.12))
	draw_colored_polygon(PackedVector2Array([center + Vector2(3, -13), center + Vector2(7, -21), center + Vector2(11, -13)]), body.lightened(0.12))
	draw_rect(Rect2(center + Vector2(-3, 8), Vector2(6, 8)), Color("#374151"), true)
	draw_string(ThemeDB.fallback_font, center + Vector2(-4, 5), "2", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#1f2937"))

func _draw_mine_landmark(center: Vector2) -> void:
	var body := Color(Config.VISIBLE_LANDMARK_COLOR)
	var dark := Color(Config.VISIBLE_LANDMARK_DARK_COLOR)
	_draw_ellipse(center + Vector2(0, 14), Vector2(19, 5), Color(0.0, 0.0, 0.0, 0.25))
	# Use simple triangles so the renderer never has to triangulate a concave
	# polygon for the two mountain peaks.
	draw_colored_polygon(PackedVector2Array([center + Vector2(-18, 10), center + Vector2(-8, -9), center + Vector2(0, 7)]), dark)
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, 7), center + Vector2(8, -17), center + Vector2(18, 10)]), dark)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-8, -9), center + Vector2(8, -17), center + Vector2(3, 8)]), body)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-4, 7), center + Vector2(0, -5), center + Vector2(5, 8)]), Color("#e5e7eb"))

func _draw_merchant_landmark(center: Vector2) -> void:
	var cloak := Color("#8b5cf6")
	var trim := Color("#fbbf24")
	_draw_ellipse(center + Vector2(0.0, 14.0), Vector2(19.0, 5.0), Color(0.0, 0.0, 0.0, 0.25))
	draw_circle(center + Vector2(0.0, -7.0), 8.0, Color("#f3c6a5"))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-13.0, 14.0), center + Vector2(-9.0, -2.0),
		center + Vector2(9.0, -2.0), center + Vector2(13.0, 14.0)
	]), cloak)
	draw_line(center + Vector2(-10.0, 2.0), center + Vector2(10.0, 2.0), trim, 3.0, true)
	draw_circle(center + Vector2(-3.0, -8.0), 1.4, Color("#172033"))
	draw_circle(center + Vector2(3.0, -8.0), 1.4, Color("#172033"))
	draw_line(center + Vector2(-3.0, -3.0), center + Vector2(3.0, -3.0), Color("#7c2d12"), 1.5, true)
	draw_line(center + Vector2(12.0, 2.0), center + Vector2(18.0, -11.0), trim, 2.5, true)
	draw_circle(center + Vector2(18.0, -11.0), 3.5, Color("#f59e0b"))

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

func _draw_pickaxe_icon(center: Vector2) -> void:
	var handle_color := Color("#d6a85c")
	var head_color := Color("#e2e8f0")
	draw_line(center + Vector2(-8, 9), center + Vector2(6, -7), handle_color, 3.0, true)
	draw_line(center + Vector2(3, -10), center + Vector2(14, -5), head_color, 4.0, true)
	draw_line(center + Vector2(3, -10), center + Vector2(7, -1), head_color, 4.0, true)
	draw_circle(center + Vector2(-8, 9), 2.0, Color("#a16207"))

func _is_in_barracks_range(cell: Vector2i) -> bool:
	if not tiles.has(barracks_range_cell) or cell == barracks_range_cell:
		return false
	return cube_distance(cell, barracks_range_cell) <= Config.BARRACKS_DETECTION_RANGE

func _draw_drag_source_preview(cell: Vector2i) -> void:
	var tile: Dictionary = tiles[cell]
	var preview_position := drag_preview_world + Vector2(0.0, -18.0)
	draw_line(axial_to_world(cell), preview_position, Color(0.94, 0.82, 0.35, 0.42), 2.0, true)
	draw_circle(preview_position + Vector2(0.0, 15.0), 22.0, Color(0.0, 0.0, 0.0, 0.28))
	_draw_building(cell, preview_position, int(tile["building"]), int(tile["building_level"]), int(tile["unit_class"]))

func _draw_building(cell: Vector2i, center: Vector2, building: int, level: int, unit_class: int = -1) -> void:
	if cell == PLAYER_HQ or cell == AI_HQ:
		var hq_color := Color("#38bdf8") if cell.x < 0 else Color("#fb7185")
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
			var mine_color := _faction_building_color(int(tiles.get(cell, {}).get("owner", UNKNOWN)), Color("#f59e0b"))
			draw_circle(center, 14.0, mine_color)
			draw_circle(center, 7.0, mine_color.lightened(0.28))
			draw_string(ThemeDB.fallback_font, center + Vector2(-5, 4), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, mine_color.darkened(0.45))
		BARRACKS:
			_draw_barracks_model(center, level, unit_class, cell in merge_effect_cells, false, int(tiles.get(cell, {}).get("owner", UNKNOWN)))
		TOWER:
			var tower_color := _faction_building_color(int(tiles.get(cell, {}).get("owner", UNKNOWN)), Color("#94a3b8"))
			draw_circle(center, 14.0, tower_color)
			draw_line(center + Vector2(-4, -4), center + Vector2(13, -18), tower_color.lightened(0.28), 4.0)
		MERCHANT:
			_draw_merchant_landmark(center)
		STEEL_BARRIER:
			_draw_steel_barrier(center, _faction_building_color(int(tiles.get(cell, {}).get("owner", UNKNOWN)), Color("#94a3b8")))

func _draw_steel_barrier(center: Vector2, color: Color) -> void:
	var dark := color.darkened(0.45)
	var light := color.lightened(0.28)
	_draw_ellipse(center + Vector2(0.0, 13.0), Vector2(21.0, 5.0), Color(0.0, 0.0, 0.0, 0.30))
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
	var level_badge_center := model_center + Vector2(18.0, -31.0) * scale
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
	if owner == PLAYER:
		return Color("#38bdf8")
	if owner == AI:
		return Color("#ef4444")
	return neutral_color

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
