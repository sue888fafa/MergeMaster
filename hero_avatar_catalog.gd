class_name HeroAvatarCatalog
extends RefCounted

const Config := preload("res://game_config.gd")
const AVATAR_ART := {
	"blue": preload("res://assets/generated/settlement/avatar_blue.png"),
	"red": preload("res://assets/generated/settlement/avatar_red.png"),
	"yellow": preload("res://assets/generated/settlement/avatar_yellow.png"),
	"pink": preload("res://assets/generated/settlement/avatar_pink.png"),
	"green": preload("res://assets/generated/settlement/avatar_green.png"),
	"purple": preload("res://assets/generated/settlement/avatar_purple.png")
}

const FACTION_AVATAR_KEYS := {
	Config.FACTION_PLAYER: "blue",
	Config.FACTION_RED: "red",
	Config.FACTION_PURPLE: "purple",
	Config.FACTION_GREEN: "green"
}

static func get_for_faction(faction: int) -> Texture2D:
	var key := str(FACTION_AVATAR_KEYS.get(faction, ""))
	return AVATAR_ART.get(key, null)
