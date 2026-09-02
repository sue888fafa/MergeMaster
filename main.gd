extends Node2D

const Config := preload("res://game_config.gd")

const PLAYER := 1
const AI := 2
const EMPTY := 0
const MINE := 1
const BARRACKS := 2
const TOWER := 3
const BARRACKS_COST := 50
const MAX_BARRACKS_LEVEL := 4
const UnitScript := preload("res://unit.gd")
const BulletScript := preload("res://bullet.gd")

@onready var board: HexBoard = $HexBoard
@onready var units_layer: Node2D = $Units
@onready var building_layer: BuildingLayer = $Buildings
@onready var ai_controller: SimpleAI = $AIController
@onready var hud: GameHUD = $HUD

var player_hq := Config.PLAYER_HQ
var ai_hq := Config.AI_HQ
var gold := {PLAYER: Config.INITIAL_GOLD, AI: Config.INITIAL_GOLD}
var base_hp := {PLAYER: Config.HQ_MAX_HP, AI: Config.HQ_MAX_HP}
var established_buildings := {PLAYER: false, AI: false}
var elapsed := 0.0
var income_timer := 0.0
var match_duration := 180.0
var game_over := false
var units: Array[BattleUnit] = []
var rng := RandomNumberGenerator.new()
var hq_initial_dispatched := {PLAYER: false, AI: false}
var last_message := "购买主城周围的金色地块扩张领地，每格需要 5 金币。"
var selected_barracks := Vector2i(999, 999)

func _ready() -> void:
	rng.randomize()
	board.tile_clicked.connect(_on_tile_clicked)
	board.tile_dragged.connect(_on_tile_dragged)
	board.tile_drag_started.connect(_on_tile_drag_started)
	building_layer.setup(board)
	ai_controller.setup(self)
	hud.setup(self)
	board.focus_camera_on_cell(player_hq)
	_refresh_purchase_cells()
	_update_hud()

func _process(delta: float) -> void:
	if game_over:
		return
	elapsed += delta
	_process_economy(delta)
	_process_hq_dispatch()
	_process_buildings(delta)
	_process_towers(delta)
	_check_time_limit()
	_update_hud()

func _process_hq_dispatch() -> void:
	for owner in [PLAYER, AI]:
		if bool(hq_initial_dispatched[owner]):
			continue
		var hq := player_hq if owner == PLAYER else ai_hq
		if not _has_enemy_in_barracks_range(hq, owner):
			continue
		_spawn_unit(owner, hq, 1, Config.UNIT_CLASS_WARRIOR)
		hq_initial_dispatched[owner] = true

func restart_game() -> void:
	for unit in units.duplicate():
		if is_instance_valid(unit):
			unit.queue_free()
	units.clear()
	gold = {PLAYER: Config.INITIAL_GOLD, AI: Config.INITIAL_GOLD}
	base_hp = {PLAYER: Config.HQ_MAX_HP, AI: Config.HQ_MAX_HP}
	established_buildings = {PLAYER: false, AI: false}
	elapsed = 0.0
	income_timer = 0.0
	game_over = false
	hq_initial_dispatched = {PLAYER: false, AI: false}
	last_message = "购买主城周围的金色地块扩张领地，每格需要 5 金币。"
	selected_barracks = Vector2i(999, 999)
	board.reset()
	board.reset_camera()
	hud.hide_result()
	_refresh_purchase_cells()
	_update_hud()

func reveal_cost(cell: Vector2i, _hq: Vector2i) -> int:
	return board.get_tile_cost(cell)

