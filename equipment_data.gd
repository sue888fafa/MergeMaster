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

const ITEMS := {
	"alliance_boots": {"slot_index": 0, "slot": "鞋子", "name": "联盟之靴", "description": "增加联盟英雄移速0.05", "icon": "res://assets/equipment/alliance_boots.svg", "effect_type": "move_speed", "effect_value": 0.05},
	"tribe_boots": {"slot_index": 0, "slot": "鞋子", "name": "部落之靴", "description": "增加部落英雄移速0.05", "icon": "res://assets/equipment/tribe_boots.svg", "effect_type": "move_speed", "effect_value": 0.05},
	"undead_boots": {"slot_index": 0, "slot": "鞋子", "name": "亡灵之靴", "description": "增加亡灵英雄移速0.05", "icon": "res://assets/equipment/undead_boots.svg", "effect_type": "move_speed", "effect_value": 0.05},
	"alliance_armor": {"slot_index": 1, "slot": "盔甲", "name": "联盟盔甲", "description": "增加联盟英雄血量0.05", "icon": "res://assets/equipment/alliance_armor.svg", "effect_type": "health", "effect_value": 0.05},
	"tribe_armor": {"slot_index": 1, "slot": "盔甲", "name": "部落盔甲", "description": "增加部落英雄血量0.05", "icon": "res://assets/equipment/tribe_armor.svg", "effect_type": "health", "effect_value": 0.05},
	"undead_armor": {"slot_index": 1, "slot": "盔甲", "name": "亡灵盔甲", "description": "增加亡灵英雄血量0.05", "icon": "res://assets/equipment/undead_armor.svg", "effect_type": "health", "effect_value": 0.05},
	"alliance_ring": {"slot_index": 2, "slot": "戒指", "name": "联盟之戒", "description": "增加联盟英雄召唤速度0.05", "icon": "res://assets/equipment/alliance_ring.svg", "effect_type": "summon_speed", "effect_value": 0.05},
	"tribe_ring": {"slot_index": 2, "slot": "戒指", "name": "部落之戒", "description": "增加部落英雄召唤速度0.05", "icon": "res://assets/equipment/tribe_ring.svg", "effect_type": "summon_speed", "effect_value": 0.05},
	"undead_ring": {"slot_index": 2, "slot": "戒指", "name": "亡灵之戒", "description": "增加亡灵英雄召唤速度0.05", "icon": "res://assets/equipment/undead_ring.svg", "effect_type": "summon_speed", "effect_value": 0.05},
	"alliance_sword": {"slot_index": 3, "slot": "武器", "name": "联盟之剑", "description": "增加联盟英雄攻击0.05", "icon": "res://assets/equipment/alliance_sword.svg", "effect_type": "attack", "effect_value": 0.05},
	"tribe_sword": {"slot_index": 3, "slot": "武器", "name": "部落之剑", "description": "增加部落英雄攻击0.05", "icon": "res://assets/equipment/tribe_sword.svg", "effect_type": "attack", "effect_value": 0.05},
	"undead_sword": {"slot_index": 3, "slot": "武器", "name": "亡灵之剑", "description": "增加亡灵英雄攻击0.05", "icon": "res://assets/equipment/undead_sword.svg", "effect_type": "attack", "effect_value": 0.05},
	"favor_necklace": {"slot_index": 4, "slot": "饰品", "name": "眷顾项链", "description": "增加幸运1点", "icon": "res://assets/equipment/favor_necklace.svg", "effect_type": "luck", "effect_value": 1.0},
	"tenacity_shield": {"slot_index": 4, "slot": "饰品", "name": "坚韧盾牌", "description": "建筑血量增加0.05", "icon": "res://assets/equipment/tenacity_shield.svg", "effect_type": "building_health", "effect_value": 0.05},
	"greed_gloves": {"slot_index": 4, "slot": "饰品", "name": "贪婪手套", "description": "每10秒恢复1点金币", "icon": "res://assets/equipment/greed_gloves.svg", "effect_type": "gold_regen", "effect_value": 1.0}
}

static func get_item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})

static func is_valid_item(item_id: String) -> bool:
	return ITEMS.has(item_id)

static func get_slot_name(slot_index: int) -> String:
	if slot_index < 0 or slot_index >= SLOT_NAMES.size():
		return "未知部位"
	return SLOT_NAMES[slot_index]
