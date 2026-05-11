extends Node

const GAME_PORT = 7777
const BROADCAST_PORT = 7778
const BROADCAST_INTERVAL = 1.0

signal player_joined(host_username: String, client_username: String)
signal joined_lobby(host_username: String, client_username: String)
signal connection_failed
signal ready_state_changed(host_ready: bool, client_ready: bool)
signal countdown_tick(seconds_left: int)
signal player_disconnected

var peer: ENetMultiplayerPeer
var room_code: String = ""
var my_username: String = ""
var host_username: String = ""
var client_username: String = ""

var udp_server: PacketPeerUDP
var udp_listener: PacketPeerUDP
var broadcast_timer: float = 0.0
var is_searching: bool = false

var host_ready: bool = false
var client_ready: bool = false
var countdown_timer: float = -1.0
var COUNTDOWN_DURATION: float = 30.0

func host_game(username: String) -> String:
	my_username = username
	host_username = username
	room_code = _generate_code()

	peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(GAME_PORT, 2)
	if err != OK:
		push_error("Failed to host: " + str(err))
		return ""
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)

	udp_server = PacketPeerUDP.new()
	udp_server.set_broadcast_enabled(true)
	udp_server.bind(0)

	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	return room_code

func _on_peer_connected(id: int):
	_request_username.rpc_id(id)

func _on_peer_disconnected(_id: int):
	player_disconnected.emit()

@rpc("authority", "call_local", "reliable")
func return_to_lobby():
	disconnect_game()
	get_tree().change_scene_to_file("res://Scenes/title_screen.tscn")

@rpc("authority", "call_remote", "reliable")
func _request_username():
	_receive_username.rpc_id(1, my_username)

@rpc("any_peer", "call_remote", "reliable")
func _receive_username(username: String):
	client_username = username
	udp_server.close()

	_confirm_lobby.rpc_id(multiplayer.get_remote_sender_id(), host_username, client_username)
	player_joined.emit(host_username, client_username)

@rpc("authority", "call_remote", "reliable")
func _confirm_lobby(h_username: String, c_username: String):
	host_username = h_username
	client_username = c_username
	joined_lobby.emit(host_username, client_username)

func join_game(code: String, username: String):
	my_username = username
	room_code = code.to_upper().strip_edges()
	is_searching = true

	udp_listener = PacketPeerUDP.new()
	udp_listener.bind(BROADCAST_PORT)

func disconnect_game():
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	if multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.disconnect(_on_connection_failed)

	if peer:
		peer.close()
		peer = null

	multiplayer.multiplayer_peer = null

	if udp_server and udp_server.is_bound():
		udp_server.close()
	if udp_listener and udp_listener.is_bound():
		udp_listener.close()

	is_searching = false
	host_ready = false
	client_ready = false
	countdown_timer = -1.0

func start_game():
	if multiplayer.is_server():
		host_ready = true
		if client_ready:
			countdown_timer = -1.0
			_sync_ready_state.rpc(host_ready, client_ready, countdown_timer)
			_load_game.rpc()
		else:
			countdown_timer = COUNTDOWN_DURATION
			_sync_ready_state.rpc(host_ready, client_ready, countdown_timer)

@rpc("authority", "call_local", "reliable") 
func _sync_ready_state(h_ready: bool, c_ready: bool, timer: float):
	host_ready = h_ready
	client_ready = c_ready
	countdown_timer = timer
	ready_state_changed.emit(host_ready, client_ready)

func set_client_ready():
	if not multiplayer.is_server():
		_notify_client_ready.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func _notify_client_ready():
	client_ready = true
	if host_ready:
		countdown_timer = -1.0
		_sync_ready_state.rpc(host_ready, client_ready, countdown_timer)
		_load_game.rpc()
	else:
		_sync_ready_state.rpc(host_ready, client_ready, countdown_timer)

@rpc("authority", "call_local", "reliable")
func _load_game():
	cleanup_network_discovery()
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _process(delta):
	if udp_server and udp_server.is_bound():
		_broadcast_presence(delta)
	if is_searching:
		_listen_for_host()

	if multiplayer.multiplayer_peer != null and multiplayer.is_server() and countdown_timer >= 0.0:
		var prev_sec = int(countdown_timer)
		countdown_timer -= delta
		var new_sec = int(countdown_timer)
		if new_sec != prev_sec:
			_sync_countdown.rpc(new_sec)
		if countdown_timer <= 0.0:
			countdown_timer = -1.0
			_load_game.rpc()

@rpc("authority", "call_local", "reliable")
func _sync_countdown(seconds_left: int):
	countdown_tick.emit(seconds_left)

func _broadcast_presence(delta: float):
	broadcast_timer += delta
	if broadcast_timer >= BROADCAST_INTERVAL:
		broadcast_timer = 0.0
		var message = ("CODE:" + room_code).to_utf8_buffer()
		udp_server.set_dest_address("255.255.255.255", BROADCAST_PORT)
		udp_server.put_packet(message)

func _listen_for_host():
	if udp_listener.get_available_packet_count() > 0:
		var packet = udp_listener.get_packet().get_string_from_utf8()
		var sender_ip = udp_listener.get_packet_ip()
		if packet == "CODE:" + room_code:
			is_searching = false
			udp_listener.close()
			_connect_to_host(sender_ip)

func _connect_to_host(ip: String):
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, GAME_PORT)
	if err != OK:
		connection_failed.emit()
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_connected_to_server():
	print("Connected to host!")

func _on_server_disconnected():
	player_disconnected.emit()

func _on_connection_failed():
	connection_failed.emit()

func _generate_code() -> String:
	const CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var code = ""
	for i in 6:
		code += CHARS[randi() % CHARS.length()]
	return code

func cleanup_network_discovery():
	if udp_server and udp_server.is_bound():
		udp_server.close()
	if udp_listener and udp_listener.is_bound():
		udp_listener.close()
	is_searching = false
	broadcast_timer = 0.0
