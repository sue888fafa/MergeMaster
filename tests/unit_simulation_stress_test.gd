extends Node2D

const MainScene := preload("res://Main.tscn")
const Config := preload("res://game_config.gd")
const TEST_COUNTS := [400, 600]
const SAMPLE_SECONDS := 5.0
const WARMUP_SECONDS := 2.0

var game: Node2D
var test_index := 0
var elapsed := 0.0
var fps_total := 0.0
var process_time_total := 0.0
var sample_count := 0
var warmup_remaining := 0.0

func _ready() -> void:
	game = MainScene.instantiate()
	add_child(game)
	await get_tree().process_frame
	game.match_duration = 9999.0
	game.game_over = false
	game.set_process(false)
	var ai_controller := game.get_node_or_null("AIController")
	if ai_controller != null:
		ai_controller.set_process(false)
	_prepare_count(TEST_COUNTS[0])

func _process(delta: float) -> void:
	if game == null:
		return
	if warmup_remaining > 0.0:
		warmup_remaining -= delta
		return
	elapsed += delta
	fps_total += Engine.get_frames_per_second()
	process_time_total += Performance.get_monitor(Performance.TIME_PROCESS)
	sample_count += 1
	if elapsed < SAMPLE_SECONDS:
		return
	print("UNIT_SIMULATION_STRESS target_units=%d live_units=%d avg_fps=%.1f avg_process_ms=%.2f static_memory=%.1fMiB" % [
		TEST_COUNTS[test_index],
		game.units.size(),
		fps_total / maxf(1.0, float(sample_count)),
		process_time_total * 1000.0 / maxf(1.0, float(sample_count)),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	])
	test_index += 1
	if test_index >= TEST_COUNTS.size():
		get_tree().quit()
		return
	_prepare_count(TEST_COUNTS[test_index])

func _prepare_count(target_count: int) -> void:
	var cells: Array = game.board.tiles.keys()
	while game.units.size() < target_count:
		var index: int = int(game.units.size())
		var faction: int = Config.FACTION_IDS[index % Config.FACTION_IDS.size()]
		var unit_class: int = index % Config.UNIT_CLASS_COUNT
		var unit = game._spawn_unit(faction, cells[index % cells.size()], 1 + index % 4, unit_class)
		unit.max_hp = 1000000000.0
		unit.hp = unit.max_hp
		unit.attack = 0.0
		unit.move_speed = 0.0
	for unit in game.units:
		unit.max_hp = 1000000000.0
		unit.hp = unit.max_hp
		unit.attack = 0.0
		unit.move_speed = 0.0
	elapsed = 0.0
	fps_total = 0.0
	process_time_total = 0.0
	sample_count = 0
	warmup_remaining = WARMUP_SECONDS
	if game.units_layer.has_method("request_visual_refresh"):
		game.units_layer.request_visual_refresh()
