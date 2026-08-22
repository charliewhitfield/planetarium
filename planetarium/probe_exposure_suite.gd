# probe_exposure_suite.gd
# TEMPORARY verification harness for the physical-light feature. Registered via
# the untracked res://ivoyager_override2.cfg [assistant_test_suites] section;
# neither file is committed. DELETE BOTH at feature completion.
extends IVAssistantTestSuite

## Exposes IVExposureManager state, derived photometry, and scene values the
## manager drives, so assistant-driven tests can assert the physical-light
## chain numerically and verify runtime-toggle restoration.


var _lights: Array[IVDynamicLight] = []
var _world_environment: WorldEnvironment
var _sun_disc_material: ShaderMaterial


func _on_simulator_started() -> void:
	_lights.clear()
	_collect(IVGlobal.get_tree().root)


func _on_about_to_free() -> void:
	_lights.clear()
	_world_environment = null
	_sun_disc_material = null


func get_method_names() -> Array[String]:
	return ["get_exposure_state", "get_photometry", "get_metering_table", "set_physical_light",
			"get_body_debug", "set_ambient_energy", "set_reflected_light", "list_lights",
			"poke_sky_radiance", "get_shadow_receivers"]


func get_method_summaries() -> Dictionary:
	return {
		"get_exposure_state": "Report exposure statics, light energies, and managed scene values.",
		"get_photometry": "Report the manager's tuning members and derived calibration.",
		"get_metering_table": "Report per-body metering rows (mirrors manager math; no parent shadow).",
		"set_physical_light": "Set the physical_light user setting ({\"enabled\": bool}).",
		"get_body_debug": "Report an IVBody's metering-relevant state ({\"name\": entity_name}).",
		"set_ambient_energy": "Override Environment.ambient_light_energy ({\"energy\": float}).",
		"set_reflected_light": "Set Environment.reflected_light_source ({\"disabled\": bool}).",
		"list_lights": "List every Light3D in the tree with energy/visibility.",
		"poke_sky_radiance": "Rewrite the sky material's energy_multiplier to trigger a radiance rebake.",
		"get_shadow_receivers": "Report per-body analytic-occlusion opt-in, visual layers, and parent-shadow fraction.",
	}


func dispatch(method: String, params: Dictionary) -> Variant:
	match method:
		"get_exposure_state":
			return _get_exposure_state()
		"get_photometry":
			return _get_photometry()
		"get_metering_table":
			return _get_metering_table()
		"set_physical_light":
			return _set_physical_light(params)
		"get_body_debug":
			return _get_body_debug(params)
		"set_ambient_energy":
			return _set_ambient_energy(params)
		"set_reflected_light":
			return _set_reflected_light(params)
		"list_lights":
			return _list_lights()
		"poke_sky_radiance":
			return _poke_sky_radiance()
		"get_shadow_receivers":
			return _get_shadow_receivers()
	return {"_error": {"code": ERR_UNKNOWN_METHOD, "message": "Unknown method: %s" % method}}


func _set_ambient_energy(params: Dictionary) -> Variant:
	if !_world_environment or !_world_environment.environment:
		return {"_error": {"code": ERR_UNAVAILABLE, "message": "No WorldEnvironment"}}
	var energy_var: Variant = params.get("energy")
	if typeof(energy_var) != TYPE_FLOAT:
		return {"_error": {"code": ERR_INVALID_PARAMS, "message": "Missing 'energy' float"}}
	var energy: float = energy_var
	_world_environment.environment.ambient_light_energy = energy
	return {"ok": true, "ambient_light_energy": energy}


func _set_reflected_light(params: Dictionary) -> Variant:
	if !_world_environment or !_world_environment.environment:
		return {"_error": {"code": ERR_UNAVAILABLE, "message": "No WorldEnvironment"}}
	var disabled: bool = params.get("disabled", true)
	_world_environment.environment.reflected_light_source = (
			Environment.REFLECTION_SOURCE_DISABLED if disabled
			else Environment.REFLECTION_SOURCE_BG)
	return {"ok": true, "disabled": disabled}


