class_name GameHUD
extends CanvasLayer

const Config := preload("res://game_config.gd")
const EquipmentDataScript := preload("res://equipment_data.gd")
const MerchantDataScript := preload("res://merchant_data.gd")
const CameraGuideScript := preload("res://camera_guide.gd")
const CameraGuideIconScript := preload("res://camera_guide_icon.gd")
const CatCompanionScript := preload("res://cat_companion.gd")
const MerchantCardIconScript := preload("res://merchant_card_icon.gd")

signal card_event_finished(owner: int, card_type: int, fate_cell: Vector2i)
signal card_draw_finished(owner: int, card_id: String, fate_cell: Vector2i)
signal merchant_item_selected(index: int)
signal merchant_dismissed
signal inventory_item_dropped(item_id: String, screen_position: Vector2)

var main_ref: Node
var status_label: Label
var stats_label: Label
var timer_label: Label
var hq_health_bar: ProgressBar
var hint_label: Label
var hint_container: Control
var hint_messages: Array[String] = []
var bombardment_banner: ColorRect
var bombardment_banner_label: Label
var bombardment_banner_message := ""
var world_broadcast_message := ""
var world_broadcast_remaining := 0.0
var cat_companion: Control
var end_panel: ColorRect
var end_label: Label
var restart_button: Button
var player_info_button: Button
var bottom_status_panel: ColorRect
var player_info_overlay: ColorRect
var player_info_panel: ColorRect
var player_info_close_button: Button
var player_info_title: Label
var player_info_attribute_label: Label
var player_info_equipment_title: Label
var player_info_equipment_slots: Array[Button] = []
var player_info_equipment_icons: Array[TextureRect] = []
var player_info_equipment_labels: Array[Label] = []
var card_event_queue: Array[Dictionary] = []
var card_event_current: Dictionary = {}
var card_event_tween: Tween
var card_event_running := false
var card_event_overlay: ColorRect
var card_event_panel: ColorRect
var card_event_title: Label
var card_event_card: Label
var card_event_detail: Label
var intelligence_news_queue: Array[Dictionary] = []
var intelligence_news_current: Dictionary = {}
var intelligence_news_tween: Tween
var intelligence_news_running := false
var intelligence_news_overlay: ColorRect
var intelligence_news_panel: ColorRect
var intelligence_news_kicker: Label
var intelligence_news_title: Label
var intelligence_news_content: Label
var intelligence_news_footer: Label
var camera_guide_layer: Control
var enemy_camera_guide: Control
var player_camera_guide: Control
var enemy_camera_guide_icon: Control
var player_camera_guide_icon: Control
var equipment_detail_overlay: ColorRect
var equipment_detail_panel: ColorRect
var equipment_detail_icon: TextureRect
var equipment_detail_title: Label
var equipment_detail_info: Label
var equipment_detail_close_button: Button
var equipment_replacement_overlay: ColorRect
var equipment_replacement_panel: ColorRect
var equipment_replacement_title: Label
var equipment_replacement_current_icon: TextureRect
var equipment_replacement_new_icon: TextureRect
var equipment_replacement_current_label: Label
var equipment_replacement_new_label: Label
var equipment_replace_button: Button
var equipment_discard_button: Button
var merchant_shop_overlay: ColorRect
var merchant_shop_panel: ColorRect
var merchant_shop_title: Label
var merchant_shop_buttons: Array[Button] = []
var merchant_shop_card_icons: Array[Control] = []
var merchant_shop_card_titles: Array[Label] = []
var merchant_shop_card_descriptions: Array[Label] = []
var merchant_shop_price_labels: Array[Label] = []
var merchant_shop_coin_icons: Array[Control] = []
var merchant_shop_close_button: Button
var merchant_shop_dismiss_button: Button
var building_damage_edge_soft: Panel
var building_damage_edge: Panel
var building_damage_edge_tween: Tween
var viewport_size := Vector2.ZERO
var camera_guide_refresh_timer := 0.0
const CAMERA_GUIDE_REFRESH_INTERVAL := 0.10

const PERSONAL_HINT_LINE_HEIGHT := 24.0
const PERSONAL_HINT_VISIBLE_LINES := 3.5
const PERSONAL_HINT_MAX_LINES := 4

func setup(controller: Node) -> void:
	main_ref = controller
	_build_ui()

func _process(delta: float) -> void:
	if world_broadcast_remaining > 0.0:
		world_broadcast_remaining = maxf(0.0, world_broadcast_remaining - delta)
		if world_broadcast_remaining <= 0.0:
			world_broadcast_message = ""
			_refresh_broadcast_banner()
	camera_guide_refresh_timer -= delta
	if camera_guide_refresh_timer <= 0.0:
		camera_guide_refresh_timer = CAMERA_GUIDE_REFRESH_INTERVAL
		update_camera_guides()

func _build_ui() -> void:
	viewport_size = get_viewport().get_visible_rect().size
	player_info_button = Button.new()
	player_info_button.text = "♟"
	player_info_button.tooltip_text = "主角信息"
	player_info_button.position = Vector2(16, 78)
	player_info_button.size = Vector2(48, 48)
	player_info_button.add_theme_font_size_override("font_size", 26)
	player_info_button.add_theme_color_override("font_color", Color("#f8fafc"))
	player_info_button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	var button_normal := StyleBoxFlat.new()
	button_normal.bg_color = Color("#17233a")
	button_normal.border_color = Color("#38bdf8")
	button_normal.set_border_width_all(2)
	button_normal.set_corner_radius_all(24)
	var button_hover := button_normal.duplicate()
	button_hover.bg_color = Color("#243b5a")
	button_hover.border_color = Color("#7dd3fc")
	player_info_button.add_theme_stylebox_override("normal", button_normal)
	player_info_button.add_theme_stylebox_override("hover", button_hover)
	player_info_button.add_theme_stylebox_override("pressed", button_hover)
	player_info_button.pressed.connect(_toggle_player_info)
	add_child(player_info_button)

	bottom_status_panel = ColorRect.new()
	bottom_status_panel.name = "BottomStatusPanel"
	bottom_status_panel.color = Color(0.03, 0.07, 0.13, 0.86)
	bottom_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_status_panel.visible = false
	add_child(bottom_status_panel)

	stats_label = Label.new()
	stats_label.add_theme_font_size_override("font_size", 18)
	stats_label.add_theme_color_override("font_color", Color("#f8fafc"))
	stats_label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.08, 0.92))
	stats_label.add_theme_constant_override("outline_size", 4)
	stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stats_label)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.add_theme_font_size_override("font_size", 17)
	status_label.add_theme_color_override("font_color", Color("#f8fafc"))
	status_label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.08, 0.92))
	status_label.add_theme_constant_override("outline_size", 4)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status_label)

	hq_health_bar = ProgressBar.new()
	hq_health_bar.name = "PlayerHQHealthBar"
	hq_health_bar.max_value = Config.HQ_MAX_HP
	hq_health_bar.value = Config.HQ_MAX_HP
	hq_health_bar.show_percentage = false
	hq_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hq_health_background := StyleBoxFlat.new()
	hq_health_background.bg_color = Color("#3f1720")
	hq_health_background.set_corner_radius_all(5)
	var hq_health_fill := StyleBoxFlat.new()
	hq_health_fill.bg_color = Color("#ef4444")
	hq_health_fill.set_corner_radius_all(5)
	hq_health_bar.add_theme_stylebox_override("background", hq_health_background)
	hq_health_bar.add_theme_stylebox_override("fill", hq_health_fill)
	hq_health_bar.visible = false
	add_child(hq_health_bar)

	timer_label = Label.new()
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 22)
	timer_label.add_theme_color_override("font_color", Color("#f8fafc"))
	timer_label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.08, 0.92))
	timer_label.add_theme_constant_override("outline_size", 5)
	timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(timer_label)

	bombardment_banner = ColorRect.new()
	bombardment_banner.color = Color(0.35, 0.03, 0.03, 0.94)
	bombardment_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bombardment_banner.visible = false
	add_child(bombardment_banner)
	bombardment_banner_label = Label.new()
	bombardment_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bombardment_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bombardment_banner_label.add_theme_font_size_override("font_size", 19)
	bombardment_banner_label.add_theme_color_override("font_color", Color("#fee2e2"))
	bombardment_banner.add_child(bombardment_banner_label)

	building_damage_edge_soft = Panel.new()
	building_damage_edge_soft.name = "BuildingDamageEdgeSoftFlash"
	building_damage_edge_soft.mouse_filter = Control.MOUSE_FILTER_IGNORE
	building_damage_edge_soft.visible = false
	var soft_edge_style := StyleBoxFlat.new()
	soft_edge_style.bg_color = Color(1.0, 0.02, 0.02, 0.0)
	soft_edge_style.border_color = Color(1.0, 0.04, 0.04, 0.22)
	soft_edge_style.set_border_width_all(34)
	building_damage_edge_soft.add_theme_stylebox_override("panel", soft_edge_style)
	add_child(building_damage_edge_soft)

	building_damage_edge = Panel.new()
	building_damage_edge.name = "BuildingDamageEdgeFlash"
	building_damage_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	building_damage_edge.visible = false
	var edge_style := StyleBoxFlat.new()
	edge_style.bg_color = Color(1.0, 0.02, 0.02, 0.0)
	edge_style.border_color = Color(1.0, 0.10, 0.10, 0.48)
	edge_style.set_border_width_all(14)
	building_damage_edge.add_theme_stylebox_override("panel", edge_style)
	add_child(building_damage_edge)
	_build_camera_guides()
	_build_cat_companion()
	_build_merchant_shop_panel()

	hint_container = Control.new()
	hint_container.name = "PersonalHintHistory"
	hint_container.position = Vector2(20, viewport_size.y * 0.66)
	hint_container.size = Vector2(viewport_size.x - 40, PERSONAL_HINT_LINE_HEIGHT * PERSONAL_HINT_VISIBLE_LINES)
	hint_container.clip_contents = true
	hint_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint_container)
	for index in range(PERSONAL_HINT_MAX_LINES):
		var line := Label.new()
		line.position = Vector2.ZERO
		line.size = Vector2(hint_container.size.x, PERSONAL_HINT_LINE_HEIGHT)
		line.add_theme_font_size_override("font_size", 15)
		line.add_theme_color_override("font_color", Color("#94a3b8"))
		line.clip_text = true
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hint_container.add_child(line)
		if index == 0:
			hint_label = line
	_render_hint_history()

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

	_build_player_info_panel()
	_build_equipment_panels()
	_build_card_event_panel()
	_build_intelligence_news_panel()
	_layout_ui()
	update_camera_guides()

