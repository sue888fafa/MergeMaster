class_name CatCompanion
extends Control

const Config := preload("res://game_config.gd")

var bubble_message := ""
var bubble_remaining := 0.0
var animation_time := 0.0
var blink_timer := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(260.0, 160.0)
	queue_redraw()

func show_bubble(message: String) -> void:
	bubble_message = message
	bubble_remaining = Config.OFFICER_BUBBLE_DURATION
	queue_redraw()

func hide_bubble() -> void:
	bubble_message = ""
	bubble_remaining = 0.0
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
	queue_redraw()

func _draw() -> void:
	var bob := sin(animation_time * 2.8) * 2.0
	var cat_center := Vector2(205.0, 123.0 + bob)
	if not bubble_message.is_empty():
		_draw_bubble()
	_draw_cat(cat_center)

func _draw_bubble() -> void:
	var bubble_rect := Rect2(4.0, 4.0, 250.0, 78.0)
	draw_style_box(_bubble_style(Color(0.03, 0.06, 0.11, 0.94), Color("#fbbf24")), bubble_rect)
	draw_colored_polygon(PackedVector2Array([
		Vector2(182.0, 82.0), Vector2(196.0, 82.0), Vector2(190.0, 96.0)
	]), Color(0.03, 0.06, 0.11, 0.94))
	var font := ThemeDB.fallback_font
	var text_rect := Rect2(14.0, 10.0, 230.0, 64.0)
	draw_multiline_string(font, text_rect.position + Vector2(0.0, 14.0), bubble_message, HORIZONTAL_ALIGNMENT_CENTER, text_rect.size.x, 14, 3, Color("#f8fafc"))

func _bubble_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	return style

func _draw_cat(center: Vector2) -> void:
	var body := Color("#d1d5db")
	var body_shadow := Color("#6b7280")
	var face := Color("#e5e7eb")
	var ear_inner := Color("#f9a8d4")
	var eye := Color("#111827")
	var accent := Color("#f59e0b")
	var tail_wave := sin(animation_time * 3.4) * 0.16

	# Ground shadow and curled tail.
	_draw_ellipse(center + Vector2(0.0, 24.0), Vector2(31.0, 7.0), Color(0.0, 0.0, 0.0, 0.28))
	draw_arc(center + Vector2(25.0, 2.0), 22.0, -1.2 + tail_wave, 1.0 + tail_wave, 18, body_shadow, 6.0, true)
	draw_arc(center + Vector2(25.0, 2.0), 18.0, -1.2 + tail_wave, 1.0 + tail_wave, 18, body, 3.0, true)

	# Body, head, and pointed ears.
	_draw_ellipse(center + Vector2(0.0, 8.0), Vector2(25.0, 25.0), body_shadow)
	_draw_ellipse(center + Vector2(0.0, 4.0), Vector2(23.0, 25.0), body)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-20.0, -12.0), center + Vector2(-17.0, -39.0), center + Vector2(-3.0, -20.0)
	]), body)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(3.0, -20.0), center + Vector2(17.0, -39.0), center + Vector2(20.0, -12.0)
	]), body)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-16.0, -17.0), center + Vector2(-15.0, -31.0), center + Vector2(-7.0, -20.0)
	]), ear_inner)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(7.0, -20.0), center + Vector2(15.0, -31.0), center + Vector2(16.0, -17.0)
	]), ear_inner)
	_draw_ellipse(center + Vector2(0.0, -10.0), Vector2(22.0, 20.0), face)

	# Blink periodically while keeping the face readable.
	var blinking := blink_timer > 3.02
	if blinking:
		draw_line(center + Vector2(-10.0, -12.0), center + Vector2(-4.0, -12.0), eye, 2.0, true)
		draw_line(center + Vector2(4.0, -12.0), center + Vector2(10.0, -12.0), eye, 2.0, true)
	else:
		draw_circle(center + Vector2(-7.0, -12.0), 3.0, eye)
		draw_circle(center + Vector2(7.0, -12.0), 3.0, eye)
		draw_circle(center + Vector2(-6.0, -13.0), 1.0, Color.WHITE)
		draw_circle(center + Vector2(8.0, -13.0), 1.0, Color.WHITE)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-3.0, -4.0), center + Vector2(3.0, -4.0), center + Vector2(0.0, 1.0)
	]), Color("#f472b6"))
	draw_line(center + Vector2(0.0, 1.0), center + Vector2(-5.0, 5.0), body_shadow, 1.5, true)
	draw_line(center + Vector2(0.0, 1.0), center + Vector2(5.0, 5.0), body_shadow, 1.5, true)

	# Small officer badge.
	draw_circle(center + Vector2(-21.0, 18.0), 8.0, Color("#172033"))
	draw_circle(center + Vector2(-21.0, 18.0), 5.0, accent)
	draw_line(center + Vector2(-21.0, 14.0), center + Vector2(-21.0, 22.0), Color("#172033"), 1.5, true)

func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(18):
		var angle := TAU * float(index) / 18.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
