class_name SettlementUI
extends Control

const Config := preload("res://game_config.gd")
const HeroAvatarCatalogScript := preload("res://hero_avatar_catalog.gd")
const TileIconScript := preload("res://settlement_tile_icon.gd")
const HEADER_ART := preload("res://assets/generated/settlement/header.png")
const MEDAL_ART := {
	1: preload("res://assets/generated/settlement/medal_gold.png"),
	2: preload("res://assets/generated/settlement/medal_silver.png"),
	3: preload("res://assets/generated/settlement/medal_bronze.png")
}

var ui_config: UIEditorConfig = preload("res://ui_editor_config.tres")

signal confirmed

var dimmer: ColorRect
var board_panel: Panel
var header_art: TextureRect
var match_time_panel: Panel
var match_time_icon: Label
var match_time_title: Label
var match_time_label: Label
var column_label: Label
var rows: Array[Panel] = []
var row_rank_art: Array[TextureRect] = []
var row_rank_labels: Array[Label] = []
var row_avatar_art: Array[TextureRect] = []
var row_avatar_placeholders: Array[Label] = []
var row_name_labels: Array[Label] = []
var row_survival_labels: Array[Label] = []
var row_tile_icons: Array[Control] = []
var row_tile_labels: Array[Label] = []
var player_summary_panel: Panel
var player_summary_title: Label
var player_summary_avatar: TextureRect
var player_summary_name: Label
var player_summary_survival: Label
var player_summary_tiles: Label
var player_summary_icon: Control
var confirm_button: Button
var viewport_size := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	set_viewport_size(get_viewport().get_visible_rect().size)
	visible = false

func _build_ui() -> void:
	dimmer = ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.color = ui_config.modal_overlay_color
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)

	board_panel = Panel.new()
	board_panel.name = "SettlementBoard"
	board_panel.add_theme_stylebox_override("panel", _panel_style(ui_config.settlement_panel_color, Color("#4c291c"), 5, 22))
	board_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(board_panel)

	header_art = TextureRect.new()
	header_art.name = "HeaderArt"
	header_art.texture = ui_config.settlement_header_texture if ui_config.settlement_header_texture != null else HEADER_ART
	header_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	header_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_panel.add_child(header_art)

	match_time_panel = Panel.new()
	match_time_panel.add_theme_stylebox_override("panel", _panel_style(Color("#fff2d7"), Color("#e8bd78"), 3, 18))
	board_panel.add_child(match_time_panel)
	match_time_icon = Label.new()
	match_time_icon.text = "◷"
	match_time_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	match_time_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	match_time_icon.add_theme_font_size_override("font_size", 42)
	match_time_icon.add_theme_color_override("font_color", Color("#2587dc"))
	match_time_panel.add_child(match_time_icon)
	match_time_title = _make_label("比赛时长", 22, Color("#74401f"))
	match_time_panel.add_child(match_time_title)
	match_time_label = _make_label("00:00", 28, Color("#4c291c"))
	match_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	match_time_panel.add_child(match_time_label)

	column_label = _make_label("名次                         名称                         存活时长              占地数量", 16, Color("#fff5df"))
	column_label.add_theme_stylebox_override("normal", _panel_style(Color("#ad7040"), Color("#70391e"), 2, 12))
	column_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	board_panel.add_child(column_label)

	for index in range(6):
		_build_row(index)

	player_summary_panel = Panel.new()
	player_summary_panel.add_theme_stylebox_override("panel", _panel_style(Color("#dceeff"), Color("#238bd6"), 3, 16))
	board_panel.add_child(player_summary_panel)
	player_summary_title = _make_label("我的成绩", 16, Color("#ffffff"))
	player_summary_title.add_theme_stylebox_override("normal", _panel_style(Color("#238bd6"), Color("#12649d"), 2, 8))
	player_summary_panel.add_child(player_summary_title)
	player_summary_avatar = TextureRect.new()
	player_summary_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player_summary_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	player_summary_avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_summary_panel.add_child(player_summary_avatar)
	player_summary_name = _make_label("玩家", 18, Color("#17344d"))
	player_summary_panel.add_child(player_summary_name)
	player_summary_survival = _make_label("00:00", 18, Color("#4c291c"))
	player_summary_panel.add_child(player_summary_survival)
	player_summary_tiles = _make_label("0", 18, Color("#4c291c"))
	player_summary_tiles.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	player_summary_panel.add_child(player_summary_tiles)
	player_summary_icon = TileIconScript.new()
	player_summary_panel.add_child(player_summary_icon)

	confirm_button = Button.new()
	confirm_button.text = "确定"
	confirm_button.focus_mode = Control.FOCUS_NONE
	confirm_button.add_theme_font_size_override("font_size", 21)
	confirm_button.pressed.connect(confirmed.emit)
	confirm_button.add_theme_stylebox_override("normal", _panel_style(ui_config.settlement_button_color, Color("#8d4e12"), 3, 18))
	confirm_button.add_theme_stylebox_override("hover", _panel_style(ui_config.settlement_button_color.lightened(0.10), Color("#8d4e12"), 3, 18))
	confirm_button.add_theme_stylebox_override("pressed", _panel_style(ui_config.settlement_button_color.darkened(0.08), Color("#71390f"), 3, 18))
	board_panel.add_child(confirm_button)

