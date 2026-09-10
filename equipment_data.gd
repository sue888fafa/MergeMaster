class_name EquipmentData
extends RefCounted

const SLOT_NAMES := ["鞋子", "盔甲", "戒指", "武器", "饰品"]

const ITEM_IDS := [
	"alliance_boots", "tribe_boots", "undead_boots",
	"alliance_armor", "tribe_armor", "undead_armor",
	"alliance_ring", "tribe_ring", "undead_ring",
	"alliance_sword", "tribe_sword", "undead_sword",
	"favor_necklace", "tenacity_shield", "greed_gloves"
]

const QUALITY_NAMES := ["", "普通", "稀有", "史诗"]
const QUALITY_COLORS := ["#cbd5e1", "#cbd5e1", "#60a5fa", "#c084fc"]

const ITEMS := {
	"alliance_boots": {"slot_index": 0, "slot": "鞋子", "name": "联盟之靴", "icon": "res://assets/equipment/alliance_boots.svg", "effect_type": "move_speed", "base_effect_value": 0.05},
	"tribe_boots": {"slot_index": 0, "slot": "鞋子", "name": "部落之靴", "icon": "res://assets/equipment/tribe_boots.svg", "effect_type": "move_speed", "base_effect_value": 0.05},
	"undead_boots": {"slot_index": 0, "slot": "鞋子", "name": "亡灵之靴", "icon": "res://assets/equipment/undead_boots.svg", "effect_type": "move_speed", "base_effect_value": 0.05},
	"alliance_armor": {"slot_index": 1, "slot": "盔甲", "name": "联盟盔甲", "icon": "res://assets/equipment/alliance_armor.svg", "effect_type": "health", "base_effect_value": 0.05},
	"tribe_armor": {"slot_index": 1, "slot": "盔甲", "name": "部落盔甲", "icon": "res://assets/equipment/tribe_armor.svg", "effect_type": "health", "base_effect_value": 0.05},
	"undead_armor": {"slot_index": 1, "slot": "盔甲", "name": "亡灵盔甲", "icon": "res://assets/equipment/undead_armor.svg", "effect_type": "health", "base_effect_value": 0.05},
	"alliance_ring": {"slot_index": 2, "slot": "戒指", "name": "联盟之戒", "icon": "res://assets/equipment/alliance_ring.svg", "effect_type": "summon_speed", "base_effect_value": 0.05},
	"tribe_ring": {"slot_index": 2, "slot": "戒指", "name": "部落之戒", "icon": "res://assets/equipment/tribe_ring.svg", "effect_type": "summon_speed", "base_effect_value": 0.05},
	"undead_ring": {"slot_index": 2, "slot": "戒指", "name": "亡灵之戒", "icon": "res://assets/equipment/undead_ring.svg", "effect_type": "summon_speed", "base_effect_value": 0.05},
	"alliance_sword": {"slot_index": 3, "slot": "武器", "name": "联盟之剑", "icon": "res://assets/equipment/alliance_sword.svg", "effect_type": "attack", "base_effect_value": 0.05},
	"tribe_sword": {"slot_index": 3, "slot": "武器", "name": "部落之剑", "icon": "res://assets/equipment/tribe_sword.svg", "effect_type": "attack", "base_effect_value": 0.05},
	"undead_sword": {"slot_index": 3, "slot": "武器", "name": "亡灵之剑", "icon": "res://assets/equipment/undead_sword.svg", "effect_type": "attack", "base_effect_value": 0.05},
	"favor_necklace": {"slot_index": 4, "slot": "饰品", "name": "眷顾项链", "icon": "res://assets/equipment/favor_necklace.svg", "effect_type": "luck", "base_effect_value": 1.0},
	"tenacity_shield": {"slot_index": 4, "slot": "饰品", "name": "坚韧盾牌", "icon": "res://assets/equipment/tenacity_shield.svg", "effect_type": "building_health", "base_effect_value": 0.05},
	"greed_gloves": {"slot_index": 4, "slot": "饰品", "name": "贪婪手套", "icon": "res://assets/equipment/greed_gloves.svg", "effect_type": "gold_regen", "base_effect_value": 1.0}
}

static func get_item(item_id: String) -> Dictionary:
	var base_id := get_base_equipment_id(item_id)
	if not ITEMS.has(base_id):
		return {}
	var item: Dictionary = ITEMS[base_id].duplicate(true)
	var quality := get_equipment_quality(item_id)
	var multiplier := float(quality)
	item["base_id"] = base_id
	item["quality"] = quality
	item["quality_name"] = QUALITY_NAMES[quality]
	item["quality_color"] = QUALITY_COLORS[quality]
	item["quality_multiplier"] = multiplier
	item["effect_value"] = float(item.get("base_effect_value", 0.0)) * multiplier
	item["name"] = "%s·%s" % [str(item["name"]), QUALITY_NAMES[quality]]
	item["description"] = get_display_description(item_id)
	return item

static func is_valid_item(item_id: String) -> bool:
	return ITEMS.has(get_base_equipment_id(item_id))

static func get_equipment_quality(item_id: String) -> int:
	var marker := item_id.rfind("__q")
	if marker < 0:
		return 1
	var parsed := int(item_id.substr(marker + 3))
	return clampi(parsed, 1, 3)

static func get_base_equipment_id(item_id: String) -> String:
	var marker := item_id.rfind("__q")
	if marker < 0:
		return item_id
	return item_id.substr(0, marker)

static func get_quality_multiplier(item_id: String) -> float:
	return float(get_equipment_quality(item_id))

static func get_effect_value(item_id: String) -> float:
	var item := get_item(item_id)
	return float(item.get("effect_value", 0.0))

static func get_display_description(item_id: String) -> String:
	var base_id := get_base_equipment_id(item_id)
	var item: Dictionary = ITEMS.get(base_id, {})
	if item.is_empty():
		return ""
	var value := float(item.get("base_effect_value", 0.0)) * float(get_equipment_quality(item_id))
	var percent := int(round(value * 100.0))
	match str(item.get("effect_type", "")):
		"move_speed": return "增加士兵移速%d%%" % percent
		"health": return "增加士兵生命%d%%" % percent
		"summon_speed": return "兵营召唤速度提高%d%%" % percent
		"attack": return "增加士兵攻击%d%%" % percent
		"building_health": return "建筑生命增加%d%%" % percent
		"luck": return "幸运效果暂未启用"
		"gold_regen": return "每10秒额外获得%d金币" % int(value)
	return ""

static func get_slot_name(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= SLOT_NAMES.size():
		return "未知部位"
	return SLOT_NAMES[slot_index]
