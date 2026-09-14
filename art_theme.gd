class_name ArtTheme
extends RefCounted

# Shared casual American-cartoon art direction. Keep gameplay colors here so
# every procedural drawing uses the same warm outline and stepped shading.
const CREAM := Color("#fff7dc")
const PAPER := Color("#fffdf4")
const SKY := Color("#80d8f7")
const SKY_LIGHT := Color("#d9f5ff")
const GRASS := Color("#72c95b")
const GRASS_LIGHT := Color("#a6e56f")
const GRASS_DARK := Color("#3d8d4e")
const CORAL := Color("#ff6f61")
const PURPLE := Color("#9b6de3")
const SUN := Color("#ffd34e")
const INK := Color("#293452")
const INK_SOFT := Color("#4b5675")
const SHADOW := Color(0.25, 0.19, 0.20, 0.24)
const PANEL := Color("#fff4d2")
const PANEL_ALT := Color("#e7f7ff")
const PANEL_BORDER := Color("#5a4d68")

enum TileMaterial {
	HARD_CANDY,
	GUMMY,
	CREAM_CANDY,
}

# Change this single constant to compare the three procedural tile finishes.
const ACTIVE_TILE_MATERIAL := TileMaterial.HARD_CANDY
const TILE_MATERIAL_PRESETS := {
	TileMaterial.HARD_CANDY: {
		"extrusion_depth": 10.0,
		"rim_darkness": 0.30,
		"bevel_lighten": 0.10,
		"face_lighten": 0.035,
		"side_darkness": [0.23, 0.36, 0.29],
		"bottom_darkness": 0.39,
		"facet_alpha": 0.17,
		"lower_shade_alpha": 0.15,
		"specular_alpha": 0.78,
		"inner_glow_alpha": 0.11,
		"texture_alpha": 0.22,
		"texture_count": 3,
		"texture_style": 0,
		"shadow_near_alpha": 0.20,
		"shadow_far_alpha": 0.09,
		"outline_width": 2.5,
		"side_highlight_alpha": 0.30,
	},
	TileMaterial.GUMMY: {
		"extrusion_depth": 9.0,
		"rim_darkness": 0.20,
		"bevel_lighten": 0.14,
		"face_lighten": 0.07,
		"side_darkness": [0.16, 0.25, 0.20],
		"bottom_darkness": 0.29,
		"facet_alpha": 0.12,
		"lower_shade_alpha": 0.09,
		"specular_alpha": 0.48,
		"inner_glow_alpha": 0.20,
		"texture_alpha": 0.16,
		"texture_count": 5,
		"texture_style": 1,
		"shadow_near_alpha": 0.16,
		"shadow_far_alpha": 0.07,
		"outline_width": 2.2,
		"side_highlight_alpha": 0.22,
	},
	TileMaterial.CREAM_CANDY: {
		"extrusion_depth": 8.0,
		"rim_darkness": 0.18,
		"bevel_lighten": 0.16,
		"face_lighten": 0.12,
		"side_darkness": [0.14, 0.21, 0.17],
		"bottom_darkness": 0.25,
		"facet_alpha": 0.08,
		"lower_shade_alpha": 0.07,
		"specular_alpha": 0.26,
		"inner_glow_alpha": 0.08,
		"texture_alpha": 0.24,
		"texture_count": 7,
		"texture_style": 2,
		"shadow_near_alpha": 0.14,
		"shadow_far_alpha": 0.06,
		"outline_width": 2.0,
		"side_highlight_alpha": 0.16,
	},
}

const PANEL_CREAM_TEXTURE := preload("res://assets/art/ui_panel_cream.svg")
const PANEL_BLUE_TEXTURE := preload("res://assets/art/ui_panel_blue.svg")
const BUTTON_BLUE_TEXTURE := preload("res://assets/art/ui_button_blue.svg")
const BUTTON_YELLOW_TEXTURE := preload("res://assets/art/ui_button_yellow.svg")
const BUTTON_CORAL_TEXTURE := preload("res://assets/art/ui_button_coral.svg")

static func tile_material(material: int = ACTIVE_TILE_MATERIAL) -> Dictionary:
	return TILE_MATERIAL_PRESETS.get(material, TILE_MATERIAL_PRESETS[TileMaterial.HARD_CANDY])

static func panel_style(background: Color = PANEL, _border: Color = PANEL_BORDER, _radius := 22, _border_width := 4) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = PANEL_BLUE_TEXTURE if background == PANEL_ALT else PANEL_CREAM_TEXTURE
	style.texture_margin_left = 34.0
	style.texture_margin_top = 34.0
	style.texture_margin_right = 34.0
	style.texture_margin_bottom = 34.0
	style.content_margin_left = 18.0
	style.content_margin_top = 18.0
	style.content_margin_right = 18.0
	style.content_margin_bottom = 22.0
	return style

static func button_style(background: Color, pressed := false) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	if background.r > 0.90 and background.g < 0.75:
		style.texture = BUTTON_CORAL_TEXTURE
	elif background.r > 0.75 and background.g > 0.65 and background.b < 0.65:
		style.texture = BUTTON_YELLOW_TEXTURE
	else:
		style.texture = BUTTON_BLUE_TEXTURE
	style.texture_margin_left = 36.0
	style.texture_margin_top = 14.0
	style.texture_margin_right = 36.0
	style.texture_margin_bottom = 14.0
	style.modulate_color = Color(0.90, 0.90, 0.90, 1.0) if pressed else Color.WHITE
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 9.0 if pressed else 6.0
	style.content_margin_bottom = 5.0 if pressed else 10.0
	return style

static func pill_style(yellow := false) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = BUTTON_YELLOW_TEXTURE if yellow else BUTTON_BLUE_TEXTURE
	style.texture_margin_left = 34.0
	style.texture_margin_top = 14.0
	style.texture_margin_right = 34.0
	style.texture_margin_bottom = 14.0
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	return style

static func apply_button(button: Button, color: Color = SKY) -> void:
	button.add_theme_stylebox_override("normal", button_style(color))
	button.add_theme_stylebox_override("hover", button_style(color.lightened(0.10)))
	button.add_theme_stylebox_override("pressed", button_style(color.darkened(0.08), true))
	button.add_theme_stylebox_override("focus", button_style(color.lightened(0.06)))
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_outline_color", Color(1.0, 1.0, 1.0, 0.45))
	button.add_theme_constant_override("outline_size", 2)
