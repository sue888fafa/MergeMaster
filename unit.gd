class_name BattleUnit
extends Node2D

const Config := preload("res://game_config.gd")

var faction := 1
var cell := Vector2i.ZERO
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
var is_ranged := false

func setup(owner: int, start_cell: Vector2i, controller: Node, source_level: int = 1, source_class: int = Config.UNIT_CLASS_WARRIOR) -> void:
	faction = owner
	cell = start_cell
	destination = start_cell
	main_ref = controller
	barracks_level = clampi(source_level, 1, 4)
	unit_class = clampi(source_class, 0, Config.UNIT_CLASS_COUNT - 1)
	max_hp = float(Config.UNIT_CLASS_BASE_HP[unit_class]) * float(barracks_level)
	hp = max_hp
	attack = float(Config.UNIT_CLASS_BASE_ATTACK[unit_class]) * float(barracks_level)
	move_speed = (Config.UNIT_BASE_MOVE_SPEED + Config.UNIT_LEVEL_MOVE_INCREMENT * float(barracks_level - 1)) * Config.UNIT_SPEED_SCALE
	attack_range = float(Config.UNIT_CLASS_ATTACK_RANGE[unit_class])
	attack_interval = float(Config.UNIT_CLASS_ATTACK_INTERVAL[unit_class])
	is_ranged = bool(Config.UNIT_CLASS_IS_RANGED[unit_class])
	position = main_ref.board.axial_to_world(cell)
	queue_redraw()

func _process(delta: float) -> void:
	if main_ref == null or main_ref.game_over:
		return
	attack_cooldown = max(0.0, attack_cooldown - delta)
	main_ref.process_unit(self, delta)
	queue_redraw()

func move_directly_to(target_position: Vector2, delta: float) -> void:
	destination = main_ref.board.world_to_axial(target_position)
	moving = true
	position = position.move_toward(target_position, move_speed * delta)
	var entered_cell: Vector2i = main_ref.board.world_to_axial(position)
	if main_ref.board.has_cell(entered_cell) and entered_cell != cell:
		cell = entered_cell
		main_ref.unit_arrived(self)
	if position.distance_to(target_position) < 1.0:
		position = target_position
		var final_cell: Vector2i = main_ref.board.world_to_axial(position)
		if main_ref.board.has_cell(final_cell) and final_cell != cell:
			cell = final_cell
			main_ref.unit_arrived(self)
		moving = false

func can_attack() -> bool:
	return attack_cooldown <= 0.0

func mark_attack() -> void:
	attack_cooldown = attack_interval

func take_damage(amount: float) -> void:
	hp -= amount
	if hp <= 0.0:
		main_ref.remove_unit(self)

func _draw() -> void:
	var body := _class_color()
	if faction == 2:
		body = body.darkened(0.18)
	draw_circle(Vector2.ZERO, 10.0, Color("#0f172a"))
	draw_circle(Vector2.ZERO, 7.0, body)
	if hp < max_hp:
		draw_rect(Rect2(-12, -17, 24, 3), Color("#0f172a"), true)
		draw_rect(Rect2(-12, -17, 24 * clamp(hp / max_hp, 0.0, 1.0), 3), Color("#4ade80"), true)

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
