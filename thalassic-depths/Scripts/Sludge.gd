extends Node

enum Room {
	SPAWN,
	R18,
	R17,
	R6,
	R5,
	R3,
	R2,
	HALLWAY,
}

const ROOM_GRAPH : Dictionary = {
	Room.SPAWN:   { "forward": [Room.R18],          "backward": []                  },
	Room.R18:     { "forward": [Room.R17],           "backward": [Room.SPAWN]        },
	Room.R17:     { "forward": [Room.R6],            "backward": [Room.R18]          },
	Room.R6:      { "forward": [Room.R3, Room.R5],   "backward": [Room.R17]          },
	Room.R5:      { "forward": [Room.R3],            "backward": [Room.R6]           },
	Room.R3:      { "forward": [Room.R2],            "backward": [Room.R6, Room.R5]  },
	Room.R2:      { "forward": [Room.HALLWAY],       "backward": [Room.R3]           },
	Room.HALLWAY: { "forward": [],                   "backward": [Room.R2]           },
}

const MOVE_INTERVAL        : float = 4.0
const HALLWAY_INTERVAL     : float = 8.0
const HALLWAY_INTERVAL_LONG: float = 16.0
const MOVE_CHANCE_BASE     : float = 0.05
const FLASH_REPEL_TIME     : float = 0.5

var current_room      : Room  = Room.SPAWN
var move_timer        : float = 0.0
var flash_timer       : float = 0.0
var is_active         : bool  = false
var first_attack_done : bool  = false  # tracks if first attack attempt has passed

var game_manager : Node = null
var player_one   : Node = null


func _ready() -> void:
	set_process(false)

	if not multiplayer.is_server():
		return

	await get_tree().process_frame

	game_manager = get_parent().get_node("GameManager")
	game_manager.hour_changed.connect(_on_hour_changed)

	player_one = get_parent().get_node_or_null("1")
	if player_one == null:
		push_error("Sludge: Player 1 node not found!")
		return

	print("[Sludge] Initialized. Starting in: ", _room_name(current_room))
	set_process(true)


func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return

	var ai_level : int = game_manager.get_ai_level("Sludge")

	if ai_level <= 0:
		if is_active:
			print("[Sludge] Deactivated (AI level 0)")
		is_active = false
		return

	if not is_active:
		print("[Sludge] Activated at AI level: ", ai_level)
	is_active = true

	if current_room == Room.HALLWAY:
		var flashing : bool = _player_is_flashing()

		if flashing:
			flash_timer += delta
			print("[Sludge] Hallway timer stalled — flash timer: %.2fs / %.2fs" % [flash_timer, FLASH_REPEL_TIME])
			if flash_timer >= FLASH_REPEL_TIME:
				flash_timer       = 0.0
				move_timer        = 0.0
				first_attack_done = false
				print("[Sludge] Flashed long enough — repelled back to spawn!")
				_repel_to_spawn()
			return
		else:
			if flash_timer > 0.0:
				print("[Sludge] Flash broken after %.2fs (needed %.2fs)" % [flash_timer, FLASH_REPEL_TIME])
			flash_timer = 0.0
			move_timer += delta

			if not first_attack_done:
				# First attack window — only fires if cameras are up
				if move_timer >= HALLWAY_INTERVAL:
					if _player_camera_is_up():
						print("[Sludge] First attack window — cameras up, attacking!")
						move_timer        = 0.0
						first_attack_done = true
						_attack()
					else:
						print("[Sludge] First attack window — cameras down, waiting for long timer.")
						move_timer        = 0.0
						first_attack_done = true
			else:
				# Second attack window — fires regardless
				if move_timer >= HALLWAY_INTERVAL_LONG:
					print("[Sludge] Second attack window — attacking regardless of cameras!")
					move_timer        = 0.0
					first_attack_done = false
					_attack()
		return

	flash_timer       = 0.0
	first_attack_done = false
	move_timer += delta
	if move_timer >= MOVE_INTERVAL:
		move_timer = 0.0
		_attempt_move(ai_level)


func _attempt_move(ai_level: int) -> void:
	var move_chance : float = clamp(ai_level * MOVE_CHANCE_BASE, 0.0, 1.0)
	var roll : float = randf()

	print("[Sludge] Movement roll: %.2f vs chance: %.2f (AI level %d)" % [roll, move_chance, ai_level])

	if roll > move_chance:
		print("[Sludge] Did not move this tick.")
		return

	var go_forward : bool = randf() < 0.66
	var direction  : String = "forward" if go_forward else "backward"

	var graph          : Dictionary = ROOM_GRAPH[current_room]
	var forward_rooms  : Array      = graph["forward"]
	var backward_rooms : Array      = graph["backward"]

	var next_room : Room

	if go_forward and forward_rooms.size() > 0:
		next_room = forward_rooms[randi() % forward_rooms.size()]
	elif not go_forward and backward_rooms.size() > 0:
		next_room = _choose_backward(backward_rooms)
		direction = "backward"
	elif forward_rooms.size() > 0:
		next_room = forward_rooms[randi() % forward_rooms.size()]
		direction = "forward (forced)"
	else:
		print("[Sludge] No valid rooms to move to from: ", _room_name(current_room))
		return

	print("[Sludge] Moving %s: %s → %s" % [direction, _room_name(current_room), _room_name(next_room)])
	_move_to(next_room)


