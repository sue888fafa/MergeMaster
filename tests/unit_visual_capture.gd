extends Node2D

const MainScene := preload("res://Main.tscn")
const Config := preload("res://game_config.gd")
const CAPTURE_ZOOMS := [0.50, 1.02, 1.20]
const UNIT_COUNT := 120

var game: Node2D
var capture_viewport: SubViewport

func _ready() -> void:
	capture_viewport = SubViewport.new()
	capture_viewport.size = Vector2i(720, 1280)
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(capture_viewport)
	game = MainScene.instantiate()
	capture_viewport.add_child(game)
	await get_tree().process_frame
	game.game_over = true
	_spawn_units()
	var output_dir := ProjectSettings.globalize_path("res://tests/output")
	DirAccess.make_dir_recursive_absolute(output_dir)
	for zoom in CAPTURE_ZOOMS:
		game.get_node("Camera2D").zoom = Vector2.ONE * zoom
		_layout_units(zoom)
		game.units_layer.request_visual_refresh()
		for _frame in range(4):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := capture_viewport.get_texture().get_image()
		var suffix := str(zoom).replace(".", "_")
		image.save_png(output_dir.path_join("unit_visual_zoom_%s.png" % suffix))
	get_tree().quit()

func _spawn_units() -> void:
	var cells: Array = game.board.tiles.keys()
	for index in range(UNIT_COUNT):
		var faction: int = Config.FACTION_IDS[index % Config.FACTION_IDS.size()]
		var unit_class: int = index % Config.UNIT_CLASS_COUNT
		var unit = game._spawn_unit(faction, cells[index % cells.size()], 1 + index % 4, unit_class)
		unit.moving = index % 3 != 0
		if index % 7 == 0:
			unit.hp *= 0.65

func _layout_units(zoom: float) -> void:
	var center: Vector2 = game.get_node("Camera2D").position
	var world_size := Vector2(720.0, 1280.0) / zoom
	var columns := 12
	var rows := int(ceil(float(UNIT_COUNT) / float(columns)))
	var usable := world_size * Vector2(0.74, 0.58)
	for index in range(game.units.size()):
		var column := index % columns
		var row := int(index / columns)
		game.units[index].position = center - usable * 0.5 + Vector2(
			usable.x * (float(column) + 0.5) / float(columns),
			usable.y * (float(row) + 0.5) / float(rows)
		)
