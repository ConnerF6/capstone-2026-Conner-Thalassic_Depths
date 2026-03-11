extends Node

const GAME_PORT = 7777
const BROADCAST_PORT = 7778
const BROADCAST_INTERVAL = 1.0

signal player_joined(host_username: String, client_username: String)
signal joined_lobby(host_username: String, client_username: String)
signal connection_failed

var peer: ENetMultiplayerPeer
var room_code: String = ""
var my_username: String = ""
var host_username: String = ""
var client_username: String = ""

var udp_server: PacketPeerUDP
var udp_listener: PacketPeerUDP
var broadcast_timer: float = 0.0
var is_searching: bool = false

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

	return room_code

func _on_peer_connected(id: int):
	_request_username.rpc_id(id)

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
	if peer:
		peer.close()
		peer = null
	if udp_server and udp_server.is_bound():
		udp_server.close()
	if udp_listener and udp_listener.is_bound():
		udp_listener.close()
	is_searching = false
	multiplayer.multiplayer_peer = null

func start_game():
	if multiplayer.is_server():
		_load_game.rpc()

@rpc("authority", "call_local", "reliable")
func _load_game():
	cleanup_network_discovery()
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _process(delta):
	if udp_server and udp_server.is_bound():
		_broadcast_presence(delta)
	if is_searching:
		_listen_for_host()

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

func _on_connected_to_server():
	print("Connected to host!")

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
