class_name HexBoard
extends Node2D

const Config := preload("res://game_config.gd")

signal tile_clicked(cell: Vector2i)
signal tile_dragged(from_cell: Vector2i, to_cell: Vector2i)
signal tile_drag_started(cell: Vector2i)

const UNKNOWN := 0
const PLAYER := 1
const AI := 2
const EMPTY := 0
const MINE := 1
const BARRACKS := 2
const TOWER := 3
const LONG_PRESS_DURATION := 0.35
const CAMERA_PAN_THRESHOLD := 8.0
const DIRECTIONS := [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]
const PLAYER_HQ := Config.PLAYER_HQ
const AI_HQ := Config.AI_HQ

var radius := Config.BOARD_RADIUS
var tile_size := 50.0
var board_origin := Vector2(640.0, 430.0)
var tiles: Dictionary = {}
var hover_cell := Vector2i(999, 999)
var selected_cell := Vector2i(999, 999)
var buildable_cells: Array[Vector2i] = []
var mergeable_cells: Array[Vector2i] = []
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
@onready var camera: Camera2D = get_parent().get_node_or_null("Camera2D")

func _ready() -> void:
	_build_map()
	_clamp_camera_position()
	queue_redraw()

func _build_map() -> void:
	tiles.clear()
	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			if abs(q + r) <= radius:
				var cell := Vector2i(q, r)
				tiles[cell] = {
					"tile_type": _roll_tile_type(),
					"unit_class": -1,
					"owner": UNKNOWN,
					"revealed": false,
					"building": EMPTY,
					"building_level": 0,
					"building_hp": 0.0,
					"building_max_hp": 0.0,
					"production_count": 0,
					"build_timer": 0.0,
					"rebuildable": false
				}

	# Only the HQs are owned at the start; their six neighbors are the initial purchase frontier.
	set_tile_owner(PLAYER_HQ, PLAYER, true)
	set_tile_owner(AI_HQ, AI, true)

func _roll_tile_type() -> int:
	var roll := randf()
	if roll < Config.RANDOM_TILE_TYPE_WEIGHT:
		return Config.RANDOM_TILE_TYPE
	if roll < Config.RANDOM_TILE_TYPE_WEIGHT + Config.BARRACKS_10_TILE_TYPE_WEIGHT:
		return Config.BARRACKS_10_TILE_TYPE
	return Config.BARRACKS_50_TILE_TYPE

func reset() -> void:
	_build_map()
	hover_cell = Vector2i(999, 999)
	selected_cell = Vector2i(999, 999)
	buildable_cells.clear()
	mergeable_cells.clear()
	purchasable_cells.clear()
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

func get_building_unit_class(cell: Vector2i) -> int:
	return int(tiles.get(cell, {}).get("unit_class", -1))

func get_tile_cost(cell: Vector2i) -> int:
	var tile: Dictionary = tiles.get(cell, {})
	match int(tile.get("tile_type", Config.RANDOM_TILE_TYPE)):
		Config.BARRACKS_10_TILE_TYPE:
			return Config.BARRACKS_10_TILE_COST
		Config.BARRACKS_50_TILE_TYPE:
			return Config.BARRACKS_50_TILE_COST
	return Config.RANDOM_TILE_COST

func set_tile_owner(cell: Vector2i, owner: int, revealed := true) -> void:
	if not tiles.has(cell):
		return
	tiles[cell]["owner"] = owner
	tiles[cell]["revealed"] = revealed

func set_building(cell: Vector2i, building: int, level: int = 1, unit_class: int = -1) -> void:
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
		else:
			tiles[cell]["unit_class"] = -1
			tiles[cell]["building_max_hp"] = 0.0
			tiles[cell]["building_hp"] = 0.0
		tiles[cell]["revealed"] = true
		if building != BARRACKS:
			tiles[cell]["production_count"] = 0
			tiles[cell]["build_timer"] = 0.0

func destroy_building(cell: Vector2i) -> bool:
	if not tiles.has(cell):
		return false
	var building := int(tiles[cell]["building"])
	if building == EMPTY:
		return false
	set_building(cell, EMPTY)
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
			camera_drag_active = true
			drag_active = false
			long_press_timer = 0.0
			drag_start_cell = Vector2i(999, 999)
		if camera_drag_active and camera != null:
			camera.position -= event.relative / camera.zoom.x
			_clamp_camera_position()
		drag_preview_world = _mouse_world_position()
		var candidate := world_to_axial(_mouse_world_position())
		hover_cell = candidate if tiles.has(candidate) else Vector2i(999, 999)
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
				selected_cell = candidate
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
	if not drag_active or long_press_active:
		return
	long_press_timer += delta
	if long_press_timer < LONG_PRESS_DURATION or not _can_start_merge_drag(drag_start_cell):
		return
	long_press_active = true
	drag_preview_world = _mouse_world_position()
	tile_drag_started.emit(drag_start_cell)
	queue_redraw()