func _list_lights() -> Variant:
	var rows: Array[Dictionary] = []
	for node in IVGlobal.get_tree().root.find_children("*", "Light3D", true, false):
		var light: Light3D = node
		rows.append({
			"name": String(light.name),
			"class": light.get_class(),
			"visible_in_tree": light.is_visible_in_tree(),
			"light_energy": light.light_energy,
			"parent": String(light.get_parent().name) if light.get_parent() else "",
		})
	return {"lights": rows}


func _poke_sky_radiance() -> Variant:
	if !_world_environment or !_world_environment.environment:
		return {"_error": {"code": ERR_UNAVAILABLE, "message": "No WorldEnvironment"}}
	var sky := _world_environment.environment.sky
	if !sky or not sky.sky_material is ShaderMaterial:
		return {"_error": {"code": ERR_UNAVAILABLE, "message": "No shader sky"}}
	var sky_material: ShaderMaterial = sky.sky_material
	var energy_var: Variant = sky_material.get_shader_parameter(&"energy_multiplier")
	sky_material.set_shader_parameter(&"energy_multiplier", energy_var)
	return {"ok": true, "energy_multiplier": energy_var}


func _get_body_debug(params: Dictionary) -> Variant:
	var name_string: String = params.get("name", "")
	var body: IVBody = IVBody.bodies.get(StringName(name_string))
	if !body:
		return {"_error": {"code": ERR_DOES_NOT_EXIST,
				"message": "No IVBody '%s' in IVBody.bodies" % name_string}}
	var camera := IVGlobal.get_viewport().get_camera_3d()
	var camera_distance := -1.0
	if camera:
		camera_distance = (body.global_position - camera.global_position).length()
	return {
		"visible": body.visible,
		"mean_radius": body.mean_radius,
		"camera_distance": camera_distance,
		"flags": body.flags,
		"albedo_characteristic": body.characteristics.get(&"albedo"),
		"child_count": body.get_child_count(),
	}


func _collect(node: Node) -> void:
	if node is IVDynamicLight:
		var light: IVDynamicLight = node
		_lights.append(light)
	elif node is WorldEnvironment:
		var world_environment: WorldEnvironment = node
		_world_environment = world_environment
	for child in node.get_children():
		_collect(child)


func _find_sun_disc_material() -> void:
	if _sun_disc_material:
		return
	var star: IVBody = IVBody.bodies.get(&"STAR_SUN")
	if !star:
		return
	for node in star.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = node
		if mesh_instance.get_surface_override_material_count() < 1:
			continue
		var material := mesh_instance.get_surface_override_material(0)
		if material is ShaderMaterial:
			var shader_material: ShaderMaterial = material
			if shader_material.get_shader_parameter(&"brightness") != null:
				_sun_disc_material = shader_material
				return


func _get_starmap_energy() -> float:
	if !_world_environment or !_world_environment.environment:
		return NAN
	var sky := _world_environment.environment.sky
	if !sky:
		return NAN
	var sky_material := sky.sky_material
	if sky_material is ShaderMaterial:
		var shader_material: ShaderMaterial = sky_material
		var energy_var: Variant = shader_material.get_shader_parameter(&"energy_multiplier")
		if typeof(energy_var) == TYPE_FLOAT:
			var energy: float = energy_var
			return energy
	return NAN


func _get_exposure_state() -> Dictionary:
	_find_sun_disc_material()
	var light_names: Array[String] = []
	var light_energies: Array[float] = []
	for light in _lights:
		light_names.append(light.name)
		light_energies.append(light.light_energy)
	var result := {
		"physical_active": IVExposureManager.physical_active,
		"exposure": IVExposureManager.exposure,
		"gain": IVExposureManager.gain,
		"sky_energy": IVExposureManager.sky_energy,
		"setting_physical_light": IVSettingsManager.get_setting(&"physical_light"),
		"light_names": light_names,
		"light_energies": light_energies,
		"starmap_energy": _get_starmap_energy(),
		"camera_sun_visible_fraction": IVSunOcclusionManager.camera_sun_visible_fraction,
	}
	if _world_environment and _world_environment.environment:
		var environment := _world_environment.environment
		result["ambient_light_energy"] = environment.ambient_light_energy
		result["tonemap_exposure"] = environment.tonemap_exposure
	if _sun_disc_material:
		var brightness_var: Variant = _sun_disc_material.get_shader_parameter(&"brightness")
		result["sun_disc_brightness"] = brightness_var
		result["sun_handoff_low"] = _sun_disc_material.get_shader_parameter(&"handoff_low")
		result["sun_handoff_high"] = _sun_disc_material.get_shader_parameter(&"handoff_high")
	return result


