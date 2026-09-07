class_name CatCompanion
extends Control

const Config := preload("res://game_config.gd")

signal expanded_changed(expanded: bool)

const COMPANION_HEIGHT := 300.0
const HEAD_RADIUS := 38.0
const SLOT_SIZE := 32.0
const SLOT_GAP := 4.0

var bubble_message := ""
var bubble_remaining := 0.0
var animation_time := 0.0
var blink_timer := 0.0
var is_expanded := false
var expanded_progress := 0.0
var expand_tween: Tween
var head_button: Button
var slot_buttons: Array[Button] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(260.0, COMPANION_HEIGHT)
	_build_interaction_controls()
	_update_interaction_layout()
	queue_redraw()

func set_viewport_size(viewport_size: Vector2) -> void:
	size = Vector2(maxf(viewport_size.x, 1.0), COMPANION_HEIGHT)
	_update_interaction_layout()
	queue_redraw()

func show_bubble(message: String) -> void:
	bubble_message = message
	bubble_remaining = Config.OFFICER_BUBBLE_DURATION
	queue_redraw()

func hide_bubble() -> void:
	bubble_message = ""
	bubble_remaining = 0.0
	queue_redraw()

func toggle_expanded() -> void:
	set_expanded(not is_expanded)

func set_expanded(expanded: bool) -> void:
	if is_expanded == expanded and (expand_tween == null or not expand_tween.is_valid()):
		return
	is_expanded = expanded
	if expand_tween != null and expand_tween.is_valid():
		expand_tween.kill()
	expand_tween = create_tween()
	expand_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	expand_tween.tween_property(self, "expanded_progress", 1.0 if expanded else 0.0, 0.35)
	expand_tween.finished.connect(_on_expand_tween_finished)
	expanded_changed.emit(expanded)
	_update_interaction_layout()
	queue_redraw()

func _on_expand_tween_finished() -> void:
	if not is_expanded:
		expanded_progress = 0.0
	_update_interaction_layout()
	queue_redraw()

func _build_interaction_controls() -> void:
	head_button = Button.new()
	head_button.name = "CatHeadButton"
	head_button.focus_mode = Control.FOCUS_NONE
	head_button.flat = true
	head_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	head_button.add_theme_stylebox_override("normal", _transparent_style())
	head_button.add_theme_stylebox_override("hover", _transparent_style())
	head_button.add_theme_stylebox_override("pressed", _transparent_style())
	head_button.pressed.connect(toggle_expanded)
	add_child(head_button)

	for index in range(8):
		var slot_button := Button.new()
		slot_button.name = "CosmeticSlot%d" % (index + 1)
		slot_button.focus_mode = Control.FOCUS_NONE
		slot_button.flat = true
		slot_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		slot_button.add_theme_stylebox_override("normal", _transparent_style())
		slot_button.add_theme_stylebox_override("hover", _slot_button_style(Color(0.35, 0.75, 0.95, 0.12)))
		slot_button.add_theme_stylebox_override("pressed", _slot_button_style(Color(0.98, 0.77, 0.25, 0.24)))
		slot_button.pressed.connect(_on_slot_pressed.bind(index, slot_button))
		slot_buttons.append(slot_button)
		add_child(slot_button)

func _transparent_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_width_left = 0
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 0
	return style

func _slot_button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(7)
	return style

func _on_slot_pressed(_index: int, slot_button: Button) -> void:
	var highlight_color := Color(1.22, 1.14, 0.82, slot_button.modulate.a)
	var normal_color := Color(1.0, 1.0, 1.0, slot_button.modulate.a)
	slot_button.modulate = highlight_color
	var feedback := create_tween()
	feedback.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	feedback.tween_property(slot_button, "modulate", normal_color, 0.16)

func _process(delta: float) -> void:
	animation_time += delta
	blink_timer += delta
	if blink_timer >= 3.2:
		blink_timer = 0.0
	if bubble_remaining > 0.0:
		bubble_remaining = maxf(0.0, bubble_remaining - delta)
		if bubble_remaining <= 0.0:
			bubble_message = ""
	_update_interaction_layout()
	queue_redraw()

