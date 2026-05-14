extends Node3D

const PLAYER_SCENE = preload("res://scenes/Player.tscn")

func _ready():
	NetworkManager.player_disconnected.connect(_on_player_disconnected)  # NEW
	if multiplayer.is_server():
		_spawn_player(1)
		multiplayer.peer_connected.connect(_on_peer_connected)
	else:
		_client_ready.rpc_id(1)

func _on_peer_connected(_id: int):
	pass

@rpc("any_peer", "call_remote", "reliable")
func _client_ready():
	var id = multiplayer.get_remote_sender_id()
	print("Client reported ready: ", id)
	_spawn_player(id)
	_spawn_self.rpc_id(id)
	await get_tree().process_frame
	var gm_nodes = get_tree().get_nodes_in_group("game_manager")
	if gm_nodes.is_empty():
		push_error("Game: GameManager not found!")
		return
	gm_nodes[0].start_night(1, [1, id])

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
	player.name = "1" if id == 1 else "2"
	add_child(player)
	player.set_multiplayer_authority(id)
	print("Spawned player: ", id)

func _on_player_disconnected():
	NetworkManager.disconnect_game()
	get_tree().change_scene_to_file("res://Scenes/title_screen.tscn")
