class_name SimpleAI
extends Node

var main_ref: Node
var think_timer := 1.0

func setup(controller: Node) -> void:
	main_ref = controller

func _process(delta: float) -> void:
	if main_ref == null or main_ref.game_over:
		return
	think_timer -= delta
	if think_timer <= 0.0:
		think_timer = 1.25
		_take_turn()

func _take_turn() -> void:
	var build_slots: Array[Vector2i] = main_ref.get_build_slots(main_ref.AI)
	if not build_slots.is_empty() and main_ref.gold[main_ref.AI] >= main_ref.BARRACKS_COST:
		main_ref.build_barracks(main_ref.AI, build_slots[0])
		return
	var candidates: Array[Vector2i] = []
	for cell in main_ref.board.tiles:
		var tile: Dictionary = main_ref.board.tiles[cell]
		if bool(tile["revealed"]):
			continue
		for neighbor in main_ref.board.neighbors(cell):
			if int(main_ref.board.tiles[neighbor]["owner"]) == main_ref.board.AI:
				candidates.append(cell)
				break
	if candidates.is_empty():
		return
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return main_ref.board.cube_distance(a, main_ref.player_hq) < main_ref.board.cube_distance(b, main_ref.player_hq)
	)
	for cell in candidates:
		var cost: int = main_ref.reveal_cost(cell, main_ref.ai_hq)
		if main_ref.gold[main_ref.AI] >= cost:
			main_ref.reveal_tile(main_ref.AI, cell)
			return