func _get_photometry() -> Dictionary:
	var manager_var: Variant = IVGlobal.program.get(&"ExposureManager")
	if not manager_var is IVExposureManager:
		return {"_error": {"code": ERR_NOT_ALLOWED,
				"message": "No ExposureManager (enable_physical_light off?)"}}
	var manager: IVExposureManager = manager_var
	return {
		"background_peak_magnitude_per_arcsec2": manager.background_peak_magnitude_per_arcsec2,
		"metering_key": manager.metering_key,
		"meter_fraction_start": manager.meter_fraction_start,
		"meter_fraction_full": manager.meter_fraction_full,
		"adapt_darken_ev_per_second": manager.adapt_darken_ev_per_second,
		"adapt_brighten_ev_per_second": manager.adapt_brighten_ev_per_second,
		"snap_ev_threshold": manager.snap_ev_threshold,
		"default_albedo": manager.default_albedo,
		"exposure_max_ev": manager.exposure_max_ev,
		"meter_transition_exponent": manager.meter_transition_exponent,
		"nightside_onset_lit_fraction": manager.nightside_onset_lit_fraction,
		"nightside_full_lit_fraction": manager.nightside_full_lit_fraction,
		"nightside_twilight_angle": manager.nightside_twilight_angle,
		"star_meter_fraction_start": manager.star_meter_fraction_start,
		"star_meter_fraction_full": manager.star_meter_fraction_full,
		"ambient_starlight_illuminance": manager.ambient_starlight_illuminance,
		"mag0_illuminance": IVAstronomy.MAG0_ILLUMINANCE,
		"sb0_luminance": IVAstronomy.SB0_LUMINANCE,
		"gain": IVExposureManager.gain,
		"sky_energy": IVExposureManager.sky_energy,
	}


