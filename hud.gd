class_name GameHUD
extends CanvasLayer

const Config := preload("res://game_config.gd")
const Art := preload("res://art_theme.gd")
const EquipmentDataScript := preload("res://equipment_data.gd")
const MerchantDataScript := preload("res://merchant_data.gd")
const CameraGuideScript := preload("res://camera_guide.gd")
const CameraGuideIconScript := preload("res://camera_guide_icon.gd")
const CatCompanionScript := preload("res://cat_companion.gd")
const MerchantCardIconScript := preload("res://merchant_card_icon.gd")
const MerchantShopArtScript := preload("res://merchant_shop_art.gd")
const MerchantShopUIScript := preload("res://merchant_shop_ui.gd")
const DivinationHouseArtScript := preload("res://divination_house_art.gd")
const DivinationTargetDisplayScript := preload("res://divination_target_display.gd")
const DivinationCrystalEffectScript := preload("res://divination_crystal_effect.gd")
const FactionStatsDisplayScript := preload("res://faction_stats_display.gd")
const FactionAvatarScript := preload("res://faction_avatar.gd")
const SettlementUIScript := preload("res://settlement_ui.gd")
const GOLD_ICON := preload("res://assets/generated/ui/coin.png")
const CASTLE_INFO_ICON := preload("res://assets/generated/ui/castle_info.png")
const BARRACKS_ICON := preload("res://assets/generated/ui/barracks_icon.png")
const SOLDIER_ICON := preload("res://assets/generated/ui/soldier_icon.png")
const BATTLE_HUD_PREVIEW_SCENE := preload("res://BattleHUDPreview.tscn")
const DIVINATION_EVENT_COUNT := 6

@export_category("UI编辑")
@export var ui_config: UIEditorConfig = preload("res://ui_editor_config.tres")

signal card_event_finished(owner: int, card_type: int, fate_cell: Vector2i)
signal card_draw_finished(owner: int, card_id: String, fate_cell: Vector2i)
signal divination_roll_finished(fate_cell: Vector2i)
signal divination_closed(fate_cell: Vector2i)
signal merchant_arrival_finished(cell: Vector2i)
signal merchant_item_selected(index: int)
signal merchant_dismissed
signal inventory_item_dropped(item_id: String, screen_position: Vector2)
signal inventory_item_dragged(item_id: String, screen_position: Vector2)
signal inventory_item_drag_ended(item_id: String, screen_position: Vector2, was_dragged: bool)

var main_ref: Node
var status_label: Label
var stats_label: Label
var gold_icon: TextureRect
var gold_panel: Panel
var player_avatar: Control
var player_summary: Control
var player_name_label: Label
var barracks_count_label: Label
var soldier_count_label: Label
var player_eliminated_label: Label
var authored_hud_layout: Dictionary = {}
var authored_control_layout: Dictionary = {}
var authored_hud_styles: Dictionary = {}
var authored_faction_stats_layout: Dictionary = {}
var fps_label: Label
var army_label: Label
var faction_stats_display: Control
var timer_label: Label
var hq_health_bar: ProgressBar
var hint_label: Label
var hint_container: Control
var hint_messages: Array[String] = []
var card_hint_panel: Panel
var card_hint_label: Label
var card_hint_tween: Tween
var bombardment_banner: ColorRect
var bombardment_banner_label: Label
var broadcast_faction_avatar: Control
var broadcast_target_avatar: Control
var broadcast_target_label: Label
var bombardment_banner_message := ""
var world_broadcast_message := ""
var world_broadcast_remaining := 0.0
var world_broadcast_faction := -1
var world_broadcast_name := ""
var world_broadcast_target_faction := -1
var world_broadcast_target_name := ""
var cat_companion: CatCompanion
var end_panel: Panel
var end_label: Label
var restart_button: Button
var spectate_button: Button
var exit_game_button: Button
var defeat_overlay: Control
var watch_mode_button: Button
var settlement_ui: Control
var player_info_button: Button
var bottom_status_panel: ColorRect
var player_info_overlay: ColorRect
var player_info_panel: Panel
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
var divination_event_queue: Array[Dictionary] = []
var divination_event_current: Dictionary = {}
var divination_event_tween: Tween
var divination_event_running := false
var divination_roll_emitted := false
var card_event_overlay: ColorRect
var card_event_panel: Panel
var card_event_title: Label
var card_event_card: Label
var card_event_detail: Label
var card_draw_result_icon: Control
var card_draw_confirm_button: Button
var card_draw_countdown_label: Label
var card_draw_countdown_remaining := 0.0
var divination_overlay: ColorRect
var divination_root: Control
var divination_panel: Panel
var divination_title: Label
var divination_target: Label
var divination_target_text: Label
var divination_target_display: DivinationTargetDisplay
var divination_event_label: Label
var divination_event_text: Label
var divination_result: Label
var divination_event_object: TextureRect
var divination_crystal_effect: DivinationCrystalEffect
var divination_desktop_event_icons: Control
var divination_start_button: Button
var divination_bubble: TextureRect
var divination_close_button: TextureButton
var divination_event_icons: Array[Label] = []
var divination_event_highlight: DivinationEventHighlight
var divination_house_art: Control
var intelligence_news_queue: Array[Dictionary] = []
var intelligence_news_current: Dictionary = {}
var intelligence_news_tween: Tween
var intelligence_news_running := false
var intelligence_news_overlay: ColorRect
var intelligence_news_panel: Panel
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
var equipment_detail_panel: Panel
var equipment_detail_icon: TextureRect
var equipment_detail_title: Label
var equipment_detail_info: Label
var equipment_detail_close_button: Button
var equipment_replacement_overlay: ColorRect
var equipment_replacement_panel: Panel
var equipment_replacement_title: Label
var equipment_replacement_current_icon: TextureRect
var equipment_replacement_new_icon: TextureRect
var equipment_recommendation_badge: Panel
var equipment_recommendation_label: Label
var equipment_replacement_current_label: Label
var equipment_replacement_new_label: Label
var equipment_replace_button: Button
var equipment_discard_button: Button
var merchant_shop_overlay: Control
var merchant_shop_panel: Panel
var merchant_shop_title: Label
var merchant_shop_gold_label: Label
var merchant_shop_art: Control
var merchant_shop_buttons: Array[Button] = []
var merchant_shop_card_icons: Array[Control] = []
var merchant_shop_card_titles: Array[Label] = []
var merchant_shop_card_descriptions: Array[Label] = []
var merchant_shop_price_labels: Array[Label] = []
var merchant_shop_coin_icons: Array[Control] = []
var merchant_shop_close_button: Button
var merchant_shop_dismiss_button: Button
var merchant_arrival_overlay: ColorRect
var merchant_arrival_panel: Panel
var merchant_arrival_title: Label
var merchant_arrival_hint: Label
var merchant_arrival_art: Control
var merchant_arrival_cards: Array[Control] = []
var merchant_arrival_tween: Tween
var building_damage_edge_soft: Panel
var building_damage_edge: Panel
var building_damage_edge_tween: Tween
var viewport_size := Vector2.ZERO
var camera_guide_refresh_timer := 0.0
const CAMERA_GUIDE_REFRESH_INTERVAL := 0.20
var fps_refresh_timer := 0.0
const FPS_REFRESH_INTERVAL := 0.25
var last_camera_transform := Transform2D.IDENTITY
var last_camera_viewport_size := Vector2(-1.0, -1.0)
var last_territory_revision := -1
var cached_enemy_territory_near_player := false

const PERSONAL_HINT_LINE_HEIGHT := 24.0
const PERSONAL_HINT_VISIBLE_LINES := 3.5
const PERSONAL_HINT_MAX_LINES := 4
const FACTION_STATS_RUNTIME_X_OFFSET := 150.0

func setup(controller: Node) -> void:
	main_ref = controller
	Art.configure_ui(ui_config)
	_build_ui()

func _process(delta: float) -> void:
	if card_event_running and not card_event_current.is_empty() and bool(card_event_current.get("is_card_draw", false)):
		card_draw_countdown_remaining = maxf(0.0, card_draw_countdown_remaining - delta)
		_update_card_draw_countdown_label()
		if card_draw_countdown_remaining <= 0.0:
			_finish_card_draw()
	fps_refresh_timer -= delta
	if fps_refresh_timer <= 0.0:
		fps_refresh_timer = FPS_REFRESH_INTERVAL
		_refresh_fps_label()
	if world_broadcast_remaining > 0.0:
		world_broadcast_remaining = maxf(0.0, world_broadcast_remaining - delta)
		if world_broadcast_remaining <= 0.0:
			world_broadcast_message = ""
			world_broadcast_faction = -1
			world_broadcast_name = ""
			world_broadcast_target_faction = -1
			world_broadcast_target_name = ""
			_refresh_broadcast_banner()
	camera_guide_refresh_timer -= delta
	if camera_guide_refresh_timer <= 0.0:
		camera_guide_refresh_timer = CAMERA_GUIDE_REFRESH_INTERVAL
		update_camera_guides()

