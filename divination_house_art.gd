class_name DivinationHouseArt
extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var center_x := size.x * 0.5
	var ball_center := Vector2(center_x, 132.0)
	_draw_miko(Vector2(center_x, 226.0))
	_draw_ellipse(Vector2(center_x, 218.0), Vector2(54.0, 10.0), Color(0.0, 0.0, 0.0, 0.28))
	draw_colored_polygon(PackedVector2Array([Vector2(center_x - 42.0, 206.0), Vector2(center_x + 42.0, 206.0), Vector2(center_x + 31.0, 226.0), Vector2(center_x - 31.0, 226.0)]), Color("#312e81"))
	draw_line(Vector2(center_x - 31.0, 210.0), Vector2(center_x + 31.0, 210.0), Color("#c4b5fd"), 2.0, true)
	draw_circle(ball_center + Vector2(3.0, 5.0), 70.0, Color(0.02, 0.01, 0.10, 0.40))
	draw_circle(ball_center, 70.0, Color(0.18, 0.31, 0.66, 0.88))
	draw_circle(ball_center + Vector2(-22.0, -25.0), 18.0, Color(0.82, 0.92, 1.0, 0.56))
	draw_arc(ball_center, 47.0, -2.4, 0.75, 28, Color("#ddd6fe"), 3.0, true)
	draw_arc(ball_center + Vector2(4.0, 3.0), 34.0, 0.3, 2.6, 24, Color("#f0abfc"), 2.0, true)
	draw_circle(ball_center + Vector2(28.0, 20.0), 3.0, Color("#fef08a"))
	draw_circle(ball_center + Vector2(-34.0, 18.0), 2.5, Color("#f5d0fe"))
	draw_circle(ball_center + Vector2(8.0, -8.0), 2.5, Color("#ffffff"))
	draw_arc(ball_center, 70.0, 0.0, TAU, 64, Color("#c4b5fd"), 3.0, true)

func _draw_miko(origin: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([origin + Vector2(-48.0, 58.0), origin + Vector2(-30.0, 12.0), origin + Vector2(30.0, 12.0), origin + Vector2(48.0, 58.0)]), Color("#f8fafc"))
	draw_colored_polygon(PackedVector2Array([origin + Vector2(-27.0, 18.0), origin + Vector2(27.0, 18.0), origin + Vector2(20.0, 72.0), origin + Vector2(-20.0, 72.0)]), Color("#b91c1c"))
	draw_rect(Rect2(origin + Vector2(-24.0, 23.0), Vector2(48.0, 8.0)), Color("#fbbf24"), true)
	draw_circle(origin + Vector2(0.0, -15.0), 22.0, Color("#f8c9a6"))
	draw_circle(origin + Vector2(0.0, -25.0), 24.0, Color("#1f2937"))
	draw_colored_polygon(PackedVector2Array([origin + Vector2(-23.0, -24.0), origin + Vector2(-35.0, 7.0), origin + Vector2(-13.0, -2.0)]), Color("#1f2937"))
	draw_colored_polygon(PackedVector2Array([origin + Vector2(23.0, -24.0), origin + Vector2(35.0, 7.0), origin + Vector2(13.0, -2.0)]), Color("#1f2937"))
	draw_circle(origin + Vector2(-7.0, -14.0), 2.2, Color("#312e81"))
	draw_circle(origin + Vector2(7.0, -14.0), 2.2, Color("#312e81"))
	draw_line(origin + Vector2(-5.0, -3.0), origin + Vector2(5.0, -3.0), Color("#9f1239"), 1.8, true)
	draw_circle(origin + Vector2(23.0, -43.0), 5.0, Color("#ef4444"))

func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(24):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
