extends Node2D

var target: Node2D
var target_cell := Vector2i(999, 999)
var target_is_building := false
var target_faction := 0
var main_ref: Node
var damage := 0.0
var speed := 360.0
var previous_position := Vector2.ZERO
var source_unit: Node = null

func setup(start_position: Vector2, next_target: Node2D, amount: float, controller: Node, attacker: Node = null) -> void:
	position = start_position
	previous_position = start_position
	target = next_target
	target_cell = Vector2i(999, 999)
	target_is_building = false
	target_faction = 0
	damage = amount
	main_ref = controller
	source_unit = attacker
	queue_redraw()

func setup_building(start_position: Vector2, next_cell: Vector2i, amount: float, owner: int, controller: Node, attacker: Node = null) -> void:
	position = start_position
	previous_position = start_position
	target = null
	target_cell = next_cell
	target_is_building = true
	target_faction = owner
	damage = amount
	main_ref = controller
	source_unit = attacker
	queue_redraw()

func _process(delta: float) -> void:
	if main_ref == null or main_ref.game_over:
		queue_free()
		return
	previous_position = position
	var target_position: Vector2
	if target_is_building:
		if not main_ref.board.has_cell(target_cell):
			queue_free()
			return
		var tile: Dictionary = main_ref.board.tiles[target_cell]
		if int(tile["owner"]) != target_faction or int(tile["building"]) == main_ref.EMPTY:
			queue_free()
			return
		target_position = main_ref.board.axial_to_world(target_cell)
	else:
		if not is_instance_valid(target) or not target.has_method("take_damage"):
			queue_free()
			return
		target_position = target.position
	position = position.move_toward(target_position, speed * delta)
	if position.distance_to(target_position) <= 8.0:
		if target_is_building:
			var attacker_owner := 0
			if is_instance_valid(source_unit):
				attacker_owner = int(source_unit.get("faction"))
			main_ref.damage_building(target_cell, damage, attacker_owner)
		else:
			# The firing unit may have been recycled while this projectile was in
			# flight. Never pass a freed object through the typed damage API.
			if is_instance_valid(source_unit):
				target.take_damage(damage, source_unit)
			else:
				target.take_damage(damage)
		queue_free()
	queue_redraw()

func _draw() -> void:
	draw_line(to_local(previous_position), Vector2.ZERO, Color(1.0, 0.85, 0.3, 0.75), 3.0, true)
	draw_circle(Vector2.ZERO, 5.0, Color("#fef08a"))
	draw_circle(Vector2.ZERO, 2.0, Color("#ffffff"))
