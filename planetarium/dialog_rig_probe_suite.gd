# dialog_rig_probe_suite.gd
# TEMPORARY verification harness for IVBody2DCaptureDialog's own render path. Registered
# via the untracked res://ivoyager_override2.cfg [assistant_test_suites] section; neither
# file is committed. DELETE BOTH once the 2D icon work is signed off.
extends IVAssistantTestSuite

## Drives IVBody2DCapturer through the sequence IVBody2DCaptureDialog uses -- stage on the
## body's own camera radius, reset pose, solve_fit_zoom, capture_image -- so the dialog-only
## half of the capturer (the fit and the readback conversion, neither of which the tools
## icon suite calls) can be rendered and measured headlessly.

const RIG_SIZE := IVBody2DCapturer.ICON_SIZE * IVBody2DCapturer.SUPERSAMPLE

var _capturer: IVBody2DCapturer
var _viewport: SubViewport
var _camera: Camera3D
var _key_light: DirectionalLight3D
var _fill_light: DirectionalLight3D
var _yaw_pivot: Node3D
var _pitch_pivot: Node3D
var _model_holder: Node3D


var _running := false
var _result: Dictionary


func get_method_names() -> Array[String]:
	return ["capture_dialog_icon", "poll_dialog_icon"]


func get_method_summaries() -> Dictionary:
	return {
		"capture_dialog_icon": "Start one render through the dialog's own path "
				+ "({\"name\": entity_name, \"out_path\": String}); poll for the result.",
		"poll_dialog_icon": "Return the running render's result once it has landed.",
	}


# The assistant dispatch is synchronous and a render needs frames, so _capture() is started
# detached and publishes through _result / _running for poll_dialog_icon to collect.
func dispatch(method: String, params: Dictionary) -> Variant:
	match method:
		"capture_dialog_icon":
			if _running:
				return {"error": "already running"}
			_running = true
			_result = {}
			_capture(params)
			return {"started": true}
		"poll_dialog_icon":
			if _running:
				return {"done": false}
			var result := _result
			_result = {}
			result["done"] = true
			return result
	return null


func _capture(params: Dictionary) -> void:
	var body_name := StringName(str(params.get("name", "")))
	if !IVBody.bodies.has(body_name):
		_finish({"error": "no body %s" % body_name})
		return
	_build_rig()
	var body: IVBody = IVBody.bodies[body_name]
	var visual := body.make_body_visual()
	if !visual:
		_free_rig()
		_finish({"error": "%s has no model" % body_name})
		return
	# The dialog's own staging: a reference radius except for a packed craft model.
	var asset_preloader: IVAssetPreloader = IVGlobal.program[&"AssetPreloader"]
	var reference_radius := 0.0
	if !asset_preloader.get_body_packed_model(body_name):
		reference_radius = body.get_camera_radius()
	var aabb := _capturer.stage_visual(visual, reference_radius)
	var key_dir := IVBody2DCapturer.KEY_DIR
	if _capturer.get_staged_model() is IVShellsModel:
		key_dir = IVBody2DCapturer.SHELLS_KEY_DIR
	var azimuth_elevation := IVBody2DCapturer.direction_to_azimuth_elevation(key_dir)
	_capturer.set_key_light(azimuth_elevation.x, azimuth_elevation.y)
	_capturer.set_brightness(IVBody2DCapturer.DEFAULT_BRIGHTNESS)
	_capturer.set_ambient(0.0)
	var zoom := 1.0
	_capturer.frame_camera(aabb, IVBody2DCapturer.DEFAULT_YAW, IVBody2DCapturer.DEFAULT_PITCH,
			zoom, Vector2.ZERO)
	var fit_msec := Time.get_ticks_msec()
	for _iteration in 2:
		zoom = await _capturer.solve_fit_zoom(zoom)
		_capturer.frame_camera(aabb, IVBody2DCapturer.DEFAULT_YAW, IVBody2DCapturer.DEFAULT_PITCH,
				zoom, Vector2.ZERO)
	fit_msec = Time.get_ticks_msec() - fit_msec
	var image := await _capturer.capture_image()
	var result := {"body": String(body_name), "zoom": zoom, "fit_msec": fit_msec,
			"reference_radius": reference_radius}
	if image:
		var out_path := str(params.get("out_path", ""))
		if !out_path.is_empty():
			result["save_error"] = image.save_png(out_path)
			result["path"] = out_path
		result["silhouette"] = str(IVBody2DCapturer.get_silhouette_rect(image))
	else:
		result["error"] = "no image"
	_capturer.clear_visual()
	_free_rig()
	_finish(result)


func _finish(result: Dictionary) -> void:
	_result = result
	_running = false


func _build_rig() -> void:
	_free_rig()
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(RIG_SIZE, RIG_SIZE)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_4X
	IVGlobal.get_tree().root.add_child(_viewport)
	_camera = Camera3D.new()
	_camera.current = true
	_viewport.add_child(_camera)
	_key_light = DirectionalLight3D.new()
	_viewport.add_child(_key_light)
	_fill_light = DirectionalLight3D.new()
	_viewport.add_child(_fill_light)
	_yaw_pivot = Node3D.new()
	_viewport.add_child(_yaw_pivot)
	_pitch_pivot = Node3D.new()
	_yaw_pivot.add_child(_pitch_pivot)
	_model_holder = Node3D.new()
	_pitch_pivot.add_child(_model_holder)
	_capturer = IVBody2DCapturer.new()
	_capturer.bind_nodes(_viewport, _camera, _key_light, _fill_light, _yaw_pivot, _pitch_pivot,
			_model_holder)


func _free_rig() -> void:
	if _viewport:
		_viewport.queue_free()
		_viewport = null
	_capturer = null
