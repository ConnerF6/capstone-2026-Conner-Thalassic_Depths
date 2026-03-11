extends CharacterBody3D

# --- Spawn Points (set these to match your office positions) ---
const SPAWN_P1 = Vector3(0, 0, 0)
const SPAWN_P2 = Vector3(0, 0, 36.7)

# --- Camera States ---
enum CamState { LEFT, CENTER, RIGHT }
const CAM_ANGLES = {
	CamState.LEFT:   90.0,
	CamState.CENTER:  0.0,
	CamState.RIGHT:   -90.0
}

# --- Settings ---
const EDGE_THRESHOLD = 0.15
const HOLD_TIME = 0
const TWEEN_DURATION = 0.3

var current_state: CamState = CamState.CENTER
var is_tweening: bool = false
var hold_timer: float = 0.0
var holding_left: bool = false
var holding_right: bool = false

@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D  

func _ready():
	print("Player node name: ", name)
	print("My peer ID: ", multiplayer.get_unique_id())
	
	$CameraRig/Camera3D.current = false
	set_process(false)

	# Simply check if this node's name matches our peer ID
	if name != str(multiplayer.get_unique_id()):
		print("Not my player, skipping: ", name)
		return

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

func _process(delta):
	_handle_camera(delta)

func _handle_camera(delta: float):
	if is_tweening:
		return

	var vp_size = get_viewport().get_visible_rect().size
	var mouse_x = get_viewport().get_mouse_position().x
	var x_frac = mouse_x / vp_size.x  # 0.0 = far left, 1.0 = far right

	var on_left  = x_frac < EDGE_THRESHOLD
	var on_right = x_frac > (1.0 - EDGE_THRESHOLD)

	# Reset hold timers when not on an edge
	if not on_left:
		holding_left = false
	if not on_right:
		holding_right = false
	if not on_left and not on_right:
		hold_timer = 0.0
		return

	if on_left:
		if not holding_left:
			# First trigger — step one state left
			holding_left = true
			hold_timer = 0.0
			_step_left()
		else:
			# Already stepped — count hold time for second step
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
		CamState.LEFT:   pass  # Already at leftmost

func _step_right():
	match current_state:
		CamState.LEFT:   _tween_to(CamState.CENTER)
		CamState.CENTER: _tween_to(CamState.RIGHT)
		CamState.RIGHT:  pass  # Already at rightmost

func _tween_to(new_state: CamState):
	current_state = new_state
	is_tweening = true

	var target_angle = CAM_ANGLES[new_state]
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(camera, "rotation_degrees:y", target_angle, TWEEN_DURATION)
	tween.tween_callback(func(): is_tweening = false)