# Hand-mirrors IVExposureManager._get_metering_target so tests can inspect
# per-candidate rows (lit/dark/star: screen fraction, weight, view factor,
# luminance, candidate exposure). Parent-shadow term omitted. Scaffolding
# only; keep in sync by hand.
func _get_metering_table() -> Dictionary:
	var manager_var: Variant = IVGlobal.program.get(&"ExposureManager")
	if not manager_var is IVExposureManager:
		return {"_error": {"code": ERR_NOT_ALLOWED,
				"message": "No ExposureManager (enable_physical_light off?)"}}
	var manager: IVExposureManager = manager_var
	var camera := IVGlobal.get_viewport().get_camera_3d()
	var star: IVBody = IVBody.bodies.get(&"STAR_SUN")
	if !camera or !star:
		return {"_error": {"code": ERR_UNAVAILABLE, "message": "No camera or star"}}
	var magnitude_var: Variant = star.characteristics.get(&"absolute_magnitude")
	if typeof(magnitude_var) != TYPE_FLOAT:
		return {"_error": {"code": ERR_UNAVAILABLE, "message": "No star absolute_magnitude"}}
	var star_absolute_magnitude: float = magnitude_var
	var view_size := camera.get_viewport().get_visible_rect().size
	var tan_half_fov := tan(deg_to_rad(camera.fov) * 0.5)
	var aspect := view_size.x / view_size.y
	var fraction_per_theta_sq := PI / (4.0 * tan_half_fov * tan_half_fov * aspect)
	var star_position := star.global_position
	var camera_position := camera.global_position
	var gain := IVExposureManager.gain
	var rest_exposure := 2.0 ** manager.exposure_max_ev
	var log_rest := log(rest_exposure)
	var rows: Array[Dictionary] = []
	for body_name: StringName in IVBody.bodies:
		var body := IVBody.bodies[body_name]
		if !body.visible or body.mean_radius <= 0.0 or gain <= 0.0:
			continue
		var camera_vector := body.global_position - camera_position
		var camera_distance := camera_vector.length()
		if camera_distance <= 0.0:
			continue
		var angular_radius := minf(body.mean_radius / camera_distance, 1.0)
		var screen_fraction := fraction_per_theta_sq * angular_radius * angular_radius
		var view_factor := _view_factor(camera, manager, body.global_position, angular_radius,
				view_size, tan_half_fov, aspect)
		if view_factor <= 0.0:
			continue
		if (body.flags & IVBody.BodyFlags.BODYFLAGS_STAR) != 0:
			if body != star:
				continue
			screen_fraction *= IVSunOcclusionManager.camera_sun_visible_fraction
			var star_weight := view_factor * _ramp_weight(screen_fraction,
					manager.star_meter_fraction_start, manager.star_meter_fraction_full)
			if star_weight <= 0.0:
				continue
			var disc_luminance := IVAstronomy.get_star_disc_luminance(
					star_absolute_magnitude, body.mean_radius)
			rows.append({
				"name": String(body_name), "candidate": "star",
				"screen_fraction": screen_fraction, "weight": star_weight,
				"view_factor": view_factor, "luminance": disc_luminance,
				"candidate_exposure": _candidate_exposure(manager, disc_luminance,
						star_weight, log_rest, rest_exposure),
			})
			continue
		var star_vector := star_position - body.global_position
		var star_distance := star_vector.length()
		if star_distance <= 0.0:
			continue
		var phase_cos := -star_vector.dot(camera_vector) / (star_distance * camera_distance)
		var lit_visible := (1.0 + phase_cos) * 0.5
		var phase_angle := acos(clampf(phase_cos, -1.0, 1.0))
		var lit_visible_cutoff := PI / 2.0 + acos(clampf(
				body.mean_radius / camera_distance, 0.0, 1.0))
		var horizon_factor := 1.0 - smoothstep(
				lit_visible_cutoff - manager.nightside_twilight_angle,
				lit_visible_cutoff, phase_angle)
		lit_visible = clampf(lit_visible * horizon_factor, 0.0, 1.0)
		var albedo := manager.default_albedo
		var albedo_var: Variant = body.characteristics.get(&"albedo")
		if typeof(albedo_var) == TYPE_FLOAT:
			var albedo_value: float = albedo_var
			if albedo_value > 0.0: # empty cell imports non-positive; mirror manager
				albedo = albedo_value
		var apparent_magnitude := IVAstronomy.get_apparent_magnitude(
				star_absolute_magnitude, star_distance)
		var illuminance := IVAstronomy.get_illuminance_from_apparent_magnitude(
				apparent_magnitude)
		var lit_luminance := albedo * (illuminance
				+ manager.ambient_starlight_illuminance) / PI
		var dark_luminance := albedo * manager.ambient_starlight_illuminance / PI
		var lit_hold := _ramp_weight(lit_visible, manager.nightside_full_lit_fraction,
				manager.nightside_onset_lit_fraction)
		var candidates := [
			["lit", screen_fraction * lit_visible, lit_luminance, lit_hold],
			["dark", screen_fraction * (1.0 - lit_visible), dark_luminance, 1.0],
		]
		for candidate_var: Array in candidates:
			var tag: String = candidate_var[0]
			var candidate_fraction: float = candidate_var[1]
			var luminance: float = candidate_var[2]
			var hold: float = candidate_var[3]
			var weight: float = view_factor * hold * _ramp_weight(candidate_fraction,
					manager.meter_fraction_start, manager.meter_fraction_full)
			if weight <= 0.0 or luminance <= 0.0:
				continue
			rows.append({
				"name": String(body_name), "candidate": tag,
				"screen_fraction": candidate_fraction, "weight": weight,
				"view_factor": view_factor, "lit_visible": lit_visible,
				"horizon_factor": horizon_factor, "albedo": albedo,
				"luminance": luminance,
				"candidate_exposure": _candidate_exposure(manager, luminance, weight,
						log_rest, rest_exposure),
			})
		var ring_row := _get_ring_row(manager, camera, body, camera_vector, camera_distance,
				star_vector, star_distance, illuminance, fraction_per_theta_sq, view_size,
				tan_half_fov, aspect, log_rest, rest_exposure)
		if !ring_row.is_empty():
			rows.append(ring_row)
	return {
		"exposure": IVExposureManager.exposure,
		"rest_exposure": rest_exposure,
		"rows": rows,
	}


