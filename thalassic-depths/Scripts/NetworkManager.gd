extends Node

const PORT = 7777
const MAX_PEERS = 2

var peer: ENetMultiplayerPeer

func host_game():
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_PEERS)
	if error != OK:
		print("Failed to host: ", error)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	print("Hosting on port ", PORT)
	# Host goes straight to game as player 1
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func join_game(ip: String):
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip, PORT)
	if error != OK:
		print("Failed to join: ", error)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	print("Connecting to ", ip)

func _on_peer_connected(id: int):
	print("Peer connected: ", id)

func _on_connected_to_server():
	print("Connected to server!")
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_connection_failed():
	print("Connection failed!")