func _build_cat_companion() -> void:
	cat_companion = CatCompanionScript.new()
	cat_companion.name = "CatCompanion"
	cat_companion.size = Vector2(viewport_size.x, 340.0)
	cat_companion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Keep modal panels created later in the tree above the companion.
	cat_companion.z_index = 0
	add_child(cat_companion)
	cat_companion.call("set_viewport_size", viewport_size)
	cat_companion.inventory_item_dropped.connect(_on_cat_inventory_item_dropped)

func _on_cat_inventory_item_dropped(item_id: String, screen_position: Vector2) -> void:
	inventory_item_dropped.emit(item_id, screen_position)

func play_card_draw(owner: int, card_id: String, fate_cell: Vector2i) -> void:
	card_event_queue.append({"owner": owner, "card_id": card_id, "fate_cell": fate_cell, "is_card_draw": true})
	if not card_event_running:
		_start_next_card_event()

func set_item_inventory(items: Array[String], fly_item_id: String = "", fly_origin: Vector2 = Vector2(-1.0, -1.0)) -> void:
	if cat_companion == null:
		return
	cat_companion.call("set_item_inventory", items)
	if not fly_item_id.is_empty():
		var origin := fly_origin
		if origin.x < 0.0 or origin.y < 0.0:
			origin = viewport_size * 0.5
		cat_companion.call("play_item_fly_in", fly_item_id, origin)

func get_merchant_item_screen_position(index: int) -> Vector2:
	if index >= 0 and index < merchant_shop_buttons.size() and is_instance_valid(merchant_shop_buttons[index]):
		return merchant_shop_buttons[index].get_global_rect().get_center()
	return viewport_size * 0.5

func show_officer_bubble(message: String) -> void:
	if cat_companion == null or message.is_empty():
		return
	cat_companion.call("show_bubble", message)

func hide_officer_bubble() -> void:
	if cat_companion == null:
		return
	cat_companion.call("hide_bubble")

func reset_cat_companion() -> void:
	if cat_companion == null:
		return
	cat_companion.call("hide_bubble")
	cat_companion.call("set_expanded", false)

func _build_merchant_shop_panel() -> void:
	merchant_shop_overlay = ColorRect.new()
	merchant_shop_overlay.name = "MerchantShopOverlay"
	merchant_shop_overlay.color = Color(0.01, 0.03, 0.07, 0.80)
	merchant_shop_overlay.position = Vector2.ZERO
	merchant_shop_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	merchant_shop_overlay.visible = false
	add_child(merchant_shop_overlay)

	merchant_shop_panel = ColorRect.new()
	merchant_shop_panel.name = "MerchantShopPanel"
	merchant_shop_panel.color = Color("#17233a")
	merchant_shop_overlay.add_child(merchant_shop_panel)

	merchant_shop_title = Label.new()
	merchant_shop_title.text = "商人商店"
	merchant_shop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	merchant_shop_title.add_theme_font_size_override("font_size", 28)
	merchant_shop_title.add_theme_color_override("font_color", Color("#f8fafc"))
	merchant_shop_panel.add_child(merchant_shop_title)

	for index in range(3):
		var item_button := Button.new()
		item_button.name = "MerchantItem%d" % index
		item_button.focus_mode = Control.FOCUS_NONE
		item_button.text = ""
		item_button.pressed.connect(_on_merchant_shop_item_pressed.bind(index))
		merchant_shop_panel.add_child(item_button)
		merchant_shop_buttons.append(item_button)

		var card_icon: Control = MerchantCardIconScript.new()
		card_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_button.add_child(card_icon)
		merchant_shop_card_icons.append(card_icon)

		var card_title := Label.new()
		card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_title.add_theme_font_size_override("font_size", 17)
		card_title.add_theme_color_override("font_color", Color("#f8fafc"))
		card_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_button.add_child(card_title)
		merchant_shop_card_titles.append(card_title)

		var card_description := Label.new()
		card_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_description.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		card_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_description.add_theme_font_size_override("font_size", 13)
		card_description.add_theme_color_override("font_color", Color("#cbd5e1"))
		card_description.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_button.add_child(card_description)
		merchant_shop_card_descriptions.append(card_description)

		var price_label := Label.new()
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		price_label.add_theme_font_size_override("font_size", 18)
		price_label.add_theme_color_override("font_color", Color("#fde68a"))
		price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_button.add_child(price_label)
		merchant_shop_price_labels.append(price_label)

		var coin_icon: Control = MerchantCardIconScript.new()
		coin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coin_icon.call("setup_coin")
		item_button.add_child(coin_icon)
		merchant_shop_coin_icons.append(coin_icon)

	merchant_shop_close_button = Button.new()
	merchant_shop_close_button.text = "离开商店"
	merchant_shop_close_button.focus_mode = Control.FOCUS_NONE
	merchant_shop_close_button.pressed.connect(hide_merchant_shop)
	merchant_shop_panel.add_child(merchant_shop_close_button)

	merchant_shop_dismiss_button = Button.new()
	merchant_shop_dismiss_button.text = "驱赶商人"
	merchant_shop_dismiss_button.focus_mode = Control.FOCUS_NONE
	merchant_shop_dismiss_button.pressed.connect(_on_merchant_shop_dismiss_pressed)
	merchant_shop_panel.add_child(merchant_shop_dismiss_button)

