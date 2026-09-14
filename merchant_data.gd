class_name MerchantData
extends RefCounted

const Config := preload("res://game_config.gd")
const ITEM_DRAGON := "dragon"
const ITEM_UPGRADE := "upgrade"
const ITEM_STEEL_BARRIER := "steel_barrier"
const ITEM_BLIZZARD := "blizzard"
const ITEM_TRANSFER_CERTIFICATE := "transfer_certificate"
const ITEM_OCCUPY := "occupy"
const ITEM_BUILD := "build"
const ITEM_RECYCLE := "recycle"
const ITEM_STEAL := "steal"
const SEALED_BARRACKS_PREFIX := "sealed_barracks:"

const ITEM_IDS := [
	ITEM_DRAGON,
	ITEM_UPGRADE,
	ITEM_STEEL_BARRIER,
	ITEM_BLIZZARD,
	ITEM_TRANSFER_CERTIFICATE
]

const CARD_IDS := [
	ITEM_DRAGON,
	ITEM_UPGRADE,
	ITEM_STEEL_BARRIER,
	ITEM_BLIZZARD,
	ITEM_TRANSFER_CERTIFICATE,
	ITEM_OCCUPY,
	ITEM_BUILD,
	ITEM_RECYCLE,
	ITEM_STEAL
]

const ITEMS := {
	ITEM_DRAGON: {
		"name": "巨龙卡",
		"description": "摧毁指定的一座建筑，但不改变地块归属。"
	},
	ITEM_UPGRADE: {
		"name": "升级卡",
		"description": "升级任意一座己方非满级兵营。"
	},
	ITEM_STEEL_BARRIER: {
		"name": "钢铁屏障卡",
		"description": "在己方空地建造高血量防御建筑，只能防御。"
	},
	ITEM_BLIZZARD: {
		"name": "暴风雪卡",
		"description": "冻结目标区域内的敌方单位，使其2秒无法攻击和移动。"
	},
	ITEM_TRANSFER_CERTIFICATE: {
		"name": "转让卡",
		"description": "将指定的敌方兵营转为己方建筑。"
	},
	ITEM_OCCUPY: {
		"name": "强占卡",
		"description": "强行将一块不属于己方的地块变为己方随机职业建筑，兵营保留原等级。"
	},
	ITEM_BUILD: {
		"name": "加建卡",
		"description": "在任意一块己方空地建造一座1级随机职业兵营。"
	},
	ITEM_RECYCLE: {
		"name": "回收卡",
		"description": "将回收卡拖到任意兵营上封印，获得一张对应等级和职业的兵营卡。"
	},
	ITEM_STEAL: {
		"name": "窃取卡",
		"description": "拖到任意阵营的地块上，随机窃取该阵营的一张卡片。没有卡片时窃取失败。"
	}
}

static func make_sealed_barracks_card(level: int, unit_class: int) -> String:
	return "%s%d:%d" % [SEALED_BARRACKS_PREFIX, clampi(level, 1, 4), clampi(unit_class, 0, 4)]

static func is_sealed_barracks_card(card_id: String) -> bool:
	if not card_id.begins_with(SEALED_BARRACKS_PREFIX):
		return false
	var parts := card_id.trim_prefix(SEALED_BARRACKS_PREFIX).split(":")
	return parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int() and int(parts[0]) >= 1 and int(parts[0]) <= 4 and int(parts[1]) >= 0 and int(parts[1]) < 5

static func is_card(card_id: String) -> bool:
	return CARD_IDS.has(card_id) or is_sealed_barracks_card(card_id)

static func get_sealed_barracks_level(card_id: String) -> int:
	if not is_sealed_barracks_card(card_id):
		return 0
	return int(card_id.trim_prefix(SEALED_BARRACKS_PREFIX).split(":")[0])

static func get_sealed_barracks_class(card_id: String) -> int:
	if not is_sealed_barracks_card(card_id):
		return -1
	return int(card_id.trim_prefix(SEALED_BARRACKS_PREFIX).split(":")[1])

static func get_item(item_id: String) -> Dictionary:
	if is_sealed_barracks_card(item_id):
		return {
			"name": "%d级%s兵营卡" % [get_sealed_barracks_level(item_id), Config.UNIT_CLASS_NAMES[get_sealed_barracks_class(item_id)]],
			"description": "放置后恢复为%d级%s兵营。" % [get_sealed_barracks_level(item_id), Config.UNIT_CLASS_NAMES[get_sealed_barracks_class(item_id)]]
		}
	return ITEMS.get(item_id, {})

static func get_item_name(item_id: String) -> String:
	return str(get_item(item_id).get("name", item_id))

static func get_description(item_id: String) -> String:
	return str(get_item(item_id).get("description", ""))
