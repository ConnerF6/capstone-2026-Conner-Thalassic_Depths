extends CharacterBody3D

# --- Spawn Points ---
const SPAWN_P1 = Vector3(0, 0.3, 0)
const SPAWN_P2 = Vector3(0.2, 0.3, 37)

# --- Camera States ---
enum CamState { LEFT, CENTER, RIGHT }
const CAM_ANGLES = {
	CamState.LEFT:   90.0,
	CamState.CENTER:  0.0,
	CamState.RIGHT:   -90.0
}

# --- Settings ---
const EDGE_THRESHOLD = 0.1
const HOLD_TIME = 0
const TWEEN_DURATION = 0.3

var current_state: CamState = CamState.CENTER
var is_tweening: bool = false
var hold_timer: float = 0.0
var holding_left: bool = false
var holding_right: bool = false
var is_player_one: bool = false

@onready var camera_rig: Node3D = $CameraRig
@onready var flashlight: SpotLight3D = $CameraRig/Flashlight
@onready var camera: Camera3D = $CameraRig/Camera3D

func _ready():
	print("Player node name: ", name)
	print("My peer ID: ", multiplayer.get_unique_id())

	$CameraRig/Camera3D.current = false
	set_process(false)

	if name != str(multiplayer.get_unique_id()):
		print("Not my player, skipping: ", name)
		return

	is_player_one = (multiplayer.get_unique_id() == 1)

	print("This is my player, setting up camera: ", name)
	$CameraRig/Camera3D.current = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	set_process(true)

	await get_tree().process_frame

	if multiplayer.get_unique_id() == 1:
		global_position = SPAWN_P1
		rotation_degrees.y = 0.0
	else:
		global_position = SPAWN_P2
		rotation_degrees.y = 180.0

	camera_rig.rotation_degrees.y = CAM_ANGLES[CamState.CENTER]
	flashlight.visible = false

func _process(delta):
	_handle_camera(delta)

func _handle_camera(delta: float):
	if is_tweening:
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

func _try_interact():
	var space_state = get_world_3d().direct_space_state
	var cam = $CameraRig/Camera3D
	var mouse_pos = get_viewport().get_mouse_position()

	# Use the camera's global transform directly
	var ray_origin = cam.global_transform.origin
	var ray_dir = cam.project_ray_normal(mouse_pos)
	var ray_end = ray_origin + ray_dir * 20.0

	print("Ray origin: ", ray_origin)
	print("Ray end: ", ray_end)

	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collision_mask = 1
	query.collide_with_bodies = false
	query.collide_with_areas = true
	var result = space_state.intersect_ray(query)

	print("Ray result: ", result)

	if result and result.collider.get_parent().has_method("activate"):
		result.collider.get_parent().activate()

func _input(event):
	if not (event is InputEventMouseButton):
		return
	if not event.pressed:
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	# Player 1 — flashlight on right look, hold to shine
	if is_player_one:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if current_state == CamState.RIGHT:
					flashlight.visible = event.pressed
		return

	# Player 2 — button interaction on left look
	if current_state == CamState.LEFT:
		_try_interact()
