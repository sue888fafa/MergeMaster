class_name WildMonster
extends Node2D

const Art := preload("res://art_theme.gd")

const Config := preload("res://game_config.gd")
const MONSTER_ART := preload("res://assets/generated/wild_monster.png")
const VISIBLE_MONSTER_ART := preload("res://assets/generated/visible_landmarks/visible_wild_monster.png")

var cell := Vector2i.ZERO
var hp := Config.WILD_MONSTER_MAX_HP
var max_hp := Config.WILD_MONSTER_MAX_HP
var attack_cooldown := 0.0
var main_ref: Node
var drop_owner := 0
var defeated := false
var monster_level := Config.WILD_MONSTER_LEVEL_ONE
var attack := Config.WILD_MONSTER_ATTACK
var visual_scale := 1.0
var spawn_animation_active := false
var use_visible_art := false
var spawn_elapsed := Config.WILD_MONSTER_SPAWN_ANIMATION_DURATION + Config.WILD_MONSTER_HEALTH_BAR_APPEAR_DURATION

func setup(start_cell: Vector2i, controller: Node, owner: int = 0, level: int = Config.WILD_MONSTER_LEVEL_ONE, show_spawn_animation := false, visible_art := false) -> void:
	cell = start_cell
	main_ref = controller
	drop_owner = owner
	defeated = false
	monster_level = clampi(level, Config.WILD_MONSTER_LEVEL_ONE, Config.WILD_MONSTER_LEVEL_THREE)
	var level_index := monster_level - 1
	max_hp = Config.WILD_MONSTER_MAX_HP * float(Config.WILD_MONSTER_LEVEL_HP_MULTIPLIERS[level_index])
	attack = Config.WILD_MONSTER_ATTACK * float(Config.WILD_MONSTER_LEVEL_ATTACK_MULTIPLIERS[level_index])
	visual_scale = float(Config.WILD_MONSTER_LEVEL_VISUAL_SCALES[level_index])
	hp = max_hp
	spawn_animation_active = show_spawn_animation
	use_visible_art = visible_art
	spawn_elapsed = 0.0 if show_spawn_animation else Config.WILD_MONSTER_SPAWN_ANIMATION_DURATION + Config.WILD_MONSTER_HEALTH_BAR_APPEAR_DURATION
	position = main_ref.board.axial_to_world(cell)
	queue_redraw()

func _process(delta: float) -> void:
	if main_ref == null or main_ref.game_over:
		return
	if spawn_animation_active:
		spawn_elapsed = minf(
			spawn_elapsed + delta,
			Config.WILD_MONSTER_SPAWN_ANIMATION_DURATION + Config.WILD_MONSTER_HEALTH_BAR_APPEAR_DURATION
		)
		if spawn_elapsed >= Config.WILD_MONSTER_SPAWN_ANIMATION_DURATION + Config.WILD_MONSTER_HEALTH_BAR_APPEAR_DURATION:
			spawn_animation_active = false
		queue_redraw()
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	main_ref.process_monster(self, delta)

func can_attack() -> bool:
	return attack_cooldown <= 0.0

func mark_attack() -> void:
	attack_cooldown = Config.WILD_MONSTER_ATTACK_INTERVAL

func take_damage(amount: float, attacker: Node = null) -> void:
	if defeated:
		return
	hp -= amount
	if hp <= 0.0:
		defeated = true
		main_ref.remove_monster(self, attacker)
	else:
		queue_redraw()

func _draw() -> void:
	var spawn_offset := Vector2.ZERO
	var spawn_scale := 1.0
	var health_bar_reveal := 1.0
	if spawn_animation_active:
		var model_progress := clampf(spawn_elapsed / Config.WILD_MONSTER_SPAWN_ANIMATION_DURATION, 0.0, 1.0)
		var model_eased := 1.0 - pow(1.0 - model_progress, 3.0)
		spawn_offset.y = lerpf(20.0, 0.0, model_eased) - sin(model_progress * PI) * 24.0
		spawn_scale = lerpf(0.55, 1.0, model_eased)
		health_bar_reveal = clampf(
			(spawn_elapsed - Config.WILD_MONSTER_SPAWN_ANIMATION_DURATION) / Config.WILD_MONSTER_HEALTH_BAR_APPEAR_DURATION,
			0.0,
			1.0
		)
	draw_set_transform(spawn_offset, 0.0, Vector2(visual_scale * spawn_scale, visual_scale * spawn_scale))
	var monster_art: Texture2D = VISIBLE_MONSTER_ART if use_visible_art else MONSTER_ART
	if monster_art != null:
		_draw_shadow_ellipse(Vector2(0.0, 15.0), Vector2(19.0, 6.0), Color(0.0, 0.0, 0.0, 0.24))
		var art_width := 82.0 if use_visible_art else 66.0
		var art_height := art_width * monster_art.get_height() / maxf(1.0, monster_art.get_width())
		draw_texture_rect(monster_art, Rect2(Vector2(-art_width * 0.5, -47.0), Vector2(art_width, art_height)), false)
		var sprite_health_alpha := health_bar_reveal if spawn_animation_active else 1.0
		if sprite_health_alpha > 0.0:
			draw_rect(Rect2(-23, -53, 46, 6), Art.INK, true)
			draw_rect(Rect2(-21, -51, 42.0 * clampf(hp / max_hp, 0.0, 1.0) * health_bar_reveal, 2), Color("#ff7cad", sprite_health_alpha), true)
		draw_circle(Vector2(20.0, -41.0), 9.0, Art.INK)
		draw_circle(Vector2(20.0, -42.0), 7.0, Art.SUN)
		draw_string(ThemeDB.fallback_font, Vector2(16.0, -38.0), str(monster_level), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Art.INK)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	# Generated candy-style monster replaces the old line-art placeholder.
	_draw_shadow_ellipse(Vector2(0.0, 15.0), Vector2(19.0, 6.0), Color(0.0, 0.0, 0.0, 0.30))
	draw_texture_rect(MONSTER_ART, Rect2(-33.0, -47.0, 66.0, 66.0), false)
	# Question-tile monsters reveal their health bar after the jump, with a
	# short width and alpha animation so the spawn reads clearly.
	var health_bar_alpha := health_bar_reveal if spawn_animation_active else 1.0
	if health_bar_alpha > 0.0:
		draw_rect(Rect2(-22, -51, 44, 4), Color(0.06, 0.09, 0.15, 0.85 * health_bar_alpha), true)
		draw_rect(Rect2(-22, -51, 44.0 * clampf(hp / max_hp, 0.0, 1.0) * health_bar_reveal, 4), Color(0.96, 0.45, 0.71, health_bar_alpha), true)
	draw_circle(Vector2(18.0, -40.0), 8.0, Color("#172033"))
	draw_string(ThemeDB.fallback_font, Vector2(14.0, -36.0), str(monster_level), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#f8fafc"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_shadow_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(20):
		var angle := TAU * float(index) / 20.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
