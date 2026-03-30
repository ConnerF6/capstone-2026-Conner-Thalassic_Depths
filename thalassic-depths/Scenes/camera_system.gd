extends Node3D

# Emitted when a player switches camera — for showing the indicator
signal camera_changed(player_id: int, cam_label: String)

var top_cameras: Array = []
var bottom_cameras: Array = []

# Tracks which camera each player is viewing
# { peer_id: cam_label }
var player_viewing: Dictionary = {}

func _ready():
	for cam in $TopFloor.get_children():
		top_cameras.append(cam)
	for cam in $BottomFloor.get_children():
		bottom_cameras.append(cam)

func get_cameras(floor: String) -> Array:
	return top_cameras if floor == "top" else bottom_cameras

func set_player_viewing(player_id: int, cam_label: String):
	player_viewing[player_id] = cam_label
	camera_changed.emit(player_id, cam_label)

func get_other_player_camera(my_id: int) -> String:
	for id in player_viewing:
		if id != my_id:
			return player_viewing[id]
	return ""
