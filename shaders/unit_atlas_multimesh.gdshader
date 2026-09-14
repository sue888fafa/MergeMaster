shader_type canvas_item;

uniform vec2 atlas_grid = vec2(1.0, 1.0);
uniform vec2 frame_uv_size = vec2(1.0, 1.0);
uniform sampler2D faction_mask : source_color;
uniform bool has_faction_mask = false;

void vertex() {
	float frame_count = max(1.0, atlas_grid.x * atlas_grid.y);
	float frame_index = floor(INSTANCE_CUSTOM.r * max(1.0, frame_count - 1.0) + 0.5);
	vec2 frame = vec2(mod(frame_index, atlas_grid.x), floor(frame_index / atlas_grid.x));
	// QuadMesh uses a bottom-left UV origin while Godot's 2D textures use a
	// top-left origin. Flip V before applying the atlas cell offset so static
	// fallbacks and runtime atlases share the same upright orientation.
	vec2 quad_uv = vec2(UV.x, 1.0 - UV.y);
	UV = frame * frame_uv_size + quad_uv * frame_uv_size;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (has_faction_mask) {
		vec4 mask = texture(faction_mask, UV);
		vec3 faction_surface = COLOR.rgb * mask.rgb;
		float coverage = mask.a;
		COLOR = vec4(mix(base.rgb, faction_surface, coverage), max(base.a, mask.a) * COLOR.a);
	} else {
		COLOR = base;
	}
}