func _build_ui() -> void:
	viewport_size = get_viewport().get_visible_rect().size
	# GoldPanel is authored in BattleHUDPreview.tscn so its background and any
	# child decoration remain editable in the Godot scene editor. The runtime
	# HUD copies that authored node and only supplies live gold data separately.
	var preview_instance := BATTLE_HUD_PREVIEW_SCENE.instantiate()
	_capture_authored_hud_layout(preview_instance)
	var authored_gold_panel := preview_instance.get_node_or_null("GoldPanel") as Panel
	if authored_gold_panel != null:
		gold_panel = authored_gold_panel.duplicate() as Panel
		gold_panel.name = "GoldPanel"
		gold_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gold_panel.z_index = 0
		add_child(gold_panel)
	player_info_button = Button.new()
	player_info_button.name = "PlayerInfoButton"
	player_info_button.text = ""
	player_info_button.tooltip_text = "城堡信息"
	player_info_button.icon = CASTLE_INFO_ICON
	player_info_button.expand_icon = true
	player_info_button.mouse_filter = Control.MOUSE_FILTER_STOP
	player_info_button.z_index = 25
	player_info_button.position = Vector2(16, 78)
	player_info_button.size = Vector2(48, 48)
	player_info_button.add_theme_font_size_override("font_size", 26)
	player_info_button.add_theme_color_override("font_color", Color("#f8fafc"))
	player_info_button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	Art.apply_flat_button(player_info_button, Art.POPUP_ACCENT)
	player_info_button.pressed.connect(_toggle_player_info)
	add_child(player_info_button)

	bottom_status_panel = ColorRect.new()
	bottom_status_panel.name = "BottomStatusPanel"
	bottom_status_panel.color = Color(1.0, 0.96, 0.82, 0.92)
	bottom_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_status_panel.visible = false
	add_child(bottom_status_panel)

	stats_label = Label.new()
	stats_label.name = "GoldLabel"
	stats_label.add_theme_font_size_override("font_size", 18)
	stats_label.add_theme_color_override("font_color", Color("#f8fafc"))
	stats_label.add_theme_color_override("font_outline_color", Color("#000000"))
	stats_label.add_theme_constant_override("outline_size", 3)
	stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stats_label)

	gold_icon = TextureRect.new()
	gold_icon.name = "GoldIcon"
	gold_icon.texture = ui_config.battle_gold_icon_texture if ui_config != null and ui_config.battle_gold_icon_texture != null else GOLD_ICON
	gold_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gold_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gold_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gold_icon.z_index = 1
	add_child(gold_icon)

	player_avatar = FactionAvatarScript.new()
	player_avatar.name = "PlayerAvatar"
	player_avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(player_avatar)
	player_name_label = Label.new()
	player_name_label.name = "PlayerNameLabel"
	player_name_label.text = "Helios"
	player_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(player_name_label)
	player_summary = Control.new()
	player_summary.name = "PlayerSummary"
	player_summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(player_summary)
	var barracks_icon := TextureRect.new()
	barracks_icon.name = "BarracksIcon"
	barracks_icon.texture = BARRACKS_ICON
	barracks_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	barracks_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	barracks_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_summary.add_child(barracks_icon)
	barracks_count_label = Label.new()
	barracks_count_label.name = "BarracksCountLabel"
	_configure_summary_count_label(barracks_count_label)
	player_summary.add_child(barracks_count_label)
	var soldier_icon := TextureRect.new()
	soldier_icon.name = "SoldierIcon"
	soldier_icon.texture = SOLDIER_ICON
	soldier_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	soldier_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	soldier_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_summary.add_child(soldier_icon)
	soldier_count_label = Label.new()
	soldier_count_label.name = "SoldierCountLabel"
	_configure_summary_count_label(soldier_count_label)
	player_summary.add_child(soldier_count_label)
	player_eliminated_label = Label.new()
	player_eliminated_label.name = "EliminatedLabel"
	_configure_summary_count_label(player_eliminated_label)
	player_eliminated_label.add_theme_color_override("font_color", Color("#fca5a5"))
	player_eliminated_label.visible = false
	player_summary.add_child(player_eliminated_label)

	fps_label = Label.new()
	fps_label.name = "FpsLabel"
	fps_label.text = "FPS --"
	fps_label.add_theme_font_size_override("font_size", 14)
	fps_label.add_theme_color_override("font_color", Color("#4ade80"))
	fps_label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.08, 0.94))
	fps_label.add_theme_constant_override("outline_size", 4)
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fps_label)
	_refresh_fps_label()

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", Color("#f8fafc"))
	status_label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.08, 0.92))
	status_label.add_theme_constant_override("outline_size", 4)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.visible = false
	add_child(status_label)

	army_label = Label.new()
	army_label.name = "ArmyLabel"
	army_label.name = "ArmyCountLabel"
	army_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	army_label.add_theme_font_size_override("font_size", 13)
	army_label.add_theme_color_override("font_color", Color("#e2e8f0"))
	army_label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.08, 0.92))
	army_label.add_theme_constant_override("outline_size", 4)
	army_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	army_label.visible = false
	add_child(army_label)

	faction_stats_display = FactionStatsDisplayScript.new()
	faction_stats_display.name = "FactionStatsDisplay"
	faction_stats_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faction_stats_display.call("configure_ui", ui_config)
	if faction_stats_display.has_method("configure_authored_layout"):
		faction_stats_display.call("configure_authored_layout", authored_faction_stats_layout)
	add_child(faction_stats_display)

	hq_health_bar = ProgressBar.new()
	hq_health_bar.name = "HQHealthBar"
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
	timer_label.name = "TimerLabel"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 22)
	timer_label.add_theme_color_override("font_color", Color("#ffffff"))
	timer_label.add_theme_color_override("font_outline_color", Color("#000000"))
	timer_label.add_theme_constant_override("outline_size", 5)
	timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(timer_label)

	bombardment_banner = ColorRect.new()
	bombardment_banner.color = Color(0.35, 0.03, 0.03, 0.94)
	bombardment_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bombardment_banner.visible = false
	add_child(bombardment_banner)
	bombardment_banner_label = Label.new()
	bombardment_banner_label.name = "BroadcastLabel"
	bombardment_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bombardment_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bombardment_banner_label.add_theme_font_size_override("font_size", 19)
	bombardment_banner_label.add_theme_color_override("font_color", Color("#fee2e2"))
	bombardment_banner.add_child(bombardment_banner_label)
	broadcast_faction_avatar = FactionAvatarScript.new()
	broadcast_faction_avatar.name = "BroadcastFactionAvatar"
	broadcast_faction_avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	broadcast_faction_avatar.visible = false
	bombardment_banner.add_child(broadcast_faction_avatar)
	broadcast_target_avatar = FactionAvatarScript.new()
	broadcast_target_avatar.name = "BroadcastTargetAvatar"
	broadcast_target_avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	broadcast_target_avatar.visible = false
	bombardment_banner.add_child(broadcast_target_avatar)
	broadcast_target_label = Label.new()
	broadcast_target_label.name = "BroadcastTargetLabel"
	broadcast_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	broadcast_target_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	broadcast_target_label.add_theme_font_size_override("font_size", 19)
	broadcast_target_label.add_theme_color_override("font_color", Color("#fee2e2"))
	broadcast_target_label.visible = false
	bombardment_banner.add_child(broadcast_target_label)

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
	_build_merchant_arrival_panel()

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
	_build_card_hint_toast()

	var defeat_scene := preload("res://DefeatUI.tscn")
	var defeat_ui: Control = defeat_scene.instantiate()
	defeat_ui.name = "DefeatOverlay"
	defeat_ui.visible = false
	defeat_ui.z_index = 120
	add_child(defeat_ui)
	defeat_overlay = defeat_ui
	end_panel = defeat_ui.get_node_or_null(NodePath("DefeatPanel")) as Panel
	if end_panel != null:
		end_panel.add_theme_stylebox_override("panel", Art.flat_panel_style(Art.POPUP_BACKGROUND_ALT, Art.POPUP_ACCENT))
	end_label = defeat_ui.get_node_or_null(NodePath("DefeatPanel/Message")) as Label
	restart_button = defeat_ui.get_node_or_null(NodePath("DefeatPanel/RestartButton")) as Button
	spectate_button = defeat_ui.get_node_or_null(NodePath("DefeatPanel/SpectateButton")) as Button
	exit_game_button = defeat_ui.get_node_or_null(NodePath("DefeatPanel/ExitGameButton")) as Button
	if restart_button != null:
		restart_button.pressed.connect(_on_restart_pressed)
	if spectate_button != null:
		spectate_button.pressed.connect(_on_spectate_pressed)
	if exit_game_button != null:
		exit_game_button.pressed.connect(_on_defeat_exit_pressed)

	watch_mode_button = Button.new()
	watch_mode_button.name = "WatchModeExitButton"
	watch_mode_button.text = "退出观战"
	watch_mode_button.size = Vector2(148, 42)
	watch_mode_button.add_theme_font_size_override("font_size", 17)
	watch_mode_button.visible = false
	watch_mode_button.z_index = 30
	watch_mode_button.pressed.connect(_on_exit_spectator_pressed)
	add_child(watch_mode_button)

	_build_player_info_panel()
	_build_equipment_panels()
	_build_card_event_panel()
	_build_divination_panel()
	_build_intelligence_news_panel()
	_apply_cartoon_buttons(self)
	_apply_flat_popup_theme()
	_apply_battle_hud_style()
	_apply_authored_battle_hud_styles()
	_layout_ui()
	settlement_ui = SettlementUIScript.new()
	settlement_ui.name = "SettlementUI"
	settlement_ui.visible = false
	settlement_ui.z_index = 200
	add_child(settlement_ui)
	settlement_ui.call("configure_ui", ui_config)
	settlement_ui.connect("confirmed", _on_settlement_confirmed)
	# BattleHUDPreview.tscn is the single source of truth for authored HUD
	# node positions and sizes. Keep this independent of the legacy layout flag.
	_apply_authored_hud_template(preview_instance)
	# The scene is the source for visual layout, but this control must always
	# remain interactive after authored properties are copied.
	player_info_button.mouse_filter = Control.MOUSE_FILTER_STOP
	player_info_button.z_index = maxi(player_info_button.z_index, 25)
	var castle_label := get_node_or_null("CastleLabel") as Control
	if castle_label != null:
		castle_label.z_index = maxi(castle_label.z_index, player_info_button.z_index + 1)
	preview_instance.free()
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
	cat_companion.set_viewport_size(viewport_size)
	cat_companion.inventory_item_dropped.connect(_on_cat_inventory_item_dropped)
	cat_companion.inventory_item_dragged.connect(_on_cat_inventory_item_dragged)
	cat_companion.inventory_item_drag_ended.connect(_on_cat_inventory_item_drag_ended)

func _on_cat_inventory_item_dropped(item_id: String, screen_position: Vector2) -> void:
	inventory_item_dropped.emit(item_id, screen_position)

func _on_cat_inventory_item_dragged(item_id: String, screen_position: Vector2) -> void:
	inventory_item_dragged.emit(item_id, screen_position)

func _on_cat_inventory_item_drag_ended(item_id: String, screen_position: Vector2, was_dragged: bool) -> void:
	inventory_item_drag_ended.emit(item_id, screen_position, was_dragged)

func play_card_draw(owner: int, card_id: String, fate_cell: Vector2i) -> void:
	card_event_queue.append({"owner": owner, "card_id": card_id, "fate_cell": fate_cell, "is_card_draw": true})
	if not card_event_running:
		_start_next_card_event()

func set_item_inventory(items: Array[String], fly_item_id: String = "", fly_origin: Vector2 = Vector2(-1.0, -1.0)) -> void:
	if cat_companion == null:
		return
	cat_companion.set_item_inventory(items)
	if not fly_item_id.is_empty():
		var origin := fly_origin
		if origin.x < 0.0 or origin.y < 0.0:
			origin = viewport_size * 0.5
		cat_companion.play_item_fly_in(fly_item_id, origin)

func get_merchant_item_screen_position(index: int) -> Vector2:
	if index >= 0 and index < merchant_shop_buttons.size() and is_instance_valid(merchant_shop_buttons[index]):
		return merchant_shop_buttons[index].get_global_rect().get_center()
	return viewport_size * 0.5

func show_officer_bubble(message: String) -> void:
	if cat_companion == null or message.is_empty():
		return
	cat_companion.show_bubble(message)

func hide_officer_bubble() -> void:
	if cat_companion == null:
		return
	cat_companion.hide_bubble()

func reset_cat_companion() -> void:
	if cat_companion == null:
		return
	cat_companion.cancel_item_drag()
	cat_companion.hide_bubble()
	cat_companion.set_expanded(false)

func hide_cat_companion() -> void:
	if cat_companion == null:
		return
	cat_companion.cancel_item_drag()
	cat_companion.hide_bubble()
	cat_companion.set_expanded(false)
	cat_companion.visible = false

func is_screen_point_over_card_cancel_area(screen_position: Vector2) -> bool:
	# The companion contains both the card inventory and the cat itself.  A
	# dragged card released anywhere in this authored HUD area is considered a
	# cancellation, rather than being converted into a map cell behind it.
	if cat_companion == null or not cat_companion.visible:
		return false
	return cat_companion.get_global_rect().has_point(screen_position)

func show_cat_companion() -> void:
	if cat_companion == null:
		return
	cat_companion.visible = true

func _build_merchant_shop_panel() -> void:
	var shop_scene := preload("res://MerchantShopUI.tscn")
	var shop_ui: MerchantShopUI = shop_scene.instantiate()
	if shop_ui == null:
		push_error("无法实例化 MerchantShopUI.tscn，商店界面将不可用。")
		return
	shop_ui.name = "MerchantShopOverlay"
	shop_ui.visible = false
	add_child(shop_ui)
	merchant_shop_overlay = shop_ui
	shop_ui.call("configure_ui", ui_config)
	merchant_shop_panel = shop_ui.get_node("MerchantShopPanel")
	merchant_shop_title = shop_ui.get_node("MerchantShopPanel/MerchantShopTitle")
	merchant_shop_gold_label = shop_ui.get_node("MerchantShopPanel/MerchantShopGold")
	merchant_shop_art = shop_ui.get_node("MerchantShopPanel/MerchantShopArt")
	for index in range(3):
		var item_button: Button = shop_ui.get_node("MerchantShopPanel/MerchantItem%d" % index)
		merchant_shop_buttons.append(item_button)
		merchant_shop_card_icons.append(item_button.get_node("CardIcon"))
		merchant_shop_card_titles.append(item_button.get_node("CardTitle"))
		merchant_shop_card_descriptions.append(item_button.get_node("CardDescription"))
		merchant_shop_price_labels.append(item_button.get_node("PurchaseButton/PurchasePrice"))
		merchant_shop_coin_icons.append(item_button.get_node("PurchaseButton/CoinIcon"))
	merchant_shop_close_button = shop_ui.get_node("MerchantShopPanel/CloseButton")
	merchant_shop_dismiss_button = shop_ui.get_node("MerchantShopPanel/DismissButton")
	shop_ui.item_selected.connect(_on_merchant_shop_item_pressed)
	shop_ui.dismissed.connect(_on_merchant_shop_dismiss_pressed)
	shop_ui.closed.connect(hide_merchant_shop)

func _build_merchant_arrival_panel() -> void:
	merchant_arrival_overlay = ColorRect.new()
	merchant_arrival_overlay.name = "MerchantArrivalOverlay"
	merchant_arrival_overlay.color = ui_config.modal_overlay_color
	merchant_arrival_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	merchant_arrival_overlay.visible = false
	add_child(merchant_arrival_overlay)

	merchant_arrival_panel = Panel.new()
	merchant_arrival_panel.name = "MerchantArrivalPanel"
	merchant_arrival_panel.add_theme_stylebox_override("panel", Art.flat_panel_style(Art.POPUP_BACKGROUND_ALT))
	merchant_arrival_overlay.add_child(merchant_arrival_panel)

	merchant_arrival_title = Label.new()
	merchant_arrival_title.text = "商人来了"
	merchant_arrival_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	merchant_arrival_title.add_theme_font_size_override("font_size", 30)
	merchant_arrival_title.add_theme_color_override("font_color", Art.INK)
	merchant_arrival_panel.add_child(merchant_arrival_title)

	merchant_arrival_hint = Label.new()
	merchant_arrival_hint.text = "看看今天带来的三张卡片"
	merchant_arrival_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	merchant_arrival_hint.add_theme_font_size_override("font_size", 17)
	merchant_arrival_hint.add_theme_color_override("font_color", Art.INK_SOFT)
	merchant_arrival_panel.add_child(merchant_arrival_hint)

	merchant_arrival_art = MerchantShopArtScript.new()
	merchant_arrival_art.name = "MerchantArrivalArt"
	merchant_arrival_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	merchant_arrival_art.call("set_presenting_cards", true)
	merchant_arrival_panel.add_child(merchant_arrival_art)

	for index in range(3):
		var card_icon: Control = MerchantCardIconScript.new()
		card_icon.name = "MerchantArrivalCard%d" % index
		card_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_icon.modulate = Color(1.0, 1.0, 1.0, 0.0)
		merchant_arrival_panel.add_child(card_icon)
		merchant_arrival_cards.append(card_icon)

