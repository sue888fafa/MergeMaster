class_name MerchantShopUI
extends Control

const Config := preload("res://game_config.gd")
const MerchantDataScript := preload("res://merchant_data.gd")
const SOLD_OUT_ART := preload("res://assets/generated/shop/sold_out.png")
const Art := preload("res://art_theme.gd")

signal item_selected(index: int)
signal dismissed
signal closed

var ui_config: UIEditorConfig = preload("res://ui_editor_config.tres")

# These are authored in MerchantShopUI.tscn.  Keep their initial visibility so
# an artist can hide a title/description (or replace it with an authored
# Label) without the shop reopening it behind their back.
var authored_card_visibility: Array[Dictionary] = []
var authored_shop_rects: Dictionary = {}

@onready var gold_label: Label = $MerchantShopPanel/MerchantShopGold
@onready var close_icon_hit_area: Button = $MerchantShopPanel/CloseIconHitArea
@onready var item_buttons: Array[Button] = [
	$MerchantShopPanel/MerchantItem0,
	$MerchantShopPanel/MerchantItem1,
	$MerchantShopPanel/MerchantItem2
]
@onready var purchase_buttons: Array[Button] = [
	$MerchantShopPanel/MerchantItem0/PurchaseButton,
	$MerchantShopPanel/MerchantItem1/PurchaseButton,
	$MerchantShopPanel/MerchantItem2/PurchaseButton
]
@onready var purchase_price_labels: Array[Label] = [
	$MerchantShopPanel/MerchantItem0/PurchaseButton/PurchasePrice,
	$MerchantShopPanel/MerchantItem1/PurchaseButton/PurchasePrice,
	$MerchantShopPanel/MerchantItem2/PurchaseButton/PurchasePrice
]
@onready var card_icons: Array[Control] = [
	$MerchantShopPanel/MerchantItem0/CardIcon,
	$MerchantShopPanel/MerchantItem1/CardIcon,
	$MerchantShopPanel/MerchantItem2/CardIcon
]
@onready var card_titles: Array[Label] = [
	$MerchantShopPanel/MerchantItem0/CardTitle,
	$MerchantShopPanel/MerchantItem1/CardTitle,
	$MerchantShopPanel/MerchantItem2/CardTitle
]
@onready var card_descriptions: Array[Label] = [
	$MerchantShopPanel/MerchantItem0/CardDescription,
	$MerchantShopPanel/MerchantItem1/CardDescription,
	$MerchantShopPanel/MerchantItem2/CardDescription
]
@onready var purchase_coin_icons: Array[Control] = [
	$MerchantShopPanel/MerchantItem0/PurchaseButton/CoinIcon,
	$MerchantShopPanel/MerchantItem1/PurchaseButton/CoinIcon,
	$MerchantShopPanel/MerchantItem2/PurchaseButton/CoinIcon
]
@onready var sold_out_stamps: Array[TextureRect] = [
	$MerchantShopPanel/MerchantItem0/SoldOutStamp,
	$MerchantShopPanel/MerchantItem1/SoldOutStamp,
	$MerchantShopPanel/MerchantItem2/SoldOutStamp
]

func _ready() -> void:
	_apply_editor_config()
	authored_card_visibility.clear()
	authored_shop_rects.clear()
	for index in range(item_buttons.size()):
		authored_card_visibility.append({
		"icon": _control_visible(card_icons[index]),
		"title": _control_visible(card_titles[index]),
		"description": _control_visible(card_descriptions[index]),
		"sold_out": _control_visible(sold_out_stamps[index], false),
	})
		_authored_shop_rect("MerchantItem%d/PurchaseButton" % index, purchase_buttons[index])
		_authored_shop_rect("MerchantItem%d/PurchaseButton/PurchasePrice" % index, purchase_price_labels[index])
		_authored_shop_rect("MerchantItem%d/PurchaseButton/CoinIcon" % index, purchase_coin_icons[index])
		_authored_shop_rect("MerchantItem%d/SoldOutStamp" % index, sold_out_stamps[index])
	for index in range(item_buttons.size()):
		# The card is now display-only; purchasing is handled by its dedicated button.
		if item_buttons[index] != null:
			item_buttons[index].mouse_filter = Control.MOUSE_FILTER_IGNORE
		if purchase_buttons[index] != null:
			purchase_buttons[index].pressed.connect(item_selected.emit.bind(index))
		if purchase_coin_icons[index] != null:
			purchase_coin_icons[index].call("setup_coin")
	close_icon_hit_area.pressed.connect(closed.emit)
	$MerchantShopPanel/CloseButton.pressed.connect(closed.emit)
	$MerchantShopPanel/DismissButton.pressed.connect(dismissed.emit)

