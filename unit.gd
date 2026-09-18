class_name BattleUnit
extends Node2D

const Config := preload("res://game_config.gd")
const ATLAS_SHADER := preload("res://shaders/unit_atlas_multimesh.gdshader")
const UNIT_ART: Array[Texture2D] = [
	preload("res://assets/generated/unit_tank.png"),
	preload("res://assets/generated/unit_warrior.png"),
	preload("res://assets/generated/unit_mage.png"),
	preload("res://assets/generated/unit_assassin.png"),
	preload("res://assets/generated/unit_archer.png")
]
const UNIT_MASKS: Array[Texture2D] = [
	preload("res://assets/generated/unit_tank_mask.png"),
	preload("res://assets/generated/unit_warrior_mask.png"),
	preload("res://assets/generated/unit_mage_mask.png"),
	preload("res://assets/generated/unit_assassin_mask.png"),
	preload("res://assets/generated/unit_archer_mask.png")
]
# Atlas-cell order follows the authored six-direction strip. The second and
# fifth cells are the two diagonal views whose visual labels are opposite to
# their logical movement names, so the movement vectors are paired explicitly
# with the authored cells below. Keep this mapping in sync with the direction
# test and the runtime atlas assets.
const DIRECTION_VECTORS: Array[Vector2] = [
	Vector2(0.5, 0.8660254038),
	Vector2(0.5, -0.8660254038),
	Vector2(-1.0, 0.0),
	Vector2(-0.5, -0.8660254038),
	Vector2(-0.5, 0.8660254038),
	Vector2(1.0, 0.0)
]

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
var garrison_slot := -1
var dispatched := false
var monster_target: Node = null
var combat_target: Dictionary = {}
var combat_target_refresh_timer := 0.0
var has_fought_player := false
var monster_interrupt_timer := 0.0
var frozen_until := 0.0
var batch_rendered := false
var visual_elapsed := 0.0
var visual_action := "idle"
var visual_action_remaining := 0.0
var visual_direction := 0
var attack_facing_position := Vector2.ZERO
var attack_facing_active := false
var legacy_sprite: Sprite2D
var hit_flash_remaining := 0.0
const HIT_FLASH_DURATION := 0.12

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
	garrison_slot = -1
	dispatched = false
	monster_target = null
	combat_target.clear()
	combat_target_refresh_timer = 0.0
	has_fought_player = false
	monster_interrupt_timer = 0.0
	frozen_until = 0.0
	hit_flash_remaining = 0.0
	position = main_ref.board.get_cell_world_center(cell) if main_ref.board.has_method("get_cell_world_center") else main_ref.board.axial_to_world(cell)
	batch_rendered = get_parent() != null and get_parent().has_method("is_batch_unit_layer")
	visible = not batch_rendered
	_setup_legacy_sprite()
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
	attack_facing_active = false

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
	_release_garrison_slot()
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
	_allocate_garrison_slot()
	garrisoned = true
	moving = true
	destination = home_cell
	queue_redraw()

func leave_garrison() -> void:
	_release_garrison_slot()
	dispatched = true
	garrisoned = false
	moving = false
	queue_redraw()

func dispatch_from_barracks() -> void:
	# Once a soldier leaves the barracks, it becomes a persistent field unit.
	# New targets are still discovered only inside its barracks dispatch area;
	# the unit is never recalled automatically.
	_release_garrison_slot()
	dispatched = true
	returning_home = false
	garrisoned = false
	moving = false
	queue_redraw()

func move_to_garrison_door(delta: float) -> void:
	if main_ref == null:
		return
	var target_position: Vector2 = main_ref.get_barracks_garrison_position(home_cell, self) if main_ref.has_method("get_barracks_garrison_position") else main_ref.board.axial_to_world(home_cell) + Config.BARRACKS_GARRISON_OFFSET
	var previous_position := position
	position = position.move_toward(target_position, move_speed * delta)
	_update_visual_direction(position - previous_position)
	moving = position.distance_to(target_position) >= 1.0
	if not moving:
		position = target_position

func _allocate_garrison_slot() -> void:
	if garrison_slot >= 0 or main_ref == null or not main_ref.has_method("_allocate_barracks_garrison_slot"):
		return
	garrison_slot = int(main_ref.call("_allocate_barracks_garrison_slot", home_cell, self))

func _release_garrison_slot() -> void:
	if garrison_slot < 0:
		return
	if main_ref != null and main_ref.has_method("_release_barracks_garrison_slot"):
		main_ref.call("_release_barracks_garrison_slot", self)
	garrison_slot = -1

