class_name DivinationCrystalEffect
extends Control

@export_category("水晶球特效")
@export var crystal_center := Vector2(310.0, 336.0)
@export var crystal_radius := Vector2(70.0, 54.0)

var effect_mode := 0
var elapsed := 0.0
var duration := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func play_glow(effect_duration := 0.65) -> void:
	effect_mode = 1
	elapsed = 0.0
	duration = maxf(0.1, effect_duration)
	visible = true
	queue_redraw()

func play_flash(effect_duration := 0.85) -> void:
	effect_mode = 2
	elapsed = 0.0
	duration = maxf(0.1, effect_duration)
	visible = true
	queue_redraw()

func clear_effect() -> void:
	effect_mode = 0
	elapsed = 0.0
	duration = 0.0
	visible = false
	queue_redraw()

func _process(delta: float) -> void:
	if effect_mode == 0:
		return
	elapsed += delta
	if elapsed >= duration:
		clear_effect()
		return
	queue_redraw()

func _draw() -> void:
	if effect_mode == 0:
		return
	var progress := clampf(elapsed / maxf(duration, 0.001), 0.0, 1.0)
	if effect_mode == 1:
		var pulse := sin(progress * PI) * 0.8
		for ring in range(3):
			var scale := 0.78 + float(ring) * 0.16 + pulse * 0.08
			_draw_ellipse(crystal_center, crystal_radius * scale, Color(0.72, 0.88, 1.0, (0.20 - float(ring) * 0.045) * pulse))
		_draw_ellipse(crystal_center, crystal_radius * (0.62 + pulse * 0.06), Color(0.92, 0.98, 1.0, 0.20 * pulse))
	else:
		var flash := sin(progress * PI)
		_draw_ellipse(crystal_center, crystal_radius * (0.72 + flash * 0.18), Color(1.0, 1.0, 1.0, 0.58 * flash))

func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(40):
		var angle := TAU * float(index) / 40.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
