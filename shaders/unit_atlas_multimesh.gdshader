shader_type canvas_item;

uniform vec2 atlas_grid = vec2(1.0, 1.0);
uniform vec2 frame_uv_size = vec2(1.0, 1.0);
uniform sampler2D faction_mask : source_color;
uniform bool has_faction_mask = false;
uniform bool use_instance_tint = false;
uniform vec4 faction_tint : source_color = vec4(1.0);
uniform vec4 faction_color_player : source_color = vec4(0.22, 0.75, 0.95, 1.0);
uniform vec4 faction_color_red : source_color = vec4(1.0, 0.40, 0.37, 1.0);
uniform vec4 faction_color_purple : source_color = vec4(0.65, 0.43, 0.89, 1.0);
uniform vec4 faction_color_green : source_color = vec4(0.33, 0.79, 0.42, 1.0);

varying float instance_faction_code;

vec3 rgb_to_hsv(vec3 color) {
	vec4 factors = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 mix_a = mix(vec4(color.bg, factors.wz), vec4(color.gb, factors.xy), step(color.b, color.g));
	vec4 mix_b = mix(vec4(mix_a.xyw, color.r), vec4(color.r, mix_a.yzx), step(mix_a.x, color.r));
	float chroma = mix_b.x - min(mix_b.w, mix_b.y);
	float epsilon = 1.0e-10;
	return vec3(abs(mix_b.z + (mix_b.w - mix_b.y) / (6.0 * chroma + epsilon)), chroma / (mix_b.x + epsilon), mix_b.x);
}

vec3 hsv_to_rgb(vec3 color) {
	vec3 rgb = clamp(abs(mod(color.x * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
	return color.z * mix(vec3(1.0), rgb, color.y);
}

void vertex() {
	float frame_count = max(1.0, atlas_grid.x * atlas_grid.y);
	float frame_index = floor(INSTANCE_CUSTOM.r * max(1.0, frame_count - 1.0) + 0.5);
	instance_faction_code = INSTANCE_CUSTOM.g;
	vec2 frame = vec2(mod(frame_index, atlas_grid.x), floor(frame_index / atlas_grid.x));
	// QuadMesh uses a bottom-left UV origin while Godot's 2D textures use a
	// top-left origin. Flip V before applying the atlas cell offset so static
	// fallbacks and runtime atlases share the same upright orientation.
	vec2 quad_uv = vec2(UV.x, 1.0 - UV.y);
	UV = frame * frame_uv_size + quad_uv * frame_uv_size;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec3 sprite_color = base.rgb;
	if (has_faction_mask) {
		vec4 mask = texture(faction_mask, UV);
		vec3 tint = faction_tint.rgb;
		if (!use_instance_tint) {
			tint = faction_tint.rgb;
		} else if (distance(COLOR.rgb, vec3(1.0)) > 0.01) {
			// MultiMesh instance color carries the exact faction color.  This
			// avoids relying solely on INSTANCE_CUSTOM on renderers where custom
			// data is not forwarded consistently.
			tint = COLOR.rgb;
		} else if (instance_faction_code < 0.375) {
			tint = faction_color_player.rgb;
		} else if (instance_faction_code < 0.625) {
			tint = faction_color_red.rgb;
		} else if (instance_faction_code < 0.875) {
			tint = faction_color_purple.rgb;
		} else {
			tint = faction_color_green.rgb;
		}
		// Preserve the source artwork's luminance so folds, shadows and highlights
		// remain visible after applying the faction hue. Every faction uses the
		// mask as the only recolor region; the original blue pixels are never used
		// as a second coverage signal.
		// Replace the hue directly in HSV space.  This removes the original blue
		// hue instead of only multiplying it, while retaining the artwork's value
		// variation for folds and highlights.
		vec3 base_hsv = rgb_to_hsv(base.rgb);
		vec3 faction_hsv = rgb_to_hsv(tint);
		base_hsv.x = faction_hsv.x;
		base_hsv.y = max(base_hsv.y, 0.78);
		base_hsv.z = max(base_hsv.z, 0.30);
		vec3 faction_surface = hsv_to_rgb(base_hsv);
		// Replace the masked garment directly. Only translucent mask edge pixels
		// receive a tiny anti-alias transition; the opaque mask interior never
		// mixes with the original blue artwork.
		if (mask.a >= 0.5) {
			sprite_color = faction_surface;
		} else if (mask.a > 0.0) {
			float edge_coverage = smoothstep(0.0, 0.5, mask.a);
			sprite_color = mix(base.rgb, faction_surface, edge_coverage);
		}
	}
	// Preserve CanvasItem modulation for the non-batched fallback sprite. Its
	// red modulate is only applied while that individual unit is hit. Batched
	// units use COLOR as their faction tint above, so it must not be multiplied
	// over the whole sprite a second time.
	if (!use_instance_tint) {
		sprite_color *= COLOR.rgb;
	}
	COLOR = vec4(sprite_color, base.a * COLOR.a);
}