func _on_tile_clicked(cell: Vector2i) -> void:
	if game_over:
		return
	var tile: Dictionary = board.get_tile(cell)
	if tile.is_empty():
		return
	if selected_barracks != Vector2i(999, 999):
		if cell == selected_barracks:
			_clear_barracks_selection()
			last_message = "已关闭主城攻击范围提示。" if cell == player_hq else "已取消兵营合成。"
			_update_hud()
			return
		_clear_barracks_selection()
		last_message = "已关闭兵营出兵范围提示。"
		_update_hud()
		return
	if cell == player_hq:
		if selected_barracks == player_hq:
			_clear_barracks_selection()
			last_message = "已关闭主城攻击范围提示。"
		else:
			_clear_barracks_selection()
			selected_barracks = player_hq
			board.set_barracks_range_cell(player_hq)
			last_message = "主城攻击范围为 %d 格。再次点击其他区域可关闭提示。" % Config.HQ_DETECTION_RANGE
		_update_hud()
		return
	if bool(tile["revealed"]) and int(tile["owner"]) == PLAYER and int(tile["building"]) == BARRACKS:
		_select_barracks(cell)
		return
	if bool(tile["revealed"]):
		return
	if not _is_adjacent_to_owner(cell, PLAYER):
		last_message = "只能购买与我方已解锁地块相邻的未知地块。"
		_update_hud()
		return
	var cost := reveal_cost(cell, player_hq)
	if gold[PLAYER] < cost:
		last_message = "金币不足，需要 %d 金币。" % cost
		_update_hud()
		return
	reveal_tile(PLAYER, cell)

func _on_tile_dragged(from_cell: Vector2i, to_cell: Vector2i) -> void:
	if game_over:
		return
	var source: Dictionary = board.get_tile(from_cell)
	var target: Dictionary = board.get_tile(to_cell)
	if source.is_empty() or target.is_empty():
		return
	if int(source["owner"]) != PLAYER or int(source["building"]) != BARRACKS:
		last_message = "只能从我方兵营开始拖拽合成。"
		_update_hud()
		return
	# The dragged source A is consumed by the destination B, which is upgraded in place.
	if merge_barracks(to_cell, from_cell):
		_clear_barracks_selection()
		return
	_select_barracks(from_cell)
	last_message = "只能将兵营拖拽到同级兵营上。"
	_update_hud()

func _on_tile_drag_started(cell: Vector2i) -> void:
	if game_over or not board.has_cell(cell):
		return
	var tile: Dictionary = board.tiles[cell]
	if int(tile["owner"]) != PLAYER or int(tile["building"]) != BARRACKS:
		return
	var targets := get_merge_targets(cell, PLAYER)
	if targets.is_empty():
		return
	selected_barracks = cell
	board.set_mergeable_cells(targets)
	board.set_barracks_range_cell(cell)
	last_message = "兵营已拖起，出兵范围 %d 格；请拖到紫色高亮的同级兵营上合成。" % Config.BARRACKS_DETECTION_RANGE
	_update_hud()

func get_build_slots(owner: int) -> Array[Vector2i]:
	var hq := player_hq if owner == PLAYER else ai_hq
	var slots: Array[Vector2i] = []
	for cell in board.tiles:
		var tile: Dictionary = board.tiles[cell]
		if int(tile["owner"]) != owner or not bool(tile["revealed"]) or int(tile["building"]) != EMPTY:
			continue
		if board.are_adjacent(cell, hq) or board.is_rebuildable(cell):
			slots.append(cell)
	return slots

func _select_barracks(cell: Vector2i) -> void:
	var level := board.get_building_level(cell)
	var next_cost := barracks_unit_cost(board.get_production_count(cell))
	selected_barracks = cell
	board.set_mergeable_cells(get_merge_targets(cell, PLAYER))
	board.set_barracks_range_cell(cell)
	if level >= MAX_BARRACKS_LEVEL:
		last_message = "这是 4 级兵营，出兵范围 %d 格；下次出兵需要 %d 金币。" % [Config.BARRACKS_DETECTION_RANGE, next_cost]
	else:
		last_message = "已选择 %d 级兵营，出兵范围 %d 格，下次出兵 %d 金币；请拖拽到紫色高亮的同级兵营。" % [level, Config.BARRACKS_DETECTION_RANGE, next_cost]
	_update_hud()

func _clear_barracks_selection() -> void:
	selected_barracks = Vector2i(999, 999)
	board.clear_mergeable_cells()
	board.clear_barracks_range_cell()