func _on_merchant_shop_item_pressed(index: int) -> void:
	if merchant_shop_overlay != null and merchant_shop_overlay.visible:
		merchant_item_selected.emit(index)

func _on_merchant_shop_dismiss_pressed() -> void:
	if merchant_shop_overlay != null and merchant_shop_overlay.visible:
		merchant_dismissed.emit()

func show_merchant_shop(items: Array[String]) -> void:
	if merchant_shop_overlay == null:
		return
	for index in range(merchant_shop_buttons.size()):
		var button := merchant_shop_buttons[index]
		var card_icon := merchant_shop_card_icons[index]
		var card_title := merchant_shop_card_titles[index]
		var card_description := merchant_shop_card_descriptions[index]
		var price_label := merchant_shop_price_labels[index]
		var coin_icon := merchant_shop_coin_icons[index]
		if index < items.size():
			var item_id := str(items[index])
			var item: Dictionary = MerchantDataScript.get_item(item_id)
			card_icon.call("setup_card", item_id)
			card_title.text = str(item.get("name", "未知卡片"))
			card_description.text = str(item.get("description", ""))
			price_label.text = str(Config.MERCHANT_ITEM_COST)
			card_icon.visible = true
			card_title.visible = true
			card_description.visible = true
			price_label.visible = true
			coin_icon.visible = true
			button.disabled = false
		else:
			button.text = ""
			card_icon.visible = false
			card_title.visible = false
			card_description.visible = false
			price_label.visible = false
			coin_icon.visible = false
			button.disabled = true
	merchant_shop_overlay.visible = true

func hide_merchant_shop() -> void:
	if merchant_shop_overlay != null:
		merchant_shop_overlay.visible = false

func _build_camera_guides() -> void:
	camera_guide_layer = Control.new()
	camera_guide_layer.name = "CameraGuideLayer"
	camera_guide_layer.position = Vector2.ZERO
	camera_guide_layer.size = viewport_size
	camera_guide_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camera_guide_layer.z_index = -1
	add_child(camera_guide_layer)

	enemy_camera_guide = CameraGuideScript.new()
	enemy_camera_guide.name = "EnemyCameraGuide"
	enemy_camera_guide.size = viewport_size
	enemy_camera_guide.call("configure", Color("#ef4444"))
	camera_guide_layer.add_child(enemy_camera_guide)

	player_camera_guide = CameraGuideScript.new()
	player_camera_guide.name = "PlayerCameraGuide"
	player_camera_guide.size = viewport_size
	player_camera_guide.call("configure", Color("#22c55e"))
	camera_guide_layer.add_child(player_camera_guide)

	enemy_camera_guide_icon = CameraGuideIconScript.new()
	enemy_camera_guide_icon.name = "EnemyCameraGuideIcon"
	enemy_camera_guide_icon.size = Vector2(64.0, 64.0)
	enemy_camera_guide_icon.call("setup", Color("#ef4444"), 1)
	enemy_camera_guide_icon.connect("clicked", _on_enemy_camera_guide_clicked)
	enemy_camera_guide_icon.visible = false
	add_child(enemy_camera_guide_icon)

	player_camera_guide_icon = CameraGuideIconScript.new()
	player_camera_guide_icon.name = "PlayerCameraGuideIcon"
	player_camera_guide_icon.size = Vector2(64.0, 64.0)
	player_camera_guide_icon.call("setup", Color("#22c55e"), 0)
	player_camera_guide_icon.connect("clicked", _on_player_camera_guide_clicked)
	player_camera_guide_icon.visible = false
	add_child(player_camera_guide_icon)

func _on_enemy_camera_guide_clicked() -> void:
	_focus_nearest_enemy_territory()

func _on_player_camera_guide_clicked() -> void:
	_focus_hq_from_guide("player_hq")

func _focus_hq_from_guide(property_name: String) -> void:
	if main_ref == null or bool(main_ref.get("game_over")):
		return
	var board_ref: Node = main_ref.get("board") as Node
	if board_ref == null:
		return
	var hq_cell: Vector2i = main_ref.get(property_name)
	if bool(board_ref.call("has_cell", hq_cell)):
		board_ref.call("focus_camera_on_cell", hq_cell)
		update_camera_guides()

func _focus_nearest_enemy_territory() -> void:
	if main_ref == null or bool(main_ref.get("game_over")):
		return
	var board_ref: Node = main_ref.get("board") as Node
	if board_ref == null:
		return
	var tiles: Dictionary = board_ref.get("tiles") as Dictionary
	var player_cells: Array[Vector2i] = []
	var enemy_cells: Array[Vector2i] = []
	for raw_cell in tiles.keys():
		var cell: Vector2i = raw_cell
		var tile: Dictionary = tiles[raw_cell]
		if not bool(tile.get("revealed", false)):
			continue
		var owner := int(tile.get("owner", 0))
		if owner == 1:
			player_cells.append(cell)
		elif owner == 2:
			enemy_cells.append(cell)
	if player_cells.is_empty() or enemy_cells.is_empty():
		return

	var nearest_enemy := enemy_cells[0]
	var nearest_distance := INF
	for enemy_cell in enemy_cells:
		for player_cell in player_cells:
			var distance := int(board_ref.call("cube_distance", player_cell, enemy_cell))
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_enemy = enemy_cell
	if bool(board_ref.call("has_cell", nearest_enemy)):
		board_ref.call("focus_camera_on_cell", nearest_enemy)
		update_camera_guides()

func clear_camera_guides() -> void:
	if enemy_camera_guide != null:
		enemy_camera_guide.call("clear_guide")
	if player_camera_guide != null:
		player_camera_guide.call("clear_guide")
	if enemy_camera_guide_icon != null:
		enemy_camera_guide_icon.visible = false
	if player_camera_guide_icon != null:
		player_camera_guide_icon.visible = false

func update_camera_guides() -> void:
	if camera_guide_layer == null or main_ref == null or bool(main_ref.get("game_over")):
		clear_camera_guides()
		return
	var board_ref: Node = main_ref.get("board") as Node
	if board_ref == null:
		clear_camera_guides()
		return
	var player_hq: Vector2i = main_ref.get("player_hq")
	var enemy_hq: Vector2i = main_ref.get("ai_hq")
	if not bool(board_ref.call("has_cell", player_hq)) or not bool(board_ref.call("has_cell", enemy_hq)):
		clear_camera_guides()
		return
	var player_target := _get_hq_screen_position(player_hq)
	var enemy_target := _get_hq_screen_position(enemy_hq)
	var player_visible := _is_hq_visible(player_target)
	var enemy_visible := _is_hq_visible(enemy_target)
	var show_player := not player_visible
	var show_enemy := not enemy_visible and _is_enemy_territory_near_player() and not _is_enemy_territory_visible()

	var safe_rect := Rect2(42.0, 184.0, maxf(1.0, viewport_size.x - 84.0), maxf(1.0, viewport_size.y - 266.0))
	camera_guide_layer.size = viewport_size
	enemy_camera_guide.size = viewport_size
	player_camera_guide.size = viewport_size
	enemy_camera_guide.call("configure_safe_rect", safe_rect)
	player_camera_guide.call("configure_safe_rect", safe_rect)
	enemy_camera_guide.call("set_indicator_offset", Vector2.ZERO)
	player_camera_guide.call("set_indicator_offset", Vector2.ZERO)
	enemy_camera_guide.call("set_guide", enemy_target, show_enemy)
	player_camera_guide.call("set_guide", player_target, show_player)

	# HQs are normally on opposite sides, but when the camera is far above or
	# below the map both edge positions can converge. Keep both badges readable.
	if show_enemy and show_player:
		var enemy_position: Vector2 = enemy_camera_guide.call("get_indicator_position")
		var player_position: Vector2 = player_camera_guide.call("get_indicator_position")
		if enemy_position.distance_to(player_position) < 88.0:
			enemy_camera_guide.call("set_indicator_offset", Vector2(0.0, -44.0))
			player_camera_guide.call("set_indicator_offset", Vector2(0.0, 44.0))
			enemy_camera_guide.call("set_guide", enemy_target, true)
			player_camera_guide.call("set_guide", player_target, true)

	enemy_camera_guide_icon.visible = show_enemy
	player_camera_guide_icon.visible = show_player
	if show_enemy:
		_position_guide_icon(enemy_camera_guide_icon, enemy_camera_guide)
	if show_player:
		_position_guide_icon(player_camera_guide_icon, player_camera_guide)

