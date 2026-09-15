class_name UIEditorConfig
extends Resource

## Central authoring resource for runtime-created UI. Edit the resource in the
## Inspector to change the game's UI without changing the scripts that build it.

@export_category("切片资源")
@export var panel_texture: Texture2D = preload("res://assets/art/ui_panel_blue.svg")
@export var panel_texture_alt: Texture2D = preload("res://assets/art/ui_panel_cream.svg")
@export var panel_texture_margins := Vector4(34.0, 34.0, 34.0, 34.0)
@export var button_texture: Texture2D = preload("res://assets/art/ui_button_blue.svg")
@export var button_texture_hover: Texture2D
@export var button_texture_pressed: Texture2D
@export var button_texture_margins := Vector4(36.0, 14.0, 36.0, 14.0)
@export var flat_panel_texture: Texture2D
@export var flat_button_texture: Texture2D

@export_category("底图颜色")
@export var panel_tint := Color.WHITE
@export var flat_panel_color := Color("#172033")
@export var flat_panel_border_color := Color("#334155")
@export var overlay_color := Color(0.01, 0.03, 0.07, 0.46)
@export var modal_overlay_color := Color(0.01, 0.03, 0.07, 0.80)

@export_category("按钮颜色")
@export var button_normal_tint := Color.WHITE
@export var button_hover_tint := Color(1.05, 1.05, 1.05, 1.0)
@export var button_pressed_tint := Color(0.90, 0.90, 0.90, 1.0)
@export var button_disabled_color := Color("#263244")
@export var popup_button_color := Color("#60a5fa")

@export_category("战斗界面布局")
@export var player_info_button_rect := Rect2(16.0, 78.0, 48.0, 48.0)
@export var player_info_close_button_rect := Rect2(-94.0, 18.0, 70.0, 34.0)
@export var gold_icon_rect := Rect2(16.0, 14.0, 28.0, 28.0)
@export var gold_label_rect := Rect2(48.0, 14.0, 118.0, 34.0)
@export var fps_label_rect := Rect2(16.0, 120.0, 100.0, 24.0)
@export var hq_health_bar_rect := Rect2(16.0, 50.0, 142.0, 10.0)
@export var timer_rect := Rect2(120.0, 62.0, -240.0, 42.0)
@export var status_label_rect := Rect2(-430.0, 14.0, 414.0, 34.0)
@export var army_label_rect := Rect2(-430.0, 45.0, 414.0, 26.0)
@export var faction_stats_position := Vector2(-16.0, 4.0)
@export var faction_stats_minimum_size := Vector2(230.0, 78.0)
@export var faction_stats_size := Vector2(234.0, 78.0)
@export var bottom_status_rect := Rect2(16.0, -78.0, 310.0, 62.0)
@export var broadcast_rect := Rect2(0.0, 110.0, 560.0, 46.0)
@export var watch_button_rect := Rect2(12.0, -58.0, 148.0, 42.0)
@export var hint_rect := Rect2(20.0, -220.0, 420.0, 84.0)

@export_category("战斗界面样式")
@export var battle_gold_icon_texture: Texture2D = preload("res://assets/generated/ui/coin.png")
@export var battle_gold_font_size := 18
@export var battle_status_font_size := 13
@export var battle_army_font_size := 13
@export var battle_timer_font_size := 22
@export var battle_fps_font_size := 14
@export var battle_broadcast_font_size := 19
@export var battle_text_color := Color("#f8fafc")
@export var battle_secondary_text_color := Color("#e2e8f0")
@export var battle_text_outline_color := Color(0.02, 0.04, 0.08, 0.92)
@export var battle_timer_color := Color("#ffffff")
@export var battle_timer_outline_color := Color("#000000")
@export var battle_broadcast_color := Color(0.35, 0.03, 0.03, 0.94)
@export var battle_broadcast_text_color := Color("#fee2e2")
@export var battle_fps_good_color := Color("#4ade80")
@export var battle_fps_warning_color := Color("#facc15")
@export var battle_fps_bad_color := Color("#f87171")
@export var battle_hq_health_background_color := Color("#3f1720")
@export var battle_hq_health_fill_color := Color("#ef4444")
@export var faction_stats_label_color := Color("#cbd5e1")
@export var faction_stats_outline_color := Color("#0b1220")
@export var faction_stats_font_size := 13
@export var faction_stats_column_spacing := 48.0
@export var faction_stats_icon_radius := 15.0
@export var faction_stats_soldier_scale := 1.0

@export_category("弹窗位置与大小")
@export var player_info_panel_size := Vector2(600.0, 760.0)
@export var player_info_panel_offset := Vector2.ZERO
@export var equipment_detail_panel_size := Vector2(600.0, 360.0)
@export var equipment_detail_panel_offset := Vector2.ZERO
@export var equipment_detail_close_button_rect := Rect2(0.0, 294.0, 120.0, 40.0)
@export var equipment_replacement_panel_size := Vector2(640.0, 450.0)
@export var equipment_replacement_panel_offset := Vector2.ZERO
@export var equipment_replace_button_rect := Rect2(-146.0, 370.0, 120.0, 42.0)
@export var equipment_discard_button_rect := Rect2(26.0, 370.0, 120.0, 42.0)
@export var card_event_panel_size := Vector2(580.0, 520.0)
@export var card_event_panel_offset := Vector2.ZERO
@export var card_draw_confirm_button_rect := Rect2(178.0, 420.0, 126.0, 42.0)
@export var card_draw_countdown_rect := Rect2(320.0, 426.0, 150.0, 30.0)
@export var divination_panel_size := Vector2(620.0, 470.0)
@export var divination_panel_offset := Vector2.ZERO
@export var intelligence_panel_size := Vector2(620.0, 380.0)
@export var intelligence_panel_offset := Vector2.ZERO
@export var merchant_arrival_panel_size := Vector2(620.0, 480.0)
@export var merchant_arrival_panel_offset := Vector2.ZERO
@export var merchant_shop_panel_size := Vector2(660.0, 500.0)
@export var merchant_shop_panel_offset := Vector2.ZERO
@export var defeat_panel_size := Vector2(620.0, 280.0)
@export var defeat_panel_offset := Vector2.ZERO
@export var settlement_panel_size := Vector2(680.0, 1140.0)
@export var settlement_panel_offset := Vector2.ZERO
@export var settlement_confirm_button_rect := Rect2(0.0, 950.0, 180.0, 54.0)

@export_category("结算界面")
@export var settlement_header_texture: Texture2D = preload("res://assets/generated/settlement/header.png")
@export var settlement_panel_color := Color("#9a6035")
@export var settlement_button_color := Color("#ffc52e")

func rect_size_or_viewport(rect: Rect2, viewport_size: Vector2, width_ratio := 0.88, height_ratio := 0.46) -> Vector2:
	var width := rect.size.x if rect.size.x > 0.0 else viewport_size.x * width_ratio
	var height := rect.size.y if rect.size.y > 0.0 else viewport_size.y * height_ratio
	return Vector2(width, height)