func _build_row(index: int) -> void:
	var row := Panel.new()
	row.name = "SettlementRow%d" % index
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_panel.add_child(row)
	rows.append(row)

	var rank_art := TextureRect.new()
	rank_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rank_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rank_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(rank_art)
	row_rank_art.append(rank_art)

	var rank_label := _make_label("", 20, Color("#ffffff"))
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rank_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(rank_label)
	row_rank_labels.append(rank_label)

	var avatar := TextureRect.new()
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(avatar)
	row_avatar_art.append(avatar)

	var placeholder := _make_label("—", 24, Color("#64748b"))
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(placeholder)
	row_avatar_placeholders.append(placeholder)

	var name_label := _make_label("未启用阵营", 18, Color("#4c291c"))
	row.add_child(name_label)
	row_name_labels.append(name_label)
	var survival_label := _make_label("--:--", 17, Color("#4c291c"))
	row.add_child(survival_label)
	row_survival_labels.append(survival_label)
	var tile_icon: Control = TileIconScript.new()
	row.add_child(tile_icon)
	row_tile_icons.append(tile_icon)
	var tile_label := _make_label("0", 17, Color("#4c291c"))
	tile_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(tile_label)
	row_tile_labels.append(tile_label)

func show_settlement(match_time: float, faction_rows: Array, player_row: Dictionary) -> void:
	match_time_label.text = _format_time(match_time)
	for index in range(6):
		var data: Dictionary = {"enabled": false}
		if index < faction_rows.size():
			data = faction_rows[index]
		_update_row(index, data)
	_update_player_summary(player_row)
	visible = true
	set_viewport_size(viewport_size if viewport_size != Vector2.ZERO else get_viewport().get_visible_rect().size)

func hide_settlement() -> void:
	visible = false

func configure_ui(config: UIEditorConfig) -> void:
	ui_config = config
	if not is_inside_tree():
		return
	if header_art != null:
		header_art.texture = ui_config.settlement_header_texture if ui_config.settlement_header_texture != null else HEADER_ART
	if dimmer != null:
		dimmer.color = ui_config.modal_overlay_color
	if board_panel != null:
		board_panel.add_theme_stylebox_override("panel", _panel_style(ui_config.settlement_panel_color, Color("#4c291c"), 5, 22))
	if confirm_button != null:
		confirm_button.add_theme_stylebox_override("normal", _panel_style(ui_config.settlement_button_color, Color("#8d4e12"), 3, 18))
		confirm_button.add_theme_stylebox_override("hover", _panel_style(ui_config.settlement_button_color.lightened(0.10), Color("#8d4e12"), 3, 18))
		confirm_button.add_theme_stylebox_override("pressed", _panel_style(ui_config.settlement_button_color.darkened(0.08), Color("#71390f"), 3, 18))
	set_viewport_size(viewport_size if viewport_size != Vector2.ZERO else get_viewport().get_visible_rect().size)