func _position_guide_icon(icon: Control, guide: Control) -> void:
	var center: Vector2 = guide.call("get_indicator_position")
	icon.position = center - icon.size * 0.5

func _is_hq_visible(screen_position: Vector2) -> bool:
	return Rect2(Vector2.ZERO, viewport_size).has_point(screen_position)

func _is_enemy_territory_visible() -> bool:
	var board_ref: Node = main_ref.get("board") as Node
	if board_ref == null:
		return false
	var tiles: Dictionary = board_ref.get("tiles") as Dictionary
	var canvas_transform := get_viewport().get_canvas_transform()
	var tile_size := float(board_ref.get("tile_size"))
	var tile_scale := maxf(canvas_transform.get_scale().x, canvas_transform.get_scale().y)
	var visible_rect := Rect2(Vector2.ZERO, viewport_size).grow((tile_size + 8.0) * tile_scale)
	for raw_cell in tiles.keys():
		var tile: Dictionary = tiles[raw_cell]
		if not bool(tile.get("revealed", false)) or int(tile.get("owner", 0)) != 2:
			continue
		var cell: Vector2i = raw_cell
		var world_position: Vector2 = board_ref.call("axial_to_world", cell)
		if visible_rect.has_point(canvas_transform * world_position):
			return true
	return false

func _get_hq_screen_position(cell: Vector2i) -> Vector2:
	var board_ref: Node = main_ref.get("board") as Node
	var world_position: Vector2 = board_ref.call("axial_to_world", cell)
	return get_viewport().get_canvas_transform() * world_position

func _is_enemy_territory_near_player() -> bool:
	var board_ref: Node = main_ref.get("board") as Node
	var tiles: Dictionary = board_ref.get("tiles") as Dictionary
	var player_cells: Array[Vector2i] = []
	var enemy_cells: Array[Vector2i] = []
	for raw_cell in tiles.keys():
		var cell: Vector2i = raw_cell
		var tile: Dictionary = tiles[raw_cell]
		if not bool(tile.get("revealed", false)):
			continue
		var owner := int(tile.get("owner", 0))
		if owner == 1:
			player_cells.append(cell)
		elif owner == 2:
			enemy_cells.append(cell)
	if player_cells.is_empty() or enemy_cells.is_empty():
		return false
	for player_cell in player_cells:
		for enemy_cell in enemy_cells:
			if int(board_ref.call("cube_distance", player_cell, enemy_cell)) <= 5:
				return true
	return false

func _build_player_info_panel() -> void:
	player_info_overlay = ColorRect.new()
	player_info_overlay.color = Color(0.01, 0.03, 0.07, 0.72)
	player_info_overlay.position = Vector2.ZERO
	player_info_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	player_info_overlay.visible = false
	add_child(player_info_overlay)

	player_info_panel = ColorRect.new()
	player_info_panel.color = Color("#111c2e")
	player_info_overlay.add_child(player_info_panel)

	player_info_title = Label.new()
	player_info_title.text = "主角信息"
	player_info_title.add_theme_font_size_override("font_size", 25)
	player_info_title.add_theme_color_override("font_color", Color("#f8fafc"))
	player_info_panel.add_child(player_info_title)

	player_info_close_button = Button.new()
	player_info_close_button.text = "关闭"
	player_info_close_button.add_theme_font_size_override("font_size", 14)
	player_info_close_button.pressed.connect(_close_player_info)
	player_info_panel.add_child(player_info_close_button)

	var attribute_header := Label.new()
	attribute_header.text = "当前属性"
	attribute_header.add_theme_font_size_override("font_size", 18)
	attribute_header.add_theme_color_override("font_color", Color("#fbbf24"))
	attribute_header.position = Vector2(28, 76)
	player_info_panel.add_child(attribute_header)

	player_info_attribute_label = Label.new()
	player_info_attribute_label.text = "血量       100 / 100\n福德       0\n财运       0"
	player_info_attribute_label.add_theme_font_size_override("font_size", 17)
	player_info_attribute_label.add_theme_color_override("font_color", Color("#dbeafe"))
	player_info_attribute_label.position = Vector2(34, 116)
	player_info_attribute_label.size = Vector2(260, 112)
	player_info_panel.add_child(player_info_attribute_label)

	player_info_equipment_title = Label.new()
	player_info_equipment_title.text = "装备栏 1"
	player_info_equipment_title.add_theme_font_size_override("font_size", 18)
	player_info_equipment_title.add_theme_color_override("font_color", Color("#fbbf24"))
	player_info_equipment_title.position = Vector2(28, 248)
	player_info_panel.add_child(player_info_equipment_title)

	for index in range(5):
		var slot := Button.new()
		slot.text = ""
		slot.focus_mode = Control.FOCUS_NONE
		slot.custom_minimum_size = Vector2(0, 72)
		slot.pressed.connect(_on_equipment_slot_pressed.bind(index))
		player_info_panel.add_child(slot)
		player_info_equipment_slots.append(slot)

		var icon := TextureRect.new()
		icon.name = "EquipmentIcon"
		icon.position = Vector2(10, 8)
		icon.size = Vector2(56, 56)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		player_info_equipment_icons.append(icon)

		var slot_label := Label.new()
		slot_label.text = "装备槽 %d\n未装备" % (index + 1)
		slot_label.position = Vector2(78, 0)
		slot_label.add_theme_font_size_override("font_size", 16)
		slot_label.add_theme_color_override("font_color", Color("#94a3b8"))
		slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_child(slot_label)
		player_info_equipment_labels.append(slot_label)