func _head_center() -> Vector2:
	return Vector2(maxf(58.0, size.x - 56.0), 180.0)

func _get_slot_layout() -> Dictionary:
	var head_center := _head_center()
	var slot_size := minf(SLOT_SIZE, maxf(24.0, (size.x - 90.0) / 12.0))
	var gap := minf(SLOT_GAP, maxf(2.0, slot_size * 0.15))
	var total_width := slot_size * 8.0 + gap * 7.0
	var right := head_center.x - 50.0
	var left := clampf(right - total_width, 8.0, maxf(8.0, size.x - total_width - 8.0))
	return {
		"size": slot_size,
		"gap": gap,
		"left": left,
		"top": 214.0
	}

func _update_interaction_layout() -> void:
	if head_button == null:
		return
	var center := _head_center()
	head_button.position = center - Vector2(HEAD_RADIUS, HEAD_RADIUS)
	head_button.size = Vector2(HEAD_RADIUS * 2.0, HEAD_RADIUS * 2.0)
	var layout := _get_slot_layout()
	var slot_size := float(layout["size"])
	var gap := float(layout["gap"])
	var left := float(layout["left"])
	var top := float(layout["top"])
	for index in range(slot_buttons.size()):
		var slot_button := slot_buttons[index]
		slot_button.position = Vector2(left + index * (slot_size + gap), top)
		slot_button.size = Vector2(slot_size, slot_size)
		slot_button.pivot_offset = Vector2(slot_size * 0.5, slot_size * 0.5)
		slot_button.visible = expanded_progress > 0.01
		slot_button.disabled = expanded_progress < 0.55
		var slot_modulate := slot_button.modulate
		slot_modulate.a = clampf(expanded_progress, 0.0, 1.0)
		slot_button.modulate = slot_modulate

func _draw() -> void:
	var bob := sin(animation_time * 2.8) * 1.8
	var head_center := _head_center() + Vector2(0.0, bob)
	var reveal := clampf(expanded_progress, 0.0, 1.0)
	if reveal > 0.01:
		_draw_expanded_body(head_center, reveal)
		_draw_item_slots(reveal)
	if not bubble_message.is_empty():
		_draw_bubble(head_center)
	_draw_cat_head(head_center)

func _draw_bubble(head_center: Vector2) -> void:
	var bubble_width := minf(250.0, maxf(150.0, size.x - 16.0))
	var bubble_x := clampf(head_center.x - bubble_width + 30.0, 8.0, maxf(8.0, size.x - bubble_width - 8.0))
	var bubble_rect := Rect2(bubble_x, 8.0, bubble_width, 78.0)
	draw_style_box(_bubble_style(Color(0.03, 0.06, 0.11, 0.94), Color("#fbbf24")), bubble_rect)
	var arrow_x := clampf(head_center.x - 12.0, bubble_rect.position.x + 24.0, bubble_rect.end.x - 24.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(arrow_x - 8.0, bubble_rect.end.y), Vector2(arrow_x + 8.0, bubble_rect.end.y), Vector2(arrow_x, bubble_rect.end.y + 13.0)
	]), Color(0.03, 0.06, 0.11, 0.94))
	var font := ThemeDB.fallback_font
	var text_rect := Rect2(bubble_rect.position + Vector2(10.0, 7.0), Vector2(bubble_width - 20.0, 64.0))
	draw_multiline_string(font, text_rect.position + Vector2(0.0, 14.0), bubble_message, HORIZONTAL_ALIGNMENT_CENTER, text_rect.size.x, 14, 3, Color("#f8fafc"))

func _bubble_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	return style