func play_merchant_arrival(items: Array[String], cell: Vector2i) -> void:
	if merchant_arrival_overlay == null:
		merchant_arrival_finished.emit(cell)
		return
	if merchant_arrival_tween != null and merchant_arrival_tween.is_valid():
		merchant_arrival_tween.kill()
	# The presentation is drawn by the merchant landmark on the map. Keep the
	# arrival overlay hidden so the world-space performance remains visible.
	if merchant_arrival_overlay != null:
		merchant_arrival_overlay.visible = false
	if merchant_shop_overlay != null:
		merchant_shop_overlay.visible = false
	merchant_arrival_tween = create_tween()
	merchant_arrival_tween.tween_interval(Config.MERCHANT_PRESENTATION_DURATION)
	merchant_arrival_tween.tween_callback(_finish_merchant_arrival.bind(cell))

func _merchant_arrival_card_position(index: int) -> Vector2:
	var card_width := merchant_arrival_panel.size.x
	var gap := 18.0
	var width := minf(82.0, (card_width - 72.0 - gap * 2.0) / 3.0)
	var start_x := (card_width - width * 3.0 - gap * 2.0) * 0.5
	return Vector2(start_x + index * (width + gap), 224.0)

func _finish_merchant_arrival(cell: Vector2i) -> void:
	if merchant_arrival_overlay != null:
		merchant_arrival_overlay.visible = false
	merchant_arrival_finished.emit(cell)

func _on_merchant_shop_item_pressed(index: int) -> void:
	if merchant_shop_overlay != null and merchant_shop_overlay.visible:
		merchant_item_selected.emit(index)

func _on_merchant_shop_dismiss_pressed() -> void:
	if merchant_shop_overlay != null and merchant_shop_overlay.visible:
		merchant_dismissed.emit()

func show_merchant_shop(items: Array[String], player_gold: int = -1) -> void:
	if merchant_shop_overlay == null:
		return
	if player_gold < 0:
		player_gold = 0
	merchant_shop_overlay.call("set_items", items, player_gold)
	_update_merchant_price_colors(player_gold)
	merchant_shop_overlay.visible = true
	# Keep the normal HUD gold bar readable above the modal dimmer.
	stats_label.z_index = 20
	gold_icon.z_index = 20

func _update_merchant_price_colors(player_gold: int) -> void:
	var price_color := Art.CORAL.darkened(0.18) if player_gold < Config.MERCHANT_ITEM_COST else Color("#a9650f")
	for price_label in merchant_shop_price_labels:
		if is_instance_valid(price_label) and price_label.visible:
			if player_gold < Config.MERCHANT_ITEM_COST:
				price_label.add_theme_color_override("font_color", price_color)
			else:
				price_label.remove_theme_color_override("font_color")

func _update_merchant_gold(player_gold: int) -> void:
	if merchant_shop_gold_label != null:
		merchant_shop_gold_label.text = "金币  %d" % maxi(0, player_gold)

func hide_merchant_shop() -> void:
	if merchant_shop_overlay != null:
		merchant_shop_overlay.visible = false
	if stats_label != null:
		stats_label.z_index = 0
	if gold_icon != null:
		gold_icon.z_index = 1

func hide_merchant_arrival() -> void:
	if merchant_arrival_tween != null and merchant_arrival_tween.is_valid():
		merchant_arrival_tween.kill()
	if merchant_arrival_overlay != null:
		merchant_arrival_overlay.visible = false
	if merchant_arrival_art != null:
		merchant_arrival_art.call("set_presenting_cards", false)

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

func _build_card_hint_toast() -> void:
	card_hint_panel = Panel.new()
	card_hint_panel.name = "CardHintToast"
	card_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_hint_panel.visible = false
	card_hint_panel.z_index = 60
	var style := StyleBoxFlat.new()
	style.bg_color = ui_config.card_hint_background_color if ui_config != null else Color(0.02, 0.04, 0.08, 0.68)
	style.set_corner_radius_all(8)
	card_hint_panel.add_theme_stylebox_override("panel", style)
	add_child(card_hint_panel)
	card_hint_label = Label.new()
	card_hint_label.name = "CardHintText"
	card_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_hint_label.add_theme_font_size_override("font_size", ui_config.card_hint_font_size if ui_config != null else 18)
	card_hint_label.add_theme_color_override("font_color", Color.WHITE)
	card_hint_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.75))
	card_hint_label.add_theme_constant_override("outline_size", 3)
	card_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_hint_panel.add_child(card_hint_label)

func _is_card_related_hint(message: String) -> bool:
	return message.contains("卡片") or message.contains("卡牌") or message.contains("抽卡") or message.contains("窃取")

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
		elif owner != 1 and owner > 0:
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
	var canvas_transform := get_viewport().get_canvas_transform()
	var territory_revision := int(main_ref.get("territory_revision"))
	var camera_changed := canvas_transform.origin != last_camera_transform.origin or canvas_transform.x != last_camera_transform.x or canvas_transform.y != last_camera_transform.y
	var territory_changed := territory_revision != last_territory_revision
	if not camera_changed and not territory_changed and viewport_size == last_camera_viewport_size:
		return
	last_camera_transform = canvas_transform
	last_camera_viewport_size = viewport_size
	if territory_changed:
		cached_enemy_territory_near_player = _is_enemy_territory_near_player()
		last_territory_revision = territory_revision
	var player_hq: Vector2i = main_ref.get("player_hq")
	var enemy_hq: Vector2i = _nearest_enemy_hq()
	if not bool(board_ref.call("has_cell", player_hq)) or not bool(board_ref.call("has_cell", enemy_hq)):
		clear_camera_guides()
		return
	var player_target := _get_hq_screen_position(player_hq)
	var enemy_target := _get_hq_screen_position(enemy_hq)
	var player_visible := _is_hq_visible(player_target)
	var enemy_visible := _is_hq_visible(enemy_target)
	var show_player := not player_visible
	var show_enemy := not enemy_visible and cached_enemy_territory_near_player and not _is_enemy_territory_visible()

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

func _nearest_enemy_hq() -> Vector2i:
	if main_ref == null or not main_ref.has_method("get_faction_ids"):
		return main_ref.get("ai_hq") if main_ref != null else Vector2i.ZERO
	var board_ref: Node = main_ref.get("board") as Node
	var player_hq: Vector2i = main_ref.get("player_hq")
	var best_cell: Vector2i = main_ref.get("ai_hq")
	var best_distance := INF
	for faction in main_ref.get_faction_ids():
		if faction == 1 or bool(main_ref.eliminated_factions.get(faction, false)):
			continue
		var hq: Vector2i = main_ref.get_hq_cell(faction)
		var distance := int(board_ref.call("cube_distance", player_hq, hq))
		if distance < best_distance:
			best_distance = distance
			best_cell = hq
	return best_cell

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
		elif owner != 1 and owner > 0:
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
	player_info_overlay.color = ui_config.overlay_color
	player_info_overlay.position = Vector2.ZERO
	player_info_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	player_info_overlay.visible = false
	add_child(player_info_overlay)

	player_info_panel = Panel.new()
	player_info_panel.add_theme_stylebox_override("panel", Art.flat_panel_style(Art.POPUP_BACKGROUND_ALT))
	player_info_overlay.add_child(player_info_panel)

	player_info_title = Label.new()
	player_info_title.text = "城堡信息"
	player_info_title.add_theme_font_size_override("font_size", 25)
	player_info_title.add_theme_color_override("font_color", Art.INK)
	player_info_panel.add_child(player_info_title)

	player_info_close_button = Button.new()
	player_info_close_button.text = "关闭"
	player_info_close_button.add_theme_font_size_override("font_size", 14)
	player_info_close_button.pressed.connect(_close_player_info)
	player_info_panel.add_child(player_info_close_button)

	var attribute_header := Label.new()
	attribute_header.text = "当前属性"
	attribute_header.add_theme_font_size_override("font_size", 18)
	attribute_header.add_theme_color_override("font_color", Color("#b96912"))
	attribute_header.position = Vector2(28, 76)
	player_info_panel.add_child(attribute_header)

	player_info_attribute_label = Label.new()
	player_info_attribute_label.text = "血量       100 / 100\n福德       0\n财运       0"
	player_info_attribute_label.add_theme_font_size_override("font_size", 17)
	player_info_attribute_label.add_theme_color_override("font_color", Art.INK_SOFT)
	player_info_attribute_label.position = Vector2(34, 116)
	player_info_attribute_label.size = Vector2(260, 112)
	player_info_panel.add_child(player_info_attribute_label)

	player_info_equipment_title = Label.new()
	player_info_equipment_title.text = "装备栏 1"
	player_info_equipment_title.add_theme_font_size_override("font_size", 18)
	player_info_equipment_title.add_theme_color_override("font_color", Color("#b96912"))
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
	equipment_detail_overlay.color = Color(0.01, 0.03, 0.07, 0.46)
	equipment_detail_overlay.position = Vector2.ZERO
	equipment_detail_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	equipment_detail_overlay.visible = false
	add_child(equipment_detail_overlay)

	equipment_detail_panel = Panel.new()
	equipment_detail_panel.add_theme_stylebox_override("panel", Art.flat_panel_style())
	equipment_detail_overlay.add_child(equipment_detail_panel)

	equipment_detail_title = Label.new()
	equipment_detail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equipment_detail_title.add_theme_font_size_override("font_size", 25)
	equipment_detail_title.add_theme_color_override("font_color", Art.INK)
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
	equipment_detail_info.add_theme_color_override("font_color", Art.INK_SOFT)
	equipment_detail_panel.add_child(equipment_detail_info)

	equipment_detail_close_button = Button.new()
	equipment_detail_close_button.text = "关闭"
	equipment_detail_close_button.pressed.connect(hide_equipment_detail)
	equipment_detail_panel.add_child(equipment_detail_close_button)

	equipment_replacement_overlay = ColorRect.new()
	equipment_replacement_overlay.color = Color(0.01, 0.03, 0.07, 0.50)
	equipment_replacement_overlay.position = Vector2.ZERO
	equipment_replacement_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	equipment_replacement_overlay.visible = false
	add_child(equipment_replacement_overlay)

	equipment_replacement_panel = Panel.new()
	equipment_replacement_panel.add_theme_stylebox_override("panel", Art.flat_panel_style())
	equipment_replacement_overlay.add_child(equipment_replacement_panel)

	equipment_replacement_title = Label.new()
	equipment_replacement_title.text = "获得同部位装备"
	equipment_replacement_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equipment_replacement_title.add_theme_font_size_override("font_size", 24)
	equipment_replacement_title.add_theme_color_override("font_color", Art.INK)
	equipment_replacement_panel.add_child(equipment_replacement_title)

	equipment_replacement_current_icon = TextureRect.new()
	equipment_replacement_current_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	equipment_replacement_current_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	equipment_replacement_panel.add_child(equipment_replacement_current_icon)

	equipment_replacement_new_icon = TextureRect.new()
	equipment_replacement_new_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	equipment_replacement_new_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	equipment_replacement_panel.add_child(equipment_replacement_new_icon)

	equipment_recommendation_badge = Panel.new()
	equipment_recommendation_badge.name = "EquipmentRecommendationBadge"
	equipment_recommendation_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	equipment_recommendation_badge.visible = false
	equipment_replacement_panel.add_child(equipment_recommendation_badge)
	equipment_recommendation_label = Label.new()
	equipment_recommendation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equipment_recommendation_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	equipment_recommendation_label.add_theme_font_size_override("font_size", 14)
	equipment_recommendation_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	equipment_recommendation_badge.add_child(equipment_recommendation_label)

	equipment_replacement_current_label = Label.new()
	equipment_replacement_current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equipment_replacement_current_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	equipment_replacement_current_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	equipment_replacement_current_label.add_theme_font_size_override("font_size", 16)
	equipment_replacement_current_label.add_theme_color_override("font_color", Art.INK_SOFT)
	equipment_replacement_panel.add_child(equipment_replacement_current_label)

	equipment_replacement_new_label = Label.new()
	equipment_replacement_new_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equipment_replacement_new_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	equipment_replacement_new_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	equipment_replacement_new_label.add_theme_font_size_override("font_size", 16)
	equipment_replacement_new_label.add_theme_color_override("font_color", Color("#8d5b13"))
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
			label.add_theme_color_override("font_color", Art.INK_SOFT)
			player_info_equipment_slots[index].tooltip_text = "点击查看装备"
		else:
			icon.texture = load(str(item["icon"])) as Texture2D
			label.text = "%s\n%s" % [item["name"], item["description"]]
			label.add_theme_color_override("font_color", Color(str(item.get("quality_color", "#f8fafc"))))
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
	_set_equipment_recommendation(int(next.get("quality", 1)) - int(current.get("quality", 1)))
	equipment_replacement_current_label.text = "当前装备\n%s\n%s" % [current["name"], current["description"]]
	equipment_replacement_new_label.text = "新装备\n%s\n%s" % [next["name"], next["description"]]
	equipment_detail_overlay.visible = false
	equipment_replacement_overlay.visible = true

func hide_equipment_replacement() -> void:
	if equipment_replacement_overlay:
		equipment_replacement_overlay.visible = false
	if equipment_recommendation_badge:
		equipment_recommendation_badge.visible = false