func _build_equipment_panels() -> void:
	equipment_detail_overlay = ColorRect.new()
	equipment_detail_overlay.color = Color(0.01, 0.03, 0.07, 0.78)
	equipment_detail_overlay.position = Vector2.ZERO
	equipment_detail_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	equipment_detail_overlay.visible = false
	add_child(equipment_detail_overlay)

	equipment_detail_panel = ColorRect.new()
	equipment_detail_panel.color = Color("#17233a")
	equipment_detail_overlay.add_child(equipment_detail_panel)

	equipment_detail_title = Label.new()
	equipment_detail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equipment_detail_title.add_theme_font_size_override("font_size", 25)
	equipment_detail_title.add_theme_color_override("font_color", Color("#f8fafc"))
	equipment_detail_panel.add_child(equipment_detail_title)

	equipment_detail_icon = TextureRect.new()
	equipment_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	equipment_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	equipment_detail_panel.add_child(equipment_detail_icon)

	equipment_detail_info = Label.new()
	equipment_detail_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equipment_detail_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	equipment_detail_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	equipment_detail_info.add_theme_font_size_override("font_size", 18)
	equipment_detail_info.add_theme_color_override("font_color", Color("#dbeafe"))
	equipment_detail_panel.add_child(equipment_detail_info)

	equipment_detail_close_button = Button.new()
	equipment_detail_close_button.text = "关闭"
	equipment_detail_close_button.pressed.connect(hide_equipment_detail)
	equipment_detail_panel.add_child(equipment_detail_close_button)

	equipment_replacement_overlay = ColorRect.new()
	equipment_replacement_overlay.color = Color(0.01, 0.03, 0.07, 0.84)
	equipment_replacement_overlay.position = Vector2.ZERO
	equipment_replacement_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	equipment_replacement_overlay.visible = false
	add_child(equipment_replacement_overlay)

	equipment_replacement_panel = ColorRect.new()
	equipment_replacement_panel.color = Color("#17233a")
	equipment_replacement_overlay.add_child(equipment_replacement_panel)

	equipment_replacement_title = Label.new()
	equipment_replacement_title.text = "获得同部位装备"
	equipment_replacement_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equipment_replacement_title.add_theme_font_size_override("font_size", 24)
	equipment_replacement_title.add_theme_color_override("font_color", Color("#f8fafc"))
	equipment_replacement_panel.add_child(equipment_replacement_title)

	equipment_replacement_current_icon = TextureRect.new()
	equipment_replacement_current_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	equipment_replacement_current_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	equipment_replacement_panel.add_child(equipment_replacement_current_icon)

	equipment_replacement_new_icon = TextureRect.new()
	equipment_replacement_new_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	equipment_replacement_new_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	equipment_replacement_panel.add_child(equipment_replacement_new_icon)

	equipment_replacement_current_label = Label.new()
	equipment_replacement_current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equipment_replacement_current_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	equipment_replacement_current_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	equipment_replacement_current_label.add_theme_font_size_override("font_size", 16)
	equipment_replacement_current_label.add_theme_color_override("font_color", Color("#cbd5e1"))
	equipment_replacement_panel.add_child(equipment_replacement_current_label)

	equipment_replacement_new_label = Label.new()
	equipment_replacement_new_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equipment_replacement_new_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	equipment_replacement_new_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	equipment_replacement_new_label.add_theme_font_size_override("font_size", 16)
	equipment_replacement_new_label.add_theme_color_override("font_color", Color("#fef3c7"))
	equipment_replacement_panel.add_child(equipment_replacement_new_label)

	equipment_replace_button = Button.new()
	equipment_replace_button.text = "替换"
	equipment_replace_button.pressed.connect(_on_equipment_replace_pressed)
	equipment_replacement_panel.add_child(equipment_replace_button)

	equipment_discard_button = Button.new()
	equipment_discard_button.text = "丢弃"
	equipment_discard_button.pressed.connect(_on_equipment_discard_pressed)
	equipment_replacement_panel.add_child(equipment_discard_button)

func refresh_equipment(equipped: Array) -> void:
	if player_info_equipment_slots.is_empty():
		return
	for index in range(player_info_equipment_slots.size()):
		var item_id := str(equipped[index]) if index < equipped.size() else ""
		var item: Dictionary = EquipmentDataScript.get_item(item_id)
		var icon := player_info_equipment_icons[index]
		var label := player_info_equipment_labels[index]
		if item.is_empty():
			icon.texture = null
			label.text = "装备槽 %d\n未装备" % (index + 1)
			player_info_equipment_slots[index].tooltip_text = "点击查看装备"
		else:
			icon.texture = load(str(item["icon"])) as Texture2D
			label.text = "%s\n%s" % [item["name"], item["slot"]]
			player_info_equipment_slots[index].tooltip_text = "%s：%s" % [item["name"], item["description"]]

func play_equipment_fly_in(equipment_id: String, world_position: Vector2) -> void:
	var item: Dictionary = EquipmentDataScript.get_item(equipment_id)
	if item.is_empty():
		return
	var flyer := TextureRect.new()
	flyer.name = "EquipmentFlyIn"
	flyer.texture = load(str(item["icon"])) as Texture2D
	flyer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flyer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flyer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flyer.size = Vector2(58.0, 58.0)
	flyer.pivot_offset = flyer.size * 0.5
	var world_screen_position := get_viewport().get_canvas_transform() * world_position
	flyer.position = world_screen_position - flyer.size * 0.5
	add_child(flyer)

	var slot_index := int(item["slot_index"])
	var target_center := player_info_button.get_global_rect().get_center()
	if player_info_overlay.visible and slot_index >= 0 and slot_index < player_info_equipment_slots.size():
		target_center = player_info_equipment_slots[slot_index].get_global_rect().get_center()
	var target_position := target_center - flyer.size * 0.5
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(flyer, "position", target_position, 0.65)
	tween.parallel().tween_property(flyer, "scale", Vector2(0.58, 0.58), 0.65)
	tween.parallel().tween_property(flyer, "rotation", 0.18, 0.65)
	tween.tween_callback(flyer.queue_free)

func _on_equipment_slot_pressed(slot: int) -> void:
	if main_ref == null or slot < 0 or slot >= EquipmentDataScript.SLOT_NAMES.size():
		return
	var item_id: String = main_ref.call("get_equipped_item", 1, slot)
	if not item_id.is_empty():
		show_equipment_detail(item_id)

func show_equipment_detail(equipment_id: String) -> void:
	var item: Dictionary = EquipmentDataScript.get_item(equipment_id)
	if item.is_empty():
		return
	equipment_detail_title.text = item["name"]
	equipment_detail_icon.texture = load(str(item["icon"])) as Texture2D
	equipment_detail_info.text = "部位：%s\n\n%s" % [item["slot"], item["description"]]
	equipment_detail_overlay.visible = true

func hide_equipment_detail() -> void:
	if equipment_detail_overlay:
		equipment_detail_overlay.visible = false

func show_equipment_replacement(current_item: String, new_item: String) -> void:
	var current: Dictionary = EquipmentDataScript.get_item(current_item)
	var next: Dictionary = EquipmentDataScript.get_item(new_item)
	if current.is_empty() or next.is_empty():
		return
	equipment_replacement_title.text = "%s部位装备替换" % next["slot"]
	equipment_replacement_current_icon.texture = load(str(current["icon"])) as Texture2D
	equipment_replacement_new_icon.texture = load(str(next["icon"])) as Texture2D
	equipment_replacement_current_label.text = "当前装备\n%s\n%s" % [current["name"], current["description"]]
	equipment_replacement_new_label.text = "新装备\n%s\n%s" % [next["name"], next["description"]]
	equipment_detail_overlay.visible = false
	equipment_replacement_overlay.visible = true

func hide_equipment_replacement() -> void:
	if equipment_replacement_overlay:
		equipment_replacement_overlay.visible = false

func _on_equipment_replace_pressed() -> void:
	if main_ref:
		main_ref.call("resolve_equipment_replacement", true)

func _on_equipment_discard_pressed() -> void:
	if main_ref:
		main_ref.call("resolve_equipment_replacement", false)

func clear_equipment_state() -> void:
	hide_equipment_detail()
	hide_equipment_replacement()
	refresh_equipment(["", "", "", "", ""])

func _toggle_player_info() -> void:
	if player_info_overlay == null:
		return
	player_info_overlay.visible = not player_info_overlay.visible
	if player_info_overlay.visible and end_panel != null:
		end_panel.visible = false

func _close_player_info() -> void:
	if player_info_overlay:
		player_info_overlay.visible = false

func _build_card_event_panel() -> void:
	card_event_overlay = ColorRect.new()
	card_event_overlay.color = Color(0.01, 0.03, 0.07, 0.78)
	card_event_overlay.position = Vector2.ZERO
	card_event_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	card_event_overlay.visible = false
	add_child(card_event_overlay)

	card_event_panel = ColorRect.new()
	card_event_panel.color = Color("#17233a")
	card_event_overlay.add_child(card_event_panel)

	card_event_title = Label.new()
	card_event_title.text = "随机事件 · 翻卡"
	card_event_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_event_title.add_theme_font_size_override("font_size", 26)
	card_event_title.add_theme_color_override("font_color", Color("#f8fafc"))
	card_event_panel.add_child(card_event_title)

	card_event_card = Label.new()
	card_event_card.text = "抽卡中..."
	card_event_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_event_card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_event_card.add_theme_font_size_override("font_size", 31)
	card_event_card.add_theme_color_override("font_color", Color("#fbbf24"))
	card_event_panel.add_child(card_event_card)

	card_event_detail = Label.new()
	card_event_detail.text = "卡片正在滚动"
	card_event_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_event_detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_event_detail.add_theme_font_size_override("font_size", 17)
	card_event_detail.add_theme_color_override("font_color", Color("#cbd5e1"))
	card_event_panel.add_child(card_event_detail)

