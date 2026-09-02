class_name GameHUD
extends CanvasLayer

var main_ref: Node
var top_bar: ColorRect
var status_label: Label
var stats_label: Label
var hint_label: Label
var end_panel: ColorRect
var end_label: Label
var restart_button: Button
var viewport_size := Vector2.ZERO

func setup(controller: Node) -> void:
	main_ref = controller
	_build_ui()

func _build_ui() -> void:
	viewport_size = get_viewport().get_visible_rect().size
	top_bar = ColorRect.new()
	top_bar.color = Color("#0b1220")
	top_bar.position = Vector2(0, 0)
	top_bar.size = Vector2(viewport_size.x, 150)
	add_child(top_bar)

	var title := Label.new()
	title.text = "占城大师 · 六边形争夺"
	title.position = Vector2(28, 16)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#f8fafc"))
	top_bar.add_child(title)

	stats_label = Label.new()
	stats_label.position = Vector2(28, 54)
	stats_label.size = Vector2(viewport_size.x - 56, 28)
	stats_label.add_theme_font_size_override("font_size", 17)
	stats_label.add_theme_color_override("font_color", Color("#cbd5e1"))
	top_bar.add_child(stats_label)

	status_label = Label.new()
	status_label.position = Vector2(28, 92)
	status_label.size = Vector2(viewport_size.x - 56, 28)
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color("#fbbf24"))
	top_bar.add_child(status_label)

	hint_label = Label.new()
	hint_label.position = Vector2(20, viewport_size.y - 48)
	hint_label.size = Vector2(viewport_size.x - 40, 30)
	hint_label.add_theme_font_size_override("font_size", 15)
	hint_label.add_theme_color_override("font_color", Color("#94a3b8"))
	add_child(hint_label)

	end_panel = ColorRect.new()
	end_panel.color = Color(0.03, 0.07, 0.13, 0.94)
	end_panel.size = Vector2(minf(viewport_size.x * 0.85, 620.0), 280.0)
	end_panel.position = Vector2((viewport_size.x - end_panel.size.x) * 0.5, (viewport_size.y - end_panel.size.y) * 0.5)
	end_panel.visible = false
	add_child(end_panel)

	end_label = Label.new()
	end_label.position = Vector2(20, 30)
	end_label.size = Vector2(end_panel.size.x - 40, 110)
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	end_label.add_theme_font_size_override("font_size", 30)
	end_panel.add_child(end_label)

	restart_button = Button.new()
	restart_button.text = "再来一局"
	restart_button.position = Vector2((end_panel.size.x - 160) * 0.5, 190)
	restart_button.size = Vector2(160, 44)
	restart_button.add_theme_font_size_override("font_size", 18)
	restart_button.pressed.connect(_on_restart_pressed)
	end_panel.add_child(restart_button)
	_layout_ui()

func _layout_ui() -> void:
	if top_bar == null:
		return
	viewport_size = get_viewport().get_visible_rect().size
	top_bar.size = Vector2(viewport_size.x, 150)
	stats_label.position = Vector2(28, 54)
	stats_label.size = Vector2(viewport_size.x - 56, 28)
	status_label.position = Vector2(28, 92)
	status_label.size = Vector2(viewport_size.x - 56, 28)
	hint_label.position = Vector2(20, viewport_size.y - 48)
	hint_label.size = Vector2(viewport_size.x - 40, 30)
	end_panel.size = Vector2(minf(viewport_size.x * 0.85, 620.0), 280.0)
	end_panel.position = Vector2((viewport_size.x - end_panel.size.x) * 0.5, (viewport_size.y - end_panel.size.y) * 0.5)
	end_label.size = Vector2(end_panel.size.x - 40, 110)
	restart_button.position = Vector2((end_panel.size.x - 160) * 0.5, 190)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_layout_ui()

func update_state(time_left: float, player_gold: int, ai_gold: int, player_hp: float, ai_hp: float, player_tiles: int, ai_tiles: int) -> void:
	if stats_label == null:
		return
	stats_label.text = "金币  %d       敌方金币  %d       时间  %03d" % [player_gold, ai_gold, int(ceil(time_left))]
	status_label.text = "我方主城  %03d HP    敌方主城  %03d HP    领地  %02d : %02d" % [int(player_hp), int(ai_hp), player_tiles, ai_tiles]

func show_hint(message: String) -> void:
	if hint_label:
		hint_label.text = message

func show_result(message: String) -> void:
	end_panel.visible = true
	end_label.text = message

func hide_result() -> void:
	if end_panel:
		end_panel.visible = false

func _on_restart_pressed() -> void:
	if main_ref:
		main_ref.restart_game()