func get_merge_targets(cell: Vector2i, owner: int) -> Array[Vector2i]:
	var targets: Array[Vector2i] = []
	if not board.has_cell(cell):
		return targets
	var source: Dictionary = board.tiles[cell]
	if int(source["owner"]) != owner or int(source["building"]) != BARRACKS:
		return targets
	var level := board.get_building_level(cell)
	if level >= MAX_BARRACKS_LEVEL:
		return targets
	for other_cell in board.tiles:
		if other_cell == cell:
			continue
		var tile: Dictionary = board.tiles[other_cell]
		if int(tile["owner"]) == owner and bool(tile["revealed"]) and int(tile["building"]) == BARRACKS and board.get_building_level(other_cell) == level and board.get_building_unit_class(other_cell) == board.get_building_unit_class(cell):
			targets.append(other_cell)
	return targets

func find_barracks_merge(owner: int) -> Array[Vector2i]:
	var first_by_level_and_class: Dictionary = {}
	for cell in board.tiles:
		var tile: Dictionary = board.tiles[cell]
		if int(tile["owner"]) != owner or not bool(tile["revealed"]) or int(tile["building"]) != BARRACKS:
			continue
		var level := board.get_building_level(cell)
		if level >= MAX_BARRACKS_LEVEL:
			continue
		var unit_class := board.get_building_unit_class(cell)
		var group_key := "%d:%d" % [level, unit_class]
		if first_by_level_and_class.has(group_key):
			var pair: Array[Vector2i] = []
			pair.append(first_by_level_and_class[group_key])
			pair.append(cell)
			return pair
		first_by_level_and_class[group_key] = cell
	return []

func build_barracks(owner: int, cell: Vector2i) -> bool:
	if game_over or not board.has_cell(cell):
		return false
	if not cell in get_build_slots(owner):
		return false
	if gold[owner] < BARRACKS_COST:
		if owner == PLAYER:
			last_message = "金币不足，建造兵营需要 %d 金币。" % BARRACKS_COST
			_update_hud()
		return false
	gold[owner] -= BARRACKS_COST
	board.set_building(cell, BARRACKS, 1, _random_unit_class())
	_register_building(owner)
	var produced := _produce_barracks_unit(cell)
	board.update_build_timer(cell, Config.BARRACKS_PRODUCTION_INTERVAL)
	last_message = "%s 建造了兵营，并派出第一名士兵。" % ("我方" if owner == PLAYER else "敌方") if produced else "%s 建造了兵营，金币不足以训练第一名士兵。" % ("我方" if owner == PLAYER else "敌方")
	board.queue_redraw()
	return true

func merge_barracks(first_cell: Vector2i, second_cell: Vector2i) -> bool:
	if game_over or not board.has_cell(first_cell) or not board.has_cell(second_cell) or first_cell == second_cell:
		return false
	var first: Dictionary = board.tiles[first_cell]
	var second: Dictionary = board.tiles[second_cell]
	var owner: int = int(first["owner"])
	var first_level := board.get_building_level(first_cell)
	var second_level := board.get_building_level(second_cell)
	var first_class := board.get_building_unit_class(first_cell)
	var second_class := board.get_building_unit_class(second_cell)
	if owner != PLAYER and owner != AI:
		return false
	if int(second["owner"]) != owner or int(first["building"]) != BARRACKS or int(second["building"]) != BARRACKS:
		return false
	if first_level != second_level or first_level < 1 or first_level >= MAX_BARRACKS_LEVEL or first_class < 0 or first_class != second_class:
		return false
	var upgraded_level := first_level + 1
	var unit_class := first_class
	var merged_production_count := board.get_production_count(first_cell) + board.get_production_count(second_cell)
	board.set_building(first_cell, BARRACKS, upgraded_level, unit_class)
	board.set_production_count(first_cell, merged_production_count)
	board.update_build_timer(first_cell, Config.BARRACKS_PRODUCTION_INTERVAL)
	board.set_building(second_cell, EMPTY)
	var unlocked := _unlock_barracks_neighbors(first_cell, owner)
	last_message = "%s兵营合成至 %d 级，开启周边 %d 格。" % ["我方" if owner == PLAYER else "敌方", upgraded_level, unlocked]
	_refresh_purchase_cells()
	board.queue_redraw()
	return true

