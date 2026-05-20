extends CharacterBody3D

const SPAWN_P1 = Vector3(0, 0.3, 0)
const SPAWN_P2 = Vector3(0.2, 0.3, 37)

enum CamState { LEFT, CENTER, RIGHT }
const CAM_ANGLES = {
	CamState.LEFT:   90.0,
	CamState.CENTER:  0.0,
	CamState.RIGHT:  -90.0
}

const EDGE_THRESHOLD = 0.1
const HOLD_TIME = 0
const TWEEN_DURATION = 0.3

var current_state: CamState = CamState.CENTER
var is_tweening: bool = false
var hold_timer: float = 0.0
var holding_left: bool = false
var holding_right: bool = false
var is_player_one: bool = false
var in_camera_system: bool = false
var is_flashing: bool = false
var is_dead: bool = false
var is_spectating: bool = false
var spectate_target: Node = null

@onready var camera_rig: Node3D = $CameraRig
@onready var flashlight: SpotLight3D = $CameraRig/Flashlight
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var spectate_camera: Camera3D = $CameraRig/SpectateCamera3D
@onready var camera_ui_root: Control = $HUD/CameraUI
@onready var camera_ui: Control = $HUD/CameraUI/CameraOverlay
@onready var death_screen: Control = $HUD/DeathScreen


func _ready():
	print("Player node name: ", name)
	print("My peer ID: ", multiplayer.get_unique_id())

	$CameraRig/Camera3D.current = false
	spectate_camera.current = false
	set_process(false)
	camera_ui_root.hide()
	death_screen.hide()

	if multiplayer.is_server() and name == "2":
		print("Not my player, skipping: ", name)
		return
	if not multiplayer.is_server() and name == "1":
		print("Not my player, skipping: ", name)
		return

	is_player_one = (name == "1")

	print("This is my player, setting up camera: ", name)
	$CameraRig/Camera3D.current = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	set_process(true)

	await get_tree().process_frame

	if name == "1":
		global_position = SPAWN_P1
		rotation_degrees.y = 0.0
	else:
		global_position = SPAWN_P2
		rotation_degrees.y = 180.0

	camera_rig.rotation_degrees.y = CAM_ANGLES[CamState.CENTER]
	flashlight.visible = false

	var camera_system_nodes: Array = []
	var attempts = 0
	while camera_system_nodes.is_empty() and attempts < 10:
		camera_system_nodes = get_tree().get_nodes_in_group("camera_system")
		if camera_system_nodes.is_empty():
			await get_tree().process_frame
		attempts += 1

	if camera_system_nodes.is_empty():
		push_error("CameraSystem not found after 10 frames!")
		return

	camera_ui.setup(camera_system_nodes[0], name.to_int())
	print("Setup complete")
	camera_ui.closed.connect(_close_camera_system)


func _open_camera_system():
	if camera_ui.camera_system == null:
		push_error("CameraOverlay has no camera_system — setup() may not have run yet")
		return

	in_camera_system = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	camera_ui_root.show()
	camera.current = false
	spectate_camera.current = false

	if camera_ui.last_camera != null:
		camera_ui._select_camera(camera_ui.last_camera)
	else:
		var cams = camera_ui.camera_system.get_cameras("top")
		if cams.size() > 0:
			camera_ui._select_camera(cams[0])


func _close_camera_system():
	if is_spectating:
		return

	in_camera_system = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	camera_ui_root.hide()
	if camera_ui.active_camera:
		camera_ui.active_camera.deactivate()
	camera.current = true


func _try_interact():
	var space_state = get_world_3d().direct_space_state
	var cam = $CameraRig/Camera3D
	var mouse_pos = get_viewport().get_mouse_position()

	var ray_origin = cam.global_transform.origin
	var ray_end = ray_origin + cam.project_ray_normal(mouse_pos) * 20.0

	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collision_mask = 1
	query.collide_with_bodies = false
	query.collide_with_areas = true
	var result = space_state.intersect_ray(query)

	if result:
		var parent = result.collider.get_parent()
		if parent.has_method("activate"):
			parent.activate()
		elif result.collider.is_in_group("monitor"):
			_open_camera_system()


