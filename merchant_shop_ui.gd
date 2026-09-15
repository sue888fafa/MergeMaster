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

@onready var gold_label: Label = $MerchantShopPanel/MerchantShopGold
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
@onready var price_labels: Array[Label] = [
	$MerchantShopPanel/MerchantItem0/Price,
	$MerchantShopPanel/MerchantItem1/Price,
	$MerchantShopPanel/MerchantItem2/Price
]
@onready var coin_icons: Array[Control] = [
	$MerchantShopPanel/MerchantItem0/CoinIcon,
	$MerchantShopPanel/MerchantItem1/CoinIcon,
	$MerchantShopPanel/MerchantItem2/CoinIcon
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
	for index in range(item_buttons.size()):
		# The card is now display-only; purchasing is handled by its dedicated button.
		item_buttons[index].mouse_filter = Control.MOUSE_FILTER_IGNORE
		purchase_buttons[index].pressed.connect(item_selected.emit.bind(index))
		coin_icons[index].call("setup_coin")
		purchase_coin_icons[index].call("setup_coin")
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
	$MerchantShopPanel.add_theme_stylebox_override("panel", Art.flat_panel_style(Art.POPUP_BACKGROUND_ALT, Art.POPUP_ACCENT))
	for button in item_buttons:
		Art.apply_flat_button(button, Art.POPUP_ACCENT)
	for button in purchase_buttons:
		Art.apply_flat_button(button, Art.SKY)
	Art.apply_flat_button($MerchantShopPanel/CloseButton, Art.POPUP_ACCENT)
	Art.apply_flat_button($MerchantShopPanel/DismissButton, Art.POPUP_ACCENT)

func set_items(items: Array[String], player_gold: int) -> void:
	# The main HUD gold bar remains visible behind this modal; avoid duplicating it here.
	gold_label.visible = false
	for index in range(item_buttons.size()):
		var available := index < items.size()
		var button := item_buttons[index]
		button.visible = true
		button.disabled = false
		var purchase_button := purchase_buttons[index]
		purchase_button.visible = available
		purchase_button.disabled = not available
		purchase_price_labels[index].visible = available
		purchase_price_labels[index].text = str(Config.MERCHANT_ITEM_COST)
		purchase_coin_icons[index].visible = available
		var card_icon := card_icons[index]
		var title := card_titles[index]
		var description := card_descriptions[index]
		var price := price_labels[index]
		var coin := coin_icons[index]
		var sold_out_stamp := sold_out_stamps[index]
		var sold_out := not available or str(items[index]).is_empty()
		card_icon.visible = available
		title.visible = available
		description.visible = available
		price.visible = available
		coin.visible = available
		# The purchase button owns the price row now.
		price.visible = false
		coin.visible = false
		sold_out_stamp.visible = sold_out
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
		purchase_button.text = ""

func set_gold(player_gold: int) -> void:
	gold_label.visible = false