func configure_ui(config: UIEditorConfig) -> void:
	ui_config = config
	Art.configure_ui(ui_config)
	if is_inside_tree():
		_apply_editor_config()

func _apply_editor_config() -> void:
	if not is_instance_valid($Overlay) or not is_instance_valid($MerchantShopPanel):
		return
	$Overlay.color = ui_config.modal_overlay_color if ui_config != null else Color(0.01, 0.03, 0.07, 0.8)
	# Do not replace the panel StyleBox here.  MerchantShopUI.tscn is the
	# source of truth for the shop's panel and button appearance.

func _control_visible(control: Control, default_value := true) -> bool:
	return control.visible if is_instance_valid(control) else default_value

func set_items(items: Array[String], player_gold: int) -> void:
	_restore_authored_shop_layout()
	set_gold(player_gold)
	for index in range(item_buttons.size()):
		var available := index < items.size()
		var button := item_buttons[index]
		if (
			button == null
			or purchase_buttons[index] == null
			or purchase_price_labels[index] == null
			or purchase_coin_icons[index] == null
			or card_icons[index] == null
			or card_titles[index] == null
			or card_descriptions[index] == null
			or sold_out_stamps[index] == null
		):
			continue
		button.disabled = false
		var purchase_button := purchase_buttons[index]
		purchase_button.visible = available
		purchase_button.disabled = not available
		purchase_price_labels[index].visible = available
		purchase_price_labels[index].text = str(Config.MERCHANT_ITEM_COST)
		# The background artwork already contains the coin on each green
		# purchase button; keep the old programmatic icon hidden.
		purchase_coin_icons[index].visible = false
		var card_icon := card_icons[index]
		var title := card_titles[index]
		var description := card_descriptions[index]
		var sold_out_stamp := sold_out_stamps[index]
		if card_icon == null or title == null or description == null or sold_out_stamp == null:
			continue
		var sold_out := not available or str(items[index]).is_empty()
		var authored := authored_card_visibility[index] if index < authored_card_visibility.size() else {}
		# A stocked card must always be visible after a shop refresh. The
		# authored visibility flag is still useful for optional text/decorative
		# nodes, but allowing it to hide the actual product made cards disappear
		# after reopening the shop.
		card_icon.visible = available
		card_icon.z_index = 5
		card_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.visible = available and bool(authored.get("title", true))
		description.visible = available and bool(authored.get("description", true))
		sold_out_stamp.visible = sold_out or bool(authored.get("sold_out", false))
		purchase_button.disabled = sold_out
		if sold_out:
			purchase_price_labels[index].visible = false
			purchase_coin_icons[index].visible = false
			continue
		var item_id := str(items[index])
		var item: Dictionary = MerchantDataScript.get_item(item_id)
		card_icon.call("setup_card", item_id)
		title.text = str(item.get("name", "未知卡片"))
		description.text = str(item.get("description", ""))

func set_gold(player_gold: int) -> void:
	if gold_label == null:
		return
	gold_label.text = "金币  %d" % maxi(0, player_gold)

func _authored_shop_rect(key: String, control: Control) -> void:
	if control == null:
		return
	authored_shop_rects[key] = {
		"position": control.position,
		"size": control.size,
		"scale": control.scale,
		"rotation": control.rotation,
	}

func _restore_authored_shop_layout() -> void:
	for key in authored_shop_rects:
		var control: Control = null
		match str(key):
			"MerchantItem0/PurchaseButton": control = purchase_buttons[0]
			"MerchantItem1/PurchaseButton": control = purchase_buttons[1]
			"MerchantItem2/PurchaseButton": control = purchase_buttons[2]
			"MerchantItem0/PurchaseButton/PurchasePrice": control = purchase_price_labels[0]
			"MerchantItem1/PurchaseButton/PurchasePrice": control = purchase_price_labels[1]
			"MerchantItem2/PurchaseButton/PurchasePrice": control = purchase_price_labels[2]
			"MerchantItem0/PurchaseButton/CoinIcon": control = purchase_coin_icons[0]
			"MerchantItem1/PurchaseButton/CoinIcon": control = purchase_coin_icons[1]
			"MerchantItem2/PurchaseButton/CoinIcon": control = purchase_coin_icons[2]
			"MerchantItem0/SoldOutStamp": control = sold_out_stamps[0]
			"MerchantItem1/SoldOutStamp": control = sold_out_stamps[1]
			"MerchantItem2/SoldOutStamp": control = sold_out_stamps[2]
			_: control = null
		if control == null:
			continue
		var authored: Dictionary = authored_shop_rects[key]
		control.position = authored["position"]
		control.size = authored["size"]
		control.scale = authored["scale"]
		control.rotation = authored["rotation"]
