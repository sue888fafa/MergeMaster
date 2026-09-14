class_name UnitVisualLayer
extends Node2D

const Config := preload("res://game_config.gd")
const Catalog := preload("res://unit_visual_catalog.gd")
const ATLAS_SHADER := preload("res://shaders/unit_atlas_multimesh.gdshader")

const LOD_NEAR := 0
const LOD_MID := 1
const LOD_FAR := 2
const NEAR_ZOOM := 0.85
const MID_ZOOM := 0.65
const NEAR_REFRESH := 1.0 / 24.0
const MID_REFRESH := 1.0 / 12.0
const FAR_REFRESH := 1.0 / 8.0
const DEPTH_BUCKET_COUNT := 8
const DEATH_DURATION := 0.60

var controller: Node
var camera: Camera2D
var refresh_accumulator := 0.0
var current_lod := LOD_NEAR
var profile_renderers: Array[Array] = []
var shadow_renderer: MultiMeshInstance2D
var halo_renderer: MultiMeshInstance2D
var health_back_renderer: MultiMeshInstance2D
var health_fill_renderer: MultiMeshInstance2D
var death_visuals: Array[Dictionary] = []

func _ready() -> void:
	controller = get_parent()
	camera = controller.get_node_or_null("Camera2D") as Camera2D
	_build_renderers()
	set_process(true)

func is_batch_unit_layer() -> bool:
	return true

func request_visual_refresh() -> void:
	refresh_accumulator = 999.0

func get_visual_draw_call_budget() -> int:
	return Catalog.get_profiles().size() * DEPTH_BUCKET_COUNT + 4

func get_active_visual_batches() -> int:
	var active := 0
	for buckets in profile_renderers:
		for renderer in buckets:
			if renderer.multimesh.visible_instance_count > 0:
				active += 1
	for renderer in [shadow_renderer, halo_renderer, health_back_renderer, health_fill_renderer]:
		if renderer != null and renderer.multimesh.visible_instance_count > 0:
			active += 1
	return active

func play_unit_death(unit: Node) -> void:
	if not is_instance_valid(unit):
		return
	death_visuals.append({
		"unit_class": int(unit.get("unit_class")),
		"faction": int(unit.get("faction")),
		"barracks_level": int(unit.get("barracks_level")),
		"position": Vector2(unit.position),
		"direction": int(unit.call("get_visual_direction")) if unit.has_method("get_visual_direction") else 0,
		"elapsed": 0.0
	})
	request_visual_refresh()

func _process(delta: float) -> void:
	if controller == null:
		controller = get_parent()
	if camera == null and controller != null:
		camera = controller.get_node_or_null("Camera2D") as Camera2D
	for index in range(death_visuals.size() - 1, -1, -1):
		death_visuals[index]["elapsed"] = float(death_visuals[index]["elapsed"]) + delta
		if float(death_visuals[index]["elapsed"]) >= DEATH_DURATION:
			death_visuals.remove_at(index)
	current_lod = _lod_for_zoom(camera.zoom.x if camera != null else Config.INITIAL_CAMERA_ZOOM)
	refresh_accumulator += delta
	var interval := NEAR_REFRESH if current_lod == LOD_NEAR else MID_REFRESH if current_lod == LOD_MID else FAR_REFRESH
	if refresh_accumulator < interval:
		return
	refresh_accumulator = fmod(refresh_accumulator, interval)
	_rebuild_instances()

func _build_renderers() -> void:
	for profile in Catalog.get_profiles():
		var buckets: Array[MultiMeshInstance2D] = []
		var shared_material := _make_atlas_material(profile)
		for bucket_index in range(DEPTH_BUCKET_COUNT):
			var renderer := _make_atlas_renderer(profile, shared_material, bucket_index)
			buckets.append(renderer)
		profile_renderers.append(buckets)
	# One shared multimesh keeps the foot shadow inexpensive even with many
	# soldiers on screen.
	shadow_renderer = _make_solid_renderer(Vector2(29.0, 10.0), Color(0.02, 0.04, 0.08, 0.48), -2, _make_ellipse_texture(false))
	halo_renderer = _make_solid_renderer(Vector2(36.0, 18.0), Color.WHITE, -1, _make_ellipse_texture(true))
	health_back_renderer = _make_solid_renderer(Vector2(26.0, 4.0), Color("#172033"), DEPTH_BUCKET_COUNT + 1)
	health_fill_renderer = _make_solid_renderer(Vector2(22.0, 2.0), Color.WHITE, DEPTH_BUCKET_COUNT + 2)