func _unlock_barracks_neighbors(cell: Vector2i, owner: int) -> int:
	var unlocked := 0
	for neighbor in board.neighbors(cell):
		var tile: Dictionary = board.tiles[neighbor]
		if bool(tile["revealed"]):
			continue
		var result := _roll_tile_result(tile)
		board.reveal(neighbor, int(result["building"]), int(result["level"]), int(result["unit_class"]))
		board.set_tile_owner(neighbor, owner, true)
		if int(board.tiles[neighbor]["building"]) == BARRACKS:
			_register_building(owner)
			_produce_barracks_unit(neighbor)
			board.update_build_timer(neighbor, Config.BARRACKS_PRODUCTION_INTERVAL)
		elif int(board.tiles[neighbor]["building"]) != EMPTY:
			_register_building(owner)
		unlocked += 1
	return unlocked

func reveal_tile(owner: int, cell: Vector2i) -> bool:
	if game_over or not board.has_cell(cell):
		return false
	var tile: Dictionary = board.tiles[cell]
	if bool(tile["revealed"]):
		return false
	if not _is_adjacent_to_owner(cell, owner):
		return false
	var hq := player_hq if owner == PLAYER else ai_hq
	var cost := reveal_cost(cell, hq)
	if gold[owner] < cost:
		return false
	gold[owner] -= cost
	var result := _roll_tile_result(tile)
	var building := int(result["building"])
	var building_level := int(result["level"])
	board.reveal(cell, building, building_level, int(result["unit_class"]))
	board.set_tile_owner(cell, owner, true)
	if building != EMPTY:
		_register_building(owner)
	if building == BARRACKS:
		_produce_barracks_unit(cell)
		board.update_build_timer(cell, Config.BARRACKS_PRODUCTION_INTERVAL)
	_refresh_purchase_cells()
	last_message = "%s 购买并解锁了 %s，消耗 %d 金币。" % ["我方" if owner == PLAYER else "敌方", _building_name(building), cost]
	return true

func _roll_tile_result(tile: Dictionary) -> Dictionary:
	var roll := rng.randf()
	match int(tile.get("tile_type", Config.RANDOM_TILE_TYPE)):
		Config.BARRACKS_10_TILE_TYPE:
			return {"building": BARRACKS, "level": 1 if roll < 0.90 else 2, "unit_class": _random_unit_class()}
		Config.BARRACKS_50_TILE_TYPE:
			return {"building": BARRACKS, "level": 2 if roll < 0.90 else 3, "unit_class": _random_unit_class()}
	# 5-gold random tile: empty 60%, level 3 2%, level 2 8%, level 1 30%.
	if roll < 0.60:
		return {"building": EMPTY, "level": 0, "unit_class": -1}
	if roll < 0.62:
		return {"building": BARRACKS, "level": 3, "unit_class": _random_unit_class()}
	if roll < 0.70:
		return {"building": BARRACKS, "level": 2, "unit_class": _random_unit_class()}
	return {"building": BARRACKS, "level": 1, "unit_class": _random_unit_class()}

func _random_unit_class() -> int:
	return rng.randi_range(0, Config.UNIT_CLASS_COUNT - 1)

func _building_name(building: int) -> String:
	match building:
		MINE:
			return "金矿"
		BARRACKS:
			return "兵营"
		TOWER:
			return "箭塔"
	return "空地"

func _is_adjacent_to_owner(cell: Vector2i, owner: int) -> bool:
	for neighbor in board.neighbors(cell):
		var tile: Dictionary = board.tiles[neighbor]
		if bool(tile["revealed"]) and int(tile["owner"]) == owner:
			return true
	return false

func _register_building(owner: int) -> void:
	if owner == PLAYER or owner == AI:
		established_buildings[owner] = true

