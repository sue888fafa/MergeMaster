class_name BattleUnit
extends Node2D

const Config := preload("res://game_config.gd")

var faction := 1
var cell := Vector2i.ZERO
var home_cell := Vector2i.ZERO
var destination := Vector2i.ZERO
var hp := 36.0
var max_hp := 36.0
var attack := Config.UNIT_BASE_ATTACK
var move_speed := Config.UNIT_BASE_MOVE_SPEED * Config.UNIT_SPEED_SCALE
var attack_range := 2.0
var attack_cooldown := 0.0
var attack_interval := 3.0
var main_ref: Node
var moving := false
var barracks_level := 1
var unit_class := Config.UNIT_CLASS_WARRIOR
var profession_race := Config.UNIT_RACE_HORDE
var is_ranged := false
var returning_home := false
var garrisoned := false
var dispatched := false
var monster_target: Node = null
var combat_target: Dictionary = {}
var combat_target_refresh_timer := 0.0
var monster_interrupt_timer := 0.0
var frozen_until := 0.0

func setup(owner: int, start_cell: Vector2i, controller: Node, source_level: int = 1, source_class: int = Config.UNIT_CLASS_WARRIOR) -> void:
	faction = owner
	cell = start_cell
	home_cell = start_cell
	destination = start_cell
	main_ref = controller
	barracks_level = clampi(source_level, 1, 4)
	unit_class = clampi(source_class, 0, Config.UNIT_CLASS_COUNT - 1)
	profession_race = Config.get_unit_class_race(unit_class)
	max_hp = float(Config.UNIT_CLASS_BASE_HP[unit_class]) * float(barracks_level)
	hp = max_hp
	# Each barracks upgrade doubles attack power while keeping level 1 unchanged.
	attack = float(Config.UNIT_CLASS_BASE_ATTACK[unit_class]) * pow(2.0, float(barracks_level - 1))
	move_speed = (Config.UNIT_BASE_MOVE_SPEED + Config.UNIT_LEVEL_MOVE_INCREMENT * float(barracks_level - 1)) * Config.UNIT_SPEED_SCALE
	refresh_equipment_stats()
	attack_range = float(Config.UNIT_CLASS_ATTACK_RANGE[unit_class])
	attack_interval = float(Config.UNIT_CLASS_ATTACK_INTERVAL[unit_class])
	is_ranged = bool(Config.UNIT_CLASS_IS_RANGED[unit_class])
	returning_home = false
	garrisoned = false
	dispatched = false
	monster_target = null
	combat_target.clear()
	combat_target_refresh_timer = 0.0
	monster_interrupt_timer = 0.0
	frozen_until = 0.0
	position = main_ref.board.axial_to_world(cell)
	queue_redraw()

func get_profession_race() -> int:
	return profession_race

func get_profession_race_name() -> String:
	return Config.get_unit_class_race_name(unit_class)

func apply_barracks_level(source_level: int) -> void:
	var health_ratio := hp / max_hp if max_hp > 0.0 else 1.0
	barracks_level = clampi(source_level, 1, 4)
	max_hp = float(Config.UNIT_CLASS_BASE_HP[unit_class]) * float(barracks_level)
	hp = clampf(max_hp * health_ratio, 0.0, max_hp)
	attack = float(Config.UNIT_CLASS_BASE_ATTACK[unit_class]) * pow(2.0, float(barracks_level - 1))
	move_speed = (Config.UNIT_BASE_MOVE_SPEED + Config.UNIT_LEVEL_MOVE_INCREMENT * float(barracks_level - 1)) * Config.UNIT_SPEED_SCALE
	refresh_equipment_stats()
	queue_redraw()

func refresh_equipment_stats() -> void:
	var health_ratio := hp / max_hp if max_hp > 0.0 else 1.0
	var equipment_health := 0.0
	var equipment_attack := 0.0
	var equipment_speed := 0.0
	if main_ref != null and main_ref.has_method("_get_faction_equipment_bonus"):
		equipment_health = float(main_ref.call("_get_faction_equipment_bonus", faction, "health"))
		equipment_attack = float(main_ref.call("_get_faction_equipment_bonus", faction, "attack"))
		equipment_speed = float(main_ref.call("_get_faction_equipment_bonus", faction, "move_speed"))
	max_hp = float(Config.UNIT_CLASS_BASE_HP[unit_class]) * float(barracks_level) * (1.0 + equipment_health)
	hp = clampf(max_hp * health_ratio, 0.0, max_hp)
	attack = float(Config.UNIT_CLASS_BASE_ATTACK[unit_class]) * pow(2.0, float(barracks_level - 1)) * (1.0 + equipment_attack)
	move_speed = (Config.UNIT_BASE_MOVE_SPEED + Config.UNIT_LEVEL_MOVE_INCREMENT * float(barracks_level - 1)) * Config.UNIT_SPEED_SCALE * (1.0 + equipment_speed)