func _make_atlas_material(profile: UnitVisualProfile) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = ATLAS_SHADER
	material.set_shader_parameter("atlas_grid", profile.atlas_grid())
	material.set_shader_parameter("frame_uv_size", profile.frame_uv_size())
	material.set_shader_parameter("has_faction_mask", profile.faction_mask_texture != null)
	if profile.faction_mask_texture != null:
		material.set_shader_parameter("faction_mask", profile.faction_mask_texture)
	return material

func _make_atlas_renderer(profile: UnitVisualProfile, material: ShaderMaterial, layer_z: int) -> MultiMeshInstance2D:
	var renderer := MultiMeshInstance2D.new()
	renderer.z_index = layer_z
	renderer.texture = profile.base_texture
	renderer.material = material
	var quad := QuadMesh.new()
	quad.size = profile.render_size
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	renderer.multimesh = multimesh
	add_child(renderer)
	return renderer

func _make_solid_renderer(size: Vector2, color: Color, layer_z: int, texture: Texture2D = null) -> MultiMeshInstance2D:
	var renderer := MultiMeshInstance2D.new()
	renderer.z_index = layer_z
	renderer.modulate = color
	renderer.texture = texture
	var quad := QuadMesh.new()
	quad.size = size
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.mesh = quad
	renderer.multimesh = multimesh
	add_child(renderer)
	return renderer

func _make_ellipse_texture(ring_only: bool) -> ImageTexture:
	var size := 64
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var normalized := Vector2(
				(float(x) + 0.5) / float(size) * 2.0 - 1.0,
				(float(y) + 0.5) / float(size) * 2.0 - 1.0
			)
			var distance := normalized.length()
			var outer_alpha := clampf((1.0 - distance) / 0.14, 0.0, 1.0)
			var alpha := outer_alpha
			if ring_only:
				var inner_alpha := clampf((distance - 0.68) / 0.12, 0.0, 1.0)
				alpha *= inner_alpha
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)

func _rebuild_instances() -> void:
	if controller == null:
		_clear_instances()
		return
	var controller_units = controller.get("units")
	if controller_units == null:
		_clear_instances()
		return
	var grouped: Array[Array] = []
	for _profile_index in range(profile_renderers.size()):
		var buckets: Array[Array] = []
		for _bucket_index in range(DEPTH_BUCKET_COUNT):
			buckets.append([])
		grouped.append(buckets)
	var visible_units: Array = []
	var view_bounds := _visible_world_bounds()
	var padded_bounds := view_bounds.grow(120.0)
	for unit in controller_units:
		if not is_instance_valid(unit) or not padded_bounds.has_point(unit.position):
			continue
		var class_index := clampi(int(unit.unit_class), 0, grouped.size() - 1)
		var bucket_index := _depth_bucket_for_position(unit.position.y, view_bounds)
		grouped[class_index][bucket_index].append(unit)
		visible_units.append(unit)
	for death in death_visuals:
		var death_position: Vector2 = death["position"]
		if not padded_bounds.has_point(death_position):
			continue
		var class_index := clampi(int(death["unit_class"]), 0, grouped.size() - 1)
		var bucket_index := _depth_bucket_for_position(death_position.y, view_bounds)
		grouped[class_index][bucket_index].append(death)
	_update_decorative_instances(visible_units)
	for class_index in range(grouped.size()):
		for bucket_index in range(DEPTH_BUCKET_COUNT):
			_update_profile_instances(class_index, bucket_index, grouped[class_index][bucket_index])

func _update_profile_instances(class_index: int, bucket_index: int, entries: Array) -> void:
	var profile := Catalog.get_profile(class_index)
	var renderer := profile_renderers[class_index][bucket_index] as MultiMeshInstance2D
	var multimesh: MultiMesh = renderer.multimesh
	_prepare_instances(multimesh, entries.size())
	for index in range(entries.size()):
		var entry = entries[index]
		var is_death := entry is Dictionary
		var level := int(entry["barracks_level"]) if is_death else int(entry.barracks_level)
		var entry_position: Vector2 = Vector2(entry["position"]) if is_death else entry.position
		var direction := int(entry["direction"]) if is_death else int(entry.get_visual_direction())
		var animation_name := "death" if is_death else str(entry.get_visual_animation())
		var elapsed := float(entry["elapsed"]) if is_death else float(entry.get_visual_elapsed())
		var faction := int(entry["faction"]) if is_death else int(entry.faction)
		var level_scale := float(Config.UNIT_LEVEL_VISUAL_SCALE[clampi(level, 1, 4) - 1])
		var origin: Vector2 = entry_position + profile.pivot_offset * level_scale
		var transform := Transform2D(0.0, Vector2(level_scale, level_scale), 0.0, origin)
		var frame_value := profile.normalized_frame(animation_name, direction, elapsed, current_lod)
		multimesh.set_instance_transform_2d(index, transform)
		multimesh.set_instance_color(index, _faction_color(faction))
		multimesh.set_instance_custom_data(index, Color(frame_value, 0.0, 0.0, 0.0))