func _draw_expanded_body(head_center: Vector2, reveal: float) -> void:
	var alpha := ease(reveal, 0.7)
	var body_center := head_center + Vector2(0.0, 66.0)
	var body := Color(0.78, 0.82, 0.86, alpha)
	var body_shadow := Color(0.34, 0.40, 0.48, alpha)
	var shirt := Color(0.18, 0.29, 0.43, alpha)
	var shirt_light := Color(0.27, 0.42, 0.60, alpha)
	var opening := Color(0.04, 0.08, 0.14, alpha)
	var slot_layout := _get_slot_layout()
	var slot_size := float(slot_layout["size"])
	var slot_left := float(slot_layout["left"])
	var arm_y := float(slot_layout["top"]) + slot_size * 0.5

	_draw_ellipse(body_center + Vector2(0.0, 7.0), Vector2(52.0, 58.0), Color(0.0, 0.0, 0.0, 0.18 * alpha))
	_draw_ellipse(body_center, Vector2(48.0, 57.0), body_shadow)
	_draw_ellipse(body_center + Vector2(0.0, -5.0), Vector2(46.0, 56.0), shirt)

	# Open coat panels and the dark gap under the hand-pulled left side.
	draw_colored_polygon(PackedVector2Array([
		body_center + Vector2(-43.0, -41.0), body_center + Vector2(-7.0, -49.0),
		body_center + Vector2(-14.0, 45.0), body_center + Vector2(-42.0, 34.0)
	]), shirt_light)
	draw_colored_polygon(PackedVector2Array([
		body_center + Vector2(6.0, -49.0), body_center + Vector2(43.0, -40.0),
		body_center + Vector2(40.0, 36.0), body_center + Vector2(13.0, 47.0)
	]), shirt)
	draw_colored_polygon(PackedVector2Array([
		body_center + Vector2(-7.0, -47.0), body_center + Vector2(7.0, -47.0),
		body_center + Vector2(12.0, 48.0), body_center + Vector2(-14.0, 45.0)
	]), opening)
	draw_line(body_center + Vector2(-3.0, -36.0), body_center + Vector2(-3.0, 34.0), Color(1.0, 1.0, 1.0, 0.16 * alpha), 2.0, true)

	# The long arm becomes the support rail for the cosmetic item slots.
	var arm_start := body_center + Vector2(-28.0, -5.0)
	var arm_end := Vector2(slot_left + slot_size * 0.5, arm_y)
	draw_line(arm_start + Vector2(0.0, 3.0), arm_end + Vector2(0.0, 3.0), Color(0.04, 0.08, 0.14, 0.65 * alpha), 24.0, true)
	draw_line(arm_start, arm_end, Color(0.72, 0.77, 0.83, alpha), 18.0, true)
	draw_line(arm_start + Vector2(0.0, -2.0), arm_end + Vector2(0.0, -2.0), Color(0.90, 0.93, 0.96, alpha), 8.0, true)

	# Paw pulling the left coat flap open.
	_draw_ellipse(body_center + Vector2(-45.0, -17.0), Vector2(13.0, 11.0), body_shadow)
	_draw_ellipse(body_center + Vector2(-46.0, -20.0), Vector2(12.0, 10.0), body)
	for claw_index in range(3):
		var claw_x := body_center.x - 52.0 + float(claw_index) * 5.0
		draw_line(Vector2(claw_x, body_center.y - 24.0), Vector2(claw_x + 1.0, body_center.y - 18.0), Color("#64748b", alpha), 1.4, true)

func _draw_item_slots(reveal: float) -> void:
	var layout := _get_slot_layout()
	var slot_size := float(layout["size"])
	var gap := float(layout["gap"])
	var left := float(layout["left"])
	var top := float(layout["top"])
	var alpha := clampf(reveal, 0.0, 1.0)
	for index in range(8):
		var rect := Rect2(left + index * (slot_size + gap), top, slot_size, slot_size)
		draw_style_box(_slot_style(alpha), rect)
		var center := rect.get_center()
		draw_circle(center, maxf(3.0, slot_size * 0.13), Color(0.80, 0.87, 0.95, 0.20 * alpha))
		draw_arc(center, slot_size * 0.25, -0.8, 2.2, 12, Color(0.80, 0.87, 0.95, 0.28 * alpha), 1.2, true)