func _set_equipment_recommendation(quality_difference: int) -> void:
	if equipment_recommendation_badge == null or equipment_recommendation_label == null:
		return
	var badge_text := "一般"
	var background_color := Color("#e5e7eb")
	var border_color := Color("#6b7280")
	var text_color := Color("#4b5563")
	if quality_difference > 0:
		badge_text = "推荐"
		background_color = Color("#dcfce7")
		border_color = Color("#16a34a")
		text_color = Color("#166534")
	elif quality_difference < 0:
		badge_text = "不推荐"
		background_color = Color("#fee2e2")
		border_color = Color("#dc2626")
		text_color = Color("#b91c1c")
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	equipment_recommendation_badge.add_theme_stylebox_override("panel", style)
	equipment_recommendation_label.text = badge_text
	equipment_recommendation_label.add_theme_color_override("font_color", text_color)
	equipment_recommendation_badge.visible = true

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
	card_event_overlay.color = ui_config.overlay_color
	card_event_overlay.position = Vector2.ZERO
	card_event_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	card_event_overlay.visible = false
	add_child(card_event_overlay)

	card_event_panel = Panel.new()
	card_event_panel.add_theme_stylebox_override("panel", Art.flat_panel_style(Art.POPUP_BACKGROUND_ALT, Art.POPUP_ACCENT))
	card_event_overlay.add_child(card_event_panel)

	card_event_title = Label.new()
	card_event_title.text = "随机事件 · 翻卡"
	card_event_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_event_title.add_theme_font_size_override("font_size", 26)
	card_event_title.add_theme_color_override("font_color", Art.INK)
	card_event_panel.add_child(card_event_title)

	card_event_card = Label.new()
	card_event_card.text = "抽卡中..."
	card_event_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_event_card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_event_card.add_theme_font_size_override("font_size", 31)
	card_event_card.add_theme_color_override("font_color", Color("#fbbf24"))
	card_event_panel.add_child(card_event_card)

	card_draw_result_icon = MerchantCardIconScript.new()
	card_draw_result_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_draw_result_icon.visible = false
	card_event_panel.add_child(card_draw_result_icon)


	card_event_detail = Label.new()
	card_event_detail.text = "卡片正在滚动"
	card_event_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_event_detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_event_detail.add_theme_font_size_override("font_size", 17)
	card_event_detail.add_theme_color_override("font_color", Art.INK_SOFT)
	card_event_panel.add_child(card_event_detail)

	card_draw_confirm_button = Button.new()
	card_draw_confirm_button.text = "确认"
	card_draw_confirm_button.visible = false
	card_draw_confirm_button.focus_mode = Control.FOCUS_ALL
	Art.apply_flat_button(card_draw_confirm_button, Art.POPUP_ACCENT)
	card_draw_confirm_button.pressed.connect(_confirm_card_draw)
	card_event_panel.add_child(card_draw_confirm_button)

	card_draw_countdown_label = Label.new()
	card_draw_countdown_label.text = "2秒后自动关闭"
	card_draw_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	card_draw_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_draw_countdown_label.add_theme_font_size_override("font_size", 16)
	card_draw_countdown_label.add_theme_color_override("font_color", Art.INK_SOFT)
	card_draw_countdown_label.visible = false
	card_event_panel.add_child(card_draw_countdown_label)


func _build_divination_panel() -> void:
	var divination_scene := preload("res://DivinationUI.tscn")
	var divination_ui: Control = divination_scene.instantiate()
	divination_ui.name = "DivinationOverlay"
	divination_ui.visible = false
	add_child(divination_ui)
	divination_root = divination_ui
	divination_overlay = divination_ui.get_node("DivinationOverlay") as ColorRect
	divination_overlay.color = ui_config.modal_overlay_color
	divination_panel = divination_ui.get_node("DivinationHouse") as Panel
	# The supplied artwork is the complete visual surface; do not add the
	# programmatic popup panel background behind it.
	divination_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	divination_title = divination_ui.get_node("DivinationHouse/DivinationTitle") as Label
	divination_title.visible = false
	divination_target = divination_ui.get_node("DivinationHouse/DivinationTarget") as Label
	divination_target.visible = false
	divination_target_text = divination_ui.get_node("DivinationHouse/DivinationTargetText") as Label
	divination_target_display = divination_ui.get_node("DivinationHouse/DivinationTargetDisplay") as DivinationTargetDisplay
	divination_target_display.visible = false
	divination_house_art = divination_ui.get_node("DivinationHouse/DivinationHouseArt") as Control
	divination_event_object = divination_ui.get_node("DivinationHouse/DivinationEventObject") as TextureRect
	divination_event_object.visible = false
	divination_crystal_effect = divination_ui.get_node("DivinationHouse/DivinationCrystalEffect") as DivinationCrystalEffect
	divination_desktop_event_icons = divination_ui.get_node("DivinationHouse/EventIcons") as Control
	divination_desktop_event_icons.visible = false
	divination_start_button = divination_ui.get_node("DivinationHouse/DivinationStartButton") as Button
	divination_start_button.pressed.connect(_on_divination_start_pressed)
	divination_bubble = divination_ui.get_node("DivinationHouse/DivinationBubble") as TextureRect
	divination_close_button = divination_ui.get_node("DivinationHouse/DivinationCloseButton") as TextureButton
	divination_close_button.pressed.connect(_close_divination_ui)
	divination_event_text = divination_ui.get_node("DivinationHouse/DivinationEventText") as Label
	divination_event_icons.clear()
	for icon_name in ["Card", "Barracks", "Loss", "Gold", "Rise", "Fall"]:
		divination_event_icons.append(divination_ui.get_node("DivinationHouse/EventIcon%s" % icon_name) as Label)
	divination_event_highlight = divination_ui.get_node("DivinationHouse/DivinationEventHighlight") as DivinationEventHighlight
	divination_event_highlight.clear_active()
	divination_event_label = divination_ui.get_node("DivinationHouse/DivinationEventLabel") as Label
	divination_event_label.visible = false
	divination_result = divination_ui.get_node_or_null("DivinationHouse/DivinationResult") as Label
	# The result is shown only in the second line of the authored bubble.
	# Keep compatibility with older scenes that still contain this extra label,
	# but never create or display a separate final-result line.
	if divination_result != null:
		divination_result.text = ""
		divination_result.visible = false

func _build_intelligence_news_panel() -> void:
	intelligence_news_overlay = ColorRect.new()
	intelligence_news_overlay.name = "IntelligenceNewsOverlay"
	intelligence_news_overlay.color = ui_config.modal_overlay_color
	intelligence_news_overlay.position = Vector2.ZERO
	intelligence_news_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	intelligence_news_overlay.visible = false
	add_child(intelligence_news_overlay)

	intelligence_news_panel = Panel.new()
	intelligence_news_panel.name = "IntelligenceNewsPaper"
	intelligence_news_panel.add_theme_stylebox_override("panel", Art.flat_panel_style())
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
	_layout_broadcast_banner_content()
	if world_broadcast_remaining > 0.0 and not world_broadcast_message.is_empty():
		bombardment_banner_label.text = "%s的占卜：" % world_broadcast_name if world_broadcast_target_faction >= 0 else world_broadcast_message
		bombardment_banner.visible = true
	elif not bombardment_banner_message.is_empty():
		bombardment_banner_label.text = bombardment_banner_message
		bombardment_banner.visible = true
	else:
		bombardment_banner.visible = false

func _layout_broadcast_banner_content() -> void:
	if bombardment_banner == null or bombardment_banner_label == null:
		return
	var has_avatar := world_broadcast_faction >= 0
	var is_divination := world_broadcast_target_faction >= 0
	if broadcast_faction_avatar != null:
		broadcast_faction_avatar.visible = has_avatar
		if has_avatar:
			broadcast_faction_avatar.position = Vector2(9.0, 7.0)
			broadcast_faction_avatar.size = Vector2(32.0, 32.0)
			broadcast_faction_avatar.call("setup", world_broadcast_faction)
	if broadcast_target_avatar != null:
		broadcast_target_avatar.visible = is_divination
		if is_divination:
			broadcast_target_avatar.position = Vector2(205.0, 7.0)
			broadcast_target_avatar.size = Vector2(32.0, 32.0)
			broadcast_target_avatar.call("setup", world_broadcast_target_faction)
	if broadcast_target_label != null:
		broadcast_target_label.visible = is_divination
		if is_divination:
			broadcast_target_label.position = Vector2(244.0, 0.0)
			broadcast_target_label.size = Vector2(maxf(0.0, bombardment_banner.size.x - 252.0), bombardment_banner.size.y)
			broadcast_target_label.text = "%s %s" % [world_broadcast_target_name, world_broadcast_message]
	if has_avatar:
		bombardment_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		bombardment_banner_label.position = Vector2(50.0, 0.0)
		bombardment_banner_label.size = Vector2(150.0 if is_divination else maxf(0.0, bombardment_banner.size.x - 62.0), bombardment_banner.size.y)
		if not is_divination:
			bombardment_banner_label.text = world_broadcast_message
	else:
		bombardment_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bombardment_banner_label.position = Vector2(12.0, 0.0)
		bombardment_banner_label.size = Vector2(maxf(0.0, bombardment_banner.size.x - 24.0), bombardment_banner.size.y)

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
		card_event_title.text = "随机事件 · 获得卡片"
		card_draw_result_icon.call("setup_card", drawn_id)
		card_draw_result_icon.visible = true
		card_event_card.text = str(drawn_item.get("name", "未知卡片"))
		card_event_detail.text = str(drawn_item.get("description", ""))
		_set_card_draw_result_layout(true)
		card_draw_countdown_remaining = Config.QUESTION_CARD_RESULT_DURATION
		card_draw_confirm_button.visible = true
		card_draw_countdown_label.visible = true
		_update_card_draw_countdown_label()
		return
	_set_card_draw_result_layout(false)
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
	if card_event_tween != null and card_event_tween.is_valid():
		card_event_tween.kill()
	var owner := int(card_event_current.get("owner", 1))
	var card_id := str(card_event_current.get("card_id", ""))
	var fate_cell: Vector2i = card_event_current.get("fate_cell", Vector2i(999, 999))
	card_draw_countdown_remaining = 0.0
	card_draw_confirm_button.visible = false
	card_draw_countdown_label.visible = false
	card_draw_finished.emit(owner, card_id, fate_cell)
	card_event_current = {}
	card_event_running = false
	_start_next_card_event()

func _confirm_card_draw() -> void:
	if not card_event_running or card_event_current.is_empty():
		return
	if not bool(card_event_current.get("is_card_draw", false)):
		return
	_finish_card_draw()

func _update_card_draw_countdown_label() -> void:
	if card_draw_countdown_label == null:
		return
	var seconds_left := maxi(0, int(ceil(card_draw_countdown_remaining)))
	card_draw_countdown_label.text = "%d秒后自动关闭" % seconds_left

func _set_card_draw_result_layout(active: bool) -> void:
	if card_draw_result_icon == null or card_event_panel == null:
		return
	card_draw_result_icon.visible = active
	if active:
		var card_width := card_event_panel.size.x
		card_draw_result_icon.position = Vector2((card_width - 112.0) * 0.5, 92.0)
		card_draw_result_icon.size = Vector2(112.0, 132.0)
		card_event_card.position = Vector2(24.0, 224.0)
		card_event_card.size = Vector2(card_width - 48.0, 52.0)
		card_event_detail.position = Vector2(34.0, 292.0)
		card_event_detail.size = Vector2(card_width - 68.0, 110.0)
		var confirm_rect := _ui_rect("card_draw_confirm_button_rect", Rect2(card_width * 0.5 - 112.0, 420.0, 126.0, 42.0))
		card_draw_confirm_button.position = confirm_rect.position
		card_draw_confirm_button.size = confirm_rect.size
		var countdown_rect := _ui_rect("card_draw_countdown_rect", Rect2(card_width * 0.5 + 30.0, 426.0, 150.0, 30.0))
		card_draw_countdown_label.position = countdown_rect.position
		card_draw_countdown_label.size = countdown_rect.size
	else:
		var card_width := card_event_panel.size.x
		card_event_card.position = Vector2(24.0, 132.0)
		card_event_card.size = Vector2(card_width - 48.0, 150.0)
		card_event_detail.position = Vector2(24.0, 310.0)
		card_event_detail.size = Vector2(card_width - 48.0, 48.0)
		card_draw_confirm_button.visible = false
		card_draw_countdown_label.visible = false

