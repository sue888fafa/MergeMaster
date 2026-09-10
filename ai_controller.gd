class_name SimpleAI
extends Node

var main_ref: Node
var think_timer := 1.0
var faction := 2

func setup(controller: Node, owner: int = 2) -> void:
	main_ref = controller
	faction = owner
	think_timer = 1.0

func reset() -> void:
	think_timer = 1.0

func _process(delta: float) -> void:
	if main_ref == null or main_ref.game_over:
		return
	think_timer -= delta
	if think_timer <= 0.0:
		think_timer = 1.25
		_take_turn()

func _take_turn() -> void:
	if main_ref.eliminated_factions.get(faction, false):
		return
	var merge_pair: Array[Vector2i] = main_ref.find_barracks_merge(faction)
	if merge_pair.size() == 2 and main_ref.merge_barracks(merge_pair[0], merge_pair[1]):
		return
	var build_slots: Array[Vector2i] = main_ref.get_build_slots(faction)
	if not build_slots.is_empty() and main_ref.gold[faction] >= main_ref.BARRACKS_COST:
		main_ref.build_barracks(faction, build_slots[0])
		return
	var candidates: Array[Vector2i] = []
	var owned_cells: Array[Vector2i] = main_ref.get_revealed_owned_cells(faction)
	var frontier_sources: Array[Vector2i] = main_ref.get_owned_cells(faction)
	var candidate_set: Dictionary = {}
	# Every candidate must neighbor an already revealed tile owned by this AI.
	# Generating the frontier from the indexed owned cells avoids scanning the
	# entire board while preserving the existing candidate sort and choice.
	for owned_cell in frontier_sources:
		for neighbor in main_ref.board.neighbors(owned_cell):
			if bool(main_ref.board.tiles[neighbor]["revealed"]):
				continue
			candidate_set[neighbor] = true
	for raw_candidate in candidate_set.keys():
		var candidate: Vector2i = raw_candidate
		candidates.append(candidate)
	if candidates.is_empty():
		return
	var frontier_distances: Dictionary = {}
	for cell in candidates:
		frontier_distances[cell] = _nearest_owned_distance(cell, owned_cells)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var a_hq_distance: int = int(main_ref.board.cube_distance(a, main_ref.get_hq_cell(faction)))
		var b_hq_distance: int = int(main_ref.board.cube_distance(b, main_ref.get_hq_cell(faction)))
		if a_hq_distance != b_hq_distance:
			return a_hq_distance < b_hq_distance
		# Keep expansion close to the robot's existing frontier when candidates
		# are equally far from its base.
		var a_frontier_distance: int = int(frontier_distances.get(a, 999999))
		var b_frontier_distance: int = int(frontier_distances.get(b, 999999))
		if a_frontier_distance != b_frontier_distance:
			return a_frontier_distance < b_frontier_distance
		return a.x < b.x if a.x != b.x else a.y < b.y
	)
	for cell in candidates:
		var cost: int = main_ref.reveal_cost(cell, main_ref.get_hq_cell(faction))
		if main_ref.gold[faction] >= cost:
			main_ref.reveal_tile(faction, cell)
			return

func _nearest_owned_distance(cell: Vector2i, owned_cells: Array[Vector2i]) -> int:
	var nearest := 999999
	for owned_cell in owned_cells:
		nearest = mini(nearest, main_ref.board.cube_distance(cell, owned_cell))
	return nearest
