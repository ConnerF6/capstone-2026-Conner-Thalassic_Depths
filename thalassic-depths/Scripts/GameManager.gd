extends Node
<<<<<<< Updated upstream
 
signal hour_changed(new_hour: int)
signal night_over(survived: bool)
signal player_died(player_id: int, killer_name: String)
 
# 5 real minutes = 6 in-game hours (12 am → 5 am)
# 50 real seconds per in-game hour
const NIGHT_DURATION   : float = 300.0   # 5:00 in seconds
const HOUR_DURATION    : float = 50.0    # seconds per in-game hour
const HOURS_IN_NIGHT   : int   = 6       # 12 am, 1 am, 2 am, 3 am, 4 am, 5 am
 
var current_night  : int   = 1
=======

signal hour_changed(new_hour: int)
signal night_over(survived: bool)
signal player_died(player_id: int, killer_name: String)

const NIGHT_DURATION   : float = 300.0
const HOUR_DURATION    : float = 50.0
const HOURS_IN_NIGHT   : int   = 6

var current_night  : int   = 10
>>>>>>> Stashed changes
var night_timer    : float = 0.0
var current_hour   : int   = 0
var night_running  : bool  = false
<<<<<<< Updated upstream
 
# Peer IDs of players who are still alive
var alive_players  : Array = []
 
# Each entry is [min_level, max_level] per hour index (0–5).
# A range like [1,2] picks randomly at the start of that hour.
# Add more entities here as you create them.
=======

# peer_id -> bool (true = alive, false = dead)
var alive_players  : Dictionary = {}

>>>>>>> Stashed changes
var ai_schedules : Dictionary = {
	"Sludge": {
		1: [[0,0],[0,0],[1,2],[2,2],[2,3],[3,3]],
		10: [[10,10], [10,10],[10,10],[10,10],[10,10],[10,10]] #debug
	}
}

var current_ai_levels : Dictionary = {}
<<<<<<< Updated upstream
 
 
func _ready() -> void:
	add_to_group("game_manager")
 
 
=======
var _death_screens_done : int = 0


func _ready() -> void:
	add_to_group("game_manager")


>>>>>>> Stashed changes
func start_night(night_num: int, player_ids: Array) -> void:
	current_night = night_num + 9 #temp for debug
	night_timer   = 0.0
	current_hour  = 0
	night_running = true
	_death_screens_done = 0
	alive_players.clear()
	for id in player_ids:
		alive_players[id] = true

	_resolve_ai_levels(0)
	hour_changed.emit(0)
	set_process(true)
<<<<<<< Updated upstream

@rpc("authority", "call_local", "reliable")
func _sync_night_over(survived: bool) -> void:
	night_running = false
	night_over.emit(survived)

func _end_night(survived: bool) -> void:
	night_running = false
	set_process(false)
	_sync_night_over.rpc(survived)
	night_over.emit(survived)
	if survived and multiplayer.is_server():
		await get_tree().create_timer(3.0).timeout
		NetworkManager.return_to_lobby.rpc()

func get_ai_level(entity_name: String) -> int:
	return current_ai_levels.get(entity_name, 0)
 
 
=======
	_resolve_ai_levels(current_hour)


func get_ai_level(entity_name: String) -> int:
	return current_ai_levels.get(entity_name, 0)


func trigger_attack(killer_name: String, targets_both: bool) -> void:
	if not multiplayer.is_server():
		return

	if targets_both:
		var targets := alive_players.keys().filter(
			func(id): return alive_players[id]
		)
		for id in targets:
			_show_death_screen.rpc_id(id, killer_name)
			notify_player_death(id, killer_name)
	else:
		_show_death_screen.rpc_id(1, killer_name)
		notify_player_death(1, killer_name)


>>>>>>> Stashed changes
@rpc("authority", "call_local", "reliable")
func notify_player_death(player_id: int, killer_name: String) -> void:
	if not multiplayer.is_server():
		return
	if not alive_players.has(player_id):
		return
	if not alive_players[player_id]:
		return

	alive_players[player_id] = false
	player_died.emit(player_id, killer_name)
	_broadcast_death.rpc(player_id, killer_name)

	var any_alive := false
	for id in alive_players:
		if alive_players[id]:
			any_alive = true
			break

	if not any_alive:
		_end_night(false)
<<<<<<< Updated upstream
 
=======


>>>>>>> Stashed changes
func _process(delta: float) -> void:
	if not night_running or not multiplayer.is_server():
		return

	night_timer += delta

	var new_hour := int(night_timer / HOUR_DURATION)
	if new_hour != current_hour and new_hour < HOURS_IN_NIGHT:
		current_hour = new_hour
		_resolve_ai_levels(current_hour)
		_sync_hour.rpc(current_hour, current_ai_levels)
		hour_changed.emit(current_hour)

	if night_timer >= NIGHT_DURATION:
		_end_night(true)


func _resolve_ai_levels(hour_index: int) -> void:
	for entity in ai_schedules:
		var schedule = ai_schedules[entity]
		var night_key = current_night if schedule.has(current_night) else schedule.keys()[0]
		var hours : Array = schedule[night_key]
		if hour_index < hours.size():
			var range_pair : Array = hours[hour_index]
			var lo : int = range_pair[0]
			var hi : int = range_pair[1]
			current_ai_levels[entity] = randi_range(lo, hi) if lo != hi else lo
		else:
			current_ai_levels[entity] = 0


<<<<<<< Updated upstream
=======
func _end_night(survived: bool) -> void:
	night_running = false
	set_process(false)

	var outcomes : Dictionary = {}
	for id in alive_players:
		outcomes[id] = alive_players[id]

	_sync_night_over.rpc(survived, outcomes)
	night_over.emit(survived)


func report_death_screen_done() -> void:
	if not multiplayer.is_server():
		_rpc_report_done.rpc_id(1)
		return
	_death_screens_done += 1
	var dead_count := 0
	for id in alive_players:
		if not alive_players[id]:
			dead_count += 1
	if _death_screens_done >= dead_count:
		_go_to_result_scene.rpc()


@rpc("any_peer", "call_local", "reliable")
func _rpc_report_done() -> void:
	if multiplayer.is_server():
		report_death_screen_done()


@rpc("authority", "call_local", "reliable")
func _show_death_screen(killer_name: String) -> void:
	print("[GameManager] Show death screen — killed by: %s" % killer_name)
	# get_tree().call_group("ui_manager", "show_death_screen", multiplayer.get_unique_id(), killer_name)


>>>>>>> Stashed changes
@rpc("authority", "call_local", "reliable")
func _sync_hour(hour: int, ai_levels: Dictionary) -> void:
	current_hour      = hour
	current_ai_levels = ai_levels
	hour_changed.emit(hour)
<<<<<<< Updated upstream
 
 
 
=======


@rpc("authority", "call_local", "reliable")
func _sync_night_over(survived: bool, outcomes: Dictionary) -> void:
	night_running = false
	night_over.emit(survived)
	GameData.night_result["survived_night"]  = survived
	GameData.night_result["player_outcomes"] = outcomes

	if survived:
		_go_to_result_scene.rpc()


>>>>>>> Stashed changes
@rpc("authority", "call_local", "reliable")
func _broadcast_death(player_id: int, killer_name: String) -> void:
	player_died.emit(player_id, killer_name)


@rpc("authority", "call_local", "reliable")
func _go_to_result_scene() -> void:
	get_tree().change_scene_to_file("res://scenes/result_screen.tscn")