# Mirrors IVExposureManager._get_view_factor.
func _view_factor(camera: Camera3D, manager: IVExposureManager, global_position: Vector3,
		angular_radius: float, view_size: Vector2, tan_half_fov: float, aspect: float) -> float:
	if camera.is_position_behind(global_position):
		return 0.0
	var screen_position := camera.unproject_position(global_position)
	var radius_fraction_y := angular_radius / (2.0 * tan_half_fov)
	var radius_fraction_x := radius_fraction_y / aspect
	var position_x := screen_position.x / view_size.x
	var position_y := screen_position.y / view_size.y
	var penetration_x := minf(position_x, 1.0 - position_x) + radius_fraction_x
	var penetration_y := minf(position_y, 1.0 - position_y) + radius_fraction_y
	var penetration := minf(penetration_x, penetration_y)
	if penetration <= 0.0:
		return 0.0
	return smoothstep(0.0, maxf(manager.meter_edge_fraction, 1e-4), penetration)


# Mirrors IVExposureManager._get_ring_candidate_exposure (parent shadow omitted,
# like the body rows). Returns {} when the ring doesn't meter.
func _get_ring_row(manager: IVExposureManager, camera: Camera3D, body: IVBody,
		camera_vector: Vector3, camera_distance: float, star_vector: Vector3,
		star_distance: float, illuminance: float, fraction_per_theta_sq: float,
		view_size: Vector2, tan_half_fov: float, aspect: float, log_rest: float,
		rest_exposure: float) -> Dictionary:
	const PHASE_EXPONENT := 6.0
	var row := IVTableData.db_find_in_array(&"rings", &"bodies", body.name)
	if row == -1:
		return {}
	var inner_radius := IVTableData.get_db_float(&"rings", &"inner_radius", row)
	var outer_radius := IVTableData.get_db_float(&"rings", &"outer_radius", row)
	var litside_phase_boost := 1.25 if IVGlobal.is_gl_compatibility else 3.0
	var axis := body.rotation_axis
	var sin_camera_elevation := -camera_vector.dot(axis) / camera_distance
	var sin_sun_elevation := star_vector.dot(axis) / star_distance
	if sin_camera_elevation * sin_sun_elevation <= 0.0:
		return {}
	var annulus_theta_sq := (outer_radius * outer_radius - inner_radius * inner_radius) \
			* absf(sin_camera_elevation) / (camera_distance * camera_distance)
	var ring_fraction := fraction_per_theta_sq * annulus_theta_sq
	var view_factor := _view_factor(camera, manager, body.global_position,
			minf(outer_radius / camera_distance, 1.0), view_size, tan_half_fov, aspect)
	var ring_weight := view_factor * _ramp_weight(ring_fraction,
			manager.meter_fraction_start, manager.meter_fraction_full)
	if ring_weight <= 0.0:
		return {}
	var to_sun := (star_vector + camera_vector).normalized()
	var phase_mix_base := (to_sun.dot(-camera_vector / camera_distance) + 1.0) * 0.5
	var phase_mix := phase_mix_base ** PHASE_EXPONENT
	var phase_factor := litside_phase_boost * phase_mix + 1.0
	var ring_luminance := manager.ring_meter_albedo * phase_factor \
			* (illuminance * absf(sin_sun_elevation)
			+ manager.ambient_starlight_illuminance) / PI
	if ring_luminance <= 0.0:
		return {}
	return {
		"name": String(body.name), "candidate": "rings",
		"screen_fraction": ring_fraction, "weight": ring_weight,
		"view_factor": view_factor, "sin_camera_elevation": sin_camera_elevation,
		"sin_sun_elevation": sin_sun_elevation, "phase_mix": phase_mix,
		"phase_factor": phase_factor, "luminance": ring_luminance,
		"candidate_exposure": _candidate_exposure(manager, ring_luminance, ring_weight,
				log_rest, rest_exposure),
	}


func _ramp_weight(screen_fraction: float, fraction_start: float, fraction_full: float) -> float:
	if screen_fraction <= fraction_start:
		return 0.0
	var log_span := log(fraction_full / fraction_start)
	if log_span <= 0.0:
		return 1.0
	return smoothstep(0.0, 1.0, log(screen_fraction / fraction_start) / log_span)


