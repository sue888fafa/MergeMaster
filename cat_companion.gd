class_name CatCompanion
extends Control

const Config := preload("res://game_config.gd")
const MerchantDataScript := preload("res://merchant_data.gd")
const MerchantCardIconScript := preload("res://merchant_card_icon.gd")
const CAT_OFFICER_ART := preload("res://assets/generated/companion/cat_officer.png")

signal expanded_changed(expanded: bool)
signal inventory_item_dropped(item_id: String, screen_position: Vector2)
signal inventory_item_dragged(item_id: String, screen_position: Vector2)
signal inventory_item_drag_ended(item_id: String, screen_position: Vector2, was_dragged: bool)

const COMPANION_HEIGHT := 340.0
const HEAD_RADIUS := 38.0
const SLOT_SIZE := 62.0
const SLOT_TOP := 218.0
const CARD_BASE_SIZE := SLOT_SIZE * 1.5
const CARD_MIN_SIZE := 40.0
const CARD_OVERLAP := 0.30
const CARD_RIGHT_MARGIN := 12.0
const CARD_OPEN_DURATION := 0.90
const CARD_CLOSE_DURATION := 0.52
const ITEM_HINT_DURATION := 1.8
const SELECTED_CARD_RISE := 16.0
const CARD_DEAL_STAGGER := 0.06
const CARD_TILT_DEGREES := [-5.0, -3.5, -2.0, -0.8, 0.8, 2.0, 3.5, 5.0]

var bubble_message := ""
var bubble_remaining := 0.0
var animation_time := 0.0
var blink_timer := 0.0
var is_expanded := false
var expanded_progress := 0.0
var expand_tween: Tween
var head_button: Button
var slot_buttons: Array[Button] = []
var inventory_items: Array[String] = []
var dragging_item_id := ""
var dragging_item_index := -1
var dragging_screen_position := Vector2.ZERO
var drag_start_screen_position := Vector2.ZERO
var drag_started := false
var flying_item_id := ""
var flying_item_index := -1
var flying_start_local := Vector2.ZERO
var flying_progress := 0.0
var fly_tween: Tween
var layout_transition_progress := 1.0
var layout_transition_from_count := 0
var layout_transition_to_count := 0
var layout_transition_tween: Tween
var pending_layout_from_count := -1
var last_layout_progress := -1.0
var last_layout_transition_progress := -1.0
var item_hint_index := -1
var item_hint_text := ""
var item_hint_progress := 0.0
var item_hint_tween: Tween
var selected_item_index := -1

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

func _hide_item_hint() -> void:
	if item_hint_tween != null and item_hint_tween.is_valid():
		item_hint_tween.kill()
	item_hint_index = -1
	item_hint_text = ""
	item_hint_progress = 0.0
	selected_item_index = -1

func _show_item_hint(index: int) -> void:
	if index < 0 or index >= inventory_items.size():
		return
	var item_id := inventory_items[index]
	var item: Dictionary = MerchantDataScript.get_item(item_id)
	if item.is_empty():
		return
	_hide_item_hint()
	item_hint_index = index
	selected_item_index = index
	item_hint_text = "%s\n%s" % [str(item.get("name", "卡片")), str(item.get("description", ""))]
	item_hint_progress = 0.0
	item_hint_tween = create_tween()
	item_hint_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	item_hint_tween.tween_property(self, "item_hint_progress", 1.0, ITEM_HINT_DURATION)
	queue_redraw()

func toggle_expanded() -> void:
	set_expanded(not is_expanded)

func set_expanded(expanded: bool) -> void:
	if is_expanded == expanded and (expand_tween == null or not expand_tween.is_valid()):
		return
	is_expanded = expanded
	if not expanded:
		_hide_item_hint()
	if expand_tween != null and expand_tween.is_valid():
		expand_tween.kill()
	expand_tween = create_tween()
	expand_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	expand_tween.tween_property(self, "expanded_progress", 1.0 if expanded else 0.0, CARD_OPEN_DURATION if expanded else CARD_CLOSE_DURATION)
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
		slot_button.add_theme_stylebox_override("hover", _transparent_style())
		slot_button.add_theme_stylebox_override("pressed", _transparent_style())
		slot_button.pressed.connect(_on_slot_pressed.bind(index, slot_button))
		slot_button.gui_input.connect(_on_slot_gui_input.bind(index))
		slot_buttons.append(slot_button)
		add_child(slot_button)