func set_monster_target(monster: Node) -> void:
	if is_instance_valid(monster):
		monster_target = monster

func clear_monster_target() -> void:
	monster_target = null

func invalidate_combat_target() -> void:
	combat_target.clear()
	combat_target_refresh_timer = 0.0

func is_targeting_monster(monster: Node) -> bool:
	return is_instance_valid(monster_target) and monster_target == monster

func freeze_for(duration: float) -> void:
	if main_ref == null:
		return
	frozen_until = maxf(frozen_until, float(main_ref.elapsed) + duration)
	queue_redraw()

func is_frozen() -> bool:
	return main_ref != null and float(main_ref.elapsed) < frozen_until

func begin_return_home() -> void:
	if returning_home:
		return
	garrisoned = false
	returning_home = true
	moving = true
	destination = home_cell
	queue_redraw()

func cancel_return_home() -> void:
	returning_home = false
	moving = false
	queue_redraw()

func begin_garrison() -> void:
	dispatched = false
	returning_home = false
	garrisoned = true
	moving = true
	destination = home_cell
	queue_redraw()

func leave_garrison() -> void:
	dispatched = true
	garrisoned = false
	moving = false
	queue_redraw()

func dispatch_from_barracks() -> void:
	# Once a soldier leaves the barracks, it becomes a persistent field unit.
	# New targets are still discovered only inside its barracks dispatch area;
	# the unit is never recalled automatically.
	dispatched = true
	returning_home = false
	garrisoned = false
	moving = false
	queue_redraw()

func move_to_garrison_door(delta: float) -> void:
	if main_ref == null:
		return
	var target_position: Vector2 = main_ref.board.axial_to_world(home_cell) + Config.BARRACKS_GARRISON_OFFSET
	position = position.move_toward(target_position, move_speed * delta)
	moving = position.distance_to(target_position) >= 1.0
	if not moving:
		position = target_position

func _process(delta: float) -> void:
	if main_ref == null or main_ref.game_over:
		return
	attack_cooldown = max(0.0, attack_cooldown - delta)
	main_ref.process_unit(self, delta)

func move_directly_to(target_position: Vector2, delta: float) -> void:
	moving = true
	position = position.move_toward(target_position, move_speed * delta)
	var entered_cell: Vector2i = main_ref.board.world_to_axial(position)
	if main_ref.board.has_cell(entered_cell) and entered_cell != cell:
		var old_cell := cell
		cell = entered_cell
		main_ref.on_unit_cell_changed(self, old_cell, cell)
		if not returning_home and not garrisoned:
			main_ref.unit_arrived(self)
	if position.distance_to(target_position) < 1.0:
		position = target_position
		var final_cell: Vector2i = main_ref.board.world_to_axial(position)
		if main_ref.board.has_cell(final_cell) and final_cell != cell:
			var old_cell := cell
			cell = final_cell
			main_ref.on_unit_cell_changed(self, old_cell, cell)
			if not returning_home and not garrisoned:
				main_ref.unit_arrived(self)
		moving = false
		if returning_home:
			main_ref.recycle_returning_unit(self)

func can_attack() -> bool:
	return attack_cooldown <= 0.0

func mark_attack() -> void:
	attack_cooldown = attack_interval

func take_damage(amount: float, _attacker: Node = null) -> void:
	hp -= amount
	queue_redraw()
	if hp <= 0.0:
		main_ref.remove_unit(self)

