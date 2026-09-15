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
@onready var status_label: Label = $StatusLabel
@onready var army_label: Label = $ArmyLabel
@onready var faction_stats: Control = $FactionStatsDisplay
@onready var broadcast_panel: Panel = $BroadcastPanel
@onready var bottom_status_panel: ColorRect = $BottomStatusPanel

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
	return "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
		str(size), str(ui_config.player_info_button_rect), str(ui_config.gold_icon_rect),
		str(ui_config.gold_label_rect), str(ui_config.fps_label_rect), str(ui_config.hq_health_bar_rect),
		str(ui_config.timer_rect), str(ui_config.status_label_rect), str(ui_config.army_label_rect),
		str(ui_config.faction_stats_position), str(ui_config.faction_stats_size)
	]

func _apply_preview() -> void:
	if not is_instance_valid(backdrop) or ui_config == null:
		return
	Art.configure_ui(ui_config)
	backdrop.color = Color("#c4ecff")
	gold_icon.texture = ui_config.battle_gold_icon_texture if ui_config.battle_gold_icon_texture != null else GOLD_ICON

	fps_label.text = "FPS 60"
	gold_label.text = "金币  12"
	status_label.text = "领地  我:24 红:18 紫:12 绿:09"
	army_label.text = "士兵  我:12 红:09 紫:07 绿:05"
	timer_label.text = "08:42"
	$BroadcastPanel/BroadcastLabel.text = "红方已淘汰"
	$BottomStatusLabel.text = "提示：点击己方领地旁的地块购买"
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
	var player_rect := ui_config.player_info_button_rect
	player_info_button.position = player_rect.position
	player_info_button.size = player_rect.size
	var gold_rect := ui_config.gold_icon_rect
	gold_icon.position = gold_rect.position
	gold_icon.size = gold_rect.size
	var gold_label_rect := ui_config.gold_label_rect
	gold_label.position = gold_label_rect.position
	gold_label.size = gold_label_rect.size
	var fps_rect := ui_config.fps_label_rect
	fps_label.position = fps_rect.position
	fps_label.size = fps_rect.size
	var hq_rect := ui_config.hq_health_bar_rect
	hq_health_bar.position = hq_rect.position
	hq_health_bar.size = hq_rect.size
	var timer_rect := ui_config.timer_rect
	timer_label.position = timer_rect.position
	timer_label.size = Vector2(maxf(1.0, timer_rect.size.x if timer_rect.size.x > 0.0 else viewport_size.x + timer_rect.size.x - timer_rect.position.x), timer_rect.size.y)
	var status_rect := ui_config.status_label_rect
	status_label.position = Vector2(maxf(1.0, viewport_size.x + status_rect.position.x), status_rect.position.y)
	status_label.size = Vector2(minf(status_rect.size.x, maxf(1.0, viewport_size.x - 32.0)), status_rect.size.y)
	var army_rect := ui_config.army_label_rect
	army_label.position = Vector2(maxf(1.0, viewport_size.x + army_rect.position.x), army_rect.position.y)
	army_label.size = Vector2(minf(army_rect.size.x, maxf(1.0, viewport_size.x - 32.0)), army_rect.size.y)
	var required_stats_size := Vector2(42.0 + float(Config.FACTION_IDS.size()) * ui_config.faction_stats_column_spacing, 78.0)
	var stats_size := Vector2(maxf(ui_config.faction_stats_minimum_size.x, maxf(ui_config.faction_stats_size.x, required_stats_size.x)), maxf(ui_config.faction_stats_minimum_size.y, maxf(ui_config.faction_stats_size.y, required_stats_size.y)))
	faction_stats.position = Vector2(maxf(8.0, viewport_size.x - stats_size.x + ui_config.faction_stats_position.x), ui_config.faction_stats_position.y)
	faction_stats.size = stats_size
	var broadcast_rect := ui_config.broadcast_rect
	broadcast_panel.position = Vector2((viewport_size.x - minf(broadcast_rect.size.x, viewport_size.x - 32.0)) * 0.5 + broadcast_rect.position.x, broadcast_rect.position.y)
	broadcast_panel.size = Vector2(minf(broadcast_rect.size.x, viewport_size.x - 32.0), broadcast_rect.size.y)
	var bottom_rect := ui_config.bottom_status_rect
	bottom_status_panel.position = Vector2(bottom_rect.position.x, viewport_size.y + bottom_rect.position.y)
	bottom_status_panel.size = Vector2(minf(bottom_rect.size.x, viewport_size.x - 32.0), bottom_rect.size.y)
	$BottomStatusLabel.position = bottom_status_panel.position + Vector2(10.0, 14.0)
	$BottomStatusLabel.size = Vector2(maxf(1.0, bottom_status_panel.size.x - 20.0), maxf(1.0, bottom_status_panel.size.y - 20.0))