func clear_card_events() -> void:
	if card_event_tween != null and card_event_tween.is_valid():
		card_event_tween.kill()
	card_event_queue.clear()
	card_event_current = {}
	card_event_running = false
	card_draw_countdown_remaining = 0.0
	if card_draw_confirm_button:
		card_draw_confirm_button.visible = false
	if card_draw_countdown_label:
		card_draw_countdown_label.visible = false
	if card_draw_result_icon:
		card_draw_result_icon.visible = false
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
	if card_hint_panel != null and card_hint_panel.visible:
		card_hint_panel.position = (viewport_size - card_hint_panel.size) * 0.5
	if camera_guide_layer != null:
		camera_guide_layer.size = viewport_size
		var guide_rect := Rect2(42.0, 184.0, maxf(1.0, viewport_size.x - 84.0), maxf(1.0, viewport_size.y - 266.0))
		enemy_camera_guide.size = viewport_size
		player_camera_guide.size = viewport_size
		enemy_camera_guide.call("configure_safe_rect", guide_rect)
		player_camera_guide.call("configure_safe_rect", guide_rect)
	var player_info_button_rect := _ui_rect("player_info_button_rect", Rect2(16.0, 78.0, 48.0, 48.0))
	var authored_rect := _authored_hud_rect("PlayerInfoButton", player_info_button_rect)
	player_info_button.position = authored_rect.position
	player_info_button.size = authored_rect.size
	player_info_button.visible = viewport_size.x >= 150.0
	player_info_title.position = Vector2(28, 20)
	var info_close_rect := _ui_rect("player_info_close_button_rect", Rect2(-94.0, 18.0, 70.0, 34.0))
	var info_size := _ui_panel_size("player_info_panel_size", Vector2(600.0, 760.0), 0.86, 0.68)
	var info_width := info_size.x
	var info_height := info_size.y
	player_info_panel.size = Vector2(info_width, info_height)
	player_info_panel.position = _centered_ui_position(info_size, "player_info_panel_offset")
	player_info_title.position = Vector2(28, 20)
	player_info_close_button.position = Vector2(info_width + info_close_rect.position.x, info_close_rect.position.y)
	player_info_close_button.size = info_close_rect.size
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
	var detail_size := _ui_panel_size("equipment_detail_panel_size", Vector2(600.0, 360.0), 0.86, 0.80)
	var detail_width := detail_size.x
	equipment_detail_panel.size = detail_size
	equipment_detail_panel.position = _centered_ui_position(detail_size, "equipment_detail_panel_offset")
	equipment_detail_title.position = Vector2(24, 22)
	equipment_detail_title.size = Vector2(detail_width - 48, 42)
	equipment_detail_icon.position = Vector2((detail_width - 96.0) * 0.5, 78)
	equipment_detail_icon.size = Vector2(96, 96)
	equipment_detail_info.position = Vector2(30, 184)
	equipment_detail_info.size = Vector2(detail_width - 60, 82)
	var detail_close_rect := _ui_rect("equipment_detail_close_button_rect", Rect2(0.0, 294.0, 120.0, 40.0))
	equipment_detail_close_button.position = Vector2((detail_width - detail_close_rect.size.x) * 0.5 + detail_close_rect.position.x, detail_close_rect.position.y)
	equipment_detail_close_button.size = detail_close_rect.size
	var replacement_size := _ui_panel_size("equipment_replacement_panel_size", Vector2(640.0, 450.0), 0.90, 0.82)
	var replacement_width := replacement_size.x
	equipment_replacement_panel.size = replacement_size
	equipment_replacement_panel.position = _centered_ui_position(replacement_size, "equipment_replacement_panel_offset")
	equipment_replacement_title.position = Vector2(24, 20)
	equipment_replacement_title.size = Vector2(replacement_width - 48, 42)
	var replacement_column_width := (replacement_width - 72.0) * 0.5
	equipment_replacement_current_icon.position = Vector2(24 + (replacement_column_width - 88.0) * 0.5, 82)
	equipment_replacement_current_icon.size = Vector2(88, 88)
	equipment_replacement_new_icon.position = Vector2(48 + replacement_column_width + (replacement_column_width - 88.0) * 0.5, 82)
	equipment_replacement_new_icon.size = Vector2(88, 88)
	if equipment_recommendation_badge != null:
		var recommendation_size := Vector2(76.0, 28.0)
		equipment_recommendation_badge.position = equipment_replacement_new_icon.position + Vector2(equipment_replacement_new_icon.size.x - recommendation_size.x + 12.0, -8.0)
		equipment_recommendation_badge.size = recommendation_size
		equipment_recommendation_label.position = Vector2.ZERO
		equipment_recommendation_label.size = recommendation_size
	equipment_replacement_current_label.position = Vector2(24, 180)
	equipment_replacement_current_label.size = Vector2(replacement_column_width, 116)
	equipment_replacement_new_label.position = Vector2(48 + replacement_column_width, 180)
	equipment_replacement_new_label.size = Vector2(replacement_column_width, 116)
	var replace_rect := _ui_rect("equipment_replace_button_rect", Rect2(-146.0, 370.0, 120.0, 42.0))
	equipment_replace_button.position = Vector2(replacement_width * 0.5 + replace_rect.position.x, replace_rect.position.y)
	equipment_replace_button.size = replace_rect.size
	var discard_rect := _ui_rect("equipment_discard_button_rect", Rect2(26.0, 370.0, 120.0, 42.0))
	equipment_discard_button.position = Vector2(replacement_width * 0.5 + discard_rect.position.x, discard_rect.position.y)
	equipment_discard_button.size = discard_rect.size
	card_event_overlay.size = viewport_size
	var card_size := _ui_panel_size("card_event_panel_size", Vector2(580.0, 520.0), 0.84, 0.60)
	var card_width := card_size.x
	var card_height := card_size.y
	card_event_panel.size = Vector2(card_width, card_height)
	card_event_panel.position = _centered_ui_position(card_size, "card_event_panel_offset")
	card_event_title.position = Vector2(24, 32)
	card_event_title.size = Vector2(card_width - 48, 48)
	card_event_card.position = Vector2(24, 132)
	card_event_card.size = Vector2(card_width - 48, 150)
	card_draw_result_icon.position = Vector2((card_width - 112.0) * 0.5, 92.0)
	card_draw_result_icon.size = Vector2(112.0, 132.0)
	card_draw_result_icon.visible = bool(card_event_current.get("is_card_draw", false))
	if card_draw_result_icon.visible:
		_set_card_draw_result_layout(true)
	else:
		card_event_detail.position = Vector2(24, 310)
		card_event_detail.size = Vector2(card_width - 48, 48)
	if card_draw_confirm_button != null:
		var confirm_rect := _ui_rect("card_draw_confirm_button_rect", Rect2(card_width * 0.5 - 112.0, 420.0, 126.0, 42.0))
		card_draw_confirm_button.position = confirm_rect.position
		card_draw_confirm_button.size = confirm_rect.size
		card_draw_confirm_button.visible = card_draw_result_icon.visible
		var countdown_rect := _ui_rect("card_draw_countdown_rect", Rect2(card_width * 0.5 + 30.0, 426.0, 150.0, 30.0))
		card_draw_countdown_label.position = countdown_rect.position
		card_draw_countdown_label.size = countdown_rect.size
		card_draw_countdown_label.visible = card_draw_result_icon.visible
		if card_draw_result_icon.visible:
			_update_card_draw_countdown_label()
	divination_overlay.size = viewport_size
	# The authored divination art is square. Keep the panel and its background
	# on one uniform scale so a short viewport never squashes the artwork.
	var divination_size := _ui_square_panel_size("divination_panel_size", Vector2(620.0, 620.0), 0.88, 0.88)
	var divination_width := divination_size.x
	var divination_height := divination_size.y
	divination_panel.size = divination_size
	divination_panel.position = _centered_ui_position(divination_size, "divination_panel_offset")
	intelligence_news_overlay.size = viewport_size
	var news_size := _ui_panel_size("intelligence_panel_size", Vector2(620.0, 380.0), 0.88, 0.50)
	var news_width := news_size.x
	var news_height := news_size.y
	intelligence_news_panel.size = Vector2(news_width, news_height)
	intelligence_news_panel.position = _centered_ui_position(news_size, "intelligence_panel_offset")
	intelligence_news_kicker.position = Vector2(24, 20)
	intelligence_news_kicker.size = Vector2(news_width - 48, 28)
	intelligence_news_title.position = Vector2(24, 64)
	intelligence_news_title.size = Vector2(news_width - 48, 56)
	intelligence_news_content.position = Vector2(34, 134)
	intelligence_news_content.size = Vector2(news_width - 68, news_height - 192)
	intelligence_news_footer.position = Vector2(24, news_height - 42)
	intelligence_news_footer.size = Vector2(news_width - 48, 24)
	if merchant_shop_overlay != null:
		merchant_shop_overlay.size = viewport_size
		var shop_size := _ui_square_panel_size("merchant_shop_panel_size", Vector2(660.0, 660.0), 0.94, 0.88)
		merchant_shop_panel.size = shop_size
		merchant_shop_panel.position = _centered_ui_position(shop_size, "merchant_shop_panel_offset")
	if merchant_arrival_overlay != null:
		merchant_arrival_overlay.size = viewport_size
	var arrival_size := _ui_panel_size("merchant_arrival_panel_size", Vector2(620.0, 480.0), 0.88, 0.58)
	var arrival_width := arrival_size.x
	var arrival_height := arrival_size.y
	merchant_arrival_panel.size = arrival_size
	merchant_arrival_panel.position = _centered_ui_position(arrival_size, "merchant_arrival_panel_offset")
	merchant_arrival_title.position = Vector2(24.0, 24.0)
	merchant_arrival_title.size = Vector2(arrival_width - 48.0, 42.0)
	merchant_arrival_hint.position = Vector2(24.0, 68.0)
	merchant_arrival_hint.size = Vector2(arrival_width - 48.0, 28.0)
	merchant_arrival_art.position = Vector2((arrival_width - 180.0) * 0.5, 92.0)
	merchant_arrival_art.size = Vector2(180.0, 132.0)
	for card_icon in merchant_arrival_cards:
		card_icon.size = Vector2(82.0, 108.0)
	var authored_player_button_rect := _authored_hud_rect("PlayerInfoButton", player_info_button_rect)
	player_info_button.position = authored_player_button_rect.position
	player_info_button.size = authored_player_button_rect.size
	if bottom_status_panel != null:
		var bottom_rect := _ui_rect("bottom_status_rect", Rect2(16.0, -78.0, 310.0, 62.0))
		bottom_status_panel.position = Vector2(bottom_rect.position.x, viewport_size.y + bottom_rect.position.y)
		bottom_status_panel.size = Vector2(maxf(1.0, minf(bottom_rect.size.x, viewport_size.x - 32.0)), bottom_rect.size.y)
	if gold_panel != null:
		# Keep the authored scene position and size; edit them directly in
		# BattleHUDPreview.tscn without this runtime HUD recreating the node.
		gold_panel.z_index = 0
	var gold_icon_rect := _authored_hud_rect("GoldIcon", _ui_rect("gold_icon_rect", Rect2(16.0, 14.0, 28.0, 28.0)))
	gold_icon.position = gold_icon_rect.position
	gold_icon.size = gold_icon_rect.size
	if player_avatar != null:
		var player_avatar_rect := _authored_hud_rect("PlayerAvatar", Rect2(16.0, 52.0, 48.0, 48.0))
		player_avatar.position = player_avatar_rect.position
		player_avatar.size = player_avatar_rect.size
	if player_name_label != null:
		var player_name_rect := _authored_hud_rect("PlayerNameLabel", Rect2(16.0, 4.0, 120.0, 24.0))
		player_name_label.position = player_name_rect.position
		player_name_label.size = player_name_rect.size
	if player_summary != null:
		var player_summary_rect := _authored_hud_rect("PlayerSummary", Rect2(138.0, 21.0, 120.0, 48.0))
		player_summary.position = player_summary_rect.position
		player_summary.size = player_summary_rect.size
	var gold_label_rect := _authored_hud_rect("GoldLabel", _ui_rect("gold_label_rect", Rect2(48.0, 14.0, 118.0, 34.0)))
	stats_label.position = gold_label_rect.position
	stats_label.size = gold_label_rect.size
	var fps_rect := _authored_hud_rect("FpsLabel", _ui_rect("fps_label_rect", Rect2(16.0, 120.0, 100.0, 24.0)))
	fps_label.position = fps_rect.position
	fps_label.size = fps_rect.size
	var status_rect := _authored_hud_rect("StatusLabel", _ui_rect("status_label_rect", Rect2(-430.0, 14.0, 414.0, 34.0)))
	status_label.position = status_rect.position
	status_label.size = status_rect.size
	var army_rect := _authored_hud_rect("ArmyLabel", _ui_rect("army_label_rect", Rect2(-430.0, 45.0, 414.0, 26.0)))
	army_label.position = army_rect.position
	army_label.size = army_rect.size
	if faction_stats_display != null:
		var faction_stats_size := Vector2(
			maxf(ui_config.faction_stats_minimum_size.x, ui_config.faction_stats_size.x),
			maxf(ui_config.faction_stats_minimum_size.y, ui_config.faction_stats_size.y)
		)
		var faction_stats_position := ui_config.faction_stats_position
		if authored_faction_stats_layout.has("root"):
			var authored_root: Rect2 = authored_faction_stats_layout["root"]
			faction_stats_size = authored_root.size
			# The preview is authored at 720px wide. Preserve its right/top
			# anchoring when the actual phone viewport has another width.
			faction_stats_position = Vector2(authored_root.position.x + authored_root.size.x - 720.0, authored_root.position.y)
		faction_stats_display.size = faction_stats_size
		faction_stats_display.position = Vector2(
			maxf(8.0, viewport_size.x - faction_stats_display.size.x + faction_stats_position.x),
			maxf(0.0, faction_stats_position.y)
		)
	var hq_rect := _authored_hud_rect("HQHealthBar", _ui_rect("hq_health_bar_rect", Rect2(16.0, 50.0, 142.0, 10.0)))
	hq_health_bar.position = hq_rect.position
	hq_health_bar.size = hq_rect.size
	building_damage_edge_soft.position = Vector2.ZERO
	building_damage_edge_soft.size = viewport_size
	building_damage_edge.position = Vector2.ZERO
	building_damage_edge.size = viewport_size
	var timer_rect := _authored_hud_rect("TimerLabel", _ui_rect("timer_rect", Rect2(120.0, 62.0, -240.0, 42.0)))
	timer_label.position = timer_rect.position
	timer_label.size = timer_rect.size if timer_rect.size.x > 0.0 else Vector2(maxf(1.0, viewport_size.x + timer_rect.size.x - timer_rect.position.x), timer_rect.size.y)
	var banner_rect := _authored_hud_rect("BroadcastPanel", _ui_rect("broadcast_rect", Rect2(0.0, 110.0, 560.0, 46.0)))
	var banner_width := maxf(1.0, minf(banner_rect.size.x, viewport_size.x - 32.0))
	bombardment_banner.position = banner_rect.position if authored_hud_layout.has("BroadcastPanel") else Vector2((viewport_size.x - banner_width) * 0.5 + banner_rect.position.x, banner_rect.position.y)
	bombardment_banner.size = Vector2(banner_width, banner_rect.size.y)
	_layout_broadcast_banner_content()
	if bottom_status_panel != null and authored_hud_layout.has("BottomStatusPanel"):
		var authored_bottom := _authored_hud_rect("BottomStatusPanel", Rect2())
		bottom_status_panel.position = authored_bottom.position
		bottom_status_panel.size = authored_bottom.size
		if has_node("BottomStatusLabel"):
			var authored_bottom_label := _authored_hud_rect("BottomStatusLabel", Rect2())
			var bottom_label := get_node("BottomStatusLabel") as Control
			bottom_label.position = authored_bottom_label.position
			bottom_label.size = authored_bottom_label.size
	var hint_rect := _ui_rect("hint_rect", Rect2(20.0, -220.0, 420.0, PERSONAL_HINT_LINE_HEIGHT * PERSONAL_HINT_VISIBLE_LINES))
	hint_container.position = Vector2(hint_rect.position.x, maxf(150.0, viewport_size.y + hint_rect.position.y))
	hint_container.size = Vector2(minf(hint_rect.size.x, maxf(1.0, viewport_size.x - 300.0)), hint_rect.size.y)
	for line in hint_container.get_children():
		line.size = Vector2(hint_container.size.x, PERSONAL_HINT_LINE_HEIGHT)
	var defeat_size := _ui_panel_size("defeat_panel_size", Vector2(620.0, 280.0), 0.90, 0.50)
	end_panel.size = defeat_size
	end_panel.position = _centered_ui_position(defeat_size, "defeat_panel_offset")
	if watch_mode_button != null:
		var watch_rect := _ui_rect("watch_button_rect", Rect2(12.0, -58.0, 148.0, 42.0))
		watch_mode_button.position = Vector2(watch_rect.position.x, maxf(8.0, viewport_size.y + watch_rect.position.y))
		watch_mode_button.size = watch_rect.size
	if cat_companion != null:
		cat_companion.size = Vector2(viewport_size.x, 340.0)
		cat_companion.position = Vector2.ZERO
		cat_companion.position.y = maxf(8.0, viewport_size.y - 348.0)
		cat_companion.set_viewport_size(viewport_size)
	if settlement_ui != null:
		settlement_ui.call("set_viewport_size", viewport_size)
	_restore_authored_control_layout()
	if faction_stats_display != null:
		var authored_stats_rect := _authored_hud_rect("FactionStatsDisplay", Rect2(faction_stats_display.position, faction_stats_display.size))
		faction_stats_display.position.x = authored_stats_rect.position.x + FACTION_STATS_RUNTIME_X_OFFSET
	update_camera_guides()

