@tool
class_name BattleHUDPreview
extends Control

const Config := preload("res://game_config.gd")
const Art := preload("res://art_theme.gd")
const GOLD_ICON := preload("res://assets/generated/ui/coin.png")

@export_category("预览配置")
@export var ui_config: UIEditorConfig = preload("res://ui_editor_config.tres")

var _last_signature := ""

@onready var backdrop: ColorRect = $Backdrop
@onready var gold_icon: TextureRect = $GoldIcon
@onready var gold_label: Label = $GoldLabel
@onready var fps_label: Label = $FpsLabel
@onready var player_info_button: Button = $PlayerInfoButton
@onready var hq_health_bar: ProgressBar = $HQHealthBar
@onready var timer_label: Label = $TimerLabel
@onready var status_label: Label = get_node_or_null("StatusLabel") as Label
@onready var army_label: Label = get_node_or_null("ArmyLabel") as Label
@onready var faction_stats: Control = $FactionStatsDisplay
@onready var broadcast_panel: Panel = $BroadcastPanel
@onready var broadcast_label: Label = get_node_or_null("BroadcastPanel/BroadcastLabel") as Label
@onready var bottom_status_panel: ColorRect = $BottomStatusPanel
@onready var bottom_status_label: Label = get_node_or_null("BottomStatusLabel") as Label

func _ready() -> void:
	_apply_preview()
	_layout_preview()

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	var signature := _config_signature()
	if signature == _last_signature:
		return
	_last_signature = signature
	_apply_preview()
	_layout_preview()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_preview()

func _config_signature() -> String:
	if ui_config == null:
		return str(size)
	return "|".join(PackedStringArray([
		str(size), str(ui_config.player_info_button_rect), str(ui_config.gold_icon_rect),
		str(ui_config.gold_label_rect), str(ui_config.fps_label_rect), str(ui_config.hq_health_bar_rect),
		str(ui_config.timer_rect), str(ui_config.status_label_rect), str(ui_config.army_label_rect),
		str(ui_config.faction_stats_position), str(ui_config.faction_stats_size),
		str(ui_config.faction_stats_avatar_size), str(ui_config.faction_stats_avatar_offset),
		str(ui_config.faction_stats_rank_icon_size), str(ui_config.faction_stats_rank_icon_offset),
		str(ui_config.faction_stats_name_rect), str(ui_config.faction_stats_name_font_size),
		str(ui_config.faction_stats_tile_rect), str(ui_config.faction_stats_tile_count_offset),
		str(ui_config.faction_stats_tile_count_font_size), str(ui_config.faction_stats_animation_duration),
		str(ui_config.faction_stats_first_card_scale)
	]))

func _apply_preview() -> void:
	if not is_instance_valid(backdrop) or ui_config == null:
		return
	Art.configure_ui(ui_config)
	backdrop.color = Color("#c4ecff")
	gold_icon.texture = ui_config.battle_gold_icon_texture if ui_config.battle_gold_icon_texture != null else GOLD_ICON

	fps_label.text = "FPS 60"
	gold_label.text = "金币  12"
	if status_label != null:
		status_label.text = "领地  我:24 红:18 紫:12 绿:09"
	if army_label != null:
		army_label.text = "士兵  我:12 红:09 紫:07 绿:05"
	timer_label.text = "08:42"
	if broadcast_label != null:
		broadcast_label.text = "红方已淘汰"
	if bottom_status_label != null:
		bottom_status_label.text = "提示：点击己方领地旁的地块购买"
	player_info_button.text = ""
	player_info_button.tooltip_text = "城堡信息"
	hq_health_bar.value = Config.HQ_MAX_HP * 0.72
	if faction_stats.has_method("configure_ui"):
		faction_stats.call("configure_ui", ui_config)
	if faction_stats.has_method("set_faction_data"):
		var territories := {Config.FACTION_PLAYER: 24, Config.FACTION_RED: 18, Config.FACTION_PURPLE: 12, Config.FACTION_GREEN: 9}
		var armies := {Config.FACTION_PLAYER: 12, Config.FACTION_RED: 9, Config.FACTION_PURPLE: 7, Config.FACTION_GREEN: 5}
		faction_stats.call("set_faction_data", Config.FACTION_IDS, territories, armies)

func _apply_label_style(label: Label, font_size: int, color: Color, outline := Color(0.02, 0.04, 0.08, 0.92)) -> void:
	label.add_theme_font_size_override("font_size", maxi(1, font_size))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", outline)
	label.add_theme_constant_override("outline_size", 4)

func _layout_preview() -> void:
	if not is_instance_valid(backdrop) or ui_config == null:
		return
	var viewport_size := size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		viewport_size = Vector2(720.0, 1280.0)
	backdrop.position = Vector2.ZERO
	backdrop.size = viewport_size