func _process(delta: float) -> void:
	if main_ref == null or main_ref.game_over:
		return
	visual_elapsed += delta
	visual_action_remaining = maxf(0.0, visual_action_remaining - delta)
	if hit_flash_remaining > 0.0:
		hit_flash_remaining = maxf(0.0, hit_flash_remaining - delta)
		if batch_rendered and is_instance_valid(main_ref) and main_ref.get("units_layer") != null:
			var visual_layer = main_ref.get("units_layer")
			if is_instance_valid(visual_layer) and visual_layer.has_method("request_visual_refresh"):
				visual_layer.call("request_visual_refresh")
		queue_redraw()
	attack_cooldown = max(0.0, attack_cooldown - delta)
	var previous_position := position
	main_ref.process_unit(self, delta)
	var movement := position - previous_position
	if movement.length_squared() > 0.01:
		_update_visual_direction(movement)
	if visual_action == "attack" and attack_facing_active:
		face_toward(attack_facing_position)
	if visual_action_remaining <= 0.0:
		attack_facing_active = false
		visual_action = "move" if moving else "idle"

func move_directly_to(target_position: Vector2, delta: float) -> void:
	moving = true
	var previous_position := position
	position = position.move_toward(target_position, move_speed * delta)
	# Update from the real world-space displacement, rather than from the
	# logical cell path. This keeps the sprite direction correct while moving
	# through a hex edge and also covers the last partial movement step.
	_update_visual_direction(position - previous_position)
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

func mark_attack(target_position: Vector2 = Vector2.ZERO) -> void:
	if target_position != Vector2.ZERO:
		attack_facing_position = target_position
		attack_facing_active = true
		face_toward(target_position)
	attack_cooldown = attack_interval
	visual_action = "attack"
	visual_action_remaining = 0.50
	visual_elapsed = 0.0

func mark_fought_player() -> void:
	if faction != Config.FACTION_PLAYER:
		has_fought_player = true
		queue_redraw()

func take_damage(amount: float, attacker: Node = null) -> void:
	if is_instance_valid(attacker) and attacker.get("faction") != null:
		var attacker_faction := int(attacker.get("faction"))
		if faction == Config.FACTION_PLAYER and attacker_faction != Config.FACTION_PLAYER:
			if attacker.has_method("mark_fought_player"):
				attacker.call("mark_fought_player")
		elif faction != Config.FACTION_PLAYER and attacker_faction == Config.FACTION_PLAYER:
			has_fought_player = true
		if faction == Config.FACTION_PLAYER or attacker_faction == Config.FACTION_PLAYER:
			hit_flash_remaining = HIT_FLASH_DURATION
	else:
		# Monster attacks do not carry a faction node, but damage to the player's
		# soldiers still needs the same hit feedback.
		if faction == Config.FACTION_PLAYER:
			hit_flash_remaining = HIT_FLASH_DURATION
	if batch_rendered and is_instance_valid(main_ref):
		var visual_layer = main_ref.get("units_layer")
		if is_instance_valid(visual_layer) and visual_layer.has_method("request_visual_refresh"):
			visual_layer.call("request_visual_refresh")
	hp -= amount
	visual_action = "death" if hp <= 0.0 else "hit"
	visual_action_remaining = 0.60 if hp <= 0.0 else 0.20
	visual_elapsed = 0.0
	queue_redraw()
	if hp <= 0.0:
		main_ref.remove_unit(self)