func _apply_battle_hud_style() -> void:
	if ui_config == null or stats_label == null:
		return
	stats_label.add_theme_font_size_override("font_size", ui_config.battle_gold_font_size)
	stats_label.add_theme_color_override("font_color", ui_config.battle_text_color)
	stats_label.add_theme_color_override("font_outline_color", ui_config.battle_text_outline_color)
	fps_label.add_theme_font_size_override("font_size", ui_config.battle_fps_font_size)
	fps_label.add_theme_color_override("font_outline_color", ui_config.battle_text_outline_color)
	status_label.add_theme_font_size_override("font_size", ui_config.battle_status_font_size)
	status_label.add_theme_color_override("font_color", ui_config.battle_text_color)
	status_label.add_theme_color_override("font_outline_color", ui_config.battle_text_outline_color)
	army_label.add_theme_font_size_override("font_size", ui_config.battle_army_font_size)
	army_label.add_theme_color_override("font_color", ui_config.battle_secondary_text_color)
	army_label.add_theme_color_override("font_outline_color", ui_config.battle_text_outline_color)
	timer_label.add_theme_font_size_override("font_size", ui_config.battle_timer_font_size)
	timer_label.add_theme_color_override("font_color", ui_config.battle_timer_color)
	timer_label.add_theme_color_override("font_outline_color", ui_config.battle_timer_outline_color)
	bombardment_banner.color = ui_config.battle_broadcast_color
	bombardment_banner_label.add_theme_font_size_override("font_size", ui_config.battle_broadcast_font_size)
	bombardment_banner_label.add_theme_color_override("font_color", ui_config.battle_broadcast_text_color)
	var hq_background := StyleBoxFlat.new()
	hq_background.bg_color = ui_config.battle_hq_health_background_color
	hq_background.set_corner_radius_all(5)
	var hq_fill := StyleBoxFlat.new()
	hq_fill.bg_color = ui_config.battle_hq_health_fill_color
	hq_fill.set_corner_radius_all(5)
	hq_health_bar.add_theme_stylebox_override("background", hq_background)
	hq_health_bar.add_theme_stylebox_override("fill", hq_fill)
	if faction_stats_display != null:
		faction_stats_display.call("configure_ui", ui_config)

func _ui_rect(property_name: String, fallback: Rect2) -> Rect2:
	if ui_config != null:
		var value: Variant = ui_config.get(property_name)
		if value is Rect2:
			return value
	return fallback

func _capture_authored_hud_layout(preview_instance: Node) -> void:
	authored_hud_layout.clear()
	authored_control_layout.clear()
	authored_hud_styles.clear()
	authored_faction_stats_layout.clear()
	for node_name in [
		"GoldPanel", "GoldIcon", "GoldLabel", "FpsLabel", "PlayerInfoButton",
		"PlayerAvatar", "PlayerNameLabel", "PlayerSummary", "HQHealthBar", "TimerLabel", "StatusLabel", "ArmyLabel", "FactionStatsDisplay",
		"BroadcastPanel", "BottomStatusPanel", "BottomStatusLabel"
	]:
		var node := preview_instance.get_node_or_null(NodePath(node_name)) as Control
		if node != null:
			authored_hud_layout[node_name] = Rect2(node.position, node.size)
			authored_hud_styles[node_name] = node.duplicate()
			_capture_authored_control_layout(node, node_name)
	var broadcast_label := preview_instance.get_node_or_null("BroadcastPanel/BroadcastLabel") as Label
	if broadcast_label != null:
		authored_hud_styles["BroadcastLabel"] = broadcast_label.duplicate()
	var authored_stats := preview_instance.get_node_or_null("FactionStatsAuthoring") as Control
	if authored_stats != null:
		authored_faction_stats_layout["root"] = Rect2(authored_stats.position, authored_stats.size)
		var cards: Dictionary = {}
		for card_name in ["PlayerCard", "RedCard", "PurpleCard", "GreenCard"]:
			var card := authored_stats.get_node_or_null(NodePath(card_name)) as Control
			if card == null:
				continue
			var card_data: Dictionary = {"rect": Rect2(card.position, card.size)}
			for child_name in ["Avatar", "RankIcon", "Name", "TileIcon", "TileCount"]:
				var child := card.get_node_or_null(NodePath(child_name)) as Control
				if child == null:
					continue
				var child_data: Dictionary = {"rect": Rect2(child.position, child.size)}
				if child is TextureRect:
					child_data["texture"] = (child as TextureRect).texture
				card_data[child_name] = child_data
			cards[card_name] = card_data
		authored_faction_stats_layout["cards"] = cards

func _capture_authored_control_layout(node: Control, node_path: String) -> void:
	if node == null:
		return
	authored_control_layout[node_path] = Rect2(node.position, node.size)
	for child in node.get_children():
		var child_control := child as Control
		if child_control == null:
			continue
		_capture_authored_control_layout(child_control, "%s/%s" % [node_path, child_control.name])

func _restore_authored_control_layout() -> void:
	for node_path in authored_control_layout:
		var path_parts := str(node_path).split("/")
		if path_parts.is_empty():
			continue
		var target := _authored_runtime_target(path_parts[0])
		if target == null:
			target = get_node_or_null(NodePath(path_parts[0])) as Control
		for index in range(1, path_parts.size()):
			if target == null:
				break
			target = target.get_node_or_null(NodePath(path_parts[index])) as Control
		if target == null:
			continue
		var authored_rect: Rect2 = authored_control_layout[node_path]
		target.position = authored_rect.position
		target.size = authored_rect.size

func _apply_authored_hud_template(preview_instance: Node) -> void:
	if preview_instance == null:
		return
	for source_child in preview_instance.get_children():
		var source_control := source_child as Control
		if source_control == null or source_control.name in ["Backdrop", "FactionStatsAuthoring", "FactionStatsDisplay"]:
			if source_control != null and source_control.name == "Backdrop":
				_copy_authored_extra_children(source_control, self)
			if source_control != null and source_control.name == "FactionStatsAuthoring":
				_copy_authored_extra_children(source_control, self, source_control.position)
			continue
		var target := _authored_runtime_target(source_control.name)
		if target == null:
			if get_node_or_null(NodePath(source_control.name)) == null:
				add_child(source_control.duplicate())
			continue
		_copy_authored_control(source_control, target)
		_copy_authored_extra_children(source_control, target)

func _authored_runtime_target(node_name: String) -> Control:
	match node_name:
		"GoldPanel": return gold_panel
		"GoldIcon": return gold_icon
		"GoldLabel": return stats_label
		"FpsLabel": return fps_label
		"PlayerInfoButton": return player_info_button
		"PlayerAvatar": return player_avatar
		"PlayerNameLabel": return player_name_label
		"PlayerSummary": return player_summary
		"HQHealthBar": return hq_health_bar
		"TimerLabel": return timer_label
		"StatusLabel": return status_label
		"ArmyLabel": return army_label
		"FactionStatsDisplay": return faction_stats_display
		"BroadcastPanel": return bombardment_banner
		"BottomStatusPanel": return bottom_status_panel
		_: return null

func _copy_authored_control(source: Control, target: Control) -> void:
	if source == null or target == null:
		return
	target.position = source.position
	target.size = source.size
	target.anchor_left = source.anchor_left
	target.anchor_top = source.anchor_top
	target.anchor_right = source.anchor_right
	target.anchor_bottom = source.anchor_bottom
	target.offset_left = source.offset_left
	target.offset_top = source.offset_top
	target.offset_right = source.offset_right
	target.offset_bottom = source.offset_bottom
	target.pivot_offset = source.pivot_offset
	target.scale = source.scale
	target.rotation = source.rotation
	target.modulate = source.modulate
	target.self_modulate = source.self_modulate
	target.z_index = source.z_index
	target.mouse_filter = source.mouse_filter
	target.clip_contents = source.clip_contents
	target.visible = source.visible
	if source is ColorRect and target is ColorRect:
		(target as ColorRect).color = (source as ColorRect).color
	if source is TextureRect and target is TextureRect:
		var source_texture := (source as TextureRect).texture
		if source_texture != null:
			(target as TextureRect).texture = source_texture
		(target as TextureRect).expand_mode = (source as TextureRect).expand_mode
		(target as TextureRect).stretch_mode = (source as TextureRect).stretch_mode
	if source is Label and target is Label:
		(target as Label).text = (source as Label).text
		(target as Label).horizontal_alignment = (source as Label).horizontal_alignment
		(target as Label).vertical_alignment = (source as Label).vertical_alignment
		(target as Label).autowrap_mode = (source as Label).autowrap_mode
	if source is Button and target is Button:
		(target as Button).text = (source as Button).text
		(target as Button).icon = (source as Button).icon
		(target as Button).expand_icon = (source as Button).expand_icon
	_copy_authored_theme_overrides(source, target)

func _copy_authored_theme_overrides(source: Control, target: Control) -> void:
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_outline_color"]:
		if source.has_theme_color_override(color_name):
			target.add_theme_color_override(color_name, source.get_theme_color(color_name))
	for size_name in ["font_size"]:
		if source.has_theme_font_size_override(size_name):
			target.add_theme_font_size_override(size_name, source.get_theme_font_size(size_name))
	for constant_name in ["outline_size"]:
		if source.has_theme_constant_override(constant_name):
			target.add_theme_constant_override(constant_name, source.get_theme_constant(constant_name))
	for style_name in ["normal", "hover", "pressed", "focus", "disabled", "panel", "background", "fill"]:
		if source.has_theme_stylebox_override(style_name):
			var style := source.get_theme_stylebox(style_name)
			if style != null:
				target.add_theme_stylebox_override(style_name, style.duplicate())

