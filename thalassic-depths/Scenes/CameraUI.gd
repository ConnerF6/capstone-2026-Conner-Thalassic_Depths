extends Control

signal closed

@onready var top_btn: Button = $FloorButtons/TopFloorButton
@onready var bottom_btn: Button = $FloorButtons/BottomFloorButton
@onready var exit_hint = $ExitHelper
@onready var cam_buttons: Array = []

var camera_system: Node = null
var active_camera: Node = null
var current_floor: String = "top"
var my_id: int = 0

func setup(cs: Node, player_id: int):
	# Fetch buttons manually instead of @onready
	cam_buttons = [
		$CameraList/CamBtn1,
		$CameraList/CamBtn2,
		$CameraList/CamBtn3,
	]
	print("Cam buttons: ", cam_buttons)
	camera_system = cs
	my_id = player_id
	camera_system.camera_changed.connect(_on_camera_changed)
	for i in cam_buttons.size():
		var idx = i
		cam_buttons[i].pressed.connect(func(): _select_camera_by_index(idx))
	_switch_floor("top")

func _select_camera_by_index(index: int):
	var cameras = camera_system.get_cameras(current_floor)
	if index >= cameras.size():
		return
	_select_camera(cameras[index])

func _select_camera(cam: Node):
	print("Selecting camera: ", cam.cam_label, " at position: ", cam.global_position)
	if active_camera:
		active_camera.deactivate()
	active_camera = cam
	active_camera.activate()
	camera_system.set_player_viewing.rpc(my_id, cam.cam_label)
	_update_button_indicators()

func _switch_floor(new_floor: String):
	current_floor = new_floor
	top_btn.modulate = Color.WHITE if new_floor == "top" else Color(0.5, 0.5, 0.5)
	bottom_btn.modulate = Color.WHITE if new_floor == "bottom" else Color(0.5, 0.5, 0.5)
	if active_camera:
		active_camera.deactivate()
		active_camera = null
	_update_button_indicators()

func _on_camera_changed(_player_id: int, _cam_label: String):
	_update_button_indicators()

func _update_button_indicators():
	var cameras = camera_system.get_cameras(current_floor)
	var other_cam = camera_system.get_other_player_camera(my_id)
	for i in cam_buttons.size():
		var btn = cam_buttons[i]
		if i >= cameras.size():
			btn.modulate = Color(0.3, 0.3, 0.3)
			continue
		var cam = cameras[i]
		if other_cam == cam.cam_label:
			btn.modulate = Color(0.4, 0.8, 1.0)
		elif active_camera == cam:
			btn.modulate = Color.WHITE
		else:
			btn.modulate = Color(0.7, 0.7, 0.7)

func _on_top_floor_button_pressed():
	_switch_floor("top")

func _on_bottom_floor_button_pressed():
	_switch_floor("bottom")

func _on_exit_helper_mouse_entered():
	if active_camera:
		active_camera.deactivate()
	closed.emit()
