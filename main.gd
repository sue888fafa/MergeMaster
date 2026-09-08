extends Node2D

const Config := preload("res://game_config.gd")
const EquipmentDataScript := preload("res://equipment_data.gd")
const MerchantDataScript := preload("res://merchant_data.gd")

const PLAYER := 1
const AI := 2
const EMPTY := 0
const MINE := 1
const BARRACKS := 2
const TOWER := 3
const MERCHANT := 4
const STEEL_BARRIER := 5
const BARRACKS_COST := 50
const MAX_BARRACKS_LEVEL := 4
const UnitScript := preload("res://unit.gd")
const BulletScript := preload("res://bullet.gd")
const MeleeAttackEffectScript := preload("res://melee_attack_effect.gd")
const FateEventScript := preload("res://fate_event.gd")
const MonsterScript := preload("res://monster.gd")
const MonsterAttackEffectScript := preload("res://monster_attack_effect.gd")
const BombardmentEffectScript := preload("res://bombardment_effect.gd")
const EquipmentDropEffectScript := preload("res://equipment_drop_effect.gd")
const BarracksUpgradeEffectScript := preload("res://barracks_upgrade_effect.gd")
const IntelligenceBuildingDropEffectScript := preload("res://intelligence_building_drop_effect.gd")
const GoldPopupEffectScript := preload("res://gold_popup_effect.gd")
const QuestionCardEffectScript := preload("res://question_card_effect.gd")
const INVALID_CELL := Vector2i(999, 999)

@onready var board: HexBoard = $HexBoard
@onready var units_layer: Node2D = $Units
@onready var equipment_effects: Node2D = $EquipmentEffects
@onready var fate_effects: Node2D = $FateEffects
@onready var bombardment_effects: Node2D = $BombardmentEffects
@onready var upgrade_effects: Node2D = $UpgradeEffects
@onready var intelligence_effects: Node2D = $IntelligenceEffects
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
var mine_income_timer := 0.0
var match_duration := Config.MATCH_DURATION
var game_over := false
var units: Array[BattleUnit] = []
var monsters: Array[WildMonster] = []
var equipped_items := {
	PLAYER: ["", "", "", "", ""],
	AI: ["", "", "", "", ""]
}
var item_inventory: Array[String] = []
var ai_card_inventory: Array[String] = []
var equipment_drop_queue: Array[Dictionary] = []
var pending_equipment_replacement: Dictionary = {}
var pending_card_land_loss: Dictionary = {}
var card_land_loss_queue: Array[Dictionary] = []
var card_land_loss_tween: Tween
var pending_intelligence_building_drop: Dictionary = {}
var intelligence_building_drop_queue: Array[Dictionary] = []
var intelligence_building_drop_tween: Tween
var pending_divinations: Dictionary = {}
var divination_tween: Tween
var divination_camera_active: Dictionary = {}
var rng := RandomNumberGenerator.new()
var hq_initial_dispatched := {PLAYER: false, AI: false}
var fate_locked_cells: Dictionary = {}
var pending_reveals: Dictionary = {}
var fate_reveal_batches: Dictionary = {}
var fate_bomb_building_targets: Dictionary = {}
var bombardment_started := false
var bombardment_round := 0
var bombardment_next_time := 0.0
var bombardment_round_centers: Array[Vector2i] = []
var bombardment_warning_round := 0
var bombardment_warning_area: Array[Vector2i] = []
var bombardment_warning_clear_time := 0.0
var bombardment_banner_hide_time := 0.0
var bombardment_locked_until: Dictionary = {}
var last_message := "购买主城周围的金色地块扩张领地，普通地块每格需要 1 金币。"
var selected_barracks := Vector2i(999, 999)
var active_item_id := ""
var active_item_cell := Vector2i(999, 999)
var merchant_shop_cell := Vector2i(999, 999)
var building_logic_accumulator := 0.0
const BUILDING_LOGIC_TICK := 0.10
var last_hud_time := -1
var last_hud_player_gold := -1
var last_hud_ai_gold := -1
var last_hud_player_tiles := -1
var last_hud_ai_tiles := -1
var last_hud_player_hp := -1.0
var last_hud_ai_hp := -1.0
var last_hud_message := ""

func _ready() -> void:
	rng.randomize()
	board.tile_clicked.connect(_on_tile_clicked)
	board.tile_dragged.connect(_on_tile_dragged)
	board.tile_drag_started.connect(_on_tile_drag_started)
	board.tile_reveal_midpoint.connect(_on_tile_reveal_midpoint)
	board.tile_reveal_finished.connect(_on_tile_reveal_finished)
	board.intelligence_building_drop_finished.connect(_on_intelligence_building_drop_finished)
	building_layer.setup(board)
	ai_controller.setup(self)
	hud.setup(self)
	hud.card_event_finished.connect(_on_card_event_finished)
	hud.card_draw_finished.connect(_on_card_draw_finished)
	hud.divination_roll_finished.connect(_on_divination_roll_finished)
	hud.merchant_item_selected.connect(_on_merchant_item_selected)
	hud.merchant_dismissed.connect(_on_merchant_dismissed)
	hud.inventory_item_dropped.connect(_on_inventory_item_dropped)
	hud.set_item_inventory(item_inventory)
	board.focus_camera_on_cell(player_hq)
	_refresh_purchase_cells()
	_update_hud()

func _process(delta: float) -> void:
	if game_over:
		return
	elapsed += delta
	_process_economy(delta)
	_process_bombardment()
	if merchant_shop_cell != INVALID_CELL:
		if not board.has_cell(merchant_shop_cell) or not bool(board.tiles[merchant_shop_cell].get("merchant_active", false)):
			merchant_shop_cell = INVALID_CELL
			hud.hide_merchant_shop()
	_process_hq_dispatch()
	building_logic_accumulator += delta
	if building_logic_accumulator >= BUILDING_LOGIC_TICK:
		var building_delta := building_logic_accumulator
		building_logic_accumulator = 0.0
		_process_buildings(building_delta)
		_process_towers(building_delta)
	_check_time_limit()
	_update_hud()

func _process_bombardment() -> void:
	_cleanup_bombardment_locks()
	if bombardment_banner_hide_time > 0.0 and elapsed >= bombardment_banner_hide_time:
		bombardment_banner_hide_time = 0.0
		hud.hide_bombardment_banner()
	if bombardment_warning_clear_time > 0.0 and elapsed >= bombardment_warning_clear_time:
		bombardment_warning_clear_time = 0.0
		board.clear_bombardment_warning_cells()
	if not bombardment_started and elapsed >= Config.BOMBARDMENT_WARNING_START:
		bombardment_started = true
		bombardment_round = 0
		bombardment_next_time = float(Config.BOMBARDMENT_ROUND_TIMES[0])
		bombardment_warning_round = 0
		bombardment_warning_area.clear()
		bombardment_banner_hide_time = 0.0

	if not bombardment_started:
		return
	var bombardment_start_time := Config.BOMBARDMENT_WARNING_START + Config.BOMBARDMENT_WARNING_DURATION
	if bombardment_round < Config.BOMBARDMENT_ROUNDS and bombardment_warning_round != bombardment_round + 1 and elapsed >= bombardment_next_time - Config.BOMBARDMENT_TELEGRAPH_DURATION:
		bombardment_warning_round = bombardment_round + 1
		bombardment_warning_area = _select_bombardment_area()
		bombardment_warning_clear_time = 0.0
		board.set_bombardment_warning_cells(bombardment_warning_area)
	if elapsed < bombardment_start_time:
		var seconds_left := maxi(0, int(ceil(bombardment_start_time - elapsed)))
		hud.show_bombardment_banner("炮轰警报：%d秒后开始轰炸" % seconds_left)
		return

	while bombardment_round < Config.BOMBARDMENT_ROUNDS and elapsed >= bombardment_next_time:
		bombardment_round += 1
		var area: Array[Vector2i] = []
		if bombardment_warning_round == bombardment_round:
			area = bombardment_warning_area.duplicate()
		else:
			area = _select_bombardment_area()
		bombardment_warning_area.clear()
		board.clear_bombardment_warning_cells()
		if not area.is_empty():
			_execute_bombardment(area)
			# Re-arm the flashing danger cue in the same frame as the world
			# bombardment announcement, so the selected seven cells remain
			# visibly high-risk during the impact effect.
			board.set_bombardment_warning_cells(area)
			bombardment_warning_clear_time = elapsed + Config.BOMBARDMENT_DANGER_DISPLAY_DURATION
		hud.show_bombardment_banner("炮轰开始：第%d轮" % bombardment_round)
		# Keep the result visible through the impact, then clear the announcement
		# one second after the bombardment presentation has finished.
		bombardment_banner_hide_time = elapsed + Config.BOMBARDMENT_EFFECT_DURATION + Config.BOMBARDMENT_BANNER_CLOSE_DELAY
		if bombardment_round < Config.BOMBARDMENT_ROUNDS:
			bombardment_next_time = float(Config.BOMBARDMENT_ROUND_TIMES[bombardment_round])
	_refresh_bombardment_visual_cells()

func _cleanup_bombardment_locks() -> void:
	var expired_cells: Array[Vector2i] = []
	for raw_cell in bombardment_locked_until.keys():
		if float(bombardment_locked_until[raw_cell]) <= elapsed:
			expired_cells.append(raw_cell)
	for cell in expired_cells:
		bombardment_locked_until.erase(cell)
	_refresh_bombardment_visual_cells()

func is_bombardment_locked(cell: Vector2i) -> bool:
	return float(bombardment_locked_until.get(cell, 0.0)) > elapsed

func get_bombardment_lock_remaining(cell: Vector2i) -> float:
	return maxf(0.0, float(bombardment_locked_until.get(cell, 0.0)) - elapsed)

func _refresh_bombardment_visual_cells() -> void:
	var active_cells: Array[Vector2i] = []
	for raw_cell in bombardment_locked_until.keys():
		active_cells.append(raw_cell)
	board.set_bombardment_cells(active_cells)

func _select_bombardment_area() -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	for raw_center in board.tiles.keys():
		var center: Vector2i = raw_center
		if center == player_hq or center == ai_hq:
			continue
		var area: Array[Vector2i] = [center]
		for neighbor in board.neighbors(center):
			area.append(neighbor)
		if area.size() != 1 + Config.BOMBARDMENT_AREA_RADIUS * 6:
			continue
		if area.has(player_hq) or area.has(ai_hq):
			continue
		candidates.append(center)
	if candidates.is_empty():
		return []
	var center: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
	bombardment_round_centers.append(center)
	var result: Array[Vector2i] = [center]
	result.append_array(board.neighbors(center))
	return result

func _execute_bombardment(area: Array[Vector2i]) -> void:
	_destroy_bombardment_units(area)
	for cell in area:
		bombardment_locked_until[cell] = elapsed + Config.BOMBARDMENT_LOCK_DURATION
		_damage_bombardment_building(cell)
		if game_over:
			return
	board.set_bombardment_cells(area)
	var positions: Array[Vector2] = []
	for cell in area:
		positions.append(board.axial_to_world(cell))
	var effect: BombardmentEffect = BombardmentEffectScript.new()
	_ensure_dynamic_layer(bombardment_effects, "BombardmentEffects").add_child(effect)
	effect.setup(positions)
	_refresh_bombardment_visual_cells()
	board.queue_redraw()

func _destroy_bombardment_units(area: Array[Vector2i]) -> void:
	var affected_cells: Dictionary = {}
	for cell in area:
		affected_cells[cell] = true
	for unit in units.duplicate():
		if is_instance_valid(unit) and affected_cells.has(unit.cell):
			remove_unit(unit)

func _damage_bombardment_building(cell: Vector2i) -> void:
	if not board.has_cell(cell):
		return
	var tile: Dictionary = board.tiles[cell]
	# The selected area already excludes both HQs. Apply the bombardment rule
	# to every remaining faction's building because this event has no caster.
	if not bool(tile["revealed"]) or cell == player_hq or cell == ai_hq:
		return
	var building := int(tile["building"])
	if building == BARRACKS:
		var level := board.get_building_level(cell)
		if level > 1:
			var unit_class := board.get_building_unit_class(cell)
			board.set_building(cell, BARRACKS, level - 1, unit_class)
			board.update_build_timer(cell, Config.BARRACKS_PRODUCTION_INTERVAL)
		else:
			board.destroy_building(cell)
	elif building == MINE or building == TOWER or building == STEEL_BARRIER:
		board.destroy_building(cell)
	elif building == MERCHANT:
		_dismiss_merchant(cell)
	else:
		return
	if hud != null:
		hud.flash_building_damage()
	_check_building_result()

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
	hud.clear_card_events()
	hud.clear_divination_events()
	hud.clear_equipment_state()
	hud.clear_hint_history()
	hud.hide_intelligence_news()
	hud.reset_cat_companion()
	for unit in units.duplicate():
		if is_instance_valid(unit):
			unit.queue_free()
	units.clear()
	for monster in monsters.duplicate():
		if is_instance_valid(monster):
			monster.queue_free()
	monsters.clear()
	equipped_items = {
		PLAYER: ["", "", "", "", ""],
		AI: ["", "", "", "", ""]
	}
	item_inventory.clear()
	ai_card_inventory.clear()
	equipment_drop_queue.clear()
	pending_equipment_replacement.clear()
	if card_land_loss_tween != null and card_land_loss_tween.is_valid():
		card_land_loss_tween.kill()
	if intelligence_building_drop_tween != null and intelligence_building_drop_tween.is_valid():
		intelligence_building_drop_tween.kill()
	if divination_tween != null and divination_tween.is_valid():
		divination_tween.kill()
	pending_card_land_loss.clear()
	card_land_loss_queue.clear()
	pending_intelligence_building_drop.clear()
	intelligence_building_drop_queue.clear()
	pending_divinations.clear()
	divination_camera_active.clear()
	board.clear_card_land_loss_cell()
	board.intelligence_building_drop_animations.clear()
	_clear_effect_children(fate_effects)
	_clear_effect_children(equipment_effects)
	_clear_effect_children(upgrade_effects)
	_clear_effect_children(intelligence_effects)
	fate_locked_cells.clear()
	pending_reveals.clear()
	fate_reveal_batches.clear()
	fate_bomb_building_targets.clear()
	bombardment_started = false
	bombardment_round = 0
	bombardment_next_time = 0.0
	bombardment_round_centers.clear()
	bombardment_warning_round = 0
	bombardment_warning_area.clear()
	bombardment_warning_clear_time = 0.0
	bombardment_banner_hide_time = 0.0
	bombardment_locked_until.clear()
	board.clear_bombardment_cells()
	board.clear_bombardment_warning_cells()
	bombardment_warning_clear_time = 0.0
	bombardment_banner_hide_time = 0.0
	_clear_effect_children(bombardment_effects)
	gold = {PLAYER: Config.INITIAL_GOLD, AI: Config.INITIAL_GOLD}
	base_hp = {PLAYER: Config.HQ_MAX_HP, AI: Config.HQ_MAX_HP}
	established_buildings = {PLAYER: false, AI: false}
	elapsed = 0.0
	income_timer = 0.0
	mine_income_timer = 0.0
	building_logic_accumulator = 0.0
	game_over = false
	hq_initial_dispatched = {PLAYER: false, AI: false}
	last_message = "购买主城周围的金色地块扩张领地，普通地块每格需要 1 金币。"
	selected_barracks = Vector2i(999, 999)
	active_item_id = ""
	active_item_cell = INVALID_CELL
	merchant_shop_cell = INVALID_CELL
	hud.hide_merchant_shop()
	hud.set_item_inventory(item_inventory)
	last_hud_time = -1
	last_hud_player_gold = -1
	last_hud_ai_gold = -1
	last_hud_player_tiles = -1
	last_hud_ai_tiles = -1
	last_hud_player_hp = -1.0
	last_hud_ai_hp = -1.0
	last_hud_message = ""
	board.reset()
	board.reset_camera()
	hud.hide_result()
	hud.hide_bombardment_banner()
	hud.hide_world_broadcast()
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
	if is_bombardment_locked(cell):
		last_message = "该地块处于炮轰禁用区，还需 %.0f 秒才能操作。" % get_bombardment_lock_remaining(cell)
		_update_hud()
		return
	if _is_reveal_locked(cell):
		last_message = "该地块正在翻转，请等待动画完成。"
		_update_hud()
		return
	if not active_item_id.is_empty():
		_try_use_active_item(cell)
		return
	if bool(tile.get("merchant_active", false)) and bool(tile.get("revealed", false)) and int(tile.get("owner", EMPTY)) == PLAYER:
		_open_merchant_shop(cell)
		return
	if bool(tile.get("revealed", false)) and int(tile.get("owner", EMPTY)) == PLAYER:
		var ground_item_id := str(tile.get("ground_item_id", ""))
		if not ground_item_id.is_empty() and MerchantDataScript.is_card(ground_item_id):
			active_item_id = ground_item_id
			active_item_cell = cell
			last_message = "已选择卡片：%s，请点击目标地块使用；再次点击此处可取消。" % MerchantDataScript.get_item_name(ground_item_id)
			_update_hud()
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
		if is_bombardment_locked(cell) or _is_card_land_loss_locked(cell):
			continue
		if board.are_adjacent(cell, hq) or board.is_rebuildable(cell):
			slots.append(cell)
	return slots

