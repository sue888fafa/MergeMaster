class_name MerchantShopArt
extends Control

const MERCHANT_ART := preload("res://assets/generated/merchant.png")

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
	var art_size := minf(size.x, size.y) * (0.92 if presenting_cards else 0.84)
	var art_rect := Rect2(
		Vector2((size.x - art_size) * 0.5, (size.y - art_size) * 0.5),
		Vector2(art_size, art_size)
	)
	draw_texture_rect(MERCHANT_ART, art_rect, false)

func _draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(24):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)
