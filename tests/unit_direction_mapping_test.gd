extends Node

const BattleUnitScript := preload("res://unit.gd")
const UnitVisualProfileScript := preload("res://unit_visual_profile.gd")

func _ready() -> void:
	var cases := [
		[Vector2(0.5, 0.8660254038), 0, "down-right"],
		[Vector2(0.5, -0.8660254038), 1, "up-right"],
		[Vector2(-1.0, 0.0), 2, "left"],
		[Vector2(-0.5, -0.8660254038), 3, "up-left"],
		[Vector2(-0.5, 0.8660254038), 4, "down-left"],
		[Vector2(1.0, 0.0), 5, "right"]
	]
	for test_case in cases:
		var actual := BattleUnitScript.direction_frame_for_movement(test_case[0])
		assert(actual == test_case[1], "%s selected frame %d, expected %d" % [test_case[2], actual, test_case[1]])
	assert(BattleUnitScript.direction_frame_for_movement(Vector2.ZERO) == 0, "zero movement must use the stable default frame")
	var animation_cases := [
		[0, 0], [1, 3], [2, 1], [3, 3], [4, 0], [5, 2]
	]
	for animation_case in animation_cases:
		assert(UnitVisualProfileScript.animation_direction_for_visual_direction(animation_case[0]) == animation_case[1], "visual direction mapping mismatch")
	print("UNIT_DIRECTION_MAPPING passed cases=%d" % cases.size())
	get_tree().quit()