func _update_decorative_instances(units: Array) -> void:
	var shadow_units: Array = [] if current_lod == LOD_FAR else units
	_prepare_instances(shadow_renderer.multimesh, shadow_units.size())
	for index in range(shadow_units.size()):
		var unit = shadow_units[index]
		var scale := float(Config.UNIT_LEVEL_VISUAL_SCALE[clampi(int(unit.barracks_level), 1, 4) - 1])
		shadow_renderer.multimesh.set_instance_transform_2d(index, Transform2D(0.0, Vector2(scale, scale), 0.0, unit.position + Vector2(2.0, 15.0) * scale))
		shadow_renderer.multimesh.set_instance_color(index, Color.WHITE)
	_prepare_instances(halo_renderer.multimesh, units.size())
	for index in range(units.size()):
		var unit = units[index]
		var scale := float(Config.UNIT_LEVEL_VISUAL_SCALE[clampi(int(unit.barracks_level), 1, 4) - 1])
		var halo_color := Color(0.35, 0.9, 1.0, 0.72) if bool(unit.is_frozen()) else Color(_faction_color(int(unit.faction)), 0.42)
		halo_renderer.multimesh.set_instance_transform_2d(index, Transform2D(0.0, Vector2(scale, scale), 0.0, unit.position + Vector2(0.0, 5.0) * scale))
		halo_renderer.multimesh.set_instance_color(index, halo_color)
	var damaged: Array = []
	if current_lod != LOD_FAR:
		for unit in units:
			var combat_target = unit.get("combat_target")
			var in_combat: bool = false
			if combat_target is Dictionary:
				in_combat = not combat_target.is_empty()
			if float(unit.hp) < float(unit.max_hp) or in_combat:
				damaged.append(unit)
	_prepare_instances(health_back_renderer.multimesh, damaged.size())
	_prepare_instances(health_fill_renderer.multimesh, damaged.size())
	for index in range(damaged.size()):
		var unit = damaged[index]
		var scale := float(Config.UNIT_LEVEL_VISUAL_SCALE[clampi(int(unit.barracks_level), 1, 4) - 1])
		var ratio := clampf(float(unit.hp) / maxf(1.0, float(unit.max_hp)), 0.0, 1.0)
		var bar_position: Vector2 = unit.position + Vector2(0.0, -18.0) * scale
		health_back_renderer.multimesh.set_instance_transform_2d(index, Transform2D(0.0, Vector2(scale, scale), 0.0, bar_position))
		health_back_renderer.multimesh.set_instance_color(index, Color.WHITE)
		var fill_position := bar_position + Vector2((-11.0 + 11.0 * ratio) * scale, 0.0)
		health_fill_renderer.multimesh.set_instance_transform_2d(index, Transform2D(0.0, Vector2(scale * ratio, scale), 0.0, fill_position))
		health_fill_renderer.multimesh.set_instance_color(index, Color("#4ade80"))

func _clear_instances() -> void:
	for buckets in profile_renderers:
		for renderer in buckets:
			renderer.multimesh.visible_instance_count = 0
	for renderer in [shadow_renderer, halo_renderer, health_back_renderer, health_fill_renderer]:
		if renderer != null:
			renderer.multimesh.visible_instance_count = 0

func _prepare_instances(multimesh: MultiMesh, count: int) -> void:
	if multimesh.instance_count < count:
		multimesh.instance_count = maxi(count, maxi(8, multimesh.instance_count * 2))
	multimesh.visible_instance_count = count

func _lod_for_zoom(zoom: float) -> int:
	if zoom >= NEAR_ZOOM:
		return LOD_NEAR
	if zoom >= MID_ZOOM:
		return LOD_MID
	return LOD_FAR

func _visible_world_bounds() -> Rect2:
	if camera == null:
		return Rect2(Vector2(-100000.0, -100000.0), Vector2(200000.0, 200000.0))
	var viewport_size := get_viewport().get_visible_rect().size / maxf(camera.zoom.x, 0.01)
	return Rect2(camera.position - viewport_size * 0.5, viewport_size)

func _depth_bucket_for_position(world_y: float, view_bounds: Rect2) -> int:
	var normalized_y := inverse_lerp(view_bounds.position.y, view_bounds.end.y, world_y)
	return clampi(int(floor(normalized_y * float(DEPTH_BUCKET_COUNT))), 0, DEPTH_BUCKET_COUNT - 1)

func _faction_color(faction: int) -> Color:
	if controller != null and controller.has_method("get_faction_color"):
		return controller.call("get_faction_color", faction)
	return Color(str(Config.FACTION_COLORS.get(faction, "#94a3b8")))