func _handle_camera(delta: float):
	if is_tweening:
		return
	if in_camera_system:
		return

	var vp_size = get_viewport().get_visible_rect().size
	var mouse_x = get_viewport().get_mouse_position().x
	var x_frac = mouse_x / vp_size.x

	var on_left  = x_frac < EDGE_THRESHOLD
	var on_right = x_frac > (1.0 - EDGE_THRESHOLD)

	if not on_left:
		holding_left = false
	if not on_right:
		holding_right = false
	if not on_left and not on_right:
		hold_timer = 0.0
		return

	if on_left:
		if not holding_left:
			holding_left = true
			hold_timer = 0.0
			_step_left()
		else:
			if current_state != CamState.LEFT:
				hold_timer += delta
				if hold_timer >= HOLD_TIME:
					hold_timer = 0.0
					_step_left()
	elif on_right:
		if not holding_right:
			holding_right = true
			hold_timer = 0.0
			_step_right()
		else:
			if current_state != CamState.RIGHT:
				hold_timer += delta
				if hold_timer >= HOLD_TIME:
					hold_timer = 0.0
					_step_right()


func _step_left():
	match current_state:
		CamState.RIGHT:  _tween_to(CamState.CENTER)
		CamState.CENTER: _tween_to(CamState.LEFT)
		CamState.LEFT:   pass


func _step_right():
	match current_state:
		CamState.LEFT:   _tween_to(CamState.CENTER)
		CamState.CENTER: _tween_to(CamState.RIGHT)
		CamState.RIGHT:  pass


func _tween_to(new_state: CamState):
	current_state = new_state
	is_tweening = true
	var target_angle = CAM_ANGLES[new_state]
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(camera, "rotation_degrees:y", target_angle, TWEEN_DURATION)
	tween.tween_callback(func(): is_tweening = false)


func _input(event):
	if in_camera_system or is_spectating:
		return
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if is_player_one and not event.pressed:
		is_flashing = false
		flashlight.visible = false
		return
	if not event.pressed:
		return
	if is_player_one:
		if current_state == CamState.RIGHT:
			flashlight.visible = true
			is_flashing = true
	if current_state == CamState.LEFT:
		_try_interact()
	elif current_state == CamState.CENTER and in_camera_system == false:
		_try_interact()


func show_death_screen(killer_name: String) -> void:
	is_dead = true
	set_process(false)
	set_process_input(false)

	var sprite_path := "res://2DArt/StaticArt/DeathScreen%s.png" % killer_name
	var tex = load(sprite_path)
	if tex:
		var DeathSprite = death_screen.find_child("DeathScreenSprite")
		DeathSprite.texture = tex
	else:
		push_error("Player: No death art found at: %s" % sprite_path)

	death_screen.show()


@rpc("any_peer", "call_local", "reliable")
func begin_spectate(target_id: int) -> void:
	death_screen.hide()
	is_spectating = true
	
	print("[Player %s] Now spectating Player %s" % [name, target_id])

	if camera_ui.closed.is_connected(_close_camera_system):
		camera_ui.closed.disconnect(_close_camera_system)

	var target_node_name := "1" if target_id == 1 else "2"
	spectate_target = get_parent().get_node_or_null(target_node_name)
	if spectate_target == null:
		push_error("[Player %s] Spectate: could not find target node '%s'" % [name, target_node_name])
		return

	# 1. Shut off loop processing cleanly so it doesn't fight the cameras
	set_process(false)

	# 2. Turn off your local cameras completely
	camera.current = false
	spectate_camera.current = false

	# 3. Target the living player's camera rig directly
	var living_player_camera = spectate_target.get_node_or_null("CameraRig/Camera3D")
	if living_player_camera:
		living_player_camera.current = true
		print("[Player %s] Successfully switched to Player %s's camera view." % [name, target_id])
	else:
		push_error("[Player %s] Found target node, but CameraRig/Camera3D is missing!" % name)


func _process(delta):
	# Loop process is now reserved exclusively for living gameplay edge-panning
	if not is_spectating:
		_handle_camera(delta)


func begin_jumpscare() -> void:
	if is_dead:
		return
	if in_camera_system:
		_close_camera_system()
	set_process(false)
	set_process_input(false)