func _draw() -> void:
	if batch_rendered:
		return
	var visual_scale: float = float(Config.UNIT_LEVEL_VISUAL_SCALE[clampi(barracks_level, 1, 4) - 1]) * Config.UNIT_DISPLAY_SCALE
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(visual_scale, visual_scale))
	var body: Color = main_ref.get_faction_color(faction) if main_ref != null and main_ref.has_method("get_faction_color") else (Color("#38bdf8") if faction == 1 else Color("#ef4444"))
	# Generated chibi sprite replaces the former stick-figure placeholder. The
	# shader preserves source luminance while the small halo provides only a
	# secondary faction cue.
	var outline := Color("#293452")
	# A compact ground shadow anchors the soldier to the tile and remains
	# independent of the facing direction.
	_draw_unit_ellipse(Vector2(2.0, 15.0), Vector2(14.0, 5.5), Color(0.26, 0.17, 0.22, 0.48))
	draw_circle(Vector2(0.0, -1.0), 15.5, Color(body, 0.16))
	var sprite_index := clampi(unit_class, 0, UNIT_ART.size() - 1)
	_update_legacy_sprite(sprite_index, visual_scale)
	if hit_flash_remaining > 0.0:
		draw_circle(Vector2.ZERO, 17.0, Color(1.0, 0.12, 0.12, 0.22))
	if is_frozen():
		draw_arc(Vector2.ZERO, 19.0, 0.0, TAU, 20, Color(0.35, 0.9, 1.0, 0.82), 2.0, true)
		draw_line(Vector2(-13.0, -15.0), Vector2(-7.0, -21.0), Color("#cffafe"), 2.0, true)
		draw_line(Vector2(7.0, -21.0), Vector2(13.0, -15.0), Color("#cffafe"), 2.0, true)
	if hp < max_hp and (faction == Config.FACTION_PLAYER or has_fought_player):
		draw_rect(Rect2(-12, -17, 24, 3), Color("#0f172a"), true)
		var health_fill_color := Color("#4ade80") if faction == Config.FACTION_PLAYER else Color("#ef4444")
		draw_rect(Rect2(-12, -17, 24 * clamp(hp / max_hp, 0.0, 1.0), 3), health_fill_color, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _setup_legacy_sprite() -> void:
	if legacy_sprite != null:
		return
	legacy_sprite = Sprite2D.new()
	legacy_sprite.centered = true
	legacy_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	legacy_sprite.material = _make_legacy_material()
	add_child(legacy_sprite)

func _make_legacy_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = ATLAS_SHADER
	material.set_shader_parameter("atlas_grid", Vector2.ONE)
	material.set_shader_parameter("frame_uv_size", Vector2.ONE)
	material.set_shader_parameter("has_faction_mask", true)
	# A fallback Sprite2D has no MultiMesh INSTANCE_CUSTOM tint data; use the
	# per-unit faction_tint uniform instead.
	material.set_shader_parameter("use_instance_tint", false)
	material.set_shader_parameter("faction_mask", UNIT_MASKS[clampi(unit_class, 0, UNIT_MASKS.size() - 1)])
	return material

func _update_legacy_sprite(sprite_index: int, visual_scale: float) -> void:
	if legacy_sprite == null:
		return
	legacy_sprite.visible = not batch_rendered
	legacy_sprite.texture = UNIT_ART[sprite_index]
	legacy_sprite.position = Vector2(0.0, -3.0 * visual_scale)
	var texture_size := Vector2(legacy_sprite.texture.get_size())
	legacy_sprite.scale = Vector2.ONE * (40.0 / maxf(1.0, texture_size.x)) * visual_scale
	# The legacy fallback has one front-facing image per class. Mirror it for
	# the left-facing atlas directions so it still follows horizontal travel;
	# the batch renderer uses the full six-direction runtime atlas.
	_apply_legacy_facing()
	legacy_sprite.modulate = Color("#ff3b3b") if hit_flash_remaining > 0.0 else Color.WHITE
	var material := legacy_sprite.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter("faction_mask", UNIT_MASKS[sprite_index])
		material.set_shader_parameter("faction_tint", main_ref.get_faction_color(faction) if main_ref != null and main_ref.has_method("get_faction_color") else Color.WHITE)

func get_visual_animation() -> String:
	return visual_action if visual_action_remaining > 0.0 else ("move" if moving else "idle")

func get_visual_direction() -> int:
	return visual_direction

func get_visual_elapsed() -> float:
	return visual_elapsed

func face_toward(target_position: Vector2) -> void:
	var direction := target_position - position
	if direction.length_squared() < 0.0001:
		return
	var previous_direction := visual_direction
	visual_direction = direction_frame_for_movement(direction)
	if legacy_sprite != null:
		_apply_legacy_facing()
	if visual_direction != previous_direction:
		queue_redraw()
		var visual_layer = main_ref.get("units_layer") if is_instance_valid(main_ref) else null
		if is_instance_valid(visual_layer) and visual_layer.has_method("request_visual_refresh"):
			visual_layer.call("request_visual_refresh")

static func direction_frame_for_movement(movement: Vector2) -> int:
	if movement.length_squared() < 0.0001:
		return 0
	var movement_direction := movement.normalized()
	var best_dot := -INF
	var best_direction := 0
	for index in range(DIRECTION_VECTORS.size()):
		var candidate_dot := movement_direction.dot(DIRECTION_VECTORS[index])
		if candidate_dot > best_dot:
			best_dot = candidate_dot
			best_direction = index
	return best_direction

func _update_visual_direction(movement: Vector2) -> void:
	if movement.length_squared() < 0.0001:
		return
	var previous_direction := visual_direction
	visual_direction = direction_frame_for_movement(movement)
	if legacy_sprite != null:
		_apply_legacy_facing()
	if visual_direction != previous_direction:
		queue_redraw()

func _apply_legacy_facing() -> void:
	if legacy_sprite == null:
		return
	# The single-image fallback can only mirror horizontal-facing views. Include
	# the upper-left frame as well; omitting it made that direction face right.
	legacy_sprite.flip_h = visual_direction == 2 or visual_direction == 3 or visual_direction == 4

func _draw_unit_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(18):
		var angle := TAU * float(index) / 18.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)

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