func _count_buildings(owner: int) -> int:
	var count := 0
	for cell in board.tiles:
		var tile: Dictionary = board.tiles[cell]
		if int(tile["owner"]) == owner and int(tile["building"]) != EMPTY:
			count += 1
	return count

func _refresh_purchase_cells() -> void:
	var candidates: Array[Vector2i] = []
	for cell in board.tiles:
		var tile: Dictionary = board.tiles[cell]
		if bool(tile["revealed"]):
			continue
		if _is_adjacent_to_owner(cell, PLAYER):
			candidates.append(cell)
	board.set_purchasable_cells(candidates)

func _process_economy(delta: float) -> void:
	income_timer += delta
	if income_timer < Config.GOLD_INCOME_INTERVAL:
		return
	var payout_count := int(floor(income_timer / Config.GOLD_INCOME_INTERVAL))
	income_timer -= float(payout_count) * Config.GOLD_INCOME_INTERVAL
	for owner in [PLAYER, AI]:
		gold[owner] += Config.BASE_GOLD_INCOME * float(payout_count)
	for cell in board.tiles:
		var tile: Dictionary = board.tiles[cell]
		if bool(tile["revealed"]) and int(tile["building"]) == MINE:
			var owner: int = int(tile["owner"])
			if owner == PLAYER or owner == AI:
				gold[owner] += 3.0 * float(payout_count)

func barracks_unit_cost(production_count: int) -> int:
	return 5 * (maxi(0, production_count) + 1)

func _produce_barracks_unit(cell: Vector2i) -> bool:
	if not board.has_cell(cell):
		return false
	var tile: Dictionary = board.tiles[cell]
	var owner: int = int(tile["owner"])
	if int(tile["building"]) != BARRACKS or (owner != PLAYER and owner != AI):
		return false
	if not _has_enemy_in_barracks_range(cell, owner):
		return false
	var production_count := board.get_production_count(cell)
	var cost := barracks_unit_cost(production_count)
	if gold[owner] < cost:
		return false
	gold[owner] -= cost
	_spawn_unit(owner, cell, board.get_building_level(cell), board.get_building_unit_class(cell))
	board.set_production_count(cell, production_count + 1)
	return true

func _has_enemy_in_barracks_range(cell: Vector2i, faction: int) -> bool:
	if _nearest_enemy(cell, faction, float(Config.BARRACKS_DETECTION_RANGE)) != null:
		return true
	if board.has_cell(_nearest_enemy_building(cell, faction, Config.BARRACKS_DETECTION_RANGE)):
		return true
	var enemy_hq := ai_hq if faction == PLAYER else player_hq
	return board.cube_distance(cell, enemy_hq) <= Config.BARRACKS_DETECTION_RANGE

func _process_buildings(delta: float) -> void:
	for cell in board.tiles:
		var tile: Dictionary = board.tiles[cell]
		if not bool(tile["revealed"]) or int(tile["building"]) != BARRACKS:
			continue
		var owner: int = int(tile["owner"])
		if owner != PLAYER and owner != AI:
			continue
		var level := board.get_building_level(cell)
		var timer := board.get_build_timer(cell) - delta
		if timer <= 0.0:
			_produce_barracks_unit(cell)
			# A barracks always advances on a fixed 10-second cycle, even when
			# the owner cannot currently pay for that soldier.
			timer = barracks_interval(level)
		board.update_build_timer(cell, timer)

func barracks_interval(level: int) -> float:
	return Config.BARRACKS_PRODUCTION_INTERVAL

func _process_towers(delta: float) -> void:
	for cell in board.tiles:
		var tile: Dictionary = board.tiles[cell]
		if int(tile["building"]) != TOWER:
			continue
		var owner: int = int(tile["owner"])
		if owner != PLAYER and owner != AI:
			continue
		var timer := board.get_build_timer(cell) - delta
		if timer > 0.0:
			board.update_build_timer(cell, timer)
			continue
		var target := _nearest_enemy(cell, owner, 2.6)
		if target != null:
			target.take_damage(8.0)
			timer = 1.2
		board.update_build_timer(cell, timer)