func _slot_style(alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.08, 0.15, 0.92 * alpha)
	style.border_color = Color(0.55, 0.70, 0.84, 0.86 * alpha)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	return style

func _draw_cat_head(center: Vector2) -> void:
	var body := Color("#d8dee7")
	var body_shadow := Color("#778397")
	var face := Color("#f1f5f9")
	var ear_inner := Color("#f9a8d4")
	var eye := Color("#172033")
	var pink := Color("#fb8fbc")

	_draw_ellipse(center + Vector2(0.0, 37.0), Vector2(35.0, 7.0), Color(0.0, 0.0, 0.0, 0.24))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-31.0, -17.0), center + Vector2(-26.0, -53.0), center + Vector2(-4.0, -28.0)
	]), body_shadow)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(4.0, -28.0), center + Vector2(27.0, -53.0), center + Vector2(32.0, -17.0)
	]), body_shadow)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-24.0, -22.0), center + Vector2(-22.0, -43.0), center + Vector2(-8.0, -27.0)
	]), ear_inner)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(8.0, -27.0), center + Vector2(22.0, -43.0), center + Vector2(24.0, -22.0)
	]), ear_inner)
	_draw_ellipse(center + Vector2(0.0, 3.0), Vector2(36.0, 35.0), body_shadow)
	_draw_ellipse(center + Vector2(0.0, -1.0), Vector2(34.0, 34.0), body)
	_draw_ellipse(center + Vector2(0.0, 5.0), Vector2(30.0, 28.0), face)

	var blinking := blink_timer > 3.02
	if blinking:
		draw_arc(center + Vector2(-12.0, -3.0), 6.0, 0.15, 2.9, 10, eye, 2.4, true)
		draw_arc(center + Vector2(12.0, -3.0), 6.0, 0.25, 2.99, 10, eye, 2.4, true)
	else:
		_draw_ellipse(center + Vector2(-12.0, -3.0), Vector2(7.0, 10.0), eye)
		_draw_ellipse(center + Vector2(12.0, -3.0), Vector2(7.0, 10.0), eye)
		draw_circle(center + Vector2(-10.0, -7.0), 2.8, Color.WHITE)
		draw_circle(center + Vector2(14.0, -7.0), 2.8, Color.WHITE)
		draw_circle(center + Vector2(-14.0, 3.0), 1.5, Color(0.65, 0.75, 0.88, 0.9))
		draw_circle(center + Vector2(10.0, 3.0), 1.5, Color(0.65, 0.75, 0.88, 0.9))

	_draw_ellipse(center + Vector2(-20.0, 13.0), Vector2(7.0, 4.0), Color(1.0, 0.45, 0.65, 0.34))
	_draw_ellipse(center + Vector2(20.0, 13.0), Vector2(7.0, 4.0), Color(1.0, 0.45, 0.65, 0.34))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-4.0, 10.0), center + Vector2(4.0, 10.0), center + Vector2(0.0, 15.0)
	]), pink)
	draw_arc(center + Vector2(0.0, 14.0), 7.0, 0.2, 1.35, 8, body_shadow, 1.6, true)
	draw_arc(center + Vector2(0.0, 14.0), 7.0, 1.8, 2.95, 8, body_shadow, 1.6, true)

	for side in [-1.0, 1.0]:
		draw_line(center + Vector2(side * 24.0, 11.0), center + Vector2(side * 43.0, 7.0), body_shadow, 1.2, true)
		draw_line(center + Vector2(side * 24.0, 15.0), center + Vector2(side * 44.0, 17.0), body_shadow, 1.2, true)

	# Small officer badge remains visible in the expanded version.
	draw_circle(center + Vector2(-30.0, 28.0), 9.0, Color("#172033"))
	draw_circle(center + Vector2(-30.0, 28.0), 6.0, Color("#fbbf24"))
	draw_circle(center + Vector2(-30.0, 28.0), 2.0, Color("#fff7cc"))

func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(24):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