func _can_start_merge_drag(cell: Vector2i) -> bool:
	if not tiles.has(cell):
		return false
	var tile: Dictionary = tiles[cell]
	if not bool(tile["revealed"]) or int(tile["owner"]) != PLAYER or int(tile["building"]) != BARRACKS:
		return false
	var main_ref := get_parent()
	if main_ref == null or not main_ref.has_method("get_merge_targets"):
		return false
	var targets: Array[Vector2i] = main_ref.get_merge_targets(cell, PLAYER)
	return not targets.is_empty()

func reset_camera() -> void:
	if camera == null:
		return
	camera.position = axial_to_world(Config.PLAYER_HQ)
	camera.zoom = Vector2(Config.INITIAL_CAMERA_ZOOM, Config.INITIAL_CAMERA_ZOOM)
	camera_drag_active = false
	_clamp_camera_position()

func focus_camera_on_cell(cell: Vector2i) -> void:
	if camera == null or not tiles.has(cell):
		return
	camera.position = axial_to_world(cell)
	_clamp_camera_position()

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
	var min_world := Vector2(INF, INF)
	var max_world := Vector2(-INF, -INF)
	for cell in tiles:
		var center := axial_to_world(cell)
		min_world.x = minf(min_world.x, center.x)
		min_world.y = minf(min_world.y, center.y)
		max_world.x = maxf(max_world.x, center.x)
		max_world.y = maxf(max_world.y, center.y)
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

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_clamp_camera_position()

func _draw() -> void:
	for cell in tiles:
		_draw_tile(cell)
	_draw_legend()

func _draw_tile(cell: Vector2i) -> void:
	var tile: Dictionary = tiles[cell]
	var center := axial_to_world(cell)
	var points := _hex_points(center, tile_size - 2.0)
	var owner: int = int(tile["owner"])
	var revealed: bool = bool(tile["revealed"])
	var fill := Color("#1c2537")
	var outline := Color("#3d4d67")
	if not revealed:
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
	if cell == hover_cell and not revealed:
		fill = Color("#334155")
		outline = Color("#facc15")
	if cell in buildable_cells:
		outline = Color("#4ade80")
	if cell in mergeable_cells:
		outline = Color("#c084fc")
	if cell in purchasable_cells:
		outline = Color("#f59e0b")
	if cell == selected_cell:
		outline = Color("#fbbf24")
		draw_circle(center, tile_size * 0.74, Color(1.0, 0.75, 0.2, 0.08))
	draw_colored_polygon(points, fill)
	if cell in mergeable_cells:
		draw_colored_polygon(points, Color(0.75, 0.45, 1.0, 0.18))
	if _is_in_barracks_range(cell):
		draw_colored_polygon(points, Color(0.96, 0.82, 0.28, 0.10))
	var outline_points := PackedVector2Array(points)
	outline_points.append(points[0])
	draw_polyline(outline_points, outline, 2.0, true)

	if not revealed:
		if cell in purchasable_cells:
			var tile_cost := get_tile_cost(cell)
			var price_color := Color("#f87171") if player_gold < tile_cost else Color("#fbbf24")
			draw_string(ThemeDB.fallback_font, center + Vector2(-18, -20), "%d金币" % tile_cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, price_color)
		draw_string(ThemeDB.fallback_font, center + Vector2(-7, 7), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#94a3b8"))
	else:
		if not (cell == drag_start_cell and long_press_active):
			_draw_building(cell, center, int(tile["building"]), int(tile["building_level"]), int(tile["unit_class"]))

	if cell == drag_start_cell and long_press_active:
		_draw_drag_source_preview(cell)

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
		draw_rect(Rect2(center - Vector2(13, 13), Vector2(26, 26)), hq_color, true)
		draw_string(ThemeDB.fallback_font, center + Vector2(-7, 6), "HQ", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#08111f"))
		return
	match building:
		MINE:
			draw_circle(center, 14.0, Color("#f59e0b"))
			draw_circle(center, 7.0, Color("#fde68a"))
			draw_string(ThemeDB.fallback_font, center + Vector2(-5, 4), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#7c2d12"))
		BARRACKS:
			var barracks_color := _unit_class_color(unit_class)
			draw_rect(Rect2(center - Vector2(14, 11), Vector2(28, 22)), barracks_color, true)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-17, -11), center + Vector2(17, -11), center + Vector2(0, -25)]), barracks_color.lightened(0.25))
			draw_string(ThemeDB.fallback_font, center + Vector2(-13, 5), _unit_class_short_name(unit_class), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#312e81"))
			draw_string(ThemeDB.fallback_font, center + Vector2(8, 5), str(level), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#312e81"))
		TOWER:
			draw_circle(center, 14.0, Color("#94a3b8"))
			draw_line(center + Vector2(-4, -4), center + Vector2(13, -18), Color("#e2e8f0"), 4.0)

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

func _hex_points(center: Vector2, size: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in range(6):
		var angle := deg_to_rad(60.0 * i - 30.0)
		result.append(center + Vector2(cos(angle), sin(angle)) * size)
	return result

func _draw_legend() -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(280, 700), "金色边框地块可购买（5 / 10 / 50 金币）    点击主城建造兵营    拖拽同级兵营合成", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#94a3b8"))
