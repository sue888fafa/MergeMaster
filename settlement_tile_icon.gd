extends Control

var amount := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func setup(value: int) -> void:
	amount = value
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var half_width := minf(size.x * 0.42, 18.0)
	var half_height := minf(size.y * 0.30, 12.0)
	var outline := Color("#16251b")
	var top_color := Color("#65c96b")
	var side_color := Color("#2e7b45")
	var top := PackedVector2Array([
		center + Vector2(0.0, -half_height),
		center + Vector2(half_width, -half_height * 0.35),
		center + Vector2(half_width, half_height * 0.55),
		center + Vector2(0.0, half_height),
		center + Vector2(-half_width, half_height * 0.55),
		center + Vector2(-half_width, -half_height * 0.35)
	])
	var side := top.duplicate()
	for index in range(side.size()):
		side[index] += Vector2(0.0, 5.0)
	draw_colored_polygon(side, outline)
	draw_colored_polygon(PackedVector2Array([
		top[3], top[4], top[5], top[0], top[1], top[2]
	]), side_color)
	draw_colored_polygon(top, outline)
	var inner := PackedVector2Array()
	for point in top:
		inner.append(center + (point - center) * 0.82)
	draw_colored_polygon(inner, top_color)
	draw_circle(center + Vector2(0.0, -2.0), 5.0, Color("#50a34f"))
	draw_circle(center + Vector2(-4.0, 2.0), 3.0, Color("#83d56f"))