func _build_intelligence_news_panel() -> void:
	intelligence_news_overlay = ColorRect.new()
	intelligence_news_overlay.name = "IntelligenceNewsOverlay"
	intelligence_news_overlay.color = Color(0.01, 0.02, 0.04, 0.70)
	intelligence_news_overlay.position = Vector2.ZERO
	intelligence_news_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	intelligence_news_overlay.visible = false
	add_child(intelligence_news_overlay)

	intelligence_news_panel = ColorRect.new()
	intelligence_news_panel.name = "IntelligenceNewsPaper"
	intelligence_news_panel.color = Color("#eee4cc")
	intelligence_news_overlay.add_child(intelligence_news_panel)

	intelligence_news_kicker = Label.new()
	intelligence_news_kicker.text = "WORLD NEWS  /  世界情报"
	intelligence_news_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intelligence_news_kicker.add_theme_font_size_override("font_size", 14)
	intelligence_news_kicker.add_theme_color_override("font_color", Color("#8a6a3d"))
	intelligence_news_panel.add_child(intelligence_news_kicker)

	intelligence_news_title = Label.new()
	intelligence_news_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intelligence_news_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	intelligence_news_title.add_theme_font_size_override("font_size", 30)
	intelligence_news_title.add_theme_color_override("font_color", Color("#251d16"))
	intelligence_news_panel.add_child(intelligence_news_title)

	intelligence_news_content = Label.new()
	intelligence_news_content.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intelligence_news_content.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	intelligence_news_content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intelligence_news_content.add_theme_font_size_override("font_size", 20)
	intelligence_news_content.add_theme_color_override("font_color", Color("#493b2d"))
	intelligence_news_panel.add_child(intelligence_news_content)

	intelligence_news_footer = Label.new()
	intelligence_news_footer.text = "占城大师 · 即时报道"
	intelligence_news_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intelligence_news_footer.add_theme_font_size_override("font_size", 13)
	intelligence_news_footer.add_theme_color_override("font_color", Color("#8a6a3d"))
	intelligence_news_panel.add_child(intelligence_news_footer)

func show_intelligence_news(title: String, content: String) -> void:
	intelligence_news_queue.append({"title": title, "content": content})
	if not intelligence_news_running:
		_start_next_intelligence_news()

func _start_next_intelligence_news() -> void:
	if intelligence_news_queue.is_empty():
		intelligence_news_running = false
		intelligence_news_current = {}
		if intelligence_news_overlay:
			intelligence_news_overlay.visible = false
		return
	intelligence_news_current = intelligence_news_queue.pop_front()
	intelligence_news_running = true
	intelligence_news_title.text = str(intelligence_news_current.get("title", "世界情报"))
	intelligence_news_content.text = str(intelligence_news_current.get("content", ""))
	intelligence_news_overlay.visible = true
	if intelligence_news_tween != null and intelligence_news_tween.is_valid():
		intelligence_news_tween.kill()
	intelligence_news_tween = create_tween()
	intelligence_news_tween.tween_interval(Config.INTELLIGENCE_NEWS_DURATION)
	intelligence_news_tween.tween_callback(_finish_intelligence_news)

func _finish_intelligence_news() -> void:
	intelligence_news_current = {}
	intelligence_news_running = false
	if intelligence_news_overlay:
		intelligence_news_overlay.visible = false
	_start_next_intelligence_news()

func hide_intelligence_news() -> void:
	if intelligence_news_tween != null and intelligence_news_tween.is_valid():
		intelligence_news_tween.kill()
	intelligence_news_queue.clear()
	intelligence_news_current = {}
	intelligence_news_running = false
	if intelligence_news_overlay:
		intelligence_news_overlay.visible = false

func _refresh_broadcast_banner() -> void:
	if bombardment_banner == null or bombardment_banner_label == null:
		return
	if world_broadcast_remaining > 0.0 and not world_broadcast_message.is_empty():
		bombardment_banner_label.text = world_broadcast_message
		bombardment_banner.visible = true
	elif not bombardment_banner_message.is_empty():
		bombardment_banner_label.text = bombardment_banner_message
		bombardment_banner.visible = true
	else:
		bombardment_banner.visible = false

func play_card_event(owner: int, card_type: int, fate_cell: Vector2i) -> void:
	card_event_queue.append({"owner": owner, "card_type": card_type, "fate_cell": fate_cell})
	if not card_event_running:
		_start_next_card_event()

func _start_next_card_event() -> void:
	if card_event_queue.is_empty():
		card_event_running = false
		card_event_current = {}
		if card_event_overlay:
			card_event_overlay.visible = false
		return
	card_event_current = card_event_queue.pop_front()
	card_event_running = true
	card_event_overlay.visible = true
	card_event_tween = create_tween()
	if bool(card_event_current.get("is_card_draw", false)):
		var drawn_id := str(card_event_current.get("card_id", ""))
		var drawn_item := MerchantDataScript.get_item(drawn_id)
		card_event_title.text = "随机事件 · 抽卡"
		_show_card_preview_text("随机获得一张卡片", "正在准备卡片库")
		card_event_tween.tween_interval(0.35)
		var preview_ids: Array = MerchantDataScript.CARD_IDS
		if preview_ids.is_empty():
			preview_ids = [drawn_id]
		for index in range(15):
			var preview_id := str(preview_ids[index % preview_ids.size()])
			var preview_item := MerchantDataScript.get_item(preview_id)
			card_event_tween.tween_callback(_show_card_preview_text.bind(str(preview_item.get("name", "未知卡片")), "卡片滚动中..."))
			card_event_tween.tween_interval(0.10)
		card_event_tween.tween_callback(_show_card_preview_text.bind(str(drawn_item.get("name", "未知卡片")), str(drawn_item.get("description", ""))))
		card_event_tween.tween_interval(0.45)
		card_event_tween.tween_callback(_finish_card_draw)
		return
	card_event_title.text = "随机事件 · 翻卡"
	card_event_card.text = "抽卡中..."
	card_event_detail.text = "卡片正在滚动"
	var card_count := Config.CARD_EVENT_UPGRADE_BARRACKS + 1
	for index in range(16):
		card_event_tween.tween_callback(_show_card_preview.bind(index % card_count)).set_delay(0.09)
	card_event_tween.tween_callback(_show_card_result.bind(int(card_event_current["card_type"])))
	card_event_tween.tween_interval(0.9)
	card_event_tween.tween_callback(_finish_card_event)

func _show_card_preview(card_type: int) -> void:
	card_event_card.text = _card_event_name(card_type)
	card_event_detail.text = "卡片滚动中..."

func _show_card_result(card_type: int) -> void:
	card_event_card.text = _card_event_name(card_type)
	card_event_detail.text = "抽卡结果"

func _show_card_preview_text(title: String, detail: String) -> void:
	card_event_card.text = title
	card_event_detail.text = detail

func _finish_card_event() -> void:
	if not card_event_running or card_event_current.is_empty():
		return
	var owner := int(card_event_current["owner"])
	var card_type := int(card_event_current["card_type"])
	var fate_cell: Vector2i = card_event_current["fate_cell"]
	card_event_finished.emit(owner, card_type, fate_cell)
	card_event_current = {}
	card_event_running = false
	_start_next_card_event()

func _finish_card_draw() -> void:
	if not card_event_running or card_event_current.is_empty():
		return
	var owner := int(card_event_current.get("owner", 1))
	var card_id := str(card_event_current.get("card_id", ""))
	var fate_cell: Vector2i = card_event_current.get("fate_cell", Vector2i(999, 999))
	card_draw_finished.emit(owner, card_id, fate_cell)
	card_event_current = {}
	card_event_running = false
	_start_next_card_event()

