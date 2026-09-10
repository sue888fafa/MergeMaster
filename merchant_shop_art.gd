class_name MerchantShopArt
extends Control

var presenting_cards := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func set_presenting_cards(value: bool) -> void:
	presenting_cards = value
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var scale_factor := minf(size.x / 112.0, size.y / 82.0)
	var center := Vector2(size.x * 0.5, size.y * 0.56)
	draw_set_transform(center, 0.0, Vector2(scale_factor, scale_factor))

	var cloak := Color("#8b5cf6")
	var cloak_dark := Color("#5b21b6")
	var trim := Color("#fbbf24")
	var skin := Color("#f3c6a5")
	var outline := Color("#172033")
	# Merchant shadow and cloak.
	_draw_ellipse(Vector2(0.0, 27.0), Vector2(28.0, 7.0), Color(0.0, 0.0, 0.0, 0.28))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-20.0, 25.0), Vector2(-15.0, -5.0), Vector2(15.0, -5.0), Vector2(20.0, 25.0)
	]), cloak)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-20.0, 25.0), Vector2(-15.0, -5.0), Vector2(-4.0, 25.0)
	]), cloak_dark)
	draw_line(Vector2(-16.0, 6.0), Vector2(16.0, 6.0), trim, 3.0, true)

	# Face, hood and friendly expression.
	draw_circle(Vector2(0.0, -13.0), 13.0, skin)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-16.0, -13.0), Vector2(-11.0, -30.0), Vector2(0.0, -38.0),
		Vector2(11.0, -30.0), Vector2(16.0, -13.0), Vector2(10.0, -8.0),
		Vector2(-10.0, -8.0)
	]), cloak_dark)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12.0, -28.0), Vector2(0.0, -42.0), Vector2(12.0, -28.0),
		Vector2(8.0, -24.0), Vector2(-8.0, -24.0)
	]), cloak)
	draw_circle(Vector2(-4.5, -14.0), 2.0, outline)
	draw_circle(Vector2(4.5, -14.0), 2.0, outline)
	draw_circle(Vector2(-5.0, -14.5), 0.7, Color.WHITE)
	draw_circle(Vector2(4.0, -14.5), 0.7, Color.WHITE)
	draw_line(Vector2(-3.0, -7.0), Vector2(3.0, -7.0), Color("#7c2d12"), 1.8, true)
	if presenting_cards:
		# During the arrival reveal the merchant lifts both hands toward the
		# three cards shown above, making the presentation read as an action.
		draw_line(Vector2(-13.0, 5.0), Vector2(-29.0, -12.0), skin, 5.0, true)
		draw_line(Vector2(13.0, 5.0), Vector2(29.0, -12.0), skin, 5.0, true)
		draw_circle(Vector2(-29.0, -12.0), 4.0, skin)
		draw_circle(Vector2(29.0, -12.0), 4.0, skin)

	# Long staff and coin pouch identify the merchant.
	draw_line(Vector2(19.0, 23.0), Vector2(28.0, -35.0), Color("#a16207"), 3.0, true)
	draw_circle(Vector2(28.0, -37.0), 6.0, trim)
	draw_circle(Vector2(28.0, -37.0), 3.5, Color("#fde68a"))
	draw_circle(Vector2(-20.0, 16.0), 6.0, Color("#d97706"))
	draw_line(Vector2(-24.0, 12.0), Vector2(-16.0, 20.0), trim, 2.0, true)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(24):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)