func set_item_inventory(items: Array[String]) -> void:
	var previous_count := inventory_items.size()
	var had_items := not inventory_items.is_empty()
	inventory_items.clear()
	for item_id in items:
		if inventory_items.size() >= 8:
			break
		if MerchantDataScript.is_card(item_id):
			inventory_items.append(item_id)
	if selected_item_index >= inventory_items.size():
		_hide_item_hint()
	if inventory_items.size() > previous_count:
		pending_layout_from_count = previous_count
	else:
		pending_layout_from_count = -1
		layout_transition_progress = 1.0
		layout_transition_from_count = inventory_items.size()
		layout_transition_to_count = inventory_items.size()
		if layout_transition_tween != null and layout_transition_tween.is_valid():
			layout_transition_tween.kill()
	_update_slot_tooltips()
	if not had_items and not inventory_items.is_empty():
		set_expanded(true)
	queue_redraw()

func cancel_item_drag() -> void:
	dragging_item_id = ""
	dragging_item_index = -1
	drag_started = false
	dragging_screen_position = Vector2.ZERO
	drag_start_screen_position = Vector2.ZERO
	_hide_item_hint()
	queue_redraw()

func play_item_fly_in(item_id: String, origin_screen_position: Vector2) -> void:
	if not inventory_items.has(item_id):
		return
	if fly_tween != null and fly_tween.is_valid():
		fly_tween.kill()
	if layout_transition_tween != null and layout_transition_tween.is_valid():
		layout_transition_tween.kill()
	flying_item_id = item_id
	flying_item_index = -1
	for index in range(inventory_items.size() - 1, -1, -1):
		if inventory_items[index] == item_id:
			flying_item_index = index
			break
	flying_start_local = get_global_transform_with_canvas().affine_inverse() * origin_screen_position
	var previous_count := pending_layout_from_count
	if previous_count >= 0 and previous_count < inventory_items.size() and previous_count > 0:
		layout_transition_from_count = previous_count
		layout_transition_to_count = inventory_items.size()
		layout_transition_progress = 0.0
		flying_start_local = _get_slot_target_rect(previous_count - 1, previous_count).get_center()
	else:
		layout_transition_from_count = inventory_items.size()
		layout_transition_to_count = inventory_items.size()
		layout_transition_progress = 1.0
	pending_layout_from_count = -1
	flying_progress = 0.0
	_update_interaction_layout()
	fly_tween = create_tween()
	fly_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	fly_tween.tween_property(self, "flying_progress", 1.0, 0.45)
	if layout_transition_from_count < layout_transition_to_count:
		layout_transition_tween = create_tween()
		layout_transition_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		layout_transition_tween.tween_property(self, "layout_transition_progress", 1.0, 0.45)
		layout_transition_tween.finished.connect(_finish_layout_transition)
	fly_tween.finished.connect(_finish_item_fly_in)
	queue_redraw()

func _finish_layout_transition() -> void:
	layout_transition_progress = 1.0
	layout_transition_from_count = layout_transition_to_count
	queue_redraw()

func _finish_item_fly_in() -> void:
	flying_item_id = ""
	flying_item_index = -1
	flying_progress = 0.0
	queue_redraw()

func _update_slot_tooltips() -> void:
	for index in range(slot_buttons.size()):
		if index < inventory_items.size():
			var item := MerchantDataScript.get_item(inventory_items[index])
			slot_buttons[index].tooltip_text = "%s\n拖动到目标地块使用\n%s" % [item.get("name", "卡片"), item.get("description", "")]
		else:
			slot_buttons[index].tooltip_text = "空道具槽"

func _transparent_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_width_left = 0
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 0
	return style

func _on_slot_pressed(_index: int, slot_button: Button) -> void:
	if not dragging_item_id.is_empty():
		return
	_show_item_hint(_index)
	var highlight_color := Color(1.22, 1.14, 0.82, slot_button.modulate.a)
	var normal_color := Color(1.0, 1.0, 1.0, slot_button.modulate.a)
	slot_button.modulate = highlight_color
	var feedback := create_tween()
	feedback.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	feedback.tween_property(slot_button, "modulate", normal_color, 0.16)