func _candidate_exposure(manager: IVExposureManager, luminance: float, weight: float,
		log_rest: float, rest_exposure: float) -> float:
	var full_exposure := minf(manager.metering_key / (luminance * IVExposureManager.gain),
			rest_exposure)
	var shaped_weight := 1.0 - (1.0 - weight) ** manager.meter_transition_exponent
	return exp(lerpf(log_rest, log(full_exposure), shaped_weight))


func _set_physical_light(params: Dictionary) -> Variant:
	var enabled_var: Variant = params.get("enabled")
	if typeof(enabled_var) != TYPE_BOOL:
		return {"_error": {"code": ERR_INVALID_PARAMS,
				"message": "Missing or invalid 'enabled' parameter"}}
	var enabled: bool = enabled_var
	IVSettingsManager.change_setting(&"physical_light", enabled)
	return {"ok": true, "enabled": enabled}


# Reports whether each visible body's visual actually receives the analytic sun
# occlusion (IVSunOcclusionManager registers a ShaderMaterial only when it is a
# surface override declaring occluder_data_a), alongside the light layer that
# lights it and the CPU parent-shadow fraction the exposure manager meters with.
func _get_shadow_receivers() -> Dictionary:
	var star: IVBody = IVBody.bodies.get(&"STAR_SUN")
	var rows: Array[Dictionary] = []
	for body_name: StringName in IVBody.bodies:
		var body := IVBody.bodies[body_name]
		if !body.visible or !body.body_visual:
			continue
		var counts := _count_materials(body.body_visual)
		rows.append({
			"name": String(body_name),
			"mean_radius_km": body.mean_radius / IVUnits.KM,
			"mesh_instances": counts[0],
			"override_shader_materials": counts[1],
			"occlusion_opt_ins": counts[2],
			"material_classes": counts[3],
			"layers": counts[4],
			"parent_shadow_fraction": _parent_shadow_fraction(body, star),
		})
	return {"exposure": IVExposureManager.exposure, "rows": rows}


func _count_materials(node: Node) -> Array:
	var mesh_instances := 0
	var override_shader_materials := 0
	var occlusion_opt_ins := 0
	var material_classes: Array[String] = []
	var layers := 0
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = child
		mesh_instances += 1
		layers |= mesh_instance.layers
		var material: Material = mesh_instance.get_surface_override_material(0)
		var from_mesh := false
		if !material:
			var mesh := mesh_instance.mesh
			if mesh and mesh.get_surface_count() > 0:
				material = mesh.surface_get_material(0)
				from_mesh = true
		if !material:
			material_classes.append("<none>")
			continue
		material_classes.append(material.get_class() + ("@mesh" if from_mesh else "@override"))
		var shader_material := material as ShaderMaterial
		if !shader_material or !shader_material.shader:
			continue
		if !from_mesh:
			override_shader_materials += 1
		for uniform: Dictionary in shader_material.shader.get_shader_uniform_list():
			if uniform[&"name"] == "occluder_data_a":
				if !from_mesh:
					occlusion_opt_ins += 1
				break
	return [mesh_instances, override_shader_materials, occlusion_opt_ins, material_classes, layers]


# Mirrors IVExposureManager._get_parent_shadow_fraction.
func _parent_shadow_fraction(body: IVBody, star: IVBody) -> float:
	if !star:
		return 1.0
	var parent := body.get_parent() as IVBody
	if !parent or parent == star:
		return 1.0
	var star_vector := star.global_position - body.global_position
	var star_distance := star_vector.length()
	var parent_vector := parent.global_position - body.global_position
	var parent_distance := parent_vector.length()
	if parent_distance <= 0.0 or parent.mean_radius <= 0.0 or star_distance <= 0.0:
		return 1.0
	var star_angular_radius := star.mean_radius / star_distance
	var parent_angular_radius := parent.mean_radius / parent_distance
	var cos_separation := star_vector.dot(parent_vector) / (star_distance * parent_distance)
	var separation := acos(clampf(cos_separation, -1.0, 1.0))
	return IVAstronomy.get_two_disc_visible_fraction(star_angular_radius, parent_angular_radius,
			separation)
