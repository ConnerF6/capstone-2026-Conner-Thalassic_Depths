extends Node3D

signal camera_changed(player_id: int, cam_label: String)

var player_viewing: Dictionary = {}

func _ready():
	pass

func get_cameras(floor_name: String) -> Array:
	if floor_name == "top":
		return $TopFloor.get_children()
	elif floor_name == "bottom":
		return $BottomFloor.get_children()
	return []

func get_camera_by_label(label: String) -> Node:
	for cam in $TopFloor.get_children():
		if cam.cam_label == label:
			return cam
	for cam in $BottomFloor.get_children():
		if cam.cam_label == label:
			return cam
	return null

@rpc("any_peer", "call_local", "reliable")
func set_player_viewing(player_id: int, cam_label: String):
	player_viewing[player_id] = cam_label
	camera_changed.emit(player_id, cam_label)

func get_other_player_camera(my_id: int) -> String:
	for id in player_viewing:
		if id != my_id:
			return player_viewing[id]
	return ""