func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	if index < 0 or index >= inventory_items.size():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		dragging_item_id = inventory_items[index]
		dragging_item_index = index
		dragging_screen_position = get_viewport().get_mouse_position()
		drag_start_screen_position = dragging_screen_position
		drag_started = false
		accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if selected_item_index >= 0 and dragging_item_id.is_empty():
			_hide_item_hint()
			queue_redraw()

func _process(delta: float) -> void:
	animation_time += delta
	blink_timer += delta
	if blink_timer >= 3.2:
		blink_timer = 0.0
	if bubble_remaining > 0.0:
		bubble_remaining = maxf(0.0, bubble_remaining - delta)
		if bubble_remaining <= 0.0:
			bubble_message = ""
	if not dragging_item_id.is_empty():
		dragging_screen_position = get_viewport().get_mouse_position()
		if not drag_started and dragging_screen_position.distance_to(drag_start_screen_position) >= 8.0:
			drag_started = true
		if drag_started:
			inventory_item_dragged.emit(dragging_item_id, dragging_screen_position)
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var dropped_item := dragging_item_id
			var dropped_position := dragging_screen_position
			var was_dragged := drag_started
			dragging_item_id = ""
			dragging_item_index = -1
			drag_started = false
			if not dropped_item.is_empty() and was_dragged:
				inventory_item_drag_ended.emit(dropped_item, dropped_position, true)
				inventory_item_dropped.emit(dropped_item, dropped_position)
			elif not dropped_item.is_empty():
				inventory_item_drag_ended.emit(dropped_item, dropped_position, false)
	if not is_equal_approx(last_layout_progress, expanded_progress) or not is_equal_approx(last_layout_transition_progress, layout_transition_progress):
		_update_interaction_layout()
	queue_redraw()

func _head_center() -> Vector2:
	return Vector2(maxf(58.0, size.x - 56.0), SLOT_TOP + SLOT_SIZE * 0.5)

func _get_slot_layout(card_count: int = -1) -> Dictionary:
	# The cards intentionally overlap like a hand of playing cards. Keep the
	# full hand right-aligned to the cat while remaining inside narrow screens.
	var count: int = card_count if card_count >= 1 else maxi(1, inventory_items.size())
	var head_center := _head_center()
	var right_edge := head_center.x - HEAD_RADIUS - CARD_RIGHT_MARGIN
	var left_margin := 8.0
	var available_width := maxf(1.0, right_edge - left_margin)
	var slot_size := minf(CARD_BASE_SIZE, maxf(CARD_MIN_SIZE, available_width / (1.0 + float(count - 1) * (1.0 - CARD_OVERLAP))))
	var step := slot_size * (1.0 - CARD_OVERLAP)
	var total_width := slot_size + step * float(count - 1)
	# On very narrow screens, increase overlap instead of allowing clipping.
	if total_width > available_width:
		step = maxf(1.0, (available_width - slot_size) / float(max(1, count - 1)))
		total_width = slot_size + step * float(count - 1)
	var left := right_edge - total_width
	return {
		"size": slot_size,
		"gap": step - slot_size,
		"left": left,
		"top": SLOT_TOP + SLOT_SIZE * 0.5 - slot_size * 0.5
	}

func _get_card_deal_progress(index: int, progress: float) -> float:
	var start := float(index) * CARD_DEAL_STAGGER
	var deal_window := maxf(0.01, 1.0 - CARD_DEAL_STAGGER * 7.0)
	return clampf((progress - start) / deal_window, 0.0, 1.0)

func _get_slot_target_rect(index: int, card_count: int) -> Rect2:
	var layout := _get_slot_layout(card_count)
	var slot_size := float(layout["size"])
	var gap := float(layout["gap"])
	var target := Vector2(float(layout["left"]) + index * (slot_size + gap), float(layout["top"]))
	if card_count == inventory_items.size() and index == selected_item_index and dragging_item_id.is_empty():
		target.y -= SELECTED_CARD_RISE
	return Rect2(target, Vector2(slot_size, slot_size))