func _copy_authored_extra_children(source_parent: Control, target_parent: Node, position_offset := Vector2.ZERO) -> void:
	if source_parent == null or target_parent == null:
		return
	for source_child in source_parent.get_children():
		var source_control := source_child as Control
		if source_control == null:
			continue
		if source_parent.name == "FactionStatsAuthoring" and source_control.name in ["PlayerCard", "RedCard", "PurpleCard", "GreenCard"]:
			continue
		var target_child := target_parent.get_node_or_null(NodePath(source_control.name)) as Control
		if target_child == null:
			target_child = source_control.duplicate() as Control
			if target_child == null:
				continue
			target_parent.add_child(target_child)
			if position_offset != Vector2.ZERO:
				target_child.position += position_offset
		else:
			_copy_authored_control(source_control, target_child)
		_copy_authored_extra_children(source_control, target_child)

func _authored_hud_rect(node_name: String, fallback: Rect2) -> Rect2:
	if authored_hud_layout.has(node_name):
		return Rect2(authored_hud_layout[node_name])
	return fallback

func _apply_authored_battle_hud_styles() -> void:
	_apply_authored_control_style("PlayerInfoButton", player_info_button)
	_apply_authored_control_style("GoldIcon", gold_icon)
	_apply_authored_control_style("GoldLabel", stats_label)
	_apply_authored_control_style("FpsLabel", fps_label)
	_apply_authored_control_style("TimerLabel", timer_label)
	_apply_authored_control_style("HQHealthBar", hq_health_bar)
	_apply_authored_control_style("BroadcastPanel", bombardment_banner)
	_apply_authored_control_style("BroadcastLabel", bombardment_banner_label)
	_apply_authored_control_style("BottomStatusPanel", bottom_status_panel)
	if authored_hud_styles.has("PlayerInfoButton"):
		var authored_button := authored_hud_styles["PlayerInfoButton"] as Button
		player_info_button.icon = authored_button.icon if authored_button.icon != null else CASTLE_INFO_ICON
		player_info_button.expand_icon = authored_button.expand_icon

func _apply_authored_control_style(node_name: String, target: Control) -> void:
	if target == null or not authored_hud_styles.has(node_name):
		return
	var source := authored_hud_styles[node_name] as Control
	if source == null:
		return
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_outline_color"]:
		if source.has_theme_color_override(color_name):
			target.add_theme_color_override(color_name, source.get_theme_color(color_name))
	for size_name in ["font_size"]:
		if source.has_theme_font_size_override(size_name):
			target.add_theme_font_size_override(size_name, source.get_theme_font_size(size_name))
	for constant_name in ["outline_size"]:
		if source.has_theme_constant_override(constant_name):
			target.add_theme_constant_override(constant_name, source.get_theme_constant(constant_name))
	for style_name in ["normal", "hover", "pressed", "focus", "disabled", "panel", "background", "fill"]:
		if source.has_theme_stylebox_override(style_name):
			var style := source.get_theme_stylebox(style_name)
			if style != null:
				target.add_theme_stylebox_override(style_name, style.duplicate())

func _ui_panel_size(property_name: String, fallback: Vector2, max_width_ratio: float, max_height_ratio: float) -> Vector2:
	var desired := fallback
	if ui_config != null:
		var value: Variant = ui_config.get(property_name)
		if value is Vector2 and value.x > 0.0 and value.y > 0.0:
			desired = value
	return Vector2(
		minf(desired.x, maxf(240.0, viewport_size.x * max_width_ratio)),
		minf(desired.y, maxf(180.0, viewport_size.y * max_height_ratio))
	)

func _ui_square_panel_size(property_name: String, fallback: Vector2, max_width_ratio: float, max_height_ratio: float) -> Vector2:
	var desired := fallback
	if ui_config != null:
		var value: Variant = ui_config.get(property_name)
		if value is Vector2 and value.x > 0.0 and value.y > 0.0:
			desired = value
	var side := minf(desired.x, desired.y)
	side = minf(side, maxf(240.0, viewport_size.x * max_width_ratio))
	side = minf(side, maxf(240.0, viewport_size.y * max_height_ratio))
	return Vector2(side, side)

func _centered_ui_position(panel_size: Vector2, offset_property: String) -> Vector2:
	var offset := Vector2.ZERO
	if ui_config != null:
		var value: Variant = ui_config.get(offset_property)
		if value is Vector2:
			offset = value
	return (viewport_size - panel_size) * 0.5 + offset

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_layout_ui()

func _configure_summary_count_label(label: Label) -> void:
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color("#f8fafc"))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.08, 0.94))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func update_state(time_left: float, player_gold: int, _ai_gold: int, player_hp: float, _ai_hp: float, player_tiles: int, ai_tiles: int, faction_scores: Dictionary = {}, faction_armies: Dictionary = {}, player_barracks: int = 0) -> void:
	if stats_label == null:
		return
	stats_label.text = "  %d" % player_gold
	var eliminated_status: Dictionary = main_ref.get("eliminated_factions") as Dictionary if main_ref != null else {}
	var player_eliminated := bool(eliminated_status.get(Config.FACTION_PLAYER, false))
	if player_avatar != null:
		player_avatar.visible = true
		player_avatar.call("setup", Config.FACTION_PLAYER)
		player_avatar.modulate = Color(0.48, 0.48, 0.48, 1.0) if player_eliminated else Color.WHITE
	if player_name_label != null:
		player_name_label.text = str(Config.FACTION_PLAYER_NAMES.get(Config.FACTION_PLAYER, "Helios"))
	if barracks_count_label != null:
		barracks_count_label.text = str(player_barracks)
	if soldier_count_label != null:
		soldier_count_label.text = str(int(faction_armies.get(Config.FACTION_PLAYER, 0)))
	if player_eliminated_label != null:
		player_eliminated_label.visible = player_eliminated
		player_eliminated_label.text = "已淘汰" if player_eliminated else ""
	if merchant_shop_overlay != null and merchant_shop_overlay.visible:
		_update_merchant_gold(player_gold)
		_update_merchant_price_colors(player_gold)
	if faction_scores.is_empty():
		status_label.text = "领地  %02d : %02d" % [player_tiles, ai_tiles]
	else:
		var score_parts: Array[String] = []
		for faction in Config.FACTION_IDS:
			var short_name := str(Config.FACTION_NAMES.get(faction, "阵营"))
			short_name = short_name.replace("玩家", "我").replace("方", "")
			score_parts.append("%s:%02d" % [short_name, int(faction_scores.get(faction, 0))])
		status_label.text = "领地 " + " ".join(score_parts)
	var army_parts: Array[String] = []
	if faction_armies.is_empty():
		army_label.text = "士兵  我:%d 敌:%d" % [0, 0]
	else:
		for faction in Config.FACTION_IDS:
			var army_name := str(Config.FACTION_NAMES.get(faction, "阵营"))
			army_name = army_name.replace("玩家", "我").replace("方", "")
			army_parts.append("%s:%d" % [army_name, int(faction_armies.get(faction, 0))])
		army_label.text = "士兵 " + " ".join(army_parts)
	if faction_stats_display != null:
		var display_scores := faction_scores
		var display_armies := faction_armies
		if display_scores.is_empty():
			for faction in Config.FACTION_IDS:
				display_scores[faction] = 0
		if display_armies.is_empty():
			for faction in Config.FACTION_IDS:
				display_armies[faction] = 0
		faction_stats_display.set_faction_data(Config.FACTION_IDS, display_scores, display_armies, eliminated_status)
	# The player's HQ health remains part of gameplay state, but its HUD bar is
	# intentionally hidden. Damage and defeat logic continue to use player_hp.
	hq_health_bar.value = clampf(player_hp, 0.0, Config.HQ_MAX_HP)
	hq_health_bar.visible = false
	var total_seconds := maxi(0, int(ceil(time_left)))
	var minutes := total_seconds / 60
	var seconds := total_seconds % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]

func reset_faction_stats_animation() -> void:
	if faction_stats_display != null and faction_stats_display.has_method("reset_ranking_animation"):
		faction_stats_display.call("reset_ranking_animation")

func _refresh_fps_label() -> void:
	if fps_label == null:
		return
	var fps := Engine.get_frames_per_second()
	fps_label.text = "FPS %d" % fps
	var fps_color := ui_config.battle_fps_good_color if ui_config != null else Color("#4ade80")
	if fps < 30:
		fps_color = ui_config.battle_fps_bad_color if ui_config != null else Color("#f87171")
	elif fps < 50:
		fps_color = ui_config.battle_fps_warning_color if ui_config != null else Color("#facc15")
	fps_label.add_theme_color_override("font_color", fps_color)

func show_hint(message: String) -> void:
	if message.is_empty():
		return
	if _is_card_related_hint(message):
		_show_card_hint_toast(message)
		return
	if hint_container == null:
		return
	if hint_messages.is_empty() or hint_messages[0] != message:
		hint_messages.push_front(message)
		if hint_messages.size() > PERSONAL_HINT_MAX_LINES:
			hint_messages.pop_back()
		_render_hint_history()

func _show_card_hint_toast(message: String) -> void:
	if card_hint_panel == null or card_hint_label == null:
		return
	if card_hint_tween != null and card_hint_tween.is_valid():
		card_hint_tween.kill()
	card_hint_label.text = message
	card_hint_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var padding := ui_config.card_hint_padding if ui_config != null else Vector2(20.0, 10.0)
	var max_width := maxf(120.0, viewport_size.x - 48.0)
	var desired := card_hint_label.get_combined_minimum_size()
	var content_width := minf(maxf(1.0, desired.x), max_width - padding.x * 2.0)
	if desired.x > max_width - padding.x * 2.0:
		card_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content_width = max_width - padding.x * 2.0
	card_hint_label.size = Vector2(content_width, maxf(30.0, card_hint_label.get_combined_minimum_size().y))
	card_hint_label.position = padding
	card_hint_panel.size = card_hint_label.size + padding * 2.0
	card_hint_panel.position = (viewport_size - card_hint_panel.size) * 0.5
	card_hint_panel.modulate.a = 1.0
	card_hint_panel.visible = true
	card_hint_tween = create_tween()
	var duration := ui_config.card_hint_duration if ui_config != null else 1.0
	var fade_duration := minf(0.12, maxf(0.02, duration * 0.25))
	card_hint_tween.tween_interval(maxf(0.02, duration - fade_duration))
	card_hint_tween.tween_property(card_hint_panel, "modulate:a", 0.0, fade_duration)
	card_hint_tween.tween_callback(func() -> void:
		card_hint_panel.visible = false
		card_hint_panel.modulate.a = 1.0
	)

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
	world_broadcast_faction = -1
	world_broadcast_name = ""
	world_broadcast_target_faction = -1
	world_broadcast_target_name = ""
	_refresh_broadcast_banner()

func show_divination_broadcast(source_faction: int, source_name: String, target_faction: int, target_name: String, result_description: String, duration: float = Config.INTELLIGENCE_BROADCAST_DURATION) -> void:
	world_broadcast_message = result_description
	world_broadcast_remaining = maxf(0.0, duration)
	world_broadcast_faction = source_faction
	world_broadcast_name = source_name
	world_broadcast_target_faction = target_faction
	world_broadcast_target_name = target_name
	_refresh_broadcast_banner()

func show_faction_elimination_broadcast(faction_name: String, faction: int, duration: float = Config.INTELLIGENCE_BROADCAST_DURATION) -> void:
	world_broadcast_message = "%s已淘汰" % faction_name
	world_broadcast_remaining = maxf(0.0, duration)
	world_broadcast_faction = faction
	world_broadcast_name = ""
	world_broadcast_target_faction = -1
	world_broadcast_target_name = ""
	_refresh_broadcast_banner()

func hide_world_broadcast() -> void:
	world_broadcast_message = ""
	world_broadcast_remaining = 0.0
	world_broadcast_faction = -1
	world_broadcast_name = ""
	world_broadcast_target_faction = -1
	world_broadcast_target_name = ""
	_refresh_broadcast_banner()

func play_divination_event(data: Dictionary) -> void:
	divination_event_queue.append(data)
	if not divination_event_running:
		_start_next_divination_event()

func _start_next_divination_event() -> void:
	if divination_event_queue.is_empty():
		divination_event_running = false
		divination_event_current = {}
		divination_roll_emitted = false
		if divination_root:
			divination_root.visible = false
		if divination_overlay:
			divination_overlay.visible = false
		if divination_start_button:
			divination_start_button.visible = false
		if divination_bubble:
			divination_bubble.visible = false
		if divination_close_button:
			divination_close_button.visible = false
		return
	divination_event_current = divination_event_queue.pop_front()
	divination_event_running = true
	divination_roll_emitted = false
	if divination_root:
		divination_root.visible = true
	divination_overlay.visible = true
	divination_start_button.visible = true
	divination_start_button.disabled = false
	divination_bubble.visible = false
	if divination_desktop_event_icons != null:
		divination_desktop_event_icons.visible = false
		divination_desktop_event_icons.modulate.a = 0.0
	divination_close_button.visible = true
	# The title is already part of the authored background artwork. Keep the
	# programmatic title disabled to avoid drawing a duplicate over the art.
	divination_title.text = ""
	divination_target_text.text = ""
	divination_target_text.visible = false
	divination_target_display.clear_target()
	divination_target_display.visible = false
	divination_target_display.modulate.a = 0.0
	divination_event_text.text = ""
	divination_event_text.visible = false
	if divination_result != null:
		divination_result.text = ""
		divination_result.visible = false
	if divination_event_highlight != null:
		divination_event_highlight.clear_active()
	if divination_crystal_effect != null:
		divination_crystal_effect.clear_effect()
	if divination_event_tween != null and divination_event_tween.is_valid():
		divination_event_tween.kill()
	return

