class_name BuildingLayer
extends Node2D

const Config := preload("res://game_config.gd")

const MINE := 1
const BARRACKS := 2
const TOWER := 3
const BARRACKS_PRODUCTION_INTERVAL := Config.BARRACKS_PRODUCTION_INTERVAL
const HQ_MAX_HP := Config.HQ_MAX_HP

var board: HexBoard
var main_ref: Node

func setup(next_board: HexBoard) -> void:
	board = next_board
	main_ref = get_parent()
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if board == null:
		return
	for cell in board.tiles:
		var tile: Dictionary = board.tiles[cell]
		if not bool(tile["revealed"]):
			continue
		if board.long_press_active and cell == board.drag_start_cell:
			continue
		var building: int = int(tile["building"])
		var center := board.axial_to_world(cell)
		if cell == Config.PLAYER_HQ or cell == Config.AI_HQ:
			_draw_hq_health(cell, center)
			continue
		if building == 0:
			continue
		var owner_color := Color("#38bdf8") if int(tile["owner"]) == board.PLAYER else Color("#fb7185")
		_draw_building_health(center, tile)
		if building == BARRACKS:
			var progress := board.get_build_timer(cell)
			var progress_ratio := clampf(1.0 - progress / BARRACKS_PRODUCTION_INTERVAL, 0.0, 1.0)
			draw_rect(Rect2(center + Vector2(-15, 25), Vector2(30, 3)), Color("#0f172a"), true)
			draw_rect(Rect2(center + Vector2(-15, 25), Vector2(30.0 * progress_ratio, 3)), owner_color, true)

func _draw_building_health(center: Vector2, tile: Dictionary) -> void:
	var max_hp: float = float(tile["building_max_hp"])
	var hp: float = float(tile["building_hp"])
	if max_hp <= 0.0 or hp >= max_hp:
		return
	var owner_color := Color("#38bdf8") if int(tile["owner"]) == board.PLAYER else Color("#fb7185")
	draw_rect(Rect2(center + Vector2(-15, 20), Vector2(30, 3)), Color("#0f172a"), true)
	draw_rect(Rect2(center + Vector2(-15, 20), Vector2(30.0 * clampf(hp / max_hp, 0.0, 1.0), 3)), owner_color, true)

func _draw_hq_health(cell: Vector2i, center: Vector2) -> void:
	if main_ref == null:
		return
	var owner := 1 if cell.x < 0 else 2
	var hp: float = float(main_ref.base_hp[owner])
	if hp >= HQ_MAX_HP:
		return
	var ratio := clampf(hp / HQ_MAX_HP, 0.0, 1.0)
	draw_rect(Rect2(center + Vector2(-18, -28), Vector2(36, 4)), Color("#0f172a"), true)
	draw_rect(Rect2(center + Vector2(-18, -28), Vector2(36.0 * ratio, 4)), Color("#f87171"), true)