func _select_barracks(cell: Vector2i) -> void:
	var level := board.get_building_level(cell)
	selected_barracks = cell
	board.set_mergeable_cells(get_merge_targets(cell, PLAYER))
	board.set_barracks_range_cell(cell)
	if level >= MAX_BARRACKS_LEVEL:
		last_message = "这是 4 级兵营，出兵范围 %d 格，出兵免费。" % Config.BARRACKS_DETECTION_RANGE
	else:
		last_message = "已选择 %d 级兵营，出兵范围 %d 格，出兵免费；请拖拽到紫色高亮的同级兵营。" % [level, Config.BARRACKS_DETECTION_RANGE]
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
		if is_bombardment_locked(other_cell) or _is_card_land_loss_locked(other_cell):
			continue
		if int(tile["owner"]) == owner and bool(tile["revealed"]) and int(tile["building"]) == BARRACKS and board.get_building_level(other_cell) == level and board.get_building_unit_class(other_cell) == board.get_building_unit_class(cell):
			targets.append(other_cell)
	return targets

func find_barracks_merge(owner: int) -> Array[Vector2i]:
	var first_by_level_and_class: Dictionary = {}
	for cell in board.tiles:
		var tile: Dictionary = board.tiles[cell]
		if int(tile["owner"]) != owner or not bool(tile["revealed"]) or int(tile["building"]) != BARRACKS:
			continue
		if is_bombardment_locked(cell) or _is_card_land_loss_locked(cell):
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
	if is_bombardment_locked(cell) or _is_card_land_loss_locked(cell):
		return false
	if not cell in get_build_slots(owner):
		return false
	if gold[owner] < BARRACKS_COST:
		if owner == PLAYER:
			last_message = "金币不足，建造兵营需要 %d 金币。" % BARRACKS_COST
			_update_hud()
		return false
	gold[owner] -= BARRACKS_COST
	var unit_class := _random_unit_class()
	board.set_building(cell, BARRACKS, 1, unit_class)
	_spawn_initial_barracks_unit(owner, cell)
	_register_building(owner)
	_reset_barracks_production_timer(cell)
	if owner == PLAYER:
		last_message = "我方建造了兵营，已配置 1 名士兵。"
	board.queue_redraw()
	return true

func merge_barracks(first_cell: Vector2i, second_cell: Vector2i) -> bool:
	if game_over or not board.has_cell(first_cell) or not board.has_cell(second_cell) or first_cell == second_cell:
		return false
	if is_bombardment_locked(first_cell) or is_bombardment_locked(second_cell) or _is_card_land_loss_locked(first_cell) or _is_card_land_loss_locked(second_cell):
		return false
	var first: Dictionary = board.tiles[first_cell]
	var second: Dictionary = board.tiles[second_cell]
	if board.is_barracks_merge_active(first_cell) or board.is_barracks_merge_active(second_cell):
		return false
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
	_reassign_barracks_units(second_cell, first_cell)
	board.set_building(first_cell, BARRACKS, upgraded_level, unit_class)
	_play_barracks_upgrade_effect(first_cell, upgraded_level)
	board.set_production_count(first_cell, _count_barracks_units(first_cell, owner))
	_reset_barracks_production_timer(first_cell)
	board.set_building(second_cell, EMPTY)
	board.start_barracks_merge(first_cell)
	if owner == PLAYER:
		last_message = "我方兵营合成至 %d 级。" % upgraded_level
	_refresh_purchase_cells()
	board.queue_redraw()
	return true

func reveal_tile(owner: int, cell: Vector2i) -> bool:
	if game_over or not board.has_cell(cell):
		return false
	if _is_reveal_locked(cell):
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
	var result := _roll_tile_result(tile)
	var fate_tile := _is_fate_tile(cell)
	if not board.start_tile_reveal(cell):
		return false
	gold[owner] -= cost
	pending_reveals[cell] = {
		"owner": owner,
		"result": result,
		"trigger_fate": true,
		"free_reveal": false,
		"cost": cost,
		"fate_origin": INVALID_CELL,
		"fate_tile": fate_tile,
		"committed": false
	}
	if owner == PLAYER:
		last_message = "我方正在翻开地块，消耗 %d 金币。" % cost
	_refresh_purchase_cells()
	return true

func _reveal_free_tile(owner: int, cell: Vector2i, allow_fate := false, fate_origin: Vector2i = INVALID_CELL) -> bool:
	if game_over or not board.has_cell(cell):
		return false
	if is_bombardment_locked(cell):
		return false
	if board.is_tile_reveal_active(cell) or pending_reveals.has(cell):
		return false
	if fate_locked_cells.has(cell) and fate_locked_cells[cell] != fate_origin:
		return false
	var tile: Dictionary = board.tiles[cell]
	if bool(tile["revealed"]):
		return false
	var result := _roll_tile_result(tile)
	var fate_tile := _is_fate_tile(cell)
	if not board.start_tile_reveal(cell):
		return false
	pending_reveals[cell] = {
		"owner": owner,
		"result": result,
		"trigger_fate": allow_fate,
		"free_reveal": true,
		"cost": 0,
		"fate_origin": fate_origin,
		"fate_tile": fate_tile,
		"committed": false
	}
	_refresh_purchase_cells()
	return true

func _apply_tile_result(owner: int, cell: Vector2i, result: Dictionary, trigger_fate: bool) -> void:
	if not board.has_cell(cell):
		return
	var building := int(result["building"])
	board.reveal(cell, building, int(result["level"]), int(result["unit_class"]))
	board.set_tile_owner(cell, owner, true)
	board.tiles[cell]["intelligence_free_claim"] = false
	board.tiles[cell]["merchant_active"] = building == MERCHANT
	board.tiles[cell]["merchant_stock"] = []
	if bool(result.get("monster", false)):
		_spawn_monster(cell)
	if _is_combat_building(building):
		_register_building(owner)
	if building == BARRACKS:
		_reset_barracks_production_timer(cell)
	if trigger_fate and (bool(result.get("fate_tile", false)) or _is_fate_tile(cell)):
		board.tiles[cell]["fate_event_active"] = true
		_trigger_random_event(owner, cell)

func _on_tile_reveal_midpoint(cell: Vector2i) -> void:
	if not pending_reveals.has(cell):
		return
	var pending: Dictionary = pending_reveals[cell]
	if bool(pending["committed"]):
		return
	pending["committed"] = true
	pending_reveals[cell] = pending
	_apply_tile_result(int(pending["owner"]), cell, pending["result"], false)
	pending["chest_claimed"] = _claim_chest_reward(int(pending["owner"]), cell)
	pending_reveals[cell] = pending
	_refresh_purchase_cells()
	board.queue_redraw()

func _on_tile_reveal_finished(cell: Vector2i) -> void:
	if not pending_reveals.has(cell):
		return
	var pending: Dictionary = pending_reveals[cell]
	pending_reveals.erase(cell)
	_refresh_purchase_cells()
	var owner := int(pending["owner"])
	var tile: Dictionary = board.tiles.get(cell, {})
	if owner == PLAYER and not bool(pending["free_reveal"]) and not bool(pending.get("chest_claimed", false)):
		last_message = "我方购买并解锁了 %s，消耗 %d 金币。" % [_building_name(int(pending["result"]["building"])), int(pending["cost"])]
	var random_event_type: int = int(pending["result"].get("random_event", -1))
	if bool(pending["trigger_fate"]) and (bool(pending.get("fate_tile", false)) or _is_fate_tile(cell)):
		board.tiles[cell]["fate_event_active"] = true
		_trigger_random_event(owner, cell)
	elif bool(pending["trigger_fate"]) and random_event_type >= 0:
		board.tiles[cell]["fate_event_active"] = true
		_trigger_random_event(owner, cell, random_event_type)
	var fate_origin: Vector2i = pending["fate_origin"]
	if fate_origin != INVALID_CELL:
		_resolve_fate_reveal(fate_origin, cell)
	_refresh_purchase_cells()
	board.queue_redraw()

func _claim_chest_reward(owner: int, cell: Vector2i) -> bool:
	if not board.has_cell(cell):
		return false
	var tile: Dictionary = board.tiles[cell]
	if not bool(tile.get("chest_reward", false)):
		return false
	var reward := int(tile.get("chest_reward_amount", Config.CHEST_REWARD_AMOUNT))
	gold[owner] += reward
	tile["chest_reward"] = false
	tile["chest_reward_amount"] = 0
	if owner == PLAYER:
		last_message = "宝箱怪藏匿的宝箱被你找到了，金币+%d" % reward
		_show_player_officer_bubble("发财了！我们找到了宝箱怪，获得了%d枚金币！" % reward)
	return true

func _show_player_officer_bubble(message: String) -> void:
	if hud != null and not game_over and not message.is_empty():
		hud.show_officer_bubble(message)

func _trigger_random_event(owner: int, fate_cell: Vector2i, forced_event_type: int = -1) -> void:
	var event_type := forced_event_type
	if event_type < 0:
		# Fate tiles now enter the divination house. Bomb, plane and chest
		# monster events are rolled by ordinary random tiles instead.
		if not _is_fate_tile(fate_cell):
			return
		event_type = Config.RANDOM_EVENT_CARD
	match event_type:
		Config.RANDOM_EVENT_BOMB:
			_trigger_bomb_event(owner, fate_cell)
		Config.RANDOM_EVENT_PLANE:
			_trigger_plane_event(owner, fate_cell)
		Config.RANDOM_EVENT_CHEST_MONSTER:
			_trigger_chest_monster_event(owner, fate_cell)
		Config.RANDOM_EVENT_CARD:
			_trigger_divination_event(owner, fate_cell)
		Config.RANDOM_EVENT_INTELLIGENCE:
			_trigger_intelligence_event(owner, fate_cell)
		Config.RANDOM_EVENT_DISPLAY_CARD:
			_trigger_display_only_card_event(owner, fate_cell)

func _trigger_divination_event(owner: int, fate_cell: Vector2i) -> void:
	var target_type := _roll_divination_target(owner)
	var target := _resolve_divination_target(owner, target_type)
	var event_type := _roll_divination_event()
	var return_position := board.get_camera_position()
	if not divination_camera_active.is_empty():
		return_position = divination_camera_active["return_position"]
	var pending := {
		"owner": owner,
		"target": target,
		"target_type": target_type,
		"event_type": event_type,
		"fate_cell": fate_cell,
		"return_position": return_position
	}
	pending_divinations[fate_cell] = pending
	if owner == PLAYER and hud != null and hud.has_method("play_divination_event"):
		pending["target_name"] = _faction_display_name(target)
		pending["target_type_name"] = _divination_target_name(target_type)
		pending["event_name"] = _divination_event_name(event_type)
		hud.play_divination_event(pending)
		return
	var result := _resolve_divination_event(owner, target, event_type)
	_present_divination_result(pending, result, false)

func _roll_divination_target(_diviner: int) -> int:
	return rng.randi_range(Config.FATE_DIVINATION_TARGET_MOST_TILES, Config.FATE_DIVINATION_TARGET_DIVINER)

