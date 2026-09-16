class_name UnitVisualCatalog
extends RefCounted

const UnitVisualProfileScript := preload("res://unit_visual_profile.gd")
const UNIT_ART: Array[Texture2D] = [
	preload("res://assets/generated/unit_tank.png"),
	preload("res://assets/generated/unit_warrior.png"),
	preload("res://assets/generated/unit_mage.png"),
	preload("res://assets/generated/unit_assassin.png"),
	preload("res://assets/generated/unit_archer.png")
]
const UNIT_MASKS: Array[Texture2D] = [
	preload("res://assets/generated/unit_tank_mask.png"),
	preload("res://assets/generated/unit_warrior_mask.png"),
	preload("res://assets/generated/unit_mage_mask.png"),
	preload("res://assets/generated/unit_assassin_mask.png"),
	preload("res://assets/generated/unit_archer_mask.png")
]
const PROFILE_IDS := ["tank", "warrior", "mage", "assassin", "archer"]
const RUNTIME_ROOT := "res://assets/units/runtime"

static var _profiles: Array[UnitVisualProfile] = []

static func get_profile(unit_class: int) -> UnitVisualProfile:
	_ensure_profiles()
	return _profiles[clampi(unit_class, 0, _profiles.size() - 1)]

static func get_profiles() -> Array[UnitVisualProfile]:
	_ensure_profiles()
	return _profiles

static func _ensure_profiles() -> void:
	if not _profiles.is_empty():
		return
	for index in range(UNIT_ART.size()):
		var profile := UnitVisualProfileScript.new()
		var profile_id: String = PROFILE_IDS[index]
		var atlas_path := "%s/%s_base.png" % [RUNTIME_ROOT, profile_id]
		var mask_path := "%s/%s_mask.png" % [RUNTIME_ROOT, profile_id]
		if profile_id == "warrior":
			atlas_path = "%s/%s_anim_base.png" % [RUNTIME_ROOT, profile_id]
			mask_path = "%s/%s_anim_mask.png" % [RUNTIME_ROOT, profile_id]
		if ResourceLoader.exists(atlas_path):
			var mask_texture: Texture2D = null
			if ResourceLoader.exists(mask_path):
				mask_texture = load(mask_path) as Texture2D
			if profile_id == "warrior":
				profile.configure_atlas(profile_id, load(atlas_path) as Texture2D, mask_texture)
			else:
				profile.configure_directional_atlas(profile_id, load(atlas_path) as Texture2D, mask_texture)
		else:
			profile.configure_static(profile_id, UNIT_ART[index], UNIT_MASKS[index])
		_profiles.append(profile)