func _get_animated_slot_rect(index: int, progress: float) -> Rect2:
	var slot_target := _get_slot_target_rect(index, inventory_items.size())
	var target := slot_target.position
	if layout_transition_from_count < layout_transition_to_count and index < layout_transition_from_count:
		var old_target := _get_slot_target_rect(index, layout_transition_from_count)
		target = old_target.position.lerp(slot_target.position, clampf(layout_transition_progress, 0.0, 1.0))
	var slot_size := slot_target.size.x
	var head_center := _head_center()
	var origin := head_center - Vector2(slot_size * 0.5, slot_size * 0.5)
	var slide := ease(clampf(progress, 0.0, 1.0), 0.82)
	return Rect2(origin.lerp(target, slide), Vector2(slot_size, slot_size))

func _update_interaction_layout() -> void:
	if head_button == null:
		return
	var center := _head_center()
	head_button.position = center - Vector2(HEAD_RADIUS, HEAD_RADIUS)
	head_button.size = Vector2(HEAD_RADIUS * 2.0, HEAD_RADIUS * 2.0)
	var layout := _get_slot_layout()
	var slot_size := float(layout["size"])
	for index in range(slot_buttons.size()):
		var slot_button := slot_buttons[index]
		var card_progress := _get_card_deal_progress(index, expanded_progress)
		var has_item := index < inventory_items.size()
		var slot_rect := _get_animated_slot_rect(index, card_progress)
		slot_button.position = slot_rect.position
		slot_button.size = slot_rect.size
		slot_button.pivot_offset = Vector2(slot_size * 0.5, slot_size * 0.5)
		slot_button.rotation = deg_to_rad(float(CARD_TILT_DEGREES[index]))
		slot_button.visible = has_item and card_progress > 0.01
		slot_button.disabled = not has_item or card_progress < 0.55
		var slot_modulate := slot_button.modulate
		slot_modulate.a = card_progress if has_item else 0.0
		slot_button.modulate = slot_modulate
	last_layout_progress = expanded_progress
	last_layout_transition_progress = layout_transition_progress

func _draw() -> void:
	var bob := sin(animation_time * 2.8) * 1.8
	var head_center := _head_center() + Vector2(0.0, bob)
	var reveal := clampf(expanded_progress, 0.0, 1.0)
	if reveal > 0.01:
		_draw_item_slots(reveal)
	if not bubble_message.is_empty():
		_draw_bubble(head_center)
	_draw_cat_head(head_center)

func _draw_bubble(head_center: Vector2) -> void:
	var bubble_width := minf(175.0, maxf(112.0, size.x - 16.0))
	var bubble_height := 55.0
	var bubble_x := clampf(head_center.x - bubble_width + 24.0, 8.0, maxf(8.0, size.x - bubble_width - 8.0))
	var bubble_y := clampf(head_center.y - HEAD_RADIUS - bubble_height - 10.0, 4.0, maxf(4.0, size.y - bubble_height - 4.0))
	var bubble_rect := Rect2(bubble_x, bubble_y, bubble_width, bubble_height)
	draw_style_box(_bubble_style(Color(0.03, 0.06, 0.11, 0.94), Color("#fbbf24")), bubble_rect)
	var arrow_x := clampf(head_center.x - 12.0, bubble_rect.position.x + 24.0, bubble_rect.end.x - 24.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(arrow_x - 7.0, bubble_rect.end.y), Vector2(arrow_x + 7.0, bubble_rect.end.y), Vector2(arrow_x, bubble_rect.end.y + 9.0)
	]), Color(0.03, 0.06, 0.11, 0.94))
	var font := ThemeDB.fallback_font
	var text_rect := Rect2(bubble_rect.position + Vector2(8.0, 5.0), Vector2(bubble_width - 16.0, bubble_height - 10.0))
	draw_multiline_string(font, text_rect.position + Vector2(0.0, 11.0), bubble_message, HORIZONTAL_ALIGNMENT_CENTER, text_rect.size.x, 11, 3, Color("#f8fafc"))

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
	for index in range(inventory_items.size()):
		var card_reveal := _get_card_deal_progress(index, reveal)
		if card_reveal <= 0.01:
			continue
		var rect := _get_animated_slot_rect(index, card_reveal)
		var center := rect.get_center()
		if index != dragging_item_index and not (index == flying_item_index and not flying_item_id.is_empty()):
			_draw_item_icon(center, inventory_items[index], 0.72 * (slot_size / SLOT_SIZE) * clampf(card_reveal, 0.0, 1.0), deg_to_rad(float(CARD_TILT_DEGREES[index])))
	if not dragging_item_id.is_empty() and drag_started:
		var dragging_local := get_global_transform_with_canvas().affine_inverse() * dragging_screen_position
		var drag_scale := 0.90 * float(layout["size"]) / SLOT_SIZE
		_draw_item_icon(dragging_local, dragging_item_id, drag_scale, deg_to_rad(-2.0))
	if not flying_item_id.is_empty() and flying_item_index >= 0:
		var fly_slot_size := float(layout["size"])
		var target := _get_slot_target_rect(flying_item_index, inventory_items.size()).get_center()
		var fly_position := flying_start_local.lerp(target, flying_progress)
		_draw_item_icon(fly_position, flying_item_id, 0.90 * (fly_slot_size / SLOT_SIZE) * (1.0 - flying_progress * 0.22))
	if item_hint_index >= 0 and item_hint_index < inventory_items.size() and item_hint_progress < 1.0:
		_draw_item_hint(item_hint_index, item_hint_text, item_hint_progress)

