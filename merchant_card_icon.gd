class_name MerchantCardIcon
extends Control

const CARD_ART := {
	"dragon": preload("res://assets/generated/cards/dragon.png"),
	"upgrade": preload("res://assets/generated/cards/upgrade.png"),
	"steel_barrier": preload("res://assets/generated/cards/steel_barrier.png"),
	"blizzard": preload("res://assets/generated/cards/blizzard.png"),
	"transfer_certificate": preload("res://assets/generated/cards/transfer_certificate.png"),
	"occupy": preload("res://assets/generated/cards/occupy.png"),
	"build": preload("res://assets/generated/cards/build.png"),
	"recycle": preload("res://assets/generated/cards/recycle.png"),
	"steal": preload("res://assets/generated/cards/steal.png")
}
const COIN_ART := preload("res://assets/generated/ui/coin.png")

var card_id := ""
var coin_mode := false

func setup_card(value: String) -> void:
	card_id = value
	coin_mode = false
	visible = true
	queue_redraw()

func setup_coin() -> void:
	card_id = ""
	coin_mode = true
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var center := size * 0.5
	if coin_mode:
		if COIN_ART != null:
			var art_size := Vector2(COIN_ART.get_size())
			var fit_scale := minf(size.x / maxf(1.0, art_size.x), size.y / maxf(1.0, art_size.y))
			var draw_size := art_size * fit_scale
			draw_texture_rect(COIN_ART, Rect2((size - draw_size) * 0.5, draw_size), false)
			return
		draw_circle(center + Vector2(1.5, 2.0), 12.0, Color(0.12, 0.08, 0.02, 0.28))
		draw_circle(center, 12.0, Color("#facc15"))
		draw_circle(center, 8.0, Color("#fde68a"))
		draw_arc(center, 12.0, 0.0, TAU, 24, Color("#a16207"), 2.0, true)
		draw_string(ThemeDB.fallback_font, center + Vector2(-4.5, 5.0), "金", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#a16207"))
		return

	var card_art := CARD_ART.get(card_id) as Texture2D
	if card_art != null:
		# The supplied card art includes its own frame, title, and illustration.
		# Keep the procedural renderer below as a fallback for future card IDs.
		var art_size := Vector2(card_art.get_size())
		var fit_scale := minf(size.x / maxf(1.0, art_size.x), size.y / maxf(1.0, art_size.y))
		var draw_size := art_size * fit_scale
		draw_texture_rect(card_art, Rect2((size - draw_size) * 0.5, draw_size), false)
		return

	var card_color := Color("#64748b")
	match card_id:
		"dragon": card_color = Color("#ef4444")
		"upgrade": card_color = Color("#8b5cf6")
		"steel_barrier": card_color = Color("#94a3b8")
		"blizzard": card_color = Color("#0891b2")
		"transfer_certificate": card_color = Color("#f59e0b")
	var rect := Rect2(center - Vector2(22.0, 29.0), Vector2(44.0, 58.0))
	draw_style_box(_card_style(card_color), rect)
	draw_line(center + Vector2(-14.0, -18.0), center + Vector2(14.0, -18.0), Color(1, 1, 1, 0.42), 2.0, true)
	match card_id:
		"dragon":
			draw_colored_polygon(PackedVector2Array([center + Vector2(-13, 13), center + Vector2(0, -10), center + Vector2(13, 13)]), Color("#fecaca"))
			draw_circle(center + Vector2(0, -10), 3.0, Color("#7f1d1d"))
		"upgrade":
			draw_string(ThemeDB.fallback_font, center + Vector2(-12, 9), "+1", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#f5f3ff"))
		"steel_barrier":
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -15), center + Vector2(13, -7), center + Vector2(9, 12), center + Vector2(0, 17), center + Vector2(-9, 12), center + Vector2(-13, -7)]), Color("#e2e8f0"))
			draw_line(center + Vector2(-7, 1), center + Vector2(7, 1), Color("#475569"), 2.0, true)
		"blizzard":
			for angle in [0.0, PI / 3.0, 2.0 * PI / 3.0]:
				var direction := Vector2(cos(angle), sin(angle)) * 13.0
				draw_line(center - direction, center + direction, Color("#cffafe"), 2.0, true)
		"transfer_certificate":
			draw_string(ThemeDB.fallback_font, center + Vector2(-8, 7), "权", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#78350f"))

func _card_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color.darkened(0.25)
	style.border_color = color.lightened(0.30)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	return style