func clear_card_events() -> void:
	if card_event_tween != null and card_event_tween.is_valid():
		card_event_tween.kill()
	card_event_queue.clear()
	card_event_current = {}
	card_event_running = false
	if card_event_overlay:
		card_event_overlay.visible = false

func _card_event_name(card_type: int) -> String:
	if card_type == Config.RANDOM_EVENT_DISPLAY_CARD:
		return "抽卡事件"
	match card_type:
		Config.CARD_EVENT_LOSE_LAND:
			return "世界随机地块失去归属"
		Config.CARD_EVENT_GAIN_GOLD:
			return "获得 10 金币"
		Config.CARD_EVENT_ENEMY_LOSE_LAND:
			return "敌方失去一块土地"
		Config.CARD_EVENT_UPGRADE_BARRACKS:
			return "升级 1 个兵营"
	return "未知卡片"

func _layout_ui() -> void:
	if stats_label == null:
		return
	viewport_size = get_viewport().get_visible_rect().size
	if camera_guide_layer != null:
		camera_guide_layer.size = viewport_size
		var guide_rect := Rect2(42.0, 184.0, maxf(1.0, viewport_size.x - 84.0), maxf(1.0, viewport_size.y - 266.0))
		enemy_camera_guide.size = viewport_size
		player_camera_guide.size = viewport_size
		enemy_camera_guide.call("configure_safe_rect", guide_rect)
		player_camera_guide.call("configure_safe_rect", guide_rect)
	player_info_button.position = Vector2(16, 78)
	player_info_button.size = Vector2(112, 36)
	player_info_button.visible = viewport_size.x >= 150.0
	player_info_title.position = Vector2(28, 20)
	player_info_close_button.position = Vector2(player_info_panel.size.x - 94, 18)
	player_info_close_button.size = Vector2(70, 34)
	var info_width := minf(viewport_size.x * 0.86, 600.0)
	var info_height := minf(viewport_size.y * 0.68, 760.0)
	player_info_panel.size = Vector2(info_width, info_height)
	player_info_panel.position = Vector2((viewport_size.x - info_width) * 0.5, (viewport_size.y - info_height) * 0.5)
	player_info_title.position = Vector2(28, 20)
	player_info_close_button.position = Vector2(info_width - 94, 18)
	player_info_equipment_title.position = Vector2(28, 248)
	var slot_width := info_width - 56.0
	for index in range(player_info_equipment_slots.size()):
		var slot := player_info_equipment_slots[index]
		slot.position = Vector2(28, 286 + index * 82)
		slot.size = Vector2(slot_width, 72)
		player_info_equipment_icons[index].position = Vector2(10, 8)
		player_info_equipment_icons[index].size = Vector2(56, 56)
		var slot_label := player_info_equipment_labels[index]
		slot_label.position = Vector2(78, 0)
		slot_label.size = Vector2(slot_width - 92, 72)
	player_info_overlay.size = viewport_size
	equipment_detail_overlay.size = viewport_size
	equipment_replacement_overlay.size = viewport_size
	var detail_width := minf(viewport_size.x * 0.86, 600.0)
	equipment_detail_panel.size = Vector2(detail_width, 360.0)
	equipment_detail_panel.position = Vector2((viewport_size.x - detail_width) * 0.5, (viewport_size.y - 360.0) * 0.5)
	equipment_detail_title.position = Vector2(24, 22)
	equipment_detail_title.size = Vector2(detail_width - 48, 42)
	equipment_detail_icon.position = Vector2((detail_width - 96.0) * 0.5, 78)
	equipment_detail_icon.size = Vector2(96, 96)
	equipment_detail_info.position = Vector2(30, 184)
	equipment_detail_info.size = Vector2(detail_width - 60, 82)
	equipment_detail_close_button.position = Vector2((detail_width - 120.0) * 0.5, 294)
	equipment_detail_close_button.size = Vector2(120, 40)
	var replacement_width := minf(viewport_size.x * 0.90, 640.0)
	equipment_replacement_panel.size = Vector2(replacement_width, 450.0)
	equipment_replacement_panel.position = Vector2((viewport_size.x - replacement_width) * 0.5, (viewport_size.y - 450.0) * 0.5)
	equipment_replacement_title.position = Vector2(24, 20)
	equipment_replacement_title.size = Vector2(replacement_width - 48, 42)
	var replacement_column_width := (replacement_width - 72.0) * 0.5
	equipment_replacement_current_icon.position = Vector2(24 + (replacement_column_width - 88.0) * 0.5, 82)
	equipment_replacement_current_icon.size = Vector2(88, 88)
	equipment_replacement_new_icon.position = Vector2(48 + replacement_column_width + (replacement_column_width - 88.0) * 0.5, 82)
	equipment_replacement_new_icon.size = Vector2(88, 88)
	equipment_replacement_current_label.position = Vector2(24, 180)
	equipment_replacement_current_label.size = Vector2(replacement_column_width, 116)
	equipment_replacement_new_label.position = Vector2(48 + replacement_column_width, 180)
	equipment_replacement_new_label.size = Vector2(replacement_column_width, 116)
	equipment_replace_button.position = Vector2(replacement_width * 0.5 - 146, 370)
	equipment_replace_button.size = Vector2(120, 42)
	equipment_discard_button.position = Vector2(replacement_width * 0.5 + 26, 370)
	equipment_discard_button.size = Vector2(120, 42)
	card_event_overlay.size = viewport_size
	var card_width := minf(viewport_size.x * 0.84, 580.0)
	var card_height := minf(viewport_size.y * 0.42, 520.0)
	card_event_panel.size = Vector2(card_width, card_height)
	card_event_panel.position = Vector2((viewport_size.x - card_width) * 0.5, (viewport_size.y - card_height) * 0.5)
	card_event_title.position = Vector2(24, 32)
	card_event_title.size = Vector2(card_width - 48, 48)
	card_event_card.position = Vector2(24, 132)
	card_event_card.size = Vector2(card_width - 48, 150)
	card_event_detail.position = Vector2(24, 310)
	card_event_detail.size = Vector2(card_width - 48, 48)
	intelligence_news_overlay.size = viewport_size
	var news_width := minf(viewport_size.x * 0.88, 620.0)
	var news_height := minf(viewport_size.y * 0.34, 380.0)
	intelligence_news_panel.size = Vector2(news_width, news_height)
	intelligence_news_panel.position = Vector2((viewport_size.x - news_width) * 0.5, (viewport_size.y - news_height) * 0.5)
	intelligence_news_kicker.position = Vector2(24, 20)
	intelligence_news_kicker.size = Vector2(news_width - 48, 28)
	intelligence_news_title.position = Vector2(24, 64)
	intelligence_news_title.size = Vector2(news_width - 48, 56)
	intelligence_news_content.position = Vector2(34, 134)
	intelligence_news_content.size = Vector2(news_width - 68, news_height - 192)
	intelligence_news_footer.position = Vector2(24, news_height - 42)
	intelligence_news_footer.size = Vector2(news_width - 48, 24)
	merchant_shop_overlay.size = viewport_size
	var merchant_width := minf(viewport_size.x * 0.92, 660.0)
	var merchant_height := minf(viewport_size.y * 0.48, 500.0)
	merchant_shop_panel.size = Vector2(merchant_width, merchant_height)
	merchant_shop_panel.position = Vector2((viewport_size.x - merchant_width) * 0.5, (viewport_size.y - merchant_height) * 0.5)
	merchant_shop_title.position = Vector2(20.0, 22.0)
	merchant_shop_title.size = Vector2(merchant_width - 40.0, 42.0)
	var merchant_gap := 12.0
	var merchant_button_width := (merchant_width - 40.0 - merchant_gap * 2.0) / 3.0
	for index in range(merchant_shop_buttons.size()):
		merchant_shop_buttons[index].position = Vector2(20.0 + index * (merchant_button_width + merchant_gap), 84.0)
		merchant_shop_buttons[index].size = Vector2(merchant_button_width, merchant_height - 154.0)
	merchant_shop_close_button.position = Vector2((merchant_width - 140.0) * 0.5, merchant_height - 56.0)
	merchant_shop_close_button.size = Vector2(140.0, 38.0)
	merchant_shop_dismiss_button.position = Vector2(20.0, merchant_height - 56.0)
	merchant_shop_dismiss_button.size = Vector2(140.0, 38.0)
	for index in range(merchant_shop_buttons.size()):
		var button_size := merchant_shop_buttons[index].size
		merchant_shop_card_icons[index].position = Vector2((button_size.x - 64.0) * 0.5, 12.0)
		merchant_shop_card_icons[index].size = Vector2(64.0, 78.0)
		merchant_shop_card_titles[index].position = Vector2(8.0, 88.0)
		merchant_shop_card_titles[index].size = Vector2(button_size.x - 16.0, 28.0)
		merchant_shop_card_descriptions[index].position = Vector2(10.0, 122.0)
		merchant_shop_card_descriptions[index].size = Vector2(button_size.x - 20.0, maxf(34.0, button_size.y - 178.0))
		merchant_shop_price_labels[index].position = Vector2(button_size.x - 88.0, button_size.y - 48.0)
		merchant_shop_price_labels[index].size = Vector2(42.0, 30.0)
		merchant_shop_coin_icons[index].position = Vector2(button_size.x - 48.0, button_size.y - 48.0)
		merchant_shop_coin_icons[index].size = Vector2(30.0, 30.0)
	player_info_button.position = Vector2(16, 78)
	player_info_button.size = Vector2(48, 48)
	if bottom_status_panel != null:
		bottom_status_panel.position = Vector2(16.0, viewport_size.y - 78.0)
		bottom_status_panel.size = Vector2(maxf(1.0, minf(310.0, viewport_size.x - 32.0)), 62.0)
	stats_label.position = Vector2(16.0, 14.0)
	stats_label.size = Vector2(150.0, 34.0)
	status_label.position = Vector2(maxf(1.0, viewport_size.x - 210.0), 14.0)
	status_label.size = Vector2(194.0, 34.0)
	hq_health_bar.position = Vector2(16.0, 50.0)
	hq_health_bar.size = Vector2(142.0, 10.0)
	building_damage_edge_soft.position = Vector2.ZERO
	building_damage_edge_soft.size = viewport_size
	building_damage_edge.position = Vector2.ZERO
	building_damage_edge.size = viewport_size
	timer_label.position = Vector2(120.0, 62.0)
	timer_label.size = Vector2(maxf(1.0, viewport_size.x - 240.0), 42.0)
	var banner_width := maxf(1.0, minf(560.0, viewport_size.x - 32.0))
	bombardment_banner.position = Vector2((viewport_size.x - banner_width) * 0.5, 14.0)
	bombardment_banner.size = Vector2(banner_width, 46.0)
	bombardment_banner_label.position = Vector2(12, 0)
	bombardment_banner_label.size = Vector2(maxf(0.0, bombardment_banner.size.x - 24), bombardment_banner.size.y)
	hint_container.position = Vector2(20.0, maxf(150.0, viewport_size.y - 220.0))
	hint_container.size = Vector2(minf(420.0, maxf(1.0, viewport_size.x - 300.0)), PERSONAL_HINT_LINE_HEIGHT * PERSONAL_HINT_VISIBLE_LINES)
	for line in hint_container.get_children():
		line.size = Vector2(hint_container.size.x, PERSONAL_HINT_LINE_HEIGHT)
	end_panel.size = Vector2(minf(viewport_size.x * 0.85, 620.0), 280.0)
	end_panel.position = Vector2((viewport_size.x - end_panel.size.x) * 0.5, (viewport_size.y - end_panel.size.y) * 0.5)
	end_label.size = Vector2(end_panel.size.x - 40, 110)
	restart_button.position = Vector2((end_panel.size.x - 160) * 0.5, 190)
	if cat_companion != null:
		cat_companion.size = Vector2(viewport_size.x, 340.0)
		cat_companion.position = Vector2.ZERO
		cat_companion.position.y = maxf(8.0, viewport_size.y - 348.0)
		cat_companion.call("set_viewport_size", viewport_size)
	update_camera_guides()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_layout_ui()

