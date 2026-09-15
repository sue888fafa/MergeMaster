class_name BombRevealEffect
extends Node2D

signal finished

const FRAME_DIRECTORY := "res://assets/generated/effects/bomb_reveal_frames"
const FRAME_DURATION := 0.06
# Keep the existing effect sizing relationship, then reduce the complete
# bomb animation presentation to 60% of its previous on-board size.
const DISPLAY_SCALE := 0.88 * 0.60

var frames: Array[Texture2D] = []
var elapsed := 0.0
var completed := false
var affected_cells: Array[Vector2i] = []

func _ready() -> void:
	var directory := DirAccess.open(FRAME_DIRECTORY)
	if directory == null:
		return
	var frame_files := directory.get_files()
	frame_files.sort()
	for frame_file in frame_files:
		if not frame_file.to_lower().ends_with(".png"):
			continue
		var frame := load("%s/%s" % [FRAME_DIRECTORY, frame_file]) as Texture2D
		if frame != null:
			frames.append(frame)
	queue_redraw()

func setup(world_position: Vector2, target_cells: Array[Vector2i]) -> void:
	position = world_position
	affected_cells = target_cells.duplicate()
	elapsed = 0.0
	completed = false
	if frames.is_empty():
		_finish()
	else:
		queue_redraw()

func _process(delta: float) -> void:
	if completed:
		return
	elapsed += delta
	queue_redraw()
	if not frames.is_empty() and elapsed >= _animation_duration():
		_finish()

func _animation_duration() -> float:
	return float(frames.size()) * FRAME_DURATION

func _finish() -> void:
	if completed:
		return
	completed = true
	finished.emit()
	queue_free()

func _draw() -> void:
	if frames.is_empty():
		return
	var frame_index := mini(int(elapsed / FRAME_DURATION), frames.size() - 1)
	var texture := frames[frame_index]
	var draw_size := Vector2(texture.get_size()) * DISPLAY_SCALE
	var fade := 1.0
	var animation_duration := _animation_duration()
	if elapsed > animation_duration - 0.12:
		fade = clampf((animation_duration - elapsed) / 0.12, 0.0, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_texture_rect(texture, Rect2(-draw_size * 0.5, draw_size), false, Color(1.0, 1.0, 1.0, fade))
	if elapsed > 0.55:
		var flash_progress := clampf((elapsed - 0.55) / 0.25, 0.0, 1.0)
		var flash_alpha := (1.0 - flash_progress) * 0.20
		draw_circle(Vector2.ZERO, (34.0 + flash_progress * 34.0) * 0.60, Color(1.0, 0.82, 0.30, flash_alpha))