func _on_divination_start_pressed() -> void:
	if not divination_event_running or divination_event_tween != null and divination_event_tween.is_valid():
		return
	divination_start_button.visible = false
	if divination_desktop_event_icons != null:
		divination_desktop_event_icons.visible = true
		divination_desktop_event_icons.modulate.a = 0.0
		var icon_fade := create_tween()
		icon_fade.tween_property(divination_desktop_event_icons, "modulate:a", 1.0, 0.65)
	if divination_crystal_effect != null:
		divination_crystal_effect.play_glow(0.65)
	var target_type_name := str(divination_event_current.get("target_type_name", "未知目标"))
	divination_target_text.text = ""
	divination_target_text.visible = false
	divination_target_display.clear_target()
	divination_target_display.visible = false
	divination_target_display.modulate.a = 0.0
	divination_event_tween = create_tween()
	divination_event_tween.tween_interval(0.65)
	divination_event_tween.tween_callback(_show_divination_bubble_and_target)
	# Reveal the selected target condition one character at a time, then show
	# the resolved player inside the crystal ball.
	var character_count := target_type_name.length()
	var character_step := Config.FATE_DIVINATION_TARGET_ROLL_DURATION / float(maxi(1, character_count))
	for index in range(character_count):
		divination_event_tween.tween_callback(_set_divination_target_text.bind(target_type_name.substr(0, index + 1)))
		divination_event_tween.tween_interval(character_step)
	divination_event_tween.tween_callback(_show_divination_target_result)
	divination_event_tween.tween_callback(_fade_in_divination_target_avatar)
	divination_event_tween.tween_interval(0.42)
	divination_event_tween.tween_callback(_start_divination_event_roll)

func _show_divination_bubble_and_target() -> void:
	if not divination_event_running:
		return
	divination_bubble.visible = true
	divination_target_text.visible = true

func _fade_in_divination_target_avatar() -> void:
	if divination_target_display == null:
		return
	divination_target_display.modulate.a = 0.0
	divination_target_display.visible = true
	var avatar_fade := create_tween()
	avatar_fade.tween_property(divination_target_display, "modulate:a", 1.0, 0.42)

func _close_divination_ui() -> void:
	if not divination_event_running:
		return
	var fate_cell: Vector2i = divination_event_current.get("fate_cell", Vector2i(999, 999))
	if divination_event_tween != null and divination_event_tween.is_valid():
		divination_event_tween.kill()
	divination_event_queue.clear()
	divination_event_current = {}
	divination_event_running = false
	divination_roll_emitted = false
	if divination_root:
		divination_root.visible = false
	divination_overlay.visible = false
	if divination_desktop_event_icons != null:
		divination_desktop_event_icons.visible = false
		divination_desktop_event_icons.modulate.a = 0.0
	if divination_crystal_effect != null:
		divination_crystal_effect.clear_effect()
	divination_closed.emit(fate_cell)

func _show_divination_target_preview(target_type_name: String) -> void:
	# Kept as a compatibility hook for older callers; target text no longer
	# scrolls during the new flow.
	divination_target_text.text = target_type_name
	divination_target_text.visible = true

func _set_divination_target_text(text_value: String) -> void:
	if not divination_event_running:
		return
	divination_target_text.text = text_value
	divination_target_text.visible = true

func _show_divination_target_result() -> void:
	divination_target_text.text = str(divination_event_current.get("target_type_name", "未知目标"))
	divination_target_text.visible = true
	if divination_target_display != null:
		divination_target_display.set_target(int(divination_event_current.get("target", 0)), str(divination_event_current.get("target_name", "未知")))
		divination_target_display.visible = false
		divination_target_display.modulate.a = 0.0

func _start_divination_event_roll() -> void:
	if not divination_event_running:
		return
	divination_event_text.visible = false
	# The target-selection tween is already running; start a fresh tween for
	# the event roll because Godot does not allow appending to a started tween.
	divination_event_tween = create_tween()
	var roll_steps := 30
	var interval_sum := 0.0
	var intervals: Array[float] = []
	for index in range(roll_steps):
		var progress := float(index) / float(roll_steps - 1)
		var interval := lerpf(0.16, 0.045, clampf(progress / 0.25, 0.0, 1.0))
		if progress > 0.72:
			interval = lerpf(0.045, 0.22, (progress - 0.72) / 0.28)
		intervals.append(interval)
		interval_sum += interval
	var interval_scale := Config.FATE_DIVINATION_ROLL_DURATION / interval_sum
	for index in range(roll_steps):
		# The highlight target is visual-only. Pick a fresh event icon for each
		# rolling step; the actual event remains determined by main.gd.
		var icon_index := randi_range(0, divination_event_icons.size() - 1)
		if index == roll_steps - 1:
			icon_index = int(divination_event_current.get("event_type", icon_index)) % divination_event_icons.size()
		divination_event_tween.tween_callback(_show_divination_icon.bind(icon_index))
		divination_event_tween.tween_interval(intervals[index] * interval_scale)
	divination_event_tween.tween_callback(_emit_divination_roll)

func _show_divination_icon(active_index: int) -> void:
	if divination_event_highlight == null:
		return
	if divination_event_highlight != null:
		divination_event_highlight.set_active(active_index, false)

func _emit_divination_roll() -> void:
	if not divination_event_running or divination_roll_emitted:
		return
	divination_roll_emitted = true
	var result_index := int(divination_event_current.get("event_type", 0))
	if divination_event_highlight != null:
		divination_event_highlight.set_active(result_index, true)
	divination_event_text.text = str(divination_event_current.get("event_name", "占卜结果"))
	divination_event_text.visible = true
	if divination_crystal_effect != null:
		divination_crystal_effect.play_flash(1.0)
	# Keep the final result visible briefly, then close the house before the
	# main scene applies the result, broadcasts it, or moves the camera.
	if divination_event_tween != null and divination_event_tween.is_valid():
		divination_event_tween.kill()
	divination_event_tween = create_tween()
	divination_event_tween.tween_interval(1.0)
	divination_event_tween.tween_callback(_close_divination_before_result)

func _close_divination_before_result() -> void:
	if not divination_event_running:
		return
	# The result has already been shown in the bubble and the slow white flash
	# has finished. Hide only the visuals; keep the pending event alive so main.gd
	# can still resolve it and complete the normal camera/result flow.
	_hide_divination_visuals()
	divination_roll_finished.emit(divination_event_current.get("fate_cell", Vector2i(999, 999)))

func _hide_divination_visuals() -> void:
	if divination_root:
		divination_root.visible = false
	if divination_overlay:
		divination_overlay.visible = false
	if divination_start_button:
		divination_start_button.visible = false
	if divination_close_button:
		divination_close_button.visible = false
	if divination_desktop_event_icons:
		divination_desktop_event_icons.visible = false
		divination_desktop_event_icons.modulate.a = 0.0
	if divination_crystal_effect:
		divination_crystal_effect.clear_effect()

func show_divination_result(message: String) -> void:
	if divination_event_text:
		divination_event_text.text = message
		divination_event_text.visible = true
	if divination_result != null:
		divination_result.text = ""
		divination_result.visible = false

func finish_divination_event() -> void:
	if divination_event_tween != null and divination_event_tween.is_valid():
		divination_event_tween.kill()
	if divination_event_highlight != null:
		divination_event_highlight.clear_active()
	divination_event_current = {}
	divination_roll_emitted = false
	divination_event_running = false
	_start_next_divination_event()

func clear_divination_events() -> void:
	if divination_event_tween != null and divination_event_tween.is_valid():
		divination_event_tween.kill()
	if divination_event_highlight != null:
		divination_event_highlight.clear_active()
	divination_event_queue.clear()
	divination_event_current = {}
	divination_roll_emitted = false
	divination_event_running = false
	if divination_root:
		divination_root.visible = false
	if divination_overlay:
		divination_overlay.visible = false
	if divination_start_button:
		divination_start_button.visible = false
	if divination_desktop_event_icons:
		divination_desktop_event_icons.visible = false
		divination_desktop_event_icons.modulate.a = 0.0
	if divination_crystal_effect:
		divination_crystal_effect.clear_effect()

func show_result(message: String) -> void:
	clear_camera_guides()
	if spectate_button != null:
		spectate_button.visible = false
	if exit_game_button != null:
		exit_game_button.visible = false
	if restart_button != null:
		restart_button.visible = true
	if watch_mode_button != null:
		watch_mode_button.visible = false
	if end_panel != null:
		end_panel.visible = true
		end_panel.z_index = 120
	if defeat_overlay != null:
		defeat_overlay.visible = true
	if end_label != null:
		end_label.text = message

func show_player_defeat_choice(message: String) -> void:
	clear_camera_guides()
	if restart_button != null:
		restart_button.visible = false
	if spectate_button != null:
		spectate_button.visible = true
	if exit_game_button != null:
		exit_game_button.visible = true
	if watch_mode_button != null:
		watch_mode_button.visible = false
	if end_panel != null:
		end_panel.visible = true
		end_panel.z_index = 120
	if defeat_overlay != null:
		defeat_overlay.visible = true
	if end_label != null:
		end_label.text = message

func show_spectator_exit() -> void:
	if end_panel != null:
		end_panel.visible = false
	if defeat_overlay != null:
		defeat_overlay.visible = false
	if exit_game_button != null:
		exit_game_button.visible = false
	if watch_mode_button != null:
		watch_mode_button.visible = true
		watch_mode_button.z_index = 130

func hide_spectator_controls() -> void:
	if watch_mode_button != null:
		watch_mode_button.visible = false
	if spectate_button != null:
		spectate_button.visible = false
	if exit_game_button != null:
		exit_game_button.visible = false

func hide_result() -> void:
	if end_panel != null:
		end_panel.visible = false
	if defeat_overlay != null:
		defeat_overlay.visible = false
	if exit_game_button != null:
		exit_game_button.visible = false

func show_settlement(match_time: float, faction_rows: Array, player_row: Dictionary) -> void:
	clear_camera_guides()
	hide_result()
	hide_spectator_controls()
	if settlement_ui != null:
		settlement_ui.z_index = 200
		settlement_ui.visible = true
		settlement_ui.call("show_settlement", match_time, faction_rows, player_row)

func hide_settlement() -> void:
	if settlement_ui != null:
		settlement_ui.call("hide_settlement")

func _on_settlement_confirmed() -> void:
	hide_settlement()

func _on_restart_pressed() -> void:
	_close_player_info()
	clear_camera_guides()
	if main_ref:
		main_ref.restart_game()

func _on_spectate_pressed() -> void:
	_close_player_info()
	clear_camera_guides()
	if main_ref:
		main_ref.continue_spectating()

func _on_defeat_exit_pressed() -> void:
	get_tree().quit()

func _on_exit_spectator_pressed() -> void:
	get_tree().quit()

func _apply_flat_popup_theme() -> void:
	# Apply the same flat treatment to every modal while leaving map HUD controls
	# and content illustrations outside the modal theme boundary.
	var popup_panels: Array[Panel] = [
		end_panel,
		player_info_panel,
		equipment_detail_panel,
		equipment_replacement_panel,
		card_event_panel,
		divination_panel,
		intelligence_news_panel,
		merchant_arrival_panel
	]
	for panel in popup_panels:
		if panel == null:
			continue
		if panel == divination_panel or panel == merchant_shop_panel or panel == end_panel:
			continue
		panel.add_theme_stylebox_override("panel", Art.flat_panel_style(Art.POPUP_BACKGROUND_ALT if panel == divination_panel or panel == card_event_panel or panel == merchant_arrival_panel or panel == player_info_panel else Art.POPUP_BACKGROUND))
		_apply_flat_popup_children(panel)
	if player_info_button != null:
		Art.apply_flat_button(player_info_button, Art.POPUP_ACCENT)

func _apply_flat_popup_children(root: Node) -> void:
	for child in root.get_children():
		if child is Button:
			Art.apply_flat_button(child as Button, Art.POPUP_ACCENT)
		elif child is Label:
			var label := child as Label
			label.add_theme_color_override("font_color", Art.POPUP_TEXT)
			label.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
			label.add_theme_constant_override("outline_size", 0)
		_apply_flat_popup_children(child)

# Run once after the dynamic HUD is built so every action shares the same
# rounded, outlined and vertically-pressed cartoon button treatment.
func _apply_cartoon_buttons(root: Node) -> void:
	for child in root.get_children():
		if child == merchant_shop_overlay:
			continue
		if child is Button:
			var button := child as Button
			if button == divination_start_button:
				_apply_cartoon_buttons(child)
				continue
			var color := Art.SKY
			if button.text.contains("丢弃") or button.text.contains("驱赶") or button.text.contains("退出"):
				color = Color("#ff9b8f")
			elif button.text.contains("替换") or button.text.contains("再来"):
				color = Art.SUN
			elif button.name.begins_with("MerchantItem"):
				color = Color("#fff0bd")
			Art.apply_button(button, color)
		_apply_cartoon_buttons(child)
