extends StaticBody3D

@export var door: NodePath
@onready var door_node = get_node(door)

func activate():
	print("Button activated!")
	_sync_toggle.rpc()

@rpc("any_peer", "call_local", "reliable")
func _sync_toggle():
	print("Syncing toggle, door node: ", door_node)
	if door_node:
		door_node.toggle()