func _resolve_divination_target(diviner: int, target_type: int) -> int:
	var owners: Array[int] = [PLAYER, AI]
	match target_type:
		Config.FATE_DIVINATION_TARGET_MOST_TILES, Config.FATE_DIVINATION_TARGET_LEAST_TILES:
			var values: Dictionary = {}
			for owner in owners:
				values[owner] = _count_owned(owner)
			var target_value := -INF if target_type == Config.FATE_DIVINATION_TARGET_MOST_TILES else INF
			var candidates: Array[int] = []
			for owner in owners:
				var value: int = int(values[owner])
				var is_better := value > target_value if target_type == Config.FATE_DIVINATION_TARGET_MOST_TILES else value < target_value
				if is_better:
					target_value = value
					candidates.clear()
					candidates.append(owner)
				elif is_equal_approx(float(value), float(target_value)):
					candidates.append(owner)
			return candidates[rng.randi_range(0, candidates.size() - 1)] if not candidates.is_empty() else diviner
		Config.FATE_DIVINATION_TARGET_MOST_GOLD, Config.FATE_DIVINATION_TARGET_LEAST_GOLD:
			var target_value := -INF if target_type == Config.FATE_DIVINATION_TARGET_MOST_GOLD else INF
			var candidates: Array[int] = []
			for owner in owners:
				var value := float(gold[owner])
				var is_better := value > target_value if target_type == Config.FATE_DIVINATION_TARGET_MOST_GOLD else value < target_value
				if is_better:
					target_value = value
					candidates.clear()
					candidates.append(owner)
				elif is_equal_approx(value, float(target_value)):
					candidates.append(owner)
			return candidates[rng.randi_range(0, candidates.size() - 1)] if not candidates.is_empty() else diviner
		Config.FATE_DIVINATION_TARGET_RANDOM_ENEMY:
			return AI if diviner == PLAYER else PLAYER
		Config.FATE_DIVINATION_TARGET_DIVINER:
			return diviner
	return diviner

func _roll_divination_event() -> int:
	return rng.randi_range(Config.FATE_DIVINATION_GAIN_CARD, Config.FATE_DIVINATION_DOWNGRADE_BARRACKS)

func _divination_target_name(target_type: int) -> String:
	match target_type:
		Config.FATE_DIVINATION_TARGET_MOST_TILES:
			return "地块最多的人"
		Config.FATE_DIVINATION_TARGET_LEAST_TILES:
			return "地块最少的人"
		Config.FATE_DIVINATION_TARGET_MOST_GOLD:
			return "金币最多的人"
		Config.FATE_DIVINATION_TARGET_LEAST_GOLD:
			return "金币最少的人"
		Config.FATE_DIVINATION_TARGET_RANDOM_ENEMY:
			return "随机一个敌人"
		Config.FATE_DIVINATION_TARGET_DIVINER:
			return "占卜者"
	return "未知目标"

func _divination_event_name(event_type: int) -> String:
	match event_type:
		Config.FATE_DIVINATION_GAIN_CARD:
			return "获得一张随机卡片"
		Config.FATE_DIVINATION_GAIN_BARRACKS:
			return "获得一座1级兵营"
		Config.FATE_DIVINATION_LOSE_BARRACKS:
			return "丢失一座1级兵营"
		Config.FATE_DIVINATION_GAIN_GOLD:
			return "获得5个金币"
		Config.FATE_DIVINATION_UPGRADE_BARRACKS:
			return "升级1座兵营"
		Config.FATE_DIVINATION_DOWNGRADE_BARRACKS:
			return "降级1座兵营"
	return "未知占卜结果"

func _resolve_divination_event(diviner: int, target: int, event_type: int) -> Dictionary:
	var result := {
		"success": false,
		"target": target,
		"event_type": event_type,
		"target_cell": INVALID_CELL,
		"card_id": ""
	}
	match event_type:
		Config.FATE_DIVINATION_GAIN_CARD:
			if (target == PLAYER and item_inventory.size() >= 8) or (target == AI and ai_card_inventory.size() >= 8):
				return result
			var card_id := _roll_card_id()
			if card_id.is_empty() or not _grant_card(target, card_id):
				return result
			result["success"] = true
			result["card_id"] = card_id
			result["target_cell"] = player_hq if target == PLAYER else ai_hq
		Config.FATE_DIVINATION_GAIN_BARRACKS:
			var empty_candidates := _divination_owned_empty_cells(target)
			if empty_candidates.is_empty():
				return result
			var cell: Vector2i = empty_candidates[rng.randi_range(0, empty_candidates.size() - 1)]
			board.set_building(cell, BARRACKS, 1, _random_unit_class())
			board.set_tile_owner(cell, target, true)
			board.set_production_count(cell, 0)
			_register_building(target)
			_spawn_initial_barracks_unit(target, cell)
			_reset_barracks_production_timer(cell)
			result["success"] = true
			result["target_cell"] = cell
		Config.FATE_DIVINATION_LOSE_BARRACKS:
			var loss_candidates := _divination_barracks_cells(target, true)
			if loss_candidates.is_empty():
				return result
			var lost_cell: Vector2i = loss_candidates[rng.randi_range(0, loss_candidates.size() - 1)]
			board.set_building(lost_cell, EMPTY)
			board.tiles[lost_cell]["merchant_active"] = false
			board.tiles[lost_cell]["merchant_stock"] = []
			board.tiles[lost_cell]["ground_item_id"] = ""
			board.set_tile_owner(lost_cell, target, true)
			_check_building_result()
			result["success"] = true
			result["target_cell"] = lost_cell
		Config.FATE_DIVINATION_GAIN_GOLD:
			gold[target] += 5.0
			_play_gold_popup(target, 5)
			result["success"] = true
			result["target_cell"] = player_hq if target == PLAYER else ai_hq
		Config.FATE_DIVINATION_UPGRADE_BARRACKS:
			var upgrade_candidates := _divination_barracks_cells(target, false)
			upgrade_candidates = upgrade_candidates.filter(func(cell: Vector2i) -> bool: return board.get_building_level(cell) < MAX_BARRACKS_LEVEL)
			if upgrade_candidates.is_empty():
				return result
			var upgraded_cell: Vector2i = upgrade_candidates[rng.randi_range(0, upgrade_candidates.size() - 1)]
			var upgraded_level := board.get_building_level(upgraded_cell) + 1
			board.set_building(upgraded_cell, BARRACKS, upgraded_level, board.get_building_unit_class(upgraded_cell))
			_play_barracks_upgrade_effect(upgraded_cell, upgraded_level)
			result["success"] = true
			result["target_cell"] = upgraded_cell
		Config.FATE_DIVINATION_DOWNGRADE_BARRACKS:
			var downgrade_candidates := _divination_barracks_cells(target, false)
			downgrade_candidates = downgrade_candidates.filter(func(cell: Vector2i) -> bool: return board.get_building_level(cell) > 1)
			if downgrade_candidates.is_empty():
				return result
			var downgraded_cell: Vector2i = downgrade_candidates[rng.randi_range(0, downgrade_candidates.size() - 1)]
			var production_timer := board.get_build_timer(downgraded_cell)
			var downgraded_level := board.get_building_level(downgraded_cell) - 1
			board.set_building(downgraded_cell, BARRACKS, downgraded_level, board.get_building_unit_class(downgraded_cell))
			board.update_build_timer(downgraded_cell, production_timer)
			result["success"] = true
			result["target_cell"] = downgraded_cell
	return result

