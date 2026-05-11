extends Control

var data = null

@onready var username_menu: Control = $UsernameMenu
@onready var connection_menu: Control = $ConnectionMenu
@onready var host_menu: Control = $HostMenu
@onready var join_menu: Control = $JoinMenu
@onready var main_menu: Control = $MainMenu

@onready var username_input: TextEdit = $UsernameMenu/UsernameInput
@onready var username_confirm: Button = $UsernameMenu/UsernameConfirm
@onready var username_label: RichTextLabel = $UsernameMenu/UsernameInputLabel

@onready var join_btn: Button = $ConnectionMenu/JoinBtn
@onready var host_btn: Button = $ConnectionMenu/HostBtn

@onready var host_code_label: Label = $HostMenu/RoomCodeLabel
@onready var host_status_label: Label = $HostMenu/StatusLabel
@onready var host_back_btn: Button = $HostMenu/BackBtn

@onready var code_input: LineEdit = $JoinMenu/CodeInput
@onready var join_connect_btn: Button = $JoinMenu/ConnectBtn
@onready var join_status_label: Label = $JoinMenu/StatusLabel
@onready var join_back_btn: Button = $JoinMenu/BackBtn

@onready var host_name_label: Label = $MainMenu/HostNameLabel
@onready var client_name_label: Label = $MainMenu/ClientNameLabel
@onready var start_btn: Button = $MainMenu/StartBtn

@onready var countdown_label: Label = $MainMenu/CountdownLabel


func _ready():
	_hide_all()
	data = load("res://Scripts/DataManager.gd").get_or_create()
	
	NetworkManager.player_joined.connect(_on_player_joined)
	NetworkManager.joined_lobby.connect(_on_joined_lobby)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.ready_state_changed.connect(_on_ready_state_changed)
	NetworkManager.countdown_tick.connect(_on_countdown_tick)
	
	countdown_label.hide()
	
	if data.username != "":
		_show(connection_menu)
	else:
		_show(username_menu)

func _on_confirm_pressed():
	var name_text = username_input.text.strip_edges()
	if name_text == "":
		return
	data.username = name_text
	data.save_game()
	_switch_to(connection_menu)

func _on_host_btn_pressed():
	var code = NetworkManager.host_game(data.username)
	host_code_label.text = "Room Code:  " + code
	host_status_label.text = "Waiting for player 2..."
	_switch_to(host_menu)

func _on_join_btn_pressed():
	_switch_to(join_menu)

func _on_host_back_pressed():
	NetworkManager.disconnect_game()
	_switch_to(connection_menu)

func _on_connect_btn_pressed():
	var code = code_input.text.strip_edges().to_upper()
	if code.length() != 6:
		join_status_label.text = "Code must be 6 characters."
		return
	join_status_label.text = "Searching for room..."
	join_connect_btn.disabled = true
	NetworkManager.join_game(code, data.username)

func _on_join_back_pressed():
	NetworkManager.disconnect_game()
	join_connect_btn.disabled = false
	join_status_label.text = ""
	_switch_to(connection_menu)

func _on_player_joined(host_username: String, client_username: String):
	host_name_label.text = "👑 " + host_username
	client_name_label.text = client_username
	start_btn.text = "Start"
	start_btn.disabled = false
	start_btn.show()
	countdown_label.hide()
	_switch_to(main_menu)

func _on_joined_lobby(host_username: String, client_username: String):
	host_name_label.text = "👑 " + host_username
	client_name_label.text = client_username
	start_btn.text = "Start"
	start_btn.disabled = false 
	start_btn.show()
	countdown_label.hide()
	_switch_to(main_menu)

func _on_ready_state_changed(h_ready: bool, c_ready: bool):
	var count = (1 if h_ready else 0) + (1 if c_ready else 0)
	start_btn.text = str(count) + "/2 Ready"

	if multiplayer.is_server() and h_ready:
		start_btn.disabled = true
	if not multiplayer.is_server() and c_ready:
		start_btn.disabled = true

func _on_connection_failed():
	join_status_label.text = "Could not find room. Try again."
	join_connect_btn.disabled = false

func _on_start_btn_pressed():
	if multiplayer.is_server():
		NetworkManager.start_game()
		start_btn.disabled = true
	else:
		NetworkManager.set_client_ready()
		start_btn.disabled = true


func _on_countdown_tick(seconds_left: int):
	countdown_label.show()
	if seconds_left > 0:
		countdown_label.text = "Starting in " + str(seconds_left) + "s..."
	else:
		countdown_label.text = "Starting!"

func _hide_all():
	username_menu.hide()
	connection_menu.hide()
	host_menu.hide()
	join_menu.hide()
	main_menu.hide()

func _show(menu: Control):
	menu.show()

func _switch_to(menu: Control):
	_hide_all()
	menu.show()