func _choose_backward(options: Array) -> Room:
	if current_room == Room.R3:
		var pick = Room.R6 if randf() < 0.66 else Room.R5
		print("[Sludge] R3 backward weighted pick: ", _room_name(pick))
		return pick
	return options[randi() % options.size()]


func _move_to(room: Room) -> void:
	var prev = current_room
	current_room      = room
	move_timer        = 0.0
	flash_timer       = 0.0
	first_attack_done = false
	_sync_room.rpc(room)
	print("[Sludge] Arrived in: %s (was: %s)" % [_room_name(room), _room_name(prev)])

	if room == Room.HALLWAY:
		print("[Sludge] ⚠ Entered HALLWAY — attack timer started (%.1fs)" % HALLWAY_INTERVAL)


func _repel_to_spawn() -> void:
	print("[Sludge] Returning to spawn: %s → SPAWN" % _room_name(current_room))
	current_room      = Room.SPAWN
	move_timer        = 0.0
	flash_timer       = 0.0
	first_attack_done = false
	_sync_room.rpc(Room.SPAWN)


func _attack() -> void:
	print("[Sludge] ☠ Attack triggered!")
	_play_jumpscare.rpc()


@rpc("authority", "call_local", "reliable")
func _play_jumpscare() -> void:
	if not is_instance_valid(player_one):
		player_one = get_parent().get_node_or_null("1")
	if player_one == null:
		push_error("Sludge: Player node not found for jumpscare!")
		if multiplayer.is_server():
			game_manager.notify_player_death(1, "Sludge")
		return

	# Lock player and close cameras before jumpscare
	if player_one.has_method("begin_jumpscare"):
		player_one.begin_jumpscare()

	var jumpscare = player_one.find_child("JumpscareSprite", true, false)
	if jumpscare == null:
		push_error("Sludge: JumpscareSprite not found!")
		if multiplayer.is_server():
			game_manager.notify_player_death(1, "Sludge")
		return

	var frames = load("res://2DArt/AnimatedArt/SludgeJumpscare.tres")
	if frames == null:
		push_error("Sludge: SpriteFrames resource not found!")
		if multiplayer.is_server():
			game_manager.notify_player_death(1, "Sludge")
		return

	jumpscare.sprite_frames = frames
	jumpscare.visible = true
	jumpscare.play("jumpscare")
	await jumpscare.animation_finished
	jumpscare.visible = false

	if multiplayer.is_server():
		game_manager.notify_player_death(1, "Sludge")


func _player_is_flashing() -> bool:
	if not is_instance_valid(player_one):
		player_one = get_parent().get_node_or_null("1")
	if player_one == null:
		return false
	if player_one.get("is_flashing") != null:
		return player_one.is_flashing
	return false


func _player_camera_is_up() -> bool:
	if not is_instance_valid(player_one):
		player_one = get_parent().get_node_or_null("1")
	if player_one == null:
		return false
	if player_one.get("in_camera_system") != null:
		return player_one.in_camera_system
	return false


func _on_hour_changed(hour: int) -> void:
	var new_level : int = game_manager.get_ai_level("Sludge")
	print("[Sludge] Hour changed to %d AM — new AI level: %d" % [hour, new_level])
	move_timer = 0.0


@rpc("authority", "call_local", "reliable")
func _sync_room(room: Room) -> void:
	current_room = room
	_update_3d_position(room)


const ROOM_POSITIONS : Dictionary = {
	Room.SPAWN:   { "pos": Vector3(24.5, -9.5, -7.5),    "rot": Vector3(0, 44.1, 0)    },
	Room.R18:     { "pos": Vector3(17.35, -5.95, 4.35),  "rot": Vector3(0, 20.2, 0)    },
	Room.R17:     { "pos": Vector3(17.25, -4.55, 13.5),  "rot": Vector3(3, 180, -25)   },
	Room.R6:      { "pos": Vector3(24.5, 0.28, 14.45),   "rot": Vector3(0, -152.0, 0)  },
	Room.R5:      { "pos": Vector3(37.8, 0.28, -4.9),    "rot": Vector3(0, -17.7, 0)   },
	Room.R3:      { "pos": Vector3(23.75, 0.28, 5.1),    "rot": Vector3(0, -22.1, 0)   },
	Room.R2:      { "pos": Vector3(16.87, 0.28, -3),     "rot": Vector3(0, -2, 0)      },
	Room.HALLWAY: { "pos": Vector3(8.53, 0.28, -4.81),   "rot": Vector3(0, 0, 0)       },
}

func _update_3d_position(room: Room) -> void:
	var data = ROOM_POSITIONS[room]
	self.global_position  = data["pos"]
	self.rotation_degrees = data["rot"]


func _room_name(room: Room) -> String:
	match room:
		Room.SPAWN:   return "SPAWN"
		Room.R18:     return "R18"
		Room.R17:     return "R17"
		Room.R6:      return "R6"
		Room.R5:      return "R5"
		Room.R3:      return "R3"
		Room.R2:      return "R2"
		Room.HALLWAY: return "HALLWAY"
	return "UNKNOWN"