func process_unit(unit: BattleUnit, delta: float) -> void:
	if not is_instance_valid(unit) or not units.has(unit):
		return
	# Re-evaluate every frame so nearby enemy soldiers always take priority over buildings.
	var enemy: BattleUnit = _nearest_enemy(unit.cell, unit.faction)
	var enemy_building_cell := Vector2i(999, 999)
	if enemy == null:
		enemy_building_cell = _nearest_enemy_building(unit.cell, unit.faction)
	var enemy_distance := INF if enemy == null else float(board.cube_distance(unit.cell, enemy.cell))
	var building_distance := INF if not board.has_cell(enemy_building_cell) else float(board.cube_distance(unit.cell, enemy_building_cell))
	if enemy != null and enemy_distance <= building_distance:
		if enemy_distance <= unit.attack_range:
			if unit.can_attack():
				if unit.is_ranged:
					_fire_bullet(unit, enemy)
				else:
					enemy.take_damage(unit.attack)
				unit.mark_attack()
			return
		unit.move_directly_to(enemy.position, delta)
		return
	if board.has_cell(enemy_building_cell):
		if building_distance <= unit.attack_range:
			if unit.can_attack():
				if unit.is_ranged:
					_fire_building_bullet(unit, enemy_building_cell)
				else:
					damage_building(enemy_building_cell, unit.attack)
				unit.mark_attack()
			return
		unit.move_directly_to(board.axial_to_world(enemy_building_cell), delta)
		return
	var enemy_hq := ai_hq if unit.faction == PLAYER else player_hq
	if unit.cell == enemy_hq:
		if unit.can_attack():
			base_hp[3 - unit.faction] -= unit.attack
			unit.mark_attack()
			_check_hq_result()
		return
	unit.move_directly_to(board.axial_to_world(enemy_hq), delta)

func unit_arrived(unit: BattleUnit) -> void:
	if not is_instance_valid(unit) or not units.has(unit):
		return
	var tile: Dictionary = board.tiles.get(unit.cell, {})
	if tile.is_empty():
		return
	# Units may cross the board visually, but only purchased/revealed tiles can
	# change ownership. Unrevealed tiles must remain neutral and uncolored.
	if not bool(tile["revealed"]):
		return
	var occupant: int = int(tile["owner"])
	if occupant == EMPTY or occupant == 3 - unit.faction:
		if occupant == 3 - unit.faction and int(tile["building"]) != EMPTY:
			var destroyed_building := int(tile["building"])
			board.destroy_building(unit.cell)
			last_message = "%s士兵摧毁了敌方%s。" % ["我方" if unit.faction == PLAYER else "敌方", _building_name(destroyed_building)]
			_check_building_result()
		if _nearest_enemy(unit.cell, unit.faction, 0.0) == null:
			board.set_tile_owner(unit.cell, unit.faction, true)
			_refresh_purchase_cells()
			board.queue_redraw()

func _next_step_toward(start: Vector2i, target: Vector2i, faction: int) -> Vector2i:
	var options: Array[Vector2i] = []
	for neighbor in board.neighbors(start):
		var tile: Dictionary = board.tiles[neighbor]
		if not bool(tile["revealed"]):
			continue
		options.append(neighbor)
	if options.is_empty():
		return start
	var current_distance := board.cube_distance(start, target)
	var has_progress := false
	for option in options:
		if board.cube_distance(option, target) < current_distance:
			has_progress = true
			break
	if not has_progress:
		return start
	options.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var a_dist := board.cube_distance(a, target)
		var b_dist := board.cube_distance(b, target)
		if a_dist == b_dist:
			return int(board.tiles[a]["owner"]) == faction
		return a_dist < b_dist
	)
	return options[0]

func _nearest_enemy(cell: Vector2i, faction: int, max_distance: float = -1.0) -> BattleUnit:
	var result: BattleUnit
	var best := INF
	for unit in units:
		if not is_instance_valid(unit) or unit.faction == faction:
			continue
		var distance := float(board.cube_distance(cell, unit.cell))
		if max_distance >= 0.0 and distance > max_distance:
			continue
		if distance < best:
			best = distance
			result = unit
	return result