func _draw_item_hint(index: int, text: String, progress: float) -> void:
	var rect := _get_animated_slot_rect(index, 1.0)
	var hint_width := minf(220.0, maxf(150.0, size.x - 16.0))
	var hint_height := 58.0
	var rise := progress * 30.0
	var hint_x := clampf(rect.get_center().x - hint_width * 0.5, 8.0, maxf(8.0, size.x - hint_width - 8.0))
	var hint_y := rect.position.y - hint_height - 12.0 - rise
	var fade := 1.0
	if progress > 0.62:
		fade = 1.0 - (progress - 0.62) / 0.38
	var hint_rect := Rect2(Vector2(hint_x, hint_y), Vector2(hint_width, hint_height))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.05, 0.10, 0.94 * fade)
	style.border_color = Color(0.98, 0.77, 0.25, 0.92 * fade)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	draw_style_box(style, hint_rect)
	var arrow_x := clampf(rect.get_center().x, hint_rect.position.x + 18.0, hint_rect.end.x - 18.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(arrow_x - 6.0, hint_rect.end.y),
		Vector2(arrow_x + 6.0, hint_rect.end.y),
		Vector2(arrow_x, hint_rect.end.y + 7.0)
	]), Color(0.02, 0.05, 0.10, 0.94 * fade))
	var font := ThemeDB.fallback_font
	var text_position := hint_rect.position + Vector2(8.0, 5.0)
	draw_multiline_string(font, text_position + Vector2(0.0, 11.0), _wrap_item_hint(text), HORIZONTAL_ALIGNMENT_CENTER, hint_width - 16.0, 12, 4, Color(0.96, 0.98, 1.0, fade))

func _wrap_item_hint(text: String) -> String:
	var lines: Array[String] = []
	for raw_line in text.split("\n"):
		var line := str(raw_line)
		while line.length() > 14:
			lines.append(line.substr(0, 14))
			line = line.substr(14)
		lines.append(line)
	return "\n".join(lines)

