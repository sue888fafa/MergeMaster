class_name UnitVisualProfile
extends Resource

enum VisualTier {
	CROWD,
	HERO
}

const DIRECTION_COUNT := 4
const STATIC_DIRECTION_COUNT := 6
const FRAMES_PER_DIRECTION := 24
const ANIMATION_OFFSETS := {
	"idle": 0,
	"move": 4,
	"attack": 10,
	"hit": 16,
	"death": 18
}
const ANIMATION_COUNTS := {
	"idle": 4,
	"move": 6,
	"attack": 6,
	"hit": 2,
	"death": 6
}
const ANIMATION_FPS := {
	"idle": 6.0,
	"move": 10.0,
	"attack": 12.0,
	"hit": 10.0,
	"death": 10.0
}

# Runtime movement keeps six logical hex directions, while animated atlases
# author four cardinal/isometric views: down, left, right, and up.
const ANIMATION_DIRECTION_FOR_VISUAL_DIRECTION := [0, 3, 1, 3, 0, 2]

@export var profile_id := ""
@export var visual_tier := VisualTier.CROWD
@export var base_texture: Texture2D
@export var faction_mask_texture: Texture2D
@export var frame_size := Vector2i(96, 96)
@export var atlas_columns := 10
@export var atlas_rows := 10
@export var atlas_animation_enabled := false
@export var directional_static_enabled := false
@export var render_size := Vector2(40.0, 40.0)
@export var pivot_offset := Vector2(0.0, -3.0)

func configure_static(next_id: String, texture: Texture2D, mask_texture: Texture2D = null) -> UnitVisualProfile:
	profile_id = next_id
	base_texture = texture
	faction_mask_texture = mask_texture
	frame_size = Vector2i(texture.get_width(), texture.get_height()) if texture != null else Vector2i.ONE
	atlas_columns = 1
	atlas_rows = 1
	atlas_animation_enabled = false
	directional_static_enabled = false
	return self

func configure_atlas(next_id: String, texture: Texture2D, mask_texture: Texture2D = null) -> UnitVisualProfile:
	profile_id = next_id
	base_texture = texture
	faction_mask_texture = mask_texture
	frame_size = Vector2i(96, 96)
	atlas_columns = 10
	atlas_rows = 10
	atlas_animation_enabled = true
	directional_static_enabled = false
	return self

func configure_directional_atlas(next_id: String, texture: Texture2D, mask_texture: Texture2D = null) -> UnitVisualProfile:
	profile_id = next_id
	base_texture = texture
	faction_mask_texture = mask_texture
	frame_size = Vector2i(96, 96)
	atlas_columns = 10
	atlas_rows = 10
	atlas_animation_enabled = false
	directional_static_enabled = true
	return self

func frame_index(animation_name: String, direction: int, elapsed: float, lod_level: int) -> int:
	if directional_static_enabled:
		return clampi(direction, 0, STATIC_DIRECTION_COUNT - 1)
	if not atlas_animation_enabled:
		return 0
	var state := animation_name if ANIMATION_COUNTS.has(animation_name) else "idle"
	var count := int(ANIMATION_COUNTS[state])
	var fps := float(ANIMATION_FPS[state])
	if lod_level == 1:
		fps = minf(fps, 12.0)
	elif lod_level >= 2:
		fps = 4.0
		count = mini(count, 2)
	var local_frame := int(floor(elapsed * fps)) % maxi(1, count)
	var animation_direction := animation_direction_for_visual_direction(direction)
	return animation_direction * FRAMES_PER_DIRECTION + int(ANIMATION_OFFSETS[state]) + local_frame

static func animation_direction_for_visual_direction(direction: int) -> int:
	return int(ANIMATION_DIRECTION_FOR_VISUAL_DIRECTION[clampi(direction, 0, ANIMATION_DIRECTION_FOR_VISUAL_DIRECTION.size() - 1)])

func normalized_frame(animation_name: String, direction: int, elapsed: float, lod_level: int) -> float:
	var total_frames := maxi(1, atlas_columns * atlas_rows)
	if total_frames <= 1:
		return 0.0
	return float(frame_index(animation_name, direction, elapsed, lod_level)) / float(total_frames - 1)

func atlas_grid() -> Vector2:
	return Vector2(maxi(1, atlas_columns), maxi(1, atlas_rows))

func frame_uv_size() -> Vector2:
	if base_texture == null:
		return Vector2.ONE
	return Vector2(frame_size) / Vector2(base_texture.get_width(), base_texture.get_height())
