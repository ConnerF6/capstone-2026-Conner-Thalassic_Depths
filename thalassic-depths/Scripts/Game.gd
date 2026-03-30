extends Node3D

const PLAYER_SCENE = preload("res://scenes/Player.tscn")

func _ready():
	if multiplayer.is_server():
		_spawn_player(1)
		multiplayer.peer_connected.connect(_on_peer_connected)
	else:
		# Client announces to host that they are ready
		_client_ready.rpc_id(1)

func _on_peer_connected(_id: int):
	pass  # Handled by _client_ready now

@rpc("any_peer", "call_remote", "reliable")
func _client_ready():
	var id = multiplayer.get_remote_sender_id()
	print("Client reported ready: ", id)
	_spawn_player(id)
	_spawn_self.rpc_id(id)

@rpc("authority", "call_remote", "reliable")
func _spawn_self():
	var my_id = multiplayer.get_unique_id()
	print("Client spawning self: ", my_id)
	_spawn_player(my_id)

func _spawn_player(id: int):
	if has_node(str(id)):
		print("Already have node for: ", id)
		return
	var player = PLAYER_SCENE.instantiate()
	player.name = str(id)
	add_child(player)
	# Explicitly assign authority to the correct peer
	player.set_multiplayer_authority(id)
	print("Spawned player: ", id)
