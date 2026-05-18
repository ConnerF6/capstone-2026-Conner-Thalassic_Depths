extends Node3D
const PLAYER_SCENE = preload("res://scenes/Player.tscn")

func _ready():
	NetworkManager.player_disconnected.connect(_on_player_disconnected)
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
	_spawn_self.rpc_id.call_deferred(id)
	await get_tree().process_frame
	var gm_nodes = get_tree().get_nodes_in_group("game_manager")
	if gm_nodes.is_empty():
		push_error("Game: GameManager not found!")
		return
	gm_nodes[0].start_night(1, [1, 2])

@rpc("authority", "call_remote", "reliable")
func _spawn_self():
	print("Client spawning self: ", multiplayer.get_unique_id())
	_spawn_player(multiplayer.get_unique_id())

func _spawn_player(id: int):
	var node_name = "1" if id == 1 else "2"
	if has_node(node_name):
		print("Already have node for: ", node_name)
		return
	var player = PLAYER_SCENE.instantiate()
	player.name = node_name
	add_child(player)
	player.set_multiplayer_authority(id)
	print("Spawned player: ", node_name, " authority: ", id)

func _on_player_disconnected():
	NetworkManager.disconnect_game()
	get_tree().change_scene_to_file("res://Scenes/title_screen.tscn")
