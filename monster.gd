class_name WildMonster
extends Node2D

const Config := preload("res://game_config.gd")

var cell := Vector2i.ZERO
var hp := Config.WILD_MONSTER_MAX_HP
var max_hp := Config.WILD_MONSTER_MAX_HP
var attack_cooldown := 0.0
var main_ref: Node
var drop_owner := 0
var defeated := false

func setup(start_cell: Vector2i, controller: Node, owner: int = 0) -> void:
	cell = start_cell
	main_ref = controller
	drop_owner = owner
	defeated = false
	max_hp = Config.WILD_MONSTER_MAX_HP
	hp = max_hp
	position = main_ref.board.axial_to_world(cell)
	queue_redraw()

func _process(delta: float) -> void:
	if main_ref == null or main_ref.game_over:
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	main_ref.process_monster(self, delta)
	queue_redraw()

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
	# Procedural monster model: shadow, body, head, horns, claws and feet.
	# Keeping it in _draw makes the model replaceable by a Sprite2D later.
	var outline := Color("#111827")
	var body := Color("#64748b")
	var body_light := Color("#94a3b8")
	var body_dark := Color("#334155")
	_draw_shadow_ellipse(Vector2(0.0, 15.0), Vector2(19.0, 6.0), Color(0.0, 0.0, 0.0, 0.30))
	draw_line(Vector2(-9.0, 8.0), Vector2(-13.0, 18.0), outline, 6.0, true)
	draw_line(Vector2(9.0, 8.0), Vector2(13.0, 18.0), outline, 6.0, true)
	draw_line(Vector2(-9.0, 8.0), Vector2(-13.0, 18.0), body_dark, 3.5, true)
	draw_line(Vector2(9.0, 8.0), Vector2(13.0, 18.0), body_dark, 3.5, true)
	var torso := PackedVector2Array([
		Vector2(-15.0, -1.0), Vector2(-11.0, -12.0), Vector2(0.0, -16.0),
		Vector2(11.0, -12.0), Vector2(15.0, -1.0), Vector2(10.0, 11.0),
		Vector2(0.0, 15.0), Vector2(-10.0, 11.0)
	])
	draw_colored_polygon(torso, outline)
	var torso_inner := PackedVector2Array([
		Vector2(-11.5, -1.0), Vector2(-8.5, -9.0), Vector2(0.0, -12.5),
		Vector2(8.5, -9.0), Vector2(11.5, -1.0), Vector2(7.0, 8.0),
		Vector2(0.0, 11.5), Vector2(-7.0, 8.0)
	])
	draw_colored_polygon(torso_inner, body)
	draw_line(Vector2(0.0, -10.0), Vector2(0.0, 10.0), body_light, 2.0, true)
	draw_line(Vector2(-6.0, -4.0), Vector2(6.0, -4.0), body_light, 2.0, true)
	# Outstretched arms and three-finger claws.
	draw_line(Vector2(-10.0, -2.0), Vector2(-23.0, 5.0), outline, 6.0, true)
	draw_line(Vector2(10.0, -2.0), Vector2(23.0, 5.0), outline, 6.0, true)
	draw_line(Vector2(-10.0, -2.0), Vector2(-23.0, 5.0), body_dark, 3.5, true)
	draw_line(Vector2(10.0, -2.0), Vector2(23.0, 5.0), body_dark, 3.5, true)
	for claw_offset in [-2.5, 0.0, 2.5]:
		draw_line(Vector2(-23.0, 5.0), Vector2(-27.0, 9.0 + claw_offset), body_light, 1.5, true)
		draw_line(Vector2(23.0, 5.0), Vector2(27.0, 9.0 + claw_offset), body_light, 1.5, true)
	# Head and horns.
	draw_circle(Vector2(0.0, -20.0), 15.0, outline)
	draw_circle(Vector2(0.0, -20.0), 12.0, body_light)
	var left_horn := PackedVector2Array([Vector2(-9.0, -29.0), Vector2(-17.0, -43.0), Vector2(-4.0, -34.0)])
	var right_horn := PackedVector2Array([Vector2(9.0, -29.0), Vector2(17.0, -43.0), Vector2(4.0, -34.0)])
	draw_colored_polygon(left_horn, outline)
	draw_colored_polygon(right_horn, outline)
	draw_colored_polygon(PackedVector2Array([Vector2(-9.0, -31.0), Vector2(-14.0, -39.0), Vector2(-6.0, -34.0)]), body_dark)
	draw_colored_polygon(PackedVector2Array([Vector2(9.0, -31.0), Vector2(14.0, -39.0), Vector2(6.0, -34.0)]), body_dark)
	draw_circle(Vector2(-5.0, -21.0), 3.5, Color("#0f172a"))
	draw_circle(Vector2(5.0, -21.0), 3.5, Color("#0f172a"))
	draw_circle(Vector2(-5.0, -21.0), 1.6, Color("#f87171"))
	draw_circle(Vector2(5.0, -21.0), 1.6, Color("#f87171"))
	draw_line(Vector2(-6.0, -14.0), Vector2(6.0, -14.0), outline, 2.5, true)
	draw_line(Vector2(-4.0, -14.0), Vector2(-3.0, -10.0), Color("#f8fafc"), 2.0, true)
	draw_line(Vector2(4.0, -14.0), Vector2(3.0, -10.0), Color("#f8fafc"), 2.0, true)
	# Keep the monster health bar visible for its entire lifetime, including
	# while it is still at full health. The monster is removed on death.
	draw_rect(Rect2(-22, -51, 44, 4), Color("#0f172a"), true)
	draw_rect(Rect2(-22, -51, 44.0 * clampf(hp / max_hp, 0.0, 1.0), 4), Color("#f472b6"), true)

func _draw_shadow_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(20):
		var angle := TAU * float(index) / 20.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