func _divination_owned_empty_cells(owner: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for raw_cell in board.tiles:
		var cell: Vector2i = raw_cell
		var tile: Dictionary = board.tiles[raw_cell]
		if _is_hq_cell(cell) or not bool(tile.get("revealed", false)) or int(tile.get("owner", EMPTY)) != owner:
			continue
		if int(tile.get("building", EMPTY)) != EMPTY or bool(tile.get("monster_active", false)) or bool(tile.get("fate_event_active", false)):
			continue
		if is_bombardment_locked(cell) or _is_card_land_loss_locked(cell) or _is_reveal_locked(cell):
			continue
		if not str(tile.get("ground_item_id", "")).is_empty():
			continue
		cells.append(cell)
	return cells

func _divination_barracks_cells(owner: int, level_one_only: bool) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for raw_cell in board.tiles:
		var cell: Vector2i = raw_cell
		var tile: Dictionary = board.tiles[raw_cell]
		if _is_hq_cell(cell) or not bool(tile.get("revealed", false)) or int(tile.get("owner", EMPTY)) != owner or int(tile.get("building", EMPTY)) != BARRACKS:
			continue
		if bool(tile.get("fate_event_active", false)) or is_bombardment_locked(cell) or _is_card_land_loss_locked(cell):
			continue
		if level_one_only and board.get_building_level(cell) != 1:
			continue
		cells.append(cell)
	return cells

func _present_divination_result(pending: Dictionary, result: Dictionary, player_visible: bool) -> void:
	var diviner := int(pending.get("owner", AI))
	var target := int(pending.get("target", diviner))
	var event_type := int(pending.get("event_type", Config.FATE_DIVINATION_GAIN_CARD))
	var result_message := _divination_result_message(diviner, target, event_type, result)
	if hud != null and not game_over:
		hud.show_world_broadcast(result_message, Config.FATE_DIVINATION_BROADCAST_DURATION)
		if player_visible:
			hud.show_divination_result(result_message if bool(result.get("success", false)) else "本次占卜未产生效果。")
	if not player_visible:
		pending_divinations.erase(pending.get("fate_cell", INVALID_CELL))
		_finish_fate_event(pending.get("fate_cell", INVALID_CELL))
		_refresh_purchase_cells()
		board.queue_redraw()
		return
	var target_cell: Vector2i = result.get("target_cell", INVALID_CELL)
	if not bool(result.get("success", false)) or not board.has_cell(target_cell):
		_begin_divination_result_delay(pending)
		return
	divination_camera_active = {
		"fate_cell": pending["fate_cell"],
		"return_position": pending["return_position"],
		"target_cell": target_cell
	}
	board.focus_camera_on_cell(target_cell, Config.FATE_DIVINATION_CAMERA_MOVE_DURATION)
	if divination_tween != null and divination_tween.is_valid():
		divination_tween.kill()
	divination_tween = create_tween()
	divination_tween.tween_interval(Config.FATE_DIVINATION_CAMERA_MOVE_DURATION + Config.FATE_DIVINATION_CAMERA_HOLD_DURATION)
	divination_tween.tween_callback(_return_from_divination_camera)

func _begin_divination_result_delay(pending: Dictionary) -> void:
	if divination_tween != null and divination_tween.is_valid():
		divination_tween.kill()
	divination_tween = create_tween()
	divination_tween.tween_interval(Config.FATE_DIVINATION_RESULT_DURATION)
	divination_tween.tween_callback(_finish_divination_presentation.bind(pending.get("fate_cell", INVALID_CELL)))

func _return_from_divination_camera() -> void:
	if divination_camera_active.is_empty():
		return
	board.focus_camera_on_position(divination_camera_active["return_position"], Config.FATE_DIVINATION_CAMERA_RETURN_DURATION)
	if divination_tween != null and divination_tween.is_valid():
		divination_tween.kill()
	divination_tween = create_tween()
	divination_tween.tween_interval(Config.FATE_DIVINATION_CAMERA_RETURN_DURATION)
	divination_tween.tween_callback(_finish_divination_presentation.bind(divination_camera_active["fate_cell"]))

func _finish_divination_presentation(fate_cell: Vector2i) -> void:
	divination_camera_active.clear()
	pending_divinations.erase(fate_cell)
	if hud != null:
		hud.finish_divination_event()
	_finish_fate_event(fate_cell)
	_refresh_purchase_cells()
	board.queue_redraw()

func _on_divination_roll_finished(fate_cell: Vector2i) -> void:
	if not pending_divinations.has(fate_cell):
		return
	var pending: Dictionary = pending_divinations[fate_cell]
	var result := _resolve_divination_event(int(pending["owner"]), int(pending["target"]), int(pending["event_type"]))
	_present_divination_result(pending, result, true)

func _divination_result_message(diviner: int, target: int, event_type: int, result: Dictionary) -> String:
	var prefix := "%s的占卜：" % _faction_display_name(diviner)
	if not bool(result.get("success", false)):
		return prefix + "本次占卜未产生效果。"
	var target_name := _faction_display_name(target)
	match event_type:
		Config.FATE_DIVINATION_GAIN_CARD:
			return prefix + "%s获得了%s" % [target_name, MerchantDataScript.get_item_name(str(result.get("card_id", "")))]
		Config.FATE_DIVINATION_GAIN_BARRACKS:
			return prefix + "%s获得了一座1级兵营" % target_name
		Config.FATE_DIVINATION_LOSE_BARRACKS:
			return prefix + "%s丢失了一座1级兵营" % target_name
		Config.FATE_DIVINATION_GAIN_GOLD:
			return prefix + "%s获得了5个金币" % target_name
		Config.FATE_DIVINATION_UPGRADE_BARRACKS:
			return prefix + "%s升级了1座兵营" % target_name
		Config.FATE_DIVINATION_DOWNGRADE_BARRACKS:
			return prefix + "%s降级了一座兵营" % target_name
	return prefix + "本次占卜未产生效果。"

func _faction_display_name(owner: int) -> String:
	return "玩家" if owner == PLAYER else "机器人"

func _play_gold_popup(owner: int, amount: int) -> void:
	var hq_cell := player_hq if owner == PLAYER else ai_hq
	var effect: Node2D = GoldPopupEffectScript.new()
	_ensure_dynamic_layer(fate_effects, "FateEffects").add_child(effect)
	effect.setup(board.axial_to_world(hq_cell), amount)

func _trigger_display_only_card_event(owner: int, cell: Vector2i) -> void:
	var card_id := _roll_card_id()
	var effect: Node2D = QuestionCardEffectScript.new()
	_ensure_dynamic_layer(fate_effects, "FateEffects").add_child(effect)
	effect.setup(board.axial_to_world(cell))
	effect.finished.connect(_on_question_card_effect_finished.bind(owner, card_id, cell))

func _on_question_card_effect_finished(owner: int, card_id: String, cell: Vector2i) -> void:
	if game_over:
		return
	if owner == PLAYER and hud != null and hud.has_method("play_card_draw"):
		hud.play_card_draw(owner, card_id, cell)
	else:
		_grant_card(owner, card_id)
		_finish_fate_event(cell)

func _roll_card_id() -> String:
	var card_ids: Array = MerchantDataScript.CARD_IDS
	if card_ids.is_empty():
		return ""
	return str(card_ids[rng.randi_range(0, card_ids.size() - 1)])

func _grant_card(owner: int, card_id: String, fly_origin := Vector2(-1.0, -1.0)) -> bool:
	if not MerchantDataScript.is_card(card_id):
		return false
	if owner == PLAYER:
		if item_inventory.size() >= 8:
			last_message = "卡片背包已满，抽到的卡片无法收入背包。"
			_update_hud()
			return false
		item_inventory.append(card_id)
		if hud != null:
			hud.set_item_inventory(item_inventory, card_id, fly_origin)
		last_message = "获得卡片：%s，拖动卡片到目标地块使用。" % MerchantDataScript.get_item_name(card_id)
		_update_hud()
		return true
	if ai_card_inventory.size() < 8:
		ai_card_inventory.append(card_id)
	return true

func _trigger_intelligence_event(owner: int, origin: Vector2i) -> void:
	var intelligence_type := _roll_intelligence_type()
	var result := _resolve_intelligence_event(owner, origin, intelligence_type)
	var title := str(result.get("title", "世界情报"))
	var content := str(result.get("content", "世界发生了一起未知事件。"))
	var target: Vector2i = result.get("target", INVALID_CELL)
	var needs_drop_presentation := owner == PLAYER and bool(result.get("success", false)) and board.has_cell(target) and _is_intelligence_building_type(intelligence_type)
	if owner == PLAYER and intelligence_type == Config.INTELLIGENCE_GOLD and bool(result.get("success", false)):
		_show_player_officer_bubble("发财了！我们获得了3枚金币！")
	if owner == PLAYER and intelligence_type == Config.INTELLIGENCE_FLOOD:
		var land_loss: Dictionary = result.get("land_loss", {})
		_show_officer_land_loss_bubble(land_loss)
	if hud != null and not game_over:
		hud.show_world_broadcast("世界情报：%s  %s" % [title, content], Config.INTELLIGENCE_BROADCAST_DURATION)
		if owner == PLAYER and not needs_drop_presentation:
			hud.show_intelligence_news(title, content)
	if needs_drop_presentation:
		_begin_intelligence_building_drop(owner, origin, target, title, content)
	else:
		_finish_fate_event(origin)
		_refresh_purchase_cells()
		board.queue_redraw()

func _is_intelligence_building_type(intelligence_type: int) -> bool:
	return intelligence_type == Config.INTELLIGENCE_LEVEL_TWO_BARRACKS or intelligence_type == Config.INTELLIGENCE_LEVEL_THREE_BARRACKS or intelligence_type == Config.INTELLIGENCE_EARTHQUAKE_MINE

func _begin_intelligence_building_drop(owner: int, origin: Vector2i, target: Vector2i, title: String, content: String) -> void:
	var pending := {
		"owner": owner,
		"origin": origin,
		"target": target,
		"return_position": board.get_camera_position(),
		"title": title,
		"content": content
	}
	# Keep a queued target locked as well, so another event cannot overwrite it
	# while the player is watching the current presentation.
	fate_locked_cells[target] = origin
	_refresh_purchase_cells()
	if not pending_intelligence_building_drop.is_empty():
		intelligence_building_drop_queue.append(pending)
		return
	pending_intelligence_building_drop = pending
	_start_intelligence_building_drop_camera()

func _start_intelligence_building_drop_camera() -> void:
	if pending_intelligence_building_drop.is_empty() or game_over:
		return
	var target: Vector2i = pending_intelligence_building_drop["target"]
	board.focus_camera_on_cell(target, Config.INTELLIGENCE_BUILDING_CAMERA_DURATION)
	if intelligence_building_drop_tween != null and intelligence_building_drop_tween.is_valid():
		intelligence_building_drop_tween.kill()
	intelligence_building_drop_tween = create_tween()
	intelligence_building_drop_tween.tween_interval(Config.INTELLIGENCE_BUILDING_CAMERA_DURATION)
	intelligence_building_drop_tween.tween_callback(_start_intelligence_building_drop_animation)

func _start_intelligence_building_drop_animation() -> void:
	if pending_intelligence_building_drop.is_empty() or game_over:
		return
	var target: Vector2i = pending_intelligence_building_drop["target"]
	if not board.start_intelligence_building_drop(target):
		_finish_intelligence_building_drop(target)
		return
	var tile: Dictionary = board.tiles[target]
	var effect := IntelligenceBuildingDropEffectScript.new()
	_ensure_dynamic_layer(intelligence_effects, "IntelligenceEffects").add_child(effect)
	effect.setup(board.axial_to_world(target), int(tile["building"]), int(tile.get("building_level", 1)))

func _on_intelligence_building_drop_finished(cell: Vector2i) -> void:
	if pending_intelligence_building_drop.is_empty() or pending_intelligence_building_drop.get("target", INVALID_CELL) != cell:
		return
	_finish_intelligence_building_drop(cell)

func _finish_intelligence_building_drop(_cell: Vector2i) -> void:
	if pending_intelligence_building_drop.is_empty():
		return
	var pending := pending_intelligence_building_drop.duplicate()
	pending["phase"] = "returning"
	pending_intelligence_building_drop = pending
	board.focus_camera_on_position(pending["return_position"], Config.INTELLIGENCE_BUILDING_CAMERA_DURATION)
	if intelligence_building_drop_tween != null and intelligence_building_drop_tween.is_valid():
		intelligence_building_drop_tween.kill()
	intelligence_building_drop_tween = create_tween()
	intelligence_building_drop_tween.tween_interval(Config.INTELLIGENCE_BUILDING_CAMERA_DURATION)
	intelligence_building_drop_tween.tween_callback(_finish_intelligence_building_drop_return)

func _finish_intelligence_building_drop_return() -> void:
	if pending_intelligence_building_drop.is_empty():
		return
	var pending := pending_intelligence_building_drop.duplicate()
	pending_intelligence_building_drop.clear()
	var target: Vector2i = pending["target"]
	var origin: Vector2i = pending["origin"]
	if fate_locked_cells.get(target, INVALID_CELL) == origin:
		fate_locked_cells.erase(target)
	_finish_fate_event(origin)
	if hud != null and int(pending.get("owner", AI)) == PLAYER:
		hud.show_intelligence_news(str(pending.get("title", "世界情报")), str(pending.get("content", "")))
	_refresh_purchase_cells()
	board.queue_redraw()
	if not intelligence_building_drop_queue.is_empty():
		pending_intelligence_building_drop = intelligence_building_drop_queue.pop_front()
		_start_intelligence_building_drop_camera()

func _roll_intelligence_type() -> int:
	return rng.randi_range(Config.INTELLIGENCE_FLOOD, Config.INTELLIGENCE_EARTHQUAKE_MINE)

func _resolve_intelligence_event(owner: int, origin: Vector2i, intelligence_type: int) -> Dictionary:
	var result := {
		"type": intelligence_type,
		"title": "世界情报",
		"content": "世界发生了一起未知事件。",
		"target": INVALID_CELL,
		"success": false
	}
	match intelligence_type:
		Config.INTELLIGENCE_FLOOD:
			result["title"] = "山洪暴发"
			var lost_cell := _select_world_land_loss_target()
			if board.has_cell(lost_cell):
				result["target"] = lost_cell
				var land_loss := _apply_land_loss(lost_cell)
				result["land_loss"] = land_loss
				result["success"] = not land_loss.is_empty()
				result["content"] = "山洪暴发，世界随机一块土地流失。"
			else:
				result["content"] = "山洪暴发，但世界上没有可流失的土地。"
		Config.INTELLIGENCE_LEVEL_TWO_BARRACKS:
			result["title"] = "发现2级兵营"
			var barracks_two_cell := _find_intelligence_empty_tile(origin)
			if board.has_cell(barracks_two_cell) and _spawn_intelligence_building(barracks_two_cell, BARRACKS, 2):
				result["target"] = barracks_two_cell
				result["success"] = true
				result["content"] = "发现一座新的2级兵营，附近出现了一座无主兵营。"
			else:
				result["content"] = "发现2级兵营，但世界上没有可用空地。"
		Config.INTELLIGENCE_LEVEL_THREE_BARRACKS:
			result["title"] = "发现3级兵营"
			var barracks_three_cell := _find_intelligence_empty_tile(origin)
			if board.has_cell(barracks_three_cell) and _spawn_intelligence_building(barracks_three_cell, BARRACKS, 3):
				result["target"] = barracks_three_cell
				result["success"] = true
				result["content"] = "发现一座新的3级兵营，附近出现了一座无主兵营。"
			else:
				result["content"] = "发现3级兵营，但世界上没有可用空地。"
		Config.INTELLIGENCE_GOLD:
			gold[owner] += 3.0
			result["success"] = true
			result["title"] = "意外之财"
			result["content"] = "获得一笔意外之财，触发者获得3个金币。"
		Config.INTELLIGENCE_EARTHQUAKE_MINE:
			result["title"] = "地震发现大片金矿"
			var mine_cell := _find_intelligence_empty_tile(origin)
			if board.has_cell(mine_cell) and _spawn_intelligence_building(mine_cell, MINE):
				result["target"] = mine_cell
				result["success"] = true
				result["content"] = "地震后发现大片金矿，附近出现了一座无主金矿。"
			else:
				result["content"] = "世界内没有可用空地，本次情报没有产生额外金矿。"
	return result

func _get_intelligence_empty_candidates(origin: Vector2i, max_distance: int) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	for raw_cell in board.tiles:
		var cell: Vector2i = raw_cell
		if cell == origin or _is_hq_cell(cell):
			continue
		var tile: Dictionary = board.tiles[raw_cell]
		if int(tile.get("building", EMPTY)) != EMPTY:
			continue
		if bool(tile.get("monster_active", false)) or bool(tile.get("fate_event_active", false)):
			continue
		if _is_reveal_locked(cell) or board.cube_distance(origin, cell) > max_distance:
			continue
		candidates.append(cell)
	return candidates

func _find_intelligence_empty_tile(origin: Vector2i) -> Vector2i:
	for distance in range(Config.INTELLIGENCE_INITIAL_SEARCH_RANGE, Config.BOARD_RADIUS * 2 + 1):
		var candidates := _get_intelligence_empty_candidates(origin, distance)
		if not candidates.is_empty():
			return candidates[rng.randi_range(0, candidates.size() - 1)]
	return INVALID_CELL

func _spawn_intelligence_building(cell: Vector2i, building: int, level := 1) -> bool:
	if not board.has_cell(cell):
		return false
	var tile: Dictionary = board.tiles[cell]
	if int(tile.get("building", EMPTY)) != EMPTY or _is_hq_cell(cell):
		return false
	if _is_reveal_locked(cell):
		return false
	var unit_class := _random_unit_class() if building == BARRACKS else -1
	board.set_building(cell, building, level, unit_class, false)
	board.set_production_count(cell, 0)
	board.update_build_timer(cell, Config.BARRACKS_PRODUCTION_INTERVAL if building == BARRACKS else 0.0)
	board.set_tile_owner(cell, board.UNKNOWN, false)
	board.tiles[cell]["tile_type"] = Config.BARRACKS_2_TILE_TYPE if building == BARRACKS else Config.MINE_TILE_TYPE
	board.tiles[cell]["intelligence_free_claim"] = building == BARRACKS
	board.tiles[cell]["rebuildable"] = false
	return true

func _trigger_card_event(owner: int, fate_cell: Vector2i) -> void:
	var card_type := rng.randi_range(0, Config.CARD_EVENT_UPGRADE_BARRACKS)
	if owner != PLAYER:
		# Card scrolling is a player-facing interaction. Resolve AI cards in the
		# background so the player's screen never displays the enemy's draw.
		if not _apply_card_event(owner, card_type, fate_cell):
			_finish_fate_event(fate_cell)
		return
	last_message = "随机事件：翻卡中，请等待卡片停止滚动。"
	if hud != null and hud.has_method("play_card_event"):
		hud.play_card_event(owner, card_type, fate_cell)
	else:
		if not _apply_card_event(owner, card_type, fate_cell):
			_finish_fate_event(fate_cell)

func _on_card_event_finished(owner: int, card_type: int, fate_cell: Vector2i) -> void:
	if card_type == Config.RANDOM_EVENT_DISPLAY_CARD:
		_finish_fate_event(fate_cell)
	elif not _apply_card_event(owner, card_type, fate_cell):
		_finish_fate_event(fate_cell)
	board.queue_redraw()

func _on_card_draw_finished(owner: int, card_id: String, fate_cell: Vector2i) -> void:
	_grant_card(owner, card_id)
	_finish_fate_event(fate_cell)
	_refresh_purchase_cells()
	board.queue_redraw()

func _apply_card_event(owner: int, card_type: int, fate_cell: Vector2i = INVALID_CELL) -> bool:
	match card_type:
		Config.CARD_EVENT_LOSE_LAND:
			var lost_cell := _select_world_land_loss_target()
			if not board.has_cell(lost_cell):
				if owner == PLAYER:
					last_message = "随机事件：没有可失去归属的地块。"
				return false
			if owner == PLAYER:
				_begin_card_land_loss(owner, lost_cell, fate_cell)
				return true
			_apply_land_loss(lost_cell)
		Config.CARD_EVENT_GAIN_GOLD:
			gold[owner] += 10.0
			if owner == PLAYER:
				last_message = "随机事件：我方获得 10 金币。"
		Config.CARD_EVENT_ENEMY_LOSE_LAND:
			var enemy_owner := 3 - owner
			var lost_enemy_cell := _select_faction_land_loss_target(enemy_owner)
			if not board.has_cell(lost_enemy_cell):
				if owner == PLAYER:
					last_message = "随机事件：敌方没有可失去归属的地块。"
				return false
			if owner == PLAYER:
				_begin_card_land_loss(owner, lost_enemy_cell, fate_cell)
				return true
			_apply_land_loss(lost_enemy_cell)
		Config.CARD_EVENT_UPGRADE_BARRACKS:
			var upgraded_cell := _upgrade_random_barracks(owner)
			if owner == PLAYER:
				if board.has_cell(upgraded_cell):
					last_message = "随机事件：我方的兵营升级了。"
				else:
					last_message = "随机事件：我方没有可升级的兵营。"
	_refresh_purchase_cells()
	board.queue_redraw()
	return false

func _faction_name(owner: int) -> String:
	return "我方" if owner == PLAYER else "敌方"

func _land_loss_candidates(owner_filter: int = 0) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	for raw_cell in board.tiles:
		var cell: Vector2i = raw_cell
		var tile: Dictionary = board.tiles[raw_cell]
		var owner := int(tile["owner"])
		if _is_hq_cell(cell) or not bool(tile["revealed"]):
			continue
		if owner != PLAYER and owner != AI:
			continue
		if owner_filter != 0 and owner != owner_filter:
			continue
		if bool(tile.get("monster_active", false)) or bool(tile.get("fate_event_active", false)):
			continue
		if _is_card_land_loss_locked(cell) or board.is_tile_reveal_active(cell) or is_bombardment_locked(cell):
			continue
		candidates.append(cell)
	return candidates

func _select_world_land_loss_target() -> Vector2i:
	return _select_land_loss_target_from_candidates(_land_loss_candidates())

func _select_faction_land_loss_target(owner: int) -> Vector2i:
	return _select_land_loss_target_from_candidates(_land_loss_candidates(owner))

func _select_land_loss_target_from_candidates(candidates: Array[Vector2i]) -> Vector2i:
	if candidates.is_empty():
		return INVALID_CELL
	var building_candidates: Array[Vector2i] = []
	for cell in candidates:
		if int(board.tiles[cell]["building"]) != EMPTY:
			building_candidates.append(cell)
	if not building_candidates.is_empty():
		candidates = building_candidates
	return candidates[rng.randi_range(0, candidates.size() - 1)]

func _apply_land_loss(cell: Vector2i) -> Dictionary:
	if not board.has_cell(cell) or _is_hq_cell(cell):
		return {}
	var tile: Dictionary = board.tiles[cell]
	if not bool(tile["revealed"]) or (int(tile["owner"]) != PLAYER and int(tile["owner"]) != AI):
		return {}
	var building := int(tile["building"])
	var owner := int(tile["owner"])
	if building == BARRACKS and board.get_building_level(cell) > 1:
		var next_level := board.get_building_level(cell) - 1
		var unit_class := board.get_building_unit_class(cell)
		var production_timer := board.get_build_timer(cell)
		board.set_building(cell, BARRACKS, next_level, unit_class)
		board.update_build_timer(cell, production_timer)
		return {"cell": cell, "owner": owner, "downgraded": true, "level": next_level}
	tile["rebuildable"] = false
	tile["chest_reward"] = false
	tile["chest_reward_amount"] = 0
	tile["fate_event_active"] = false
	tile["monster_active"] = false
	if building != EMPTY:
		# Destroying a 1-level building leaves the already revealed land owned.
		board.set_building(cell, EMPTY)
		tile["merchant_active"] = false
		tile["merchant_stock"] = []
		tile["ground_item_id"] = ""
		board.set_tile_owner(cell, owner, true)
		_check_building_result()
		return {"cell": cell, "owner": owner, "building_destroyed": building}
	# Only an already empty tile loses its ownership and becomes unknown again.
	tile["merchant_active"] = false
	tile["merchant_stock"] = []
	tile["ground_item_id"] = ""
	board.set_tile_owner(cell, board.UNKNOWN, false)
	_check_building_result()
	return {"cell": cell, "owner": owner, "lost": true, "building": building}

func _land_loss_message(result: Dictionary) -> String:
	if result.is_empty():
		return "随机事件：没有可失去归属的地块。"
	if bool(result.get("downgraded", false)):
		return "随机事件：%s的兵营降为 %d 级。" % [_faction_name(int(result["owner"])), int(result["level"])]
	if bool(result.get("building_destroyed", false)):
		return "随机事件：%s的%s被摧毁，地块保留归属。" % [_faction_name(int(result["owner"])), _building_name(int(result["building_destroyed"]))]
	return "随机事件：%s失去了一块土地。" % _faction_name(int(result["owner"]))

func _is_card_land_loss_locked(cell: Vector2i) -> bool:
	if not pending_card_land_loss.is_empty() and pending_card_land_loss.get("cell", INVALID_CELL) == cell:
		return true
	for queued in card_land_loss_queue:
		if queued.get("cell", INVALID_CELL) == cell:
			return true
	return false

func is_card_land_loss_locked(cell: Vector2i) -> bool:
	return _is_card_land_loss_locked(cell)

func _begin_card_land_loss(owner: int, cell: Vector2i, fate_cell: Vector2i) -> void:
	var pending := {
		"owner": owner,
		"cell": cell,
		"fate_cell": fate_cell,
		"return_position": board.get_camera_position()
	}
	if not pending_card_land_loss.is_empty():
		card_land_loss_queue.append(pending)
		return
	pending_card_land_loss = pending
	_start_card_land_loss_camera()

func _start_card_land_loss_camera() -> void:
	if pending_card_land_loss.is_empty() or game_over:
		return
	var cell: Vector2i = pending_card_land_loss["cell"]
	last_message = "随机事件：目标地块即将失去归属或降级。"
	board.focus_camera_on_cell(cell, Config.CARD_LAND_LOSS_CAMERA_DURATION)
	if card_land_loss_tween != null and card_land_loss_tween.is_valid():
		card_land_loss_tween.kill()
	card_land_loss_tween = create_tween()
	card_land_loss_tween.tween_interval(Config.CARD_LAND_LOSS_CAMERA_DURATION)
	card_land_loss_tween.tween_callback(_start_card_land_loss_flash)

func _start_card_land_loss_flash() -> void:
	if pending_card_land_loss.is_empty() or game_over:
		return
	var cell: Vector2i = pending_card_land_loss["cell"]
	board.set_card_land_loss_cell(cell)
	if card_land_loss_tween != null and card_land_loss_tween.is_valid():
		card_land_loss_tween.kill()
	card_land_loss_tween = create_tween()
	card_land_loss_tween.tween_interval(Config.CARD_LAND_LOSS_FLASH_DURATION)
	card_land_loss_tween.tween_callback(_finish_card_land_loss)

func _finish_card_land_loss() -> void:
	if pending_card_land_loss.is_empty():
		return
	var pending := pending_card_land_loss.duplicate()
	board.clear_card_land_loss_cell()
	var result := _apply_land_loss(pending["cell"])
	last_message = _land_loss_message(result)
	_show_officer_land_loss_bubble(result)
	_refresh_purchase_cells()
	board.queue_redraw()
	if game_over:
		pending_card_land_loss.clear()
		return
	pending_card_land_loss["phase"] = "returning"
	board.focus_camera_on_position(pending["return_position"], Config.CARD_LAND_LOSS_CAMERA_DURATION)
	if card_land_loss_tween != null and card_land_loss_tween.is_valid():
		card_land_loss_tween.kill()
	card_land_loss_tween = create_tween()
	card_land_loss_tween.tween_interval(Config.CARD_LAND_LOSS_CAMERA_DURATION)
	card_land_loss_tween.tween_callback(_finish_card_land_loss_return)

func _show_officer_land_loss_bubble(result: Dictionary) -> void:
	if result.is_empty() or int(result.get("owner", AI)) != PLAYER:
		return
	var affected := bool(result.get("lost", false)) or bool(result.get("downgraded", false)) or bool(result.get("building_destroyed", false))
	if affected:
		_show_player_officer_bubble("运气不佳，我们丢失了一座城市")

func _finish_card_land_loss_return() -> void:
	if pending_card_land_loss.is_empty():
		return
	var pending := pending_card_land_loss.duplicate()
	pending_card_land_loss.clear()
	_finish_fate_event(pending["fate_cell"])
	if not card_land_loss_queue.is_empty():
		pending_card_land_loss = card_land_loss_queue.pop_front()
		_start_card_land_loss_camera()

func _is_hq_cell(cell: Vector2i) -> bool:
	return cell == player_hq or cell == ai_hq

func _upgrade_random_barracks(owner: int) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for cell in board.tiles:
		var tile: Dictionary = board.tiles[cell]
		if bool(tile["revealed"]) and int(tile["owner"]) == owner and int(tile["building"]) == BARRACKS and board.get_building_level(cell) < MAX_BARRACKS_LEVEL and not _is_card_land_loss_locked(cell):
			candidates.append(cell)
	if candidates.is_empty():
		return Vector2i(999, 999)
	var upgraded_cell: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
	var current_level: int = clampi(board.get_building_level(upgraded_cell), 1, MAX_BARRACKS_LEVEL)
	var next_level: int = mini(current_level + 1, MAX_BARRACKS_LEVEL)
	board.set_building(upgraded_cell, BARRACKS, next_level, board.get_building_unit_class(upgraded_cell))
	_play_barracks_upgrade_effect(upgraded_cell, next_level)
	return upgraded_cell

func _trigger_bomb_event(owner: int, fate_cell: Vector2i) -> void:
	if owner == PLAYER:
		_show_player_officer_bubble("BOOM！")
	var reveal_targets: Array[Vector2i] = []
	var building_targets: Array[Vector2i] = []
	for neighbor in board.neighbors(fate_cell):
		if _is_available_fate_target(neighbor):
			reveal_targets.append(neighbor)
		elif _is_enemy_building(neighbor, owner):
			building_targets.append(neighbor)
	if reveal_targets.is_empty() and building_targets.is_empty():
		_finish_fate_event(fate_cell)
		if owner == PLAYER:
			last_message = "随机事件：命运地块触发炸弹，但周围没有可作用目标。"
		return
	if owner == PLAYER:
		last_message = "随机事件：命运地块触发炸弹，周围地块和敌方建筑即将受到影响。"
	fate_bomb_building_targets[fate_cell] = building_targets
	_start_fate_effect(Config.RANDOM_EVENT_BOMB, owner, fate_cell, fate_cell, reveal_targets)

func _trigger_plane_event(owner: int, fate_cell: Vector2i) -> void:
	if owner == PLAYER:
		_show_player_officer_bubble("起飞！")
	var target := _find_plane_target(fate_cell)
	if not board.has_cell(target):
		_finish_fate_event(fate_cell)
		if owner == PLAYER:
			last_message = "随机事件：命运地块召唤飞机，但没有可开启地块。"
		return
	if owner == PLAYER:
		last_message = "随机事件：命运地块召唤纸飞机，正在寻找新的地块。"
	var targets: Array[Vector2i] = [target]
	_start_fate_effect(Config.RANDOM_EVENT_PLANE, owner, fate_cell, target, targets)

func _trigger_chest_monster_event(owner: int, fate_cell: Vector2i) -> void:
	if owner == PLAYER:
		last_message = "碰到箱子怪了，它一溜烟跑了"
	var candidates: Array[Vector2i] = []
	for cell in board.tiles:
		if _is_available_fate_target(cell) and board.cube_distance(fate_cell, cell) <= Config.CHEST_SEARCH_RANGE:
			candidates.append(cell)
	if candidates.is_empty():
		_finish_fate_event(fate_cell)
		return
	var target: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
	var targets: Array[Vector2i] = [target]
	_start_fate_effect(Config.RANDOM_EVENT_CHEST_MONSTER, owner, fate_cell, target, targets)

func _is_available_fate_target(cell: Vector2i) -> bool:
	return board.has_cell(cell) and not bool(board.tiles[cell]["revealed"]) and not _is_reveal_locked(cell)

func _is_enemy_building(cell: Vector2i, owner: int) -> bool:
	if not board.has_cell(cell) or owner != PLAYER and owner != AI:
		return false
	var tile: Dictionary = board.tiles[cell]
	var building := int(tile["building"])
	return bool(tile["revealed"]) and int(tile["owner"]) == 3 - owner and _is_combat_building(building)

func _find_plane_target(fate_cell: Vector2i) -> Vector2i:
	var nearby: Array[Vector2i] = []
	for neighbor in board.neighbors(fate_cell):
		if _is_available_fate_target(neighbor):
			nearby.append(neighbor)
	if not nearby.is_empty():
		return nearby[rng.randi_range(0, nearby.size() - 1)]
	var nearest_distance := INF
	var nearest: Array[Vector2i] = []
	for cell in board.tiles:
		if not _is_available_fate_target(cell):
			continue
		var distance := board.cube_distance(fate_cell, cell)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest.clear()
			nearest.append(cell)
		elif distance == nearest_distance:
			nearest.append(cell)
	if nearest.is_empty():
		return Vector2i(999, 999)
	return nearest[rng.randi_range(0, nearest.size() - 1)]

func _start_fate_effect(event_type: int, owner: int, origin: Vector2i, target: Vector2i, locked_cells: Array[Vector2i]) -> void:
	for cell in locked_cells:
		fate_locked_cells[cell] = origin
	var effect: FateEvent = FateEventScript.new()
	_ensure_dynamic_layer(fate_effects, "FateEffects").add_child(effect)
	effect.setup(event_type, board.axial_to_world(origin), board.axial_to_world(target))
	effect.finished.connect(_on_fate_effect_finished.bind(effect, event_type, owner, origin, target, locked_cells))

func _on_fate_effect_finished(effect: FateEvent, event_type: int, owner: int, origin: Vector2i, target: Vector2i, locked_cells: Array[Vector2i]) -> void:
	var pending_cells: Array[Vector2i] = []
	match event_type:
		Config.RANDOM_EVENT_BOMB:
			for building_cell in fate_bomb_building_targets.get(origin, []):
				_damage_bomb_building(building_cell, owner == PLAYER)
			fate_bomb_building_targets.erase(origin)
			for cell in locked_cells:
				if _reveal_free_tile(owner, cell, false, origin):
					pending_cells.append(cell)
		Config.RANDOM_EVENT_PLANE:
			# A plane can reveal a fate tile; allow the revealed target to start
			# its normal fate-card flow after the reveal animation completes.
			if _reveal_free_tile(owner, target, true, origin):
				pending_cells.append(target)
		Config.RANDOM_EVENT_CHEST_MONSTER:
			if board.has_cell(target) and not bool(board.tiles[target]["revealed"]):
				board.tiles[target]["chest_reward"] = true
				board.tiles[target]["chest_reward_amount"] = Config.CHEST_REWARD_AMOUNT
			_release_fate_locks(origin, locked_cells)
			_finish_fate_event(origin)
			board.queue_redraw()
			return
	if pending_cells.is_empty():
		_release_fate_locks(origin, locked_cells)
		_finish_fate_event(origin)
	else:
		fate_reveal_batches[origin] = {
			"pending_cells": pending_cells,
			"locked_cells": locked_cells
		}
	board.queue_redraw()

func _damage_bomb_building(cell: Vector2i, notify_player := true) -> void:
	if not board.has_cell(cell):
		return
	var tile: Dictionary = board.tiles[cell]
	var building := int(tile["building"])
	if building == BARRACKS:
		var level := board.get_building_level(cell)
		if level > 1:
			var unit_class := board.get_building_unit_class(cell)
			board.set_building(cell, BARRACKS, level - 1, unit_class)
			board.update_build_timer(cell, Config.BARRACKS_PRODUCTION_INTERVAL)
			if notify_player:
				last_message = "炸弹使敌方兵营降为 %d 级。" % (level - 1)
		else:
			board.destroy_building(cell)
			if notify_player:
				last_message = "炸弹摧毁了敌方 1 级兵营。"
	elif building == MINE or building == TOWER or building == STEEL_BARRIER:
		board.destroy_building(cell)
		if notify_player:
			last_message = "炸弹摧毁了敌方%s。" % _building_name(building)
	elif building == MERCHANT:
		_dismiss_merchant(cell)
		if notify_player:
			last_message = "炸弹摧毁了商人。"
	else:
		return
	if hud != null:
		hud.flash_building_damage()
	_check_building_result()

func _resolve_fate_reveal(origin: Vector2i, cell: Vector2i) -> void:
	if not fate_reveal_batches.has(origin):
		return
	var batch: Dictionary = fate_reveal_batches[origin]
	var pending_cells: Array[Vector2i] = batch["pending_cells"]
	pending_cells.erase(cell)
	if not pending_cells.is_empty():
		batch["pending_cells"] = pending_cells
		fate_reveal_batches[origin] = batch
		return
	_release_fate_locks(origin, batch["locked_cells"])
	fate_reveal_batches.erase(origin)
	_finish_fate_event(origin)

func _release_fate_locks(origin: Vector2i, cells: Array[Vector2i]) -> void:
	for cell in cells:
		if fate_locked_cells.get(cell, INVALID_CELL) == origin:
			fate_locked_cells.erase(cell)

func _finish_fate_event(fate_cell: Vector2i) -> void:
	if board.has_cell(fate_cell):
		board.tiles[fate_cell]["fate_event_active"] = false
	board.queue_redraw()

func _roll_tile_result(tile: Dictionary) -> Dictionary:
	if not bool(tile.get("revealed", false)) and int(tile.get("building", EMPTY)) != EMPTY:
		return {
			"building": int(tile["building"]),
			"level": int(tile.get("building_level", 0)),
			"unit_class": int(tile.get("unit_class", -1))
		}
	match int(tile.get("tile_type", Config.BARRACKS_TILE_TYPE)):
		Config.BARRACKS_TILE_TYPE:
			return {"building": BARRACKS, "level": 1, "unit_class": _random_unit_class()}
		Config.QUESTION_TILE_TYPE:
			return _roll_question_tile_result(tile)
		Config.VISIBLE_TILE_TYPE:
			return _roll_visible_tile_result(tile)
	return {"building": BARRACKS, "level": 1, "unit_class": _random_unit_class()}

func _roll_question_tile_result(_tile: Dictionary) -> Dictionary:
	var roll := rng.randf()
	var threshold := Config.QUESTION_EMPTY_WEIGHT
	if roll < threshold:
		return {"building": EMPTY, "level": 0, "unit_class": -1}
	threshold += Config.QUESTION_PLANE_WEIGHT
	if roll < threshold:
		return {"building": EMPTY, "level": 0, "unit_class": -1, "random_event": Config.RANDOM_EVENT_PLANE}
	threshold += Config.QUESTION_BOMB_WEIGHT
	if roll < threshold:
		return {"building": EMPTY, "level": 0, "unit_class": -1, "random_event": Config.RANDOM_EVENT_BOMB}
	threshold += Config.QUESTION_CARD_WEIGHT
	if roll < threshold:
		return {"building": EMPTY, "level": 0, "unit_class": -1, "random_event": Config.RANDOM_EVENT_DISPLAY_CARD}
	threshold += Config.QUESTION_WILD_MONSTER_WEIGHT
	if roll < threshold:
		return {"building": EMPTY, "level": 0, "unit_class": -1, "monster": true}
	threshold += Config.QUESTION_CHEST_MONSTER_WEIGHT
	if roll < threshold:
		return {"building": EMPTY, "level": 0, "unit_class": -1, "random_event": Config.RANDOM_EVENT_CHEST_MONSTER}
	threshold += Config.QUESTION_LEVEL_ONE_BARRACKS_WEIGHT
	if roll < threshold:
		return {"building": BARRACKS, "level": 1, "unit_class": _random_unit_class()}
	return {"building": MERCHANT, "level": 0, "unit_class": -1}

func _roll_visible_tile_result(tile: Dictionary) -> Dictionary:
	match int(tile.get("visible_tile_result", Config.VISIBLE_FATE)):
		Config.VISIBLE_WILD_MONSTER:
			return {"building": EMPTY, "level": 0, "unit_class": -1, "monster": true}
		Config.VISIBLE_MINE:
			return {"building": MINE, "level": 0, "unit_class": -1}
		Config.VISIBLE_LEVEL_TWO_BARRACKS:
			return {"building": BARRACKS, "level": 2, "unit_class": _random_unit_class()}
	return {"building": EMPTY, "level": 0, "unit_class": -1}

func _is_fate_tile(cell: Vector2i) -> bool:
	if not board.has_cell(cell):
		return false
	var tile: Dictionary = board.tiles[cell]
	return int(tile.get("tile_type", -1)) == Config.VISIBLE_TILE_TYPE and int(tile.get("visible_tile_result", -1)) == Config.VISIBLE_FATE

func _random_unit_class() -> int:
	return rng.randi_range(0, Config.UNIT_CLASS_COUNT - 1)

func _open_merchant_shop(cell: Vector2i) -> void:
	if not board.has_cell(cell) or not bool(board.tiles[cell].get("merchant_active", false)):
		return
	merchant_shop_cell = cell
	var stock: Array[String] = []
	for raw_item in board.tiles[cell].get("merchant_stock", []):
		var item_id := str(raw_item)
		if MerchantDataScript.ITEM_IDS.has(item_id):
			stock.append(item_id)
	if stock.is_empty():
		var pool: Array = MerchantDataScript.ITEM_IDS.duplicate()
		while stock.size() < 3 and not pool.is_empty():
			var pool_index := rng.randi_range(0, pool.size() - 1)
			stock.append(str(pool[pool_index]))
			pool.remove_at(pool_index)
		board.tiles[cell]["merchant_stock"] = stock
	if hud != null:
		hud.show_merchant_shop(stock)

func _on_merchant_item_selected(index: int) -> void:
	if game_over or not board.has_cell(merchant_shop_cell):
		return
	var cell := merchant_shop_cell
	var tile: Dictionary = board.tiles[cell]
	var stock: Array = tile.get("merchant_stock", [])
	if not bool(tile.get("merchant_active", false)) or index < 0 or index >= stock.size():
		return
	var item_id := str(stock[index])
	if not MerchantDataScript.CARD_IDS.has(item_id):
		return
	if item_inventory.size() >= 8:
		last_message = "卡片背包已满，最多携带 8 张卡片。"
		_update_hud()
		return
	if gold[PLAYER] < Config.MERCHANT_ITEM_COST:
		last_message = "金币不足，卡片需要 %d 金币。" % Config.MERCHANT_ITEM_COST
		_update_hud()
		return
	gold[PLAYER] -= Config.MERCHANT_ITEM_COST
	var item_origin := hud.get_merchant_item_screen_position(index)
	stock.remove_at(index)
	tile["merchant_stock"] = stock
	item_inventory.append(item_id)
	hud.set_item_inventory(item_inventory, item_id, item_origin)
	last_message = "获得卡片：%s，已收入卡片背包。拖动卡片到目标地块使用。" % MerchantDataScript.get_item_name(item_id)
	if stock.is_empty():
		_dismiss_merchant(cell)
	else:
		hud.show_merchant_shop(stock)
	_refresh_purchase_cells()
	_update_hud()
	board.queue_redraw()

func _dismiss_merchant(cell: Vector2i) -> void:
	if not board.has_cell(cell):
		return
	var tile: Dictionary = board.tiles[cell]
	if int(tile.get("building", EMPTY)) == MERCHANT or bool(tile.get("merchant_active", false)):
		tile["merchant_active"] = false
		tile["merchant_stock"] = []
		tile["ground_item_id"] = ""
		board.destroy_building(cell)
	if merchant_shop_cell == cell:
		merchant_shop_cell = INVALID_CELL
		if hud != null:
			hud.hide_merchant_shop()
	board.queue_redraw()

func _on_merchant_dismissed() -> void:
	if game_over or merchant_shop_cell == INVALID_CELL:
		return
	_dismiss_merchant(merchant_shop_cell)
	last_message = "商人已被驱赶。"
	_update_hud()

func _on_inventory_item_dropped(item_id: String, screen_position: Vector2) -> void:
	if game_over or not MerchantDataScript.is_card(item_id) or not item_inventory.has(item_id):
		return
	var canvas_world := get_viewport().get_canvas_transform().affine_inverse() * screen_position
	var board_position := board.to_local(canvas_world)
	var target_cell := board.world_to_axial(board_position)
	if not board.has_cell(target_cell):
		last_message = "请将卡片拖到地图上的目标地块。"
		_update_hud()
		return
	active_item_id = item_id
	active_item_cell = INVALID_CELL
	_try_use_active_item(target_cell)
	if active_item_id == item_id and active_item_cell == INVALID_CELL:
		_clear_active_item()

func _try_use_active_item(target_cell: Vector2i) -> void:
	if active_item_id.is_empty():
		return
	var inventory_item := active_item_cell == INVALID_CELL
	if inventory_item:
		if not item_inventory.has(active_item_id):
			_clear_active_item("卡片已不可用。")
			return
	else:
		if not board.has_cell(active_item_cell):
			_clear_active_item("地面卡片已不可用。")
			return
		var source_tile: Dictionary = board.tiles[active_item_cell]
		if str(source_tile.get("ground_item_id", "")) != active_item_id or int(source_tile.get("owner", EMPTY)) != PLAYER:
			_clear_active_item("地面卡片已不可用。")
			return
		if target_cell == active_item_cell:
			_clear_active_item("已取消卡片使用。")
			return
	if not board.has_cell(target_cell) or is_bombardment_locked(target_cell) or _is_card_land_loss_locked(target_cell):
		last_message = "该地块当前无法使用卡片。"
		_update_hud()
		return
	var used := false
	var replacement_card_id := ""
	if MerchantDataScript.is_sealed_barracks_card(active_item_id):
		var sealed_tile: Dictionary = board.tiles[target_cell]
		if target_cell != player_hq and target_cell != ai_hq and bool(sealed_tile.get("revealed", false)) and int(sealed_tile.get("owner", EMPTY)) == PLAYER and int(sealed_tile.get("building", EMPTY)) == EMPTY and not bool(sealed_tile.get("monster_active", false)) and str(sealed_tile.get("ground_item_id", "")).is_empty():
			var sealed_level := MerchantDataScript.get_sealed_barracks_level(active_item_id)
			var sealed_class := MerchantDataScript.get_sealed_barracks_class(active_item_id)
			board.set_building(target_cell, BARRACKS, sealed_level, sealed_class)
			_spawn_initial_barracks_unit(PLAYER, target_cell)
			_register_building(PLAYER)
			used = true
	else:
		match active_item_id:
			MerchantDataScript.ITEM_DRAGON:
				if _is_enemy_building(target_cell, PLAYER):
					board.destroy_building(target_cell)
					_check_building_result()
					used = true
			MerchantDataScript.ITEM_UPGRADE:
				if bool(board.tiles[target_cell].get("revealed", false)) and int(board.tiles[target_cell].get("owner", EMPTY)) == PLAYER and int(board.tiles[target_cell].get("building", EMPTY)) == BARRACKS:
					var level := board.get_building_level(target_cell)
					if level < MAX_BARRACKS_LEVEL:
						var production_count := board.get_production_count(target_cell)
						var build_timer := board.get_build_timer(target_cell)
						board.set_building(target_cell, BARRACKS, level + 1, board.get_building_unit_class(target_cell))
						board.set_production_count(target_cell, production_count)
						board.update_build_timer(target_cell, build_timer)
						_play_barracks_upgrade_effect(target_cell, level + 1)
						used = true
			MerchantDataScript.ITEM_STEEL_BARRIER:
				if bool(board.tiles[target_cell].get("revealed", false)) and int(board.tiles[target_cell].get("owner", EMPTY)) == PLAYER and int(board.tiles[target_cell].get("building", EMPTY)) == EMPTY and str(board.tiles[target_cell].get("ground_item_id", "")).is_empty() and not bool(board.tiles[target_cell].get("monster_active", false)):
					board.set_building(target_cell, STEEL_BARRIER, 1)
					board.set_tile_owner(target_cell, PLAYER, true)
					_register_building(PLAYER)
					used = true
			MerchantDataScript.ITEM_BLIZZARD:
				for unit in units:
					if is_instance_valid(unit) and unit.faction == AI and board.cube_distance(unit.cell, target_cell) <= Config.MERCHANT_STORM_RADIUS:
						unit.freeze_for(Config.MERCHANT_STORM_DURATION)
				used = true
			MerchantDataScript.ITEM_TRANSFER_CERTIFICATE:
				if _is_enemy_building(target_cell, PLAYER) and int(board.tiles[target_cell].get("building", EMPTY)) == BARRACKS:
					board.set_tile_owner(target_cell, PLAYER, true)
					used = true
			MerchantDataScript.ITEM_OCCUPY:
				var occupy_tile: Dictionary = board.tiles[target_cell]
				if target_cell != player_hq and target_cell != ai_hq and int(occupy_tile.get("owner", EMPTY)) != PLAYER and not bool(occupy_tile.get("monster_active", false)) and bool(occupy_tile.get("revealed", false)):
					var occupy_level := 1
					if int(occupy_tile.get("building", EMPTY)) == BARRACKS:
						occupy_level = clampi(int(occupy_tile.get("building_level", 1)), 1, MAX_BARRACKS_LEVEL)
					board.set_building(target_cell, BARRACKS, occupy_level, _random_unit_class())
					board.set_tile_owner(target_cell, PLAYER, true)
					_register_building(PLAYER)
					used = true
			MerchantDataScript.ITEM_BUILD:
				if bool(board.tiles[target_cell].get("revealed", false)) and int(board.tiles[target_cell].get("owner", EMPTY)) == PLAYER and int(board.tiles[target_cell].get("building", EMPTY)) == EMPTY and not bool(board.tiles[target_cell].get("monster_active", false)) and str(board.tiles[target_cell].get("ground_item_id", "")).is_empty():
					board.set_building(target_cell, BARRACKS, 1, _random_unit_class())
					_spawn_initial_barracks_unit(PLAYER, target_cell)
					_register_building(PLAYER)
					used = true
			MerchantDataScript.ITEM_RECYCLE:
				replacement_card_id = _seal_barracks_with_recycle_card(target_cell)
				used = not replacement_card_id.is_empty()
	if used:
		var used_name := MerchantDataScript.get_item_name(active_item_id)
		if inventory_item:
			item_inventory.erase(active_item_id)
			if not replacement_card_id.is_empty() and item_inventory.size() < 8:
				item_inventory.append(replacement_card_id)
			hud.set_item_inventory(item_inventory)
		else:
			board.tiles[active_item_cell]["ground_item_id"] = ""
		_clear_active_item("已使用卡片：%s。" % used_name)
		_refresh_purchase_cells()
		board.queue_redraw()
	else:
		if active_item_id == MerchantDataScript.ITEM_RECYCLE:
			last_message = "回收卡必须拖到一座兵营上使用。"
		else:
			last_message = "该卡片无法对这个目标使用。"
		_update_hud()

func _seal_barracks_with_recycle_card(target_cell: Vector2i) -> String:
	if not board.has_cell(target_cell) or target_cell == player_hq or target_cell == ai_hq:
		return ""
	if is_bombardment_locked(target_cell) or _is_card_land_loss_locked(target_cell):
		return ""
	var tile: Dictionary = board.tiles[target_cell]
	if not bool(tile.get("revealed", false)) or int(tile.get("building", EMPTY)) != BARRACKS:
		return ""
	var recycle_level := board.get_building_level(target_cell)
	var recycle_class := board.get_building_unit_class(target_cell)
	var sealed_card_id := MerchantDataScript.make_sealed_barracks_card(recycle_level, recycle_class)
	var recycle_owner := int(tile.get("owner", EMPTY))
	for unit in units:
		if not is_instance_valid(unit) or unit.home_cell != target_cell:
			continue
		unit.home_cell = player_hq if recycle_owner == PLAYER else ai_hq
		unit.destination = unit.home_cell
	board.set_building(target_cell, EMPTY)
	return sealed_card_id

func _clear_active_item(message: String = "") -> void:
	active_item_id = ""
	active_item_cell = INVALID_CELL
	if not message.is_empty():
		last_message = message
		_update_hud()

func _building_name(building: int) -> String:
	match building:
		MINE:
			return "金矿"
		BARRACKS:
			return "兵营"
		TOWER:
			return "箭塔"
		STEEL_BARRIER:
			return "钢铁屏障"
	return "空地"

func _is_combat_building(building: int) -> bool:
	return building == MINE or building == BARRACKS or building == TOWER or building == STEEL_BARRIER

func _is_adjacent_to_owner(cell: Vector2i, owner: int) -> bool:
	for neighbor in board.neighbors(cell):
		var tile: Dictionary = board.tiles[neighbor]
		if bool(tile["revealed"]) and int(tile["owner"]) == owner:
			return true
	return false

func _is_reveal_locked(cell: Vector2i) -> bool:
	return fate_locked_cells.has(cell) or pending_reveals.has(cell) or board.is_tile_reveal_active(cell) or is_bombardment_locked(cell) or _is_card_land_loss_locked(cell)

func _register_building(owner: int) -> void:
	if owner == PLAYER or owner == AI:
		established_buildings[owner] = true

func _count_buildings(owner: int) -> int:
	var count := 0
	for cell in board.tiles:
		var tile: Dictionary = board.tiles[cell]
		if int(tile["owner"]) == owner and _is_combat_building(int(tile["building"])):
			count += 1
	return count

func _refresh_purchase_cells() -> void:
	var candidates: Array[Vector2i] = []
	for cell in board.tiles:
		var tile: Dictionary = board.tiles[cell]
		if bool(tile["revealed"]) or _is_reveal_locked(cell):
			continue
		if _is_adjacent_to_owner(cell, PLAYER):
			candidates.append(cell)
	board.set_purchasable_cells(candidates)

func _process_economy(delta: float) -> void:
	income_timer += delta
	if income_timer >= Config.GOLD_INCOME_INTERVAL:
		var payout_count := int(floor(income_timer / Config.GOLD_INCOME_INTERVAL))
		income_timer -= float(payout_count) * Config.GOLD_INCOME_INTERVAL
		for owner in [PLAYER, AI]:
			gold[owner] += Config.BASE_GOLD_INCOME * float(payout_count)

	mine_income_timer += delta
	if mine_income_timer < Config.MINE_INCOME_INTERVAL:
		return
	var mine_payout_count := int(floor(mine_income_timer / Config.MINE_INCOME_INTERVAL))
	mine_income_timer -= float(mine_payout_count) * Config.MINE_INCOME_INTERVAL
	for cell in board.tiles:
		var tile: Dictionary = board.tiles[cell]
		if bool(tile["revealed"]) and int(tile["building"]) == MINE:
			var owner: int = int(tile["owner"])
			if owner == PLAYER or owner == AI:
				gold[owner] += Config.MINE_GOLD_INCOME * float(mine_payout_count)

func _produce_barracks_unit(cell: Vector2i) -> bool:
	if not board.has_cell(cell):
		return false
	if is_bombardment_locked(cell):
		return false
	var tile: Dictionary = board.tiles[cell]
	var owner: int = int(tile["owner"])
	if int(tile["building"]) != BARRACKS or (owner != PLAYER and owner != AI):
		return false
	if _count_active_units(owner) >= Config.MAX_ACTIVE_UNITS_PER_FACTION:
		return false
	var capacity := board.get_building_level(cell)
	if _count_barracks_units(cell, owner) >= capacity:
		return false
	var unit := _spawn_unit(owner, cell, capacity, board.get_building_unit_class(cell))
	if not _has_enemy_in_barracks_range(cell, owner):
		unit.begin_garrison()
	board.set_production_count(cell, _count_barracks_units(cell, owner))
	return true

func _count_active_units(owner: int) -> int:
	var count := 0
	for unit in units:
		if is_instance_valid(unit) and unit.faction == owner:
			count += 1
	return count

func _count_barracks_units(cell: Vector2i, owner: int) -> int:
	var count := 0
	for unit in units:
		if not is_instance_valid(unit) or unit.faction != owner or unit.home_cell != cell:
			continue
		count += 1
	return count

func _reassign_barracks_units(from_cell: Vector2i, to_cell: Vector2i) -> void:
	for unit in units:
		if not is_instance_valid(unit) or unit.home_cell != from_cell:
			continue
		unit.home_cell = to_cell
		unit.destination = to_cell

func _reset_barracks_production_timer(cell: Vector2i) -> void:
	if not board.has_cell(cell) or int(board.tiles[cell].get("building", EMPTY)) != BARRACKS:
		return
	var owner := int(board.tiles[cell].get("owner", EMPTY))
	var capacity := board.get_building_level(cell)
	if owner == PLAYER or owner == AI:
		board.update_build_timer(cell, 0.0 if _count_barracks_units(cell, owner) >= capacity else Config.BARRACKS_PRODUCTION_INTERVAL)
	else:
		board.update_build_timer(cell, Config.BARRACKS_PRODUCTION_INTERVAL)

func _has_enemy_in_barracks_range(cell: Vector2i, faction: int) -> bool:
	if _nearest_enemy(cell, faction, float(Config.BARRACKS_DETECTION_RANGE)) != null:
		return true
	if board.has_cell(_nearest_enemy_building(cell, faction, Config.BARRACKS_DETECTION_RANGE)):
		return true
	if _nearest_wild_monster(cell, float(Config.BARRACKS_DETECTION_RANGE)) != null:
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
		if is_bombardment_locked(cell):
			continue
		var level := board.get_building_level(cell)
		var unit_count := _count_barracks_units(cell, owner)
		board.set_production_count(cell, unit_count)
		var timer := board.get_build_timer(cell)
		if unit_count >= level:
			timer = 0.0
		else:
			timer = maxf(0.0, timer - delta)
			if timer <= 0.0 and _produce_barracks_unit(cell):
				unit_count = _count_barracks_units(cell, owner)
				timer = 0.0 if unit_count >= level else barracks_interval(level)
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
	if unit.is_frozen():
		return
	var target: Dictionary = _locked_monster_target(unit)
	if target.is_empty():
		target = _nearest_combat_target(unit.cell, unit.faction, float(Config.BARRACKS_DETECTION_RANGE))
		if str(target.get("kind", "")) == "monster":
			unit.set_monster_target(target["node"])
	if unit.returning_home:
		if target.is_empty():
			if board.has_cell(unit.home_cell):
				unit.move_directly_to(board.axial_to_world(unit.home_cell), delta)
			else:
				recycle_returning_unit(unit)
			return
		unit.cancel_return_home()

	if unit.garrisoned:
		if not _is_valid_barracks_home(unit):
			unit.leave_garrison()
		elif target.is_empty():
			unit.move_to_garrison_door(delta)
			return
		else:
			unit.leave_garrison()

	if target.is_empty() and _is_valid_barracks_home(unit):
		unit.begin_garrison()
		unit.move_to_garrison_door(delta)
		return

	if not target.is_empty():
		var target_distance := float(target["distance"])
		match str(target["kind"]):
			"unit":
				var enemy: BattleUnit = target["node"]
				if target_distance <= unit.attack_range:
					if unit.can_attack():
						if unit.is_ranged:
							_fire_bullet(unit, enemy)
						else:
							_play_melee_attack_effect(unit.position, enemy.position)
							enemy.take_damage(unit.attack)
						unit.mark_attack()
					return
				unit.move_directly_to(enemy.position, delta)
			"building":
				var building_cell: Vector2i = target["cell"]
				if target_distance <= unit.attack_range:
					if unit.can_attack():
						if unit.is_ranged:
							_fire_building_bullet(unit, building_cell)
						else:
							_play_melee_attack_effect(unit.position, board.axial_to_world(building_cell))
							damage_building(building_cell, unit.attack, unit.faction)
						unit.mark_attack()
					return
				unit.move_directly_to(board.axial_to_world(building_cell), delta)
			"monster":
				var monster: WildMonster = target["node"]
				if target_distance <= unit.attack_range:
					if unit.can_attack():
						if unit.is_ranged:
							_fire_bullet(unit, monster)
						else:
							_play_melee_attack_effect(unit.position, monster.position)
							monster.take_damage(unit.attack, unit)
						unit.mark_attack()
					return
				unit.move_directly_to(monster.position, delta)
			"hq":
				var enemy_hq: Vector2i = target["cell"]
				if unit.cell == enemy_hq:
					if unit.can_attack():
						if not unit.is_ranged:
							_play_melee_attack_effect(unit.position, board.axial_to_world(enemy_hq))
						base_hp[3 - unit.faction] -= unit.attack
						unit.mark_attack()
						_check_hq_result()
					return
				unit.move_directly_to(board.axial_to_world(enemy_hq), delta)
		return
	var enemy_hq := ai_hq if unit.faction == PLAYER else player_hq
	if unit.cell == enemy_hq:
		if unit.can_attack():
			if not unit.is_ranged:
				_play_melee_attack_effect(unit.position, board.axial_to_world(enemy_hq))
			base_hp[3 - unit.faction] -= unit.attack
			unit.mark_attack()
			_check_hq_result()
		return
	unit.move_directly_to(board.axial_to_world(enemy_hq), delta)

func _is_valid_barracks_home(unit: BattleUnit) -> bool:
	if not board.has_cell(unit.home_cell):
		return false
	var tile: Dictionary = board.tiles[unit.home_cell]
	return bool(tile.get("revealed", false)) and int(tile.get("owner", EMPTY)) == unit.faction and int(tile.get("building", EMPTY)) == BARRACKS

func _nearest_combat_target(cell: Vector2i, faction: int, max_distance: float) -> Dictionary:
	var result: Dictionary = {}
	var best_distance := INF
	var best_priority := 99
	for other_unit in units:
		if not is_instance_valid(other_unit) or other_unit.faction == faction:
			continue
		var distance := float(board.cube_distance(cell, other_unit.cell))
		if distance > max_distance or (distance > best_distance or distance == best_distance and best_priority <= 0):
			continue
		best_distance = distance
		best_priority = 0
		result = {"kind": "unit", "node": other_unit, "cell": other_unit.cell, "distance": distance}
	for other_cell in board.tiles:
		var tile: Dictionary = board.tiles[other_cell]
		var owner: int = int(tile["owner"])
		var building: int = int(tile["building"])
		if not bool(tile["revealed"]) or owner == faction or is_bombardment_locked(other_cell):
			continue
		if not _is_combat_building(building):
			continue
		var distance := float(board.cube_distance(cell, other_cell))
		if distance > max_distance or (distance > best_distance or distance == best_distance and best_priority <= 1):
			continue
		best_distance = distance
		best_priority = 1
		result = {"kind": "building", "cell": other_cell, "distance": distance}
	for monster in monsters:
		if not is_instance_valid(monster):
			continue
		var distance := float(board.cube_distance(cell, monster.cell))
		if distance > max_distance or (distance > best_distance or distance == best_distance and best_priority <= 2):
			continue
		best_distance = distance
		best_priority = 2
		result = {"kind": "monster", "node": monster, "cell": monster.cell, "distance": distance}
	var enemy_hq := ai_hq if faction == PLAYER else player_hq
	var hq_distance := float(board.cube_distance(cell, enemy_hq))
	if hq_distance <= max_distance and (hq_distance < best_distance or hq_distance == best_distance and best_priority > 3):
		result = {"kind": "hq", "cell": enemy_hq, "distance": hq_distance}
	return result

func _locked_monster_target(unit: BattleUnit) -> Dictionary:
	var monster: Node = unit.monster_target
	if not is_instance_valid(monster) or not monster is WildMonster or not monsters.has(monster):
		unit.clear_monster_target()
		return {}
	var wild_monster: WildMonster = monster
	var distance := float(board.cube_distance(unit.cell, wild_monster.cell))
	if distance > float(Config.BARRACKS_DETECTION_RANGE):
		unit.clear_monster_target()
		return {}
	return {"kind": "monster", "node": wild_monster, "cell": wild_monster.cell, "distance": distance}

func _has_nearby_combat_target(cell: Vector2i, faction: int) -> bool:
	return not _nearest_combat_target(cell, faction, float(Config.BARRACKS_DETECTION_RANGE)).is_empty()

func unit_arrived(unit: BattleUnit) -> void:
	if not is_instance_valid(unit) or not units.has(unit):
		return
	if unit.returning_home:
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
			if is_bombardment_locked(unit.cell):
				return
			var destroyed_building := int(tile["building"])
			board.destroy_building(unit.cell)
			if hud != null:
				hud.flash_building_damage()
			if unit.faction == PLAYER:
				last_message = "我方士兵摧毁了敌方%s。" % _building_name(destroyed_building)
			_check_building_result()
		if _nearest_enemy(unit.cell, unit.faction, 0.0) == null:
			if occupant != unit.faction:
				tile["merchant_active"] = false
				tile["merchant_stock"] = []
				tile["ground_item_id"] = ""
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

func _nearest_wild_monster(cell: Vector2i, max_distance: float = -1.0) -> WildMonster:
	var result: WildMonster
	var best := INF
	for monster in monsters:
		if not is_instance_valid(monster):
			continue
		var distance := float(board.cube_distance(cell, monster.cell))
		if max_distance >= 0.0 and distance > max_distance:
			continue
		if distance < best:
			best = distance
			result = monster
	return result

func _nearest_monster_attacker(monster: WildMonster) -> BattleUnit:
	var result: BattleUnit
	var best := INF
	for unit in units:
		if not is_instance_valid(unit) or not unit.is_targeting_monster(monster):
			continue
		var distance := float(board.cube_distance(unit.cell, monster.cell))
		if distance > float(Config.WILD_MONSTER_ATTACK_RANGE) or distance >= best:
			continue
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
		if not bool(tile["revealed"]) or owner == faction or is_bombardment_locked(other_cell) or not _is_combat_building(building):
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
	_ensure_dynamic_layer(units_layer, "Units").add_child(unit)
	unit.setup(owner, cell, self, barracks_level, unit_class)
	units.append(unit)
	return unit

func _spawn_initial_barracks_unit(owner: int, cell: Vector2i) -> bool:
	if owner != PLAYER and owner != AI:
		return false
	if not board.has_cell(cell) or int(board.tiles[cell].get("building", EMPTY)) != BARRACKS:
		return false
	var level := board.get_building_level(cell)
	var unit_count := _count_barracks_units(cell, owner)
	if unit_count < level and _count_active_units(owner) < Config.MAX_ACTIVE_UNITS_PER_FACTION:
		var unit := _spawn_unit(owner, cell, level, board.get_building_unit_class(cell))
		if not _has_enemy_in_barracks_range(cell, owner):
			unit.begin_garrison()
		unit_count += 1
	board.set_production_count(cell, unit_count)
	board.update_build_timer(cell, 0.0 if unit_count >= level else Config.BARRACKS_PRODUCTION_INTERVAL)
	return unit_count > 0

func _spawn_monster(cell: Vector2i) -> WildMonster:
	var monster: WildMonster = MonsterScript.new()
	_ensure_dynamic_layer(units_layer, "Units").add_child(monster)
	monster.setup(cell, self, int(board.tiles[cell]["owner"]))
	monsters.append(monster)
	board.tiles[cell]["monster_active"] = true
	return monster

func _fire_bullet(unit: BattleUnit, target: Node2D) -> void:
	var bullet = BulletScript.new()
	_ensure_dynamic_layer(units_layer, "Units").add_child(bullet)
	bullet.setup(unit.position, target, unit.attack, self, unit)

func _play_melee_attack_effect(start_position: Vector2, target_position: Vector2) -> void:
	var effect = MeleeAttackEffectScript.new()
	_ensure_dynamic_layer(units_layer, "Units").add_child(effect)
	effect.call("setup", start_position, target_position)

func _play_barracks_upgrade_effect(cell: Vector2i, level: int) -> void:
	if not board.has_cell(cell) or not is_instance_valid(upgrade_effects):
		return
	var effect: Node2D = BarracksUpgradeEffectScript.new()
	_ensure_dynamic_layer(upgrade_effects, "UpgradeEffects").add_child(effect)
	effect.setup(board.axial_to_world(cell), level)

func process_monster(monster: WildMonster, _delta: float) -> void:
	if not is_instance_valid(monster) or not monsters.has(monster):
		return
	var target := _nearest_monster_attacker(monster)
	if target == null or not monster.can_attack():
		return
	_play_monster_attack_effect(monster.position, target.position)
	target.take_damage(Config.WILD_MONSTER_ATTACK)
	monster.mark_attack()

func _play_monster_attack_effect(start_position: Vector2, target_position: Vector2) -> void:
	var effect: MonsterAttackEffect = MonsterAttackEffectScript.new()
	_ensure_dynamic_layer(units_layer, "Units").add_child(effect)
	effect.setup(start_position, target_position)

func remove_monster(monster: WildMonster, killer: Node = null) -> void:
	if not monsters.has(monster):
		return
	var defeated_cell := monster.cell
	var drop_owner := monster.drop_owner
	for unit in units:
		if is_instance_valid(unit) and unit.is_targeting_monster(monster):
			unit.clear_monster_target()
	monsters.erase(monster)
	if board.has_cell(defeated_cell):
		board.set_building(defeated_cell, EMPTY)
		board.set_tile_owner(defeated_cell, drop_owner, true)
		board.tiles[defeated_cell]["monster_active"] = false
		board.tiles[defeated_cell]["rebuildable"] = false
	if is_instance_valid(monster):
		monster.queue_free()
	if drop_owner == PLAYER or drop_owner == AI:
		_play_equipment_drop(drop_owner, _random_equipment_id(), board.axial_to_world(defeated_cell))
	if killer is BattleUnit and units.has(killer):
		var killer_unit: BattleUnit = killer
		if not _has_nearby_combat_target(killer_unit.cell, killer_unit.faction):
			killer_unit.begin_return_home()
	_refresh_purchase_cells()
	board.queue_redraw()

func _random_equipment_id() -> String:
	return EquipmentDataScript.ITEM_IDS[rng.randi_range(0, EquipmentDataScript.ITEM_IDS.size() - 1)]

func _play_equipment_drop(owner: int, equipment_id: String, drop_position: Vector2) -> void:
	var effect: EquipmentDropEffect = EquipmentDropEffectScript.new()
	_ensure_dynamic_layer(equipment_effects, "EquipmentEffects").add_child(effect)
	effect.setup(equipment_id, drop_position)
	effect.landed.connect(_on_equipment_drop_landed.bind(owner, equipment_id, drop_position))

func _on_equipment_drop_landed(owner: int, equipment_id: String, drop_position: Vector2) -> void:
	if not game_over:
		grant_equipment(owner, equipment_id, drop_position)

func grant_equipment(owner: int, equipment_id: String, drop_position := Vector2.ZERO) -> void:
	if (owner != PLAYER and owner != AI) or not EquipmentDataScript.is_valid_item(equipment_id):
		return
	var item: Dictionary = EquipmentDataScript.get_item(equipment_id)
	var slot := int(item["slot_index"])
	var current_id := str(equipped_items[owner][slot])
	if owner == PLAYER and not current_id.is_empty():
		equipment_drop_queue.append({"id": equipment_id, "drop_position": drop_position})
		_process_equipment_drop_queue()
		return
	_equipment_set(owner, slot, equipment_id, drop_position)
	if owner == PLAYER:
		last_message = "获得装备：%s。" % item["name"]

func _process_equipment_drop_queue() -> void:
	if not pending_equipment_replacement.is_empty():
		return
	while not equipment_drop_queue.is_empty():
		var drop: Dictionary = equipment_drop_queue.pop_front()
		var equipment_id := str(drop.get("id", ""))
		var drop_position: Vector2 = drop.get("drop_position", Vector2.ZERO)
		var item: Dictionary = EquipmentDataScript.get_item(equipment_id)
		if item.is_empty():
			continue
		var slot := int(item["slot_index"])
		var current_id := str(equipped_items[PLAYER][slot])
		if current_id.is_empty():
			_equipment_set(PLAYER, slot, equipment_id, drop_position)
			last_message = "获得装备：%s，已自动装备。" % item["name"]
			continue
		pending_equipment_replacement = {
			"slot": slot,
			"current_id": current_id,
			"new_id": equipment_id,
			"drop_position": drop_position
		}
		hud.show_equipment_replacement(current_id, equipment_id)
		break

func resolve_equipment_replacement(replace_item: bool) -> void:
	if pending_equipment_replacement.is_empty():
		return
	var pending: Dictionary = pending_equipment_replacement.duplicate()
	pending_equipment_replacement.clear()
	if replace_item:
		_equipment_set(PLAYER, int(pending["slot"]), str(pending["new_id"]), pending.get("drop_position", Vector2.ZERO))
		last_message = "已替换为装备：%s。" % EquipmentDataScript.get_item(str(pending["new_id"]))["name"]
	else:
		last_message = "已丢弃新装备：%s。" % EquipmentDataScript.get_item(str(pending["new_id"]))["name"]
	hud.hide_equipment_replacement()
	_process_equipment_drop_queue()

func get_equipped_item(owner: int, slot: int) -> String:
	if (owner != PLAYER and owner != AI) or slot < 0 or slot >= EquipmentDataScript.SLOT_NAMES.size():
		return ""
	return str(equipped_items[owner][slot])

func _equipment_set(owner: int, slot: int, equipment_id: String, drop_position := Vector2.ZERO) -> void:
	if slot < 0 or slot >= EquipmentDataScript.SLOT_NAMES.size() or not EquipmentDataScript.is_valid_item(equipment_id):
		return
	equipped_items[owner][slot] = equipment_id
	if owner == PLAYER and hud != null:
		hud.refresh_equipment(equipped_items[PLAYER])
		if drop_position != Vector2.ZERO:
			hud.play_equipment_fly_in(equipment_id, drop_position)

func _fire_building_bullet(unit: BattleUnit, target_cell: Vector2i) -> void:
	var bullet = BulletScript.new()
	_ensure_dynamic_layer(units_layer, "Units").add_child(bullet)
	var target_owner: int = int(board.tiles[target_cell]["owner"])
	bullet.setup_building(unit.position, target_cell, unit.attack, target_owner, self, unit)

func damage_building(cell: Vector2i, amount: float, attacker_owner := 0) -> void:
	if not board.has_cell(cell):
		return
	if is_bombardment_locked(cell):
		return
	var tile: Dictionary = board.tiles[cell]
	var building: int = int(tile["building"])
	if not _is_combat_building(building):
		return
	var hp := board.get_building_hp(cell) - amount
	if hp <= 0.0:
		board.destroy_building(cell)
		if attacker_owner == PLAYER:
			last_message = "我方士兵摧毁了敌方%s。" % _building_name(building)
	else:
		board.set_building_hp(cell, hp)
	if hud != null:
		hud.flash_building_damage()
	_check_building_result()
	board.queue_redraw()

func remove_unit(unit: BattleUnit) -> void:
	var home_cell := unit.home_cell if is_instance_valid(unit) else INVALID_CELL
	if units.has(unit):
		units.erase(unit)
	if board.has_cell(home_cell) and int(board.tiles[home_cell].get("building", EMPTY)) == BARRACKS:
		board.set_production_count(home_cell, _count_barracks_units(home_cell, int(board.tiles[home_cell].get("owner", EMPTY))))
		board.update_build_timer(home_cell, 0.0)
	if is_instance_valid(unit):
		unit.queue_free()

func recycle_returning_unit(unit: BattleUnit) -> void:
	if not is_instance_valid(unit) or not units.has(unit):
		return
	if _is_valid_barracks_home(unit):
		unit.begin_garrison()
		return
	units.erase(unit)
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
	hud.clear_card_events()
	hud.clear_divination_events()
	hud.hide_intelligence_news()
	hud.reset_cat_companion()
	hud.hide_merchant_shop()
	merchant_shop_cell = INVALID_CELL
	_clear_active_item()
	equipment_drop_queue.clear()
	pending_equipment_replacement.clear()
	if card_land_loss_tween != null and card_land_loss_tween.is_valid():
		card_land_loss_tween.kill()
	if intelligence_building_drop_tween != null and intelligence_building_drop_tween.is_valid():
		intelligence_building_drop_tween.kill()
	if divination_tween != null and divination_tween.is_valid():
		divination_tween.kill()
	pending_card_land_loss.clear()
	card_land_loss_queue.clear()
	pending_intelligence_building_drop.clear()
	intelligence_building_drop_queue.clear()
	pending_divinations.clear()
	divination_camera_active.clear()
	board.clear_card_land_loss_cell()
	board.intelligence_building_drop_animations.clear()
	hud.clear_equipment_state()
	hud.hide_bombardment_banner()
	hud.hide_world_broadcast()
	board.clear_bombardment_cells()
	board.clear_bombardment_warning_cells()
	_clear_effect_children(bombardment_effects)
	_clear_effect_children(upgrade_effects)
	_clear_effect_children(intelligence_effects)
	hud.show_result(message)

func _clear_effect_children(effect_layer) -> void:
	if not is_instance_valid(effect_layer):
		return
	for effect in effect_layer.get_children():
		if is_instance_valid(effect):
			effect.queue_free()

func _ensure_dynamic_layer(current_layer, layer_name: String) -> Node2D:
	if is_instance_valid(current_layer) and current_layer is Node2D:
		var active_layer := current_layer as Node2D
		if not active_layer.is_queued_for_deletion():
			return active_layer
	var replacement := Node2D.new()
	replacement.name = layer_name
	add_child(replacement)
	match layer_name:
		"Units":
			units_layer = replacement
		"FateEffects":
			fate_effects = replacement
		"BombardmentEffects":
			bombardment_effects = replacement
		"UpgradeEffects":
			upgrade_effects = replacement
		"IntelligenceEffects":
			intelligence_effects = replacement
	return replacement

func _update_hud() -> void:
	if hud == null:
		return
	var time_left := int(ceil(max(0.0, match_duration - elapsed)))
	var player_gold_value := int(gold[PLAYER])
	var ai_gold_value := int(gold[AI])
	var player_tiles := _count_owned(PLAYER)
	var ai_tiles := _count_owned(AI)
	if time_left == last_hud_time and player_gold_value == last_hud_player_gold and ai_gold_value == last_hud_ai_gold and player_tiles == last_hud_player_tiles and ai_tiles == last_hud_ai_tiles and is_equal_approx(base_hp[PLAYER], last_hud_player_hp) and is_equal_approx(base_hp[AI], last_hud_ai_hp) and last_message == last_hud_message:
		return
	board.set_player_gold(gold[PLAYER])
	hud.update_state(max(0.0, match_duration - elapsed), player_gold_value, ai_gold_value, base_hp[PLAYER], base_hp[AI], player_tiles, ai_tiles)
	if last_message != last_hud_message:
		hud.show_hint(last_message)
	last_hud_time = time_left
	last_hud_player_gold = player_gold_value
	last_hud_ai_gold = ai_gold_value
	last_hud_player_tiles = player_tiles
	last_hud_ai_tiles = ai_tiles
	last_hud_player_hp = base_hp[PLAYER]
	last_hud_ai_hp = base_hp[AI]
	last_hud_message = last_message