func _nearest_enemy_building(cell: Vector2i, faction: int, max_distance: int = -1) -> Vector2i:
	var result := Vector2i(999, 999)
	var best := INF
	for other_cell in board.tiles:
		var tile: Dictionary = board.tiles[other_cell]
		var owner: int = int(tile["owner"])
		var building: int = int(tile["building"])
		if not bool(tile["revealed"]) or owner == faction or (building != MINE and building != BARRACKS and building != TOWER):
			continue
		var distance := float(board.cube_distance(cell, other_cell))
		if max_distance >= 0 and distance > float(max_distance):
			continue
		if distance < best:
			best = distance
			result = other_cell
	return result

func _spawn_unit(owner: int, cell: Vector2i, barracks_level: int = 1, unit_class: int = Config.UNIT_CLASS_WARRIOR) -> BattleUnit:
	var unit: BattleUnit = UnitScript.new()
	units_layer.add_child(unit)
	unit.setup(owner, cell, self, barracks_level, unit_class)
	units.append(unit)
	return unit

func _fire_bullet(unit: BattleUnit, target: BattleUnit) -> void:
	var bullet = BulletScript.new()
	units_layer.add_child(bullet)
	bullet.setup(unit.position, target, unit.attack, self)

func _fire_building_bullet(unit: BattleUnit, target_cell: Vector2i) -> void:
	var bullet = BulletScript.new()
	units_layer.add_child(bullet)
	var target_owner: int = int(board.tiles[target_cell]["owner"])
	bullet.setup_building(unit.position, target_cell, unit.attack, target_owner, self)

func damage_building(cell: Vector2i, amount: float) -> void:
	if not board.has_cell(cell):
		return
	var tile: Dictionary = board.tiles[cell]
	var building: int = int(tile["building"])
	if building != MINE and building != BARRACKS and building != TOWER:
		return
	var hp := board.get_building_hp(cell) - amount
	if hp <= 0.0:
		board.destroy_building(cell)
		last_message = "士兵摧毁了敌方%s。" % _building_name(building)
	else:
		board.set_building_hp(cell, hp)
	_check_building_result()
	board.queue_redraw()

func remove_unit(unit: BattleUnit) -> void:
	if units.has(unit):
		units.erase(unit)
	if is_instance_valid(unit):
		unit.queue_free()

func _check_building_result() -> void:
	if established_buildings[PLAYER] and _count_buildings(PLAYER) == 0:
		_end_game("失败\n你的所有建筑都被摧毁了")
	elif established_buildings[AI] and _count_buildings(AI) == 0:
		_end_game("胜利\n敌方所有建筑都被摧毁了")

func _check_hq_result() -> void:
	if base_hp[PLAYER] <= 0.0:
		_end_game("失败\n敌方部队摧毁了你的主城")
	elif base_hp[AI] <= 0.0:
		_end_game("胜利\n你摧毁了敌方主城")

func _check_time_limit() -> void:
	if elapsed < match_duration:
		return
	var player_tiles := _count_owned(PLAYER)
	var ai_tiles := _count_owned(AI)
	if player_tiles > ai_tiles:
		_end_game("胜利\n时间结束，你占领了更多地块")
	elif ai_tiles > player_tiles:
		_end_game("失败\n时间结束，敌方占领了更多地块")
	else:
		_end_game("平局\n双方占领地块数量相同")

func _count_owned(owner: int) -> int:
	var count := 0
	for cell in board.tiles:
		if int(board.tiles[cell]["owner"]) == owner:
			count += 1
	return count

func _end_game(message: String) -> void:
	if game_over:
		return
	game_over = true
	hud.show_result(message)

func _update_hud() -> void:
	if hud == null:
		return
	board.set_player_gold(gold[PLAYER])
	hud.update_state(max(0.0, match_duration - elapsed), int(gold[PLAYER]), int(gold[AI]), base_hp[PLAYER], base_hp[AI], _count_owned(PLAYER), _count_owned(AI))
	hud.show_hint(last_message)
