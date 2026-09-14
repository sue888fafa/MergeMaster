extends Node2D

const MainScene := preload("res://Main.tscn")
const Config := preload("res://game_config.gd")
const UNIT_COUNT := 600
const SAMPLE_SECONDS := 5.0
const TEST_ZOOMS := [0.50, 1.02, 1.20]

var game: Node2D
var test_index := 0
var elapsed := 0.0
var fps_total := 0.0
var sample_count := 0
var max_draw_calls := 0.0

func _ready() -> void:
	game = MainScene.instantiate()
	add_child(game)
	await get_tree().process_frame
	_spawn_units()
	game.game_over = true
	_start_sample(0)

func _process(delta: float) -> void:
	if game == null:
		return
	elapsed += delta
	fps_total += Engine.get_frames_per_second()
	sample_count += 1
	max_draw_calls = maxf(max_draw_calls, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	if elapsed < SAMPLE_SECONDS:
		return
	var average_fps := fps_total / maxf(1.0, float(sample_count))
	var active_batches := int(game.units_layer.call("get_active_visual_batches")) if game.units_layer.has_method("get_active_visual_batches") else -1
	var batch_budget := int(game.units_layer.call("get_visual_draw_call_budget")) if game.units_layer.has_method("get_visual_draw_call_budget") else -1
	print("UNIT_VISUAL_STRESS zoom=%.2f units=%d avg_fps=%.1f measured_draw_calls=%.0f active_batches=%d batch_budget=%d static_memory=%.1fMiB" % [
		TEST_ZOOMS[test_index],
		UNIT_COUNT,
		average_fps,
		max_draw_calls,
		active_batches,
		batch_budget,
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	])
	test_index += 1
	if test_index >= TEST_ZOOMS.size():
		if DisplayServer.get_name() == "headless":
			get_tree().quit()
		else:
			set_process(false)
		return
	_start_sample(test_index)

func _spawn_units() -> void:
	var cells: Array = game.board.tiles.keys()
	for index in range(UNIT_COUNT):
		var faction: int = Config.FACTION_IDS[index % Config.FACTION_IDS.size()]
		var unit_class := index % Config.UNIT_CLASS_COUNT
		var unit = game._spawn_unit(faction, cells[index % cells.size()], 1 + index % 4, unit_class)
		unit.moving = index % 3 != 0
		if index % 7 == 0:
			unit.hp *= 0.65

func _start_sample(index: int) -> void:
	elapsed = 0.0
	fps_total = 0.0
	sample_count = 0
	max_draw_calls = 0.0
	game.get_node("Camera2D").zoom = Vector2.ONE * float(TEST_ZOOMS[index])
	_layout_units(float(TEST_ZOOMS[index]))
	if game.units_layer.has_method("request_visual_refresh"):
		game.units_layer.request_visual_refresh()

func _layout_units(zoom: float) -> void:
	var center: Vector2 = game.get_node("Camera2D").position
	var world_size := Vector2(720.0, 1280.0) / zoom
	var columns := 30
	var rows := int(ceil(float(UNIT_COUNT) / float(columns)))
	var usable := world_size - Vector2(80.0, 120.0) / zoom
	for index in range(game.units.size()):
		var column := index % columns
		var row := int(index / columns)
		game.units[index].position = center - usable * 0.5 + Vector2(
			usable.x * (float(column) + 0.5) / float(columns),
			usable.y * (float(row) + 0.5) / float(rows)
		)
