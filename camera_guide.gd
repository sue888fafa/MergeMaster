class_name CameraGuide
extends Control

var target_screen_position := Vector2.ZERO
var guide_visible := false
var indicator_position := Vector2.ZERO
var indicator_offset := Vector2.ZERO
var guide_color := Color.WHITE
var safe_rect := Rect2(48.0, 190.0, 624.0, 1000.0)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

func configure(color: Color) -> void:
	guide_color = color
	queue_redraw()

func configure_safe_rect(rect: Rect2) -> void:
	safe_rect = rect
	if guide_visible:
		indicator_position = _calculate_indicator_position(target_screen_position)
		queue_redraw()

func set_indicator_offset(offset: Vector2) -> void:
	if indicator_offset == offset:
		return
	indicator_offset = offset
	if guide_visible:
		indicator_position = _calculate_indicator_position(target_screen_position)
		queue_redraw()

func set_guide(new_target_screen_position: Vector2, visible: bool) -> void:
	var next_position := _calculate_indicator_position(new_target_screen_position) if visible else Vector2.ZERO
	var changed := target_screen_position != new_target_screen_position or guide_visible != visible or indicator_position != next_position
	target_screen_position = new_target_screen_position
	guide_visible = visible
	indicator_position = next_position
	if changed:
		queue_redraw()

func clear_guide() -> void:
	set_guide(Vector2.ZERO, false)

func get_indicator_position() -> Vector2:
	return indicator_position

func _calculate_indicator_position(target: Vector2) -> Vector2:
	if not is_inside_tree():
		return Vector2.ZERO
	var viewport_size := get_viewport_rect().size
	var center := viewport_size * 0.5
	var direction := target - center
	if direction.length_squared() < 0.01:
		direction = Vector2.UP
	else:
		direction = direction.normalized()

	var distance := INF
	if absf(direction.x) > 0.001:
		var horizontal_edge := safe_rect.end.x if direction.x > 0.0 else safe_rect.position.x
		distance = minf(distance, (horizontal_edge - center.x) / direction.x)
	if absf(direction.y) > 0.001:
		var vertical_edge := safe_rect.end.y if direction.y > 0.0 else safe_rect.position.y
		distance = minf(distance, (vertical_edge - center.y) / direction.y)
	if not is_finite(distance) or distance < 0.0:
		distance = minf(viewport_size.x, viewport_size.y) * 0.5
	var result := center + direction * distance + indicator_offset
	var padding := Vector2(30.0, 30.0)
	return Vector2(
		clampf(result.x, safe_rect.position.x + padding.x, safe_rect.end.x - padding.x),
		clampf(result.y, safe_rect.position.y + padding.y, safe_rect.end.y - padding.y)
	)

func _draw() -> void:
	if not guide_visible:
		return
	# The dim under-stroke keeps the guide readable over the map without
	# covering the HUD controls.
	draw_line(indicator_position, target_screen_position, Color(0.02, 0.04, 0.08, 0.75), 7.0, true)
	draw_line(indicator_position, target_screen_position, Color(guide_color, 0.8), 3.0, true)
	var direction := (target_screen_position - indicator_position).normalized()
	if direction.length_squared() > 0.01:
		var side := Vector2(-direction.y, direction.x)
		var arrow_tip := indicator_position + direction * 12.0
		var arrow_base := indicator_position + direction * 1.0
		var arrow_points := PackedVector2Array([
			arrow_tip,
			arrow_base + side * 6.0,
			arrow_base - side * 6.0
		])
		draw_colored_polygon(arrow_points, guide_color)