func _draw() -> void:
	var visual_scale: float = float(Config.UNIT_LEVEL_VISUAL_SCALE[clampi(barracks_level, 1, 4) - 1])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(visual_scale, visual_scale))
	var body: Color = main_ref.get_faction_color(faction) if main_ref != null and main_ref.has_method("get_faction_color") else (Color("#38bdf8") if faction == 1 else Color("#ef4444"))
	# A small humanoid silhouette reads more clearly as a soldier than a dot,
	# while keeping the same compact footprint on the hex tile.
	var outline := Color("#0f172a")
	draw_circle(Vector2(0.0, -6.0), 5.0, outline)
	draw_circle(Vector2(0.0, -6.0), 3.5, body.lightened(0.12))
	draw_rect(Rect2(-5.5, -1.0, 11.0, 10.0), outline, true)
	draw_rect(Rect2(-3.8, -1.0, 7.6, 7.8), body, true)
	draw_line(Vector2(-4.5, 1.0), Vector2(-9.0, 6.0), outline, 3.0, true)
	draw_line(Vector2(4.5, 1.0), Vector2(9.0, 6.0), outline, 3.0, true)
	draw_line(Vector2(-2.5, 8.0), Vector2(-4.5, 14.0), outline, 3.0, true)
	draw_line(Vector2(2.5, 8.0), Vector2(4.5, 14.0), outline, 3.0, true)
	_draw_class_signature(body, outline)
	if is_frozen():
		draw_arc(Vector2.ZERO, 19.0, 0.0, TAU, 20, Color(0.35, 0.9, 1.0, 0.82), 2.0, true)
		draw_line(Vector2(-13.0, -15.0), Vector2(-7.0, -21.0), Color("#cffafe"), 2.0, true)
		draw_line(Vector2(7.0, -21.0), Vector2(13.0, -15.0), Color("#cffafe"), 2.0, true)
	if hp < max_hp:
		draw_rect(Rect2(-12, -17, 24, 3), Color("#0f172a"), true)
		draw_rect(Rect2(-12, -17, 24 * clamp(hp / max_hp, 0.0, 1.0), 3), Color("#4ade80"), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_class_signature(body: Color, outline: Color) -> void:
	var detail := body.lightened(0.30)
	match unit_class:
		Config.UNIT_CLASS_TANK:
			# Shield: a broad, unmistakable defensive silhouette.
			draw_colored_polygon(PackedVector2Array([
				Vector2(-12.0, -2.0), Vector2(-7.0, -5.0), Vector2(-7.0, 5.0), Vector2(-12.0, 8.0)
			]), detail)
			draw_polyline(PackedVector2Array([Vector2(-12.0, -2.0), Vector2(-7.0, -5.0), Vector2(-7.0, 5.0), Vector2(-12.0, 8.0), Vector2(-12.0, -2.0)]), outline, 1.5, true)
		Config.UNIT_CLASS_WARRIOR:
			# Sword: a short diagonal blade held beside the body.
			draw_line(Vector2(6.0, 4.0), Vector2(13.0, -7.0), detail, 2.5, true)
			draw_line(Vector2(4.0, 3.0), Vector2(8.0, 6.0), outline, 2.0, true)
		Config.UNIT_CLASS_MAGE:
			# Staff and glowing orb.
			draw_line(Vector2(8.0, 8.0), Vector2(10.0, -14.0), outline, 2.0, true)
			draw_circle(Vector2(10.0, -16.0), 3.0, detail)
			draw_circle(Vector2(10.0, -16.0), 1.3, Color("#fef08a"))
		Config.UNIT_CLASS_ASSASSIN:
			# Twin compact daggers, angled away from the silhouette.
			draw_line(Vector2(-5.0, 4.0), Vector2(-12.0, -5.0), detail, 2.0, true)
			draw_line(Vector2(5.0, 4.0), Vector2(12.0, -5.0), detail, 2.0, true)
		Config.UNIT_CLASS_ARCHER:
			# Bow arc and a visible arrow.
			draw_arc(Vector2(8.0, 0.0), 7.0, -PI * 0.72, PI * 0.72, 10, detail, 1.8, true)
			draw_line(Vector2(8.0, -6.0), Vector2(8.0, 6.0), outline, 1.2, true)
			draw_line(Vector2(8.0, 0.0), Vector2(15.0, 0.0), detail, 1.5, true)

func _class_color() -> Color:
	match unit_class:
		Config.UNIT_CLASS_TANK:
			return Color("#94a3b8")
		Config.UNIT_CLASS_WARRIOR:
			return Color("#38bdf8")
		Config.UNIT_CLASS_MAGE:
			return Color("#f472b6")
		Config.UNIT_CLASS_ASSASSIN:
			return Color("#ef4444")
		Config.UNIT_CLASS_ARCHER:
			return Color("#4ade80")
	return Color("#38bdf8")