func _draw_item_icon(center: Vector2, item_id: String, scale: float, rotation := 0.0) -> void:
	draw_set_transform(center, rotation, Vector2(scale, scale))
	if not MerchantDataScript.is_sealed_barracks_card(item_id):
		var card_art := MerchantCardIconScript.CARD_ART.get(item_id) as Texture2D
		if card_art != null:
			var card_width := 52.0
			var card_height := card_width * card_art.get_height() / maxf(1.0, card_art.get_width())
			draw_texture_rect(card_art, Rect2(-card_width * 0.5, -card_height * 0.5, card_width, card_height), false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
	match item_id:
		MerchantDataScript.ITEM_DRAGON:
			draw_colored_polygon(PackedVector2Array([Vector2(-14, 8), Vector2(0, -13), Vector2(14, 8)]), Color("#ef4444"))
			draw_circle(Vector2(0, -13), 4.0, Color("#fca5a5"))
			draw_line(Vector2(-9, 3), Vector2(-16, -6), Color("#ef4444"), 3.0, true)
			draw_line(Vector2(9, 3), Vector2(16, -6), Color("#ef4444"), 3.0, true)
		MerchantDataScript.ITEM_UPGRADE:
			draw_circle(Vector2.ZERO, 14.0, Color("#7c3aed"))
			draw_string(ThemeDB.fallback_font, Vector2(-7, 6), "+1", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#f5f3ff"))
		MerchantDataScript.ITEM_STEEL_BARRIER:
			draw_colored_polygon(PackedVector2Array([Vector2(0, -15), Vector2(14, -7), Vector2(10, 10), Vector2(0, 16), Vector2(-10, 10), Vector2(-14, -7)]), Color("#94a3b8"))
			draw_line(Vector2(-7, 0), Vector2(7, 0), Color("#f8fafc"), 2.0, true)
		MerchantDataScript.ITEM_BLIZZARD:
			draw_circle(Vector2.ZERO, 13.0, Color("#155e75"))
			for angle in [0.0, PI / 3.0, 2.0 * PI / 3.0]:
				draw_line(-Vector2(cos(angle), sin(angle)) * 11.0, Vector2(cos(angle), sin(angle)) * 11.0, Color("#a5f3fc"), 2.0, true)
		MerchantDataScript.ITEM_TRANSFER_CERTIFICATE:
			draw_rect(Rect2(-11, -14, 22, 28), Color("#fef3c7"), true)
			draw_polyline(PackedVector2Array([Vector2(-11, -14), Vector2(11, -14), Vector2(11, 14), Vector2(-11, 14), Vector2(-11, -14)]), Color("#f59e0b"), 2.0, true)
			draw_string(ThemeDB.fallback_font, Vector2(-5, 5), "权", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#b45309"))
		MerchantDataScript.ITEM_OCCUPY:
			draw_circle(Vector2.ZERO, 13.0, Color("#b91c1c"))
			draw_colored_polygon(PackedVector2Array([Vector2(-2, -9), Vector2(7, -1), Vector2(2, 4), Vector2(-7, -4)]), Color("#fee2e2"))
			draw_line(Vector2(-8, 8), Vector2(8, -8), Color("#fee2e2"), 3.0, true)
		MerchantDataScript.ITEM_BUILD:
			draw_rect(Rect2(-12, -10, 24, 20), Color("#15803d"), true)
			draw_colored_polygon(PackedVector2Array([Vector2(-15, -10), Vector2(0, -21), Vector2(15, -10)]), Color("#86efac"))
			draw_line(Vector2(0, -7), Vector2(0, 7), Color("#dcfce7"), 2.0, true)
		MerchantDataScript.ITEM_RECYCLE:
			draw_circle(Vector2.ZERO, 13.0, Color("#0f766e"))
			draw_arc(Vector2.ZERO, 8.0, -2.7, 0.2, 12, Color("#ccfbf1"), 2.5, true)
			draw_line(Vector2(7, -6), Vector2(10, 0), Color("#ccfbf1"), 2.5, true)
	if MerchantDataScript.is_sealed_barracks_card(item_id):
		var sealed_level := MerchantDataScript.get_sealed_barracks_level(item_id)
		draw_colored_polygon(PackedVector2Array([Vector2(-12, 8), Vector2(0, -13), Vector2(12, 8)]), Color("#475569"))
		draw_circle(Vector2(0, -13), 5.0, Color("#e2e8f0"))
		draw_string(ThemeDB.fallback_font, Vector2(-4, 17), str(sealed_level), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#fef08a"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_cat_head(center: Vector2) -> void:
	var art_width := 104.0
	var art_height := art_width * CAT_OFFICER_ART.get_height() / maxf(1.0, CAT_OFFICER_ART.get_width())
	draw_texture_rect(
		CAT_OFFICER_ART,
		Rect2(center - Vector2(art_width, art_height) * 0.5, Vector2(art_width, art_height)),
		false
	)

func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(24):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