func set_viewport_size(value: Vector2) -> void:
	viewport_size = value
	size = viewport_size
	if dimmer == null or board_panel == null:
		return
	dimmer.position = Vector2.ZERO
	dimmer.size = viewport_size
	var requested_size := ui_config.settlement_panel_size if ui_config != null else Vector2(680.0, 1140.0)
	var board_width := minf(requested_size.x, maxf(300.0, viewport_size.x - 24.0))
	var board_height := minf(requested_size.y, maxf(700.0, viewport_size.y - 24.0))
	board_panel.size = Vector2(board_width, board_height)
	var panel_offset := ui_config.settlement_panel_offset if ui_config != null else Vector2.ZERO
	board_panel.position = Vector2((viewport_size.x - board_width) * 0.5, (viewport_size.y - board_height) * 0.5) + panel_offset
	header_art.position = Vector2(18.0, 8.0)
	header_art.size = Vector2(board_width - 36.0, 202.0)
	match_time_panel.position = Vector2(26.0, 214.0)
	match_time_panel.size = Vector2(board_width - 52.0, 70.0)
	match_time_icon.position = Vector2(12.0, 4.0)
	match_time_icon.size = Vector2(60.0, 60.0)
	match_time_title.position = Vector2(82.0, 0.0)
	match_time_title.size = Vector2(130.0, 70.0)
	match_time_label.position = Vector2(220.0, 0.0)
	match_time_label.size = Vector2(board_width - 244.0, 70.0)
	column_label.position = Vector2(26.0, 294.0)
	column_label.size = Vector2(board_width - 52.0, 42.0)
	var row_width := board_width - 52.0
	for index in range(rows.size()):
		var row := rows[index]
		row.position = Vector2(26.0, 344.0 + float(index) * 78.0)
		row.size = Vector2(row_width, 72.0)
		row_rank_art[index].position = Vector2(12.0, 5.0)
		row_rank_art[index].size = Vector2(60.0, 60.0)
		row_rank_labels[index].position = Vector2(12.0, 5.0)
		row_rank_labels[index].size = Vector2(60.0, 60.0)
		row_avatar_art[index].position = Vector2(78.0, 5.0)
		row_avatar_art[index].size = Vector2(62.0, 62.0)
		row_avatar_placeholders[index].position = Vector2(78.0, 5.0)
		row_avatar_placeholders[index].size = Vector2(62.0, 62.0)
		row_name_labels[index].position = Vector2(150.0, 0.0)
		row_name_labels[index].size = Vector2(row_width * 0.34, 72.0)
		row_survival_labels[index].position = Vector2(row_width * 0.57, 0.0)
		row_survival_labels[index].size = Vector2(row_width * 0.20, 72.0)
		row_tile_icons[index].position = Vector2(row_width * 0.82, 13.0)
		row_tile_icons[index].size = Vector2(42.0, 44.0)
		row_tile_labels[index].position = Vector2(row_width * 0.91, 0.0)
		row_tile_labels[index].size = Vector2(row_width * 0.08, 72.0)
	player_summary_panel.position = Vector2(26.0, 830.0)
	player_summary_panel.size = Vector2(row_width, 82.0)
	player_summary_title.position = Vector2(-2.0, -22.0)
	player_summary_title.size = Vector2(110.0, 28.0)
	player_summary_avatar.position = Vector2(82.0, 8.0)
	player_summary_avatar.size = Vector2(62.0, 62.0)
	player_summary_name.position = Vector2(154.0, 0.0)
	player_summary_name.size = Vector2(row_width * 0.34, 82.0)
	player_summary_survival.position = Vector2(row_width * 0.57, 0.0)
	player_summary_survival.size = Vector2(row_width * 0.20, 82.0)
	player_summary_icon.position = Vector2(row_width * 0.82, 19.0)
	player_summary_icon.size = Vector2(42.0, 44.0)
	player_summary_tiles.position = Vector2(row_width * 0.91, 0.0)
	player_summary_tiles.size = Vector2(row_width * 0.08, 82.0)
	var confirm_rect := ui_config.settlement_confirm_button_rect if ui_config != null else Rect2(0.0, 950.0, 180.0, 54.0)
	confirm_button.position = Vector2((board_width - confirm_rect.size.x) * 0.5 + confirm_rect.position.x, minf(board_height - confirm_rect.size.y - 18.0, confirm_rect.position.y))
	confirm_button.size = confirm_rect.size

func _update_row(index: int, data: Dictionary) -> void:
	var enabled := bool(data.get("enabled", false))
	var rank := int(data.get("rank", 0))
	var faction := int(data.get("faction", -1))
	var color := Color("#d9dde4") if not enabled else Color(str(Config.FACTION_COLORS.get(faction, "#d9dde4")))
	rows[index].add_theme_stylebox_override("panel", _panel_style(Color("#f7ead0") if enabled else Color("#d5d9df"), color if enabled else Color("#a4acb8"), 3 if faction == Config.FACTION_PLAYER else 2, 14))
	row_rank_art[index].texture = MEDAL_ART.get(rank, null)
	row_rank_art[index].visible = enabled and rank <= 3 and MEDAL_ART.has(rank)
	row_rank_labels[index].text = str(rank) if enabled and rank > 3 else ""
	row_rank_labels[index].visible = enabled and rank > 3
	row_avatar_art[index].texture = HeroAvatarCatalogScript.get_for_faction(faction)
	row_avatar_art[index].visible = enabled and row_avatar_art[index].texture != null
	row_avatar_placeholders[index].visible = not row_avatar_art[index].visible
	row_name_labels[index].text = str(data.get("name", "未启用阵营"))
	row_name_labels[index].modulate = Color.WHITE if enabled else Color(0.55, 0.58, 0.64, 1.0)
	row_survival_labels[index].text = _format_time(float(data.get("survival_time", 0.0))) if enabled else "--:--"
	row_survival_labels[index].modulate = Color.WHITE if enabled else Color(0.55, 0.58, 0.64, 1.0)
	row_tile_icons[index].call("setup", int(data.get("territories", 0)))
	row_tile_labels[index].text = str(int(data.get("territories", 0))) if enabled else "--"
	row_tile_labels[index].modulate = Color.WHITE if enabled else Color(0.55, 0.58, 0.64, 1.0)

func _update_player_summary(data: Dictionary) -> void:
	var faction := int(data.get("faction", Config.FACTION_PLAYER))
	player_summary_avatar.texture = HeroAvatarCatalogScript.get_for_faction(faction)
	player_summary_name.text = str(data.get("name", "玩家"))
	player_summary_survival.text = _format_time(float(data.get("survival_time", 0.0)))
	player_summary_tiles.text = str(int(data.get("territories", 0)))
	player_summary_icon.call("setup", int(data.get("territories", 0)))

func _format_time(seconds: float) -> String:
	var total_seconds := maxi(0, int(floor(seconds + 0.5)))
	return "%02d:%02d" % [int(total_seconds / 60), total_seconds % 60]

func _make_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("#3c2417"))
	label.add_theme_constant_override("outline_size", 3)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _panel_style(background: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style
