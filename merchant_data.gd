class_name MerchantData
extends RefCounted

const ITEM_DRAGON := "dragon"
const ITEM_UPGRADE := "upgrade"
const ITEM_STEEL_BARRIER := "steel_barrier"
const ITEM_BLIZZARD := "blizzard"
const ITEM_TRANSFER_CERTIFICATE := "transfer_certificate"

const ITEM_IDS := [
	ITEM_DRAGON,
	ITEM_UPGRADE,
	ITEM_STEEL_BARRIER,
	ITEM_BLIZZARD,
	ITEM_TRANSFER_CERTIFICATE
]

const ITEMS := {
	ITEM_DRAGON: {
		"name": "巨龙",
		"description": "摧毁指定的一座建筑，但不改变地块归属。"
	},
	ITEM_UPGRADE: {
		"name": "升级",
		"description": "升级指定的己方兵营，不能用于空地或满级兵营。"
	},
	ITEM_STEEL_BARRIER: {
		"name": "钢铁屏障",
		"description": "在己方空地建造高血量防御建筑，只能防御。"
	},
	ITEM_BLIZZARD: {
		"name": "暴风雪",
		"description": "冻结目标区域内的敌方单位，使其2秒无法攻击和移动。"
	},
	ITEM_TRANSFER_CERTIFICATE: {
		"name": "转让证书",
		"description": "将指定的敌方兵营转为己方建筑。"
	}
}

static func get_item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})

static func get_item_name(item_id: String) -> String:
	return str(get_item(item_id).get("name", item_id))

static func get_description(item_id: String) -> String:
	return str(get_item(item_id).get("description", ""))
