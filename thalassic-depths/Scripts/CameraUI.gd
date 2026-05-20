extends Control

signal closed

@onready var top_btn: Button = $FloorButtons/TopFloorButton
@onready var bottom_btn: Button = $FloorButtons/BottomFloorButton
@onready var cam_list: Node = $CameraList
@onready var feed: TextureRect = $FeedDisplay
@onready var camera_backdrop: Sprite2D = $CameraBackdrop

const BACKDROP_TOP = preload("res://2DArt/StaticArt/ThalaTop.png")
const BACKDROP_BOTTOM = preload("res://2DArt/StaticArt/ThalaBottom.png")

var camera_system: Node = null
var active_camera: Node = null
var last_camera: Node = null   # persists across open/close cycles
var current_floor: String = "top"
var my_id: int = 0


func setup(cs: Node, player_id: int):
	camera_system = cs
	my_id = player_id
	camera_system.camera_changed.connect(_on_camera_changed)
	for btn in cam_list.get_children():
		if not btn.pressed.is_connected(_on_cam_btn_pressed.bind(btn)):
			btn.pressed.connect(_on_cam_btn_pressed.bind(btn))
	_switch_floor("top")


func _on_cam_btn_pressed(btn: Button):
	var cam = camera_system.get_camera_by_label(btn.cam_label)
	if cam == null:
		push_error("No camera found for label: " + btn.cam_label)
		return
	_select_camera(cam)


func _select_camera(cam: Node):
	if active_camera:
		active_camera.deactivate()
	active_camera = cam
	last_camera = cam   # remember this for next open
	active_camera.activate()
	camera_system.set_player_viewing.rpc(my_id, cam.cam_label)
	_update_button_indicators()
	await get_tree().process_frame
	feed.texture = cam.get_texture()
	print("Feed texture set: ", feed.texture)


func _switch_floor(new_floor: String):
	current_floor = new_floor
	top_btn.modulate = Color.WHITE if new_floor == "top" else Color(0.5, 0.5, 0.5)
	bottom_btn.modulate = Color.WHITE if new_floor == "bottom" else Color(0.5, 0.5, 0.5)
	camera_backdrop.texture = BACKDROP_TOP if new_floor == "top" else BACKDROP_BOTTOM
	for btn in cam_list.get_children():
		btn.visible = (btn.floor_group == new_floor)
	_update_button_indicators()


func _on_camera_changed(player_id: int, cam_label: String):
	_update_button_indicators()

	# Only care about the other player's changes from here on
	if player_id == my_id:
		return

	var my_player = get_parent().get_parent().get_parent()
	if not my_player.is_spectating:
		return

	if cam_label == "":
		# Alive player closed the camera system — close it for the spectator too
		if active_camera:
			active_camera.deactivate()
		active_camera = null
		# Note: do NOT clear last_camera here — we want to restore it if they reopen
		my_player.in_camera_system = false
		get_parent().hide()   # camera_ui_root
	else:
		# Alive player is viewing a camera — mirror it for the spectator
		var cam = camera_system.get_camera_by_label(cam_label)
		if cam == null:
			return

		if not get_parent().visible:
			# System wasn't open for spectator yet — open it now
			my_player.in_camera_system = true
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			get_parent().show()   # camera_ui_root

		_select_camera(cam)


func _update_button_indicators():
	var other_cam = camera_system.get_other_player_camera(my_id)
	for btn in cam_list.get_children():
		if btn.floor_group != current_floor:
			continue
		var cam = camera_system.get_camera_by_label(btn.cam_label)
		if cam == null:
			continue
		if other_cam == btn.cam_label and active_camera == cam:
			btn.modulate = Color(0.4, 0.8, 1.0)
		elif other_cam == btn.cam_label:
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
	if camera_system:
		camera_system.set_player_viewing.rpc(my_id, "")
	active_camera = null
	closed.emit()