func update_state(time_left: float, player_gold: int, _ai_gold: int, player_hp: float, _ai_hp: float, player_tiles: int, ai_tiles: int) -> void:
	if stats_label == null:
		return
	stats_label.text = "金币  %d" % player_gold
	status_label.text = "领地  %02d : %02d" % [player_tiles, ai_tiles]
	hq_health_bar.value = clampf(player_hp, 0.0, Config.HQ_MAX_HP)
	hq_health_bar.visible = player_hp < Config.HQ_MAX_HP - 0.01
	var total_seconds := maxi(0, int(ceil(time_left)))
	var minutes := total_seconds / 60
	var seconds := total_seconds % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]

func show_hint(message: String) -> void:
	if hint_container == null or message.is_empty():
		return
	if hint_messages.is_empty() or hint_messages[0] != message:
		hint_messages.push_front(message)
		if hint_messages.size() > PERSONAL_HINT_MAX_LINES:
			hint_messages.pop_back()
		_render_hint_history()

func clear_hint_history() -> void:
	hint_messages.clear()
	_render_hint_history()

func _render_hint_history() -> void:
	if hint_container == null:
		return
	var lines := hint_container.get_children()
	for index in range(lines.size()):
		var line: Label = lines[index]
		line.position = Vector2(0.0, float(index) * PERSONAL_HINT_LINE_HEIGHT)
		line.text = hint_messages[index] if index < hint_messages.size() else ""
		line.modulate = Color(1.0, 1.0, 1.0, 0.5 if index == PERSONAL_HINT_MAX_LINES - 1 else 1.0)

func show_bombardment_banner(message: String) -> void:
	if bombardment_banner == null or bombardment_banner_label == null:
		return
	bombardment_banner_message = message
	_refresh_broadcast_banner()

func hide_bombardment_banner() -> void:
	bombardment_banner_message = ""
	_refresh_broadcast_banner()

func flash_building_damage() -> void:
	if building_damage_edge == null or building_damage_edge_soft == null:
		return
	if building_damage_edge_tween != null and building_damage_edge_tween.is_valid():
		building_damage_edge_tween.kill()
	building_damage_edge.visible = true
	building_damage_edge_soft.visible = true
	building_damage_edge.modulate.a = 1.0
	building_damage_edge_soft.modulate.a = 1.0
	building_damage_edge_tween = create_tween()
	building_damage_edge_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	building_damage_edge_tween.tween_property(building_damage_edge, "modulate:a", 0.0, 0.30)
	building_damage_edge_tween.parallel().tween_property(building_damage_edge_soft, "modulate:a", 0.0, 0.30)
	building_damage_edge_tween.tween_callback(func() -> void:
		building_damage_edge.visible = false
		building_damage_edge_soft.visible = false
	)

func show_world_broadcast(message: String, duration: float = Config.INTELLIGENCE_BROADCAST_DURATION) -> void:
	world_broadcast_message = message
	world_broadcast_remaining = maxf(0.0, duration)
	_refresh_broadcast_banner()

func hide_world_broadcast() -> void:
	world_broadcast_message = ""
	world_broadcast_remaining = 0.0
	_refresh_broadcast_banner()

func show_result(message: String) -> void:
	clear_camera_guides()
	end_panel.visible = true
	end_label.text = message

func hide_result() -> void:
	if end_panel:
		end_panel.visible = false

func _on_restart_pressed() -> void:
	_close_player_info()
	clear_camera_guides()
	if main_ref:
		main_ref.restart_game()
