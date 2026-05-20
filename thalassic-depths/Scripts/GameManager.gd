extends Node

signal hour_changed(new_hour: int)
signal night_over(survived: bool)
signal player_died(player_id: int, killer_name: String)

const NIGHT_DURATION   : float = 300.0
const HOUR_DURATION    : float = 50.0
const HOURS_IN_NIGHT   : int   = 6

var current_night  : int   = 1
var night_timer    : float = 0.0
var current_hour   : int   = 0
var night_running  : bool  = false

var alive_players  : Dictionary = {}

var ai_schedules : Dictionary = {
	"Sludge": {
		1: [[0,0],[0,0],[1,2],[2,2],[2,3],[3,3]],
		10: [[20,20],[20,20],[20,20],[20,20],[20,20],[20,20]]
	}
}

var current_ai_levels : Dictionary = {}


func _ready() -> void:
	add_to_group("game_manager")


func start_night(night_num: int, player_ids: Array) -> void:
	current_night = night_num + 9
	night_timer   = 0.0
	current_hour  = 0
	night_running = true
	alive_players.clear()
	for id in player_ids:
		alive_players[id] = true

	_resolve_ai_levels(current_hour)
	hour_changed.emit(0)
	set_process(true)


func get_ai_level(entity_name: String) -> int:
	return current_ai_levels.get(entity_name, 0)


func is_player_alive(player_id: int) -> bool:
	return alive_players.get(player_id, false)


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

	var survivor_id : int = -1
	for id in alive_players:
		if alive_players[id]:
			survivor_id = id
			break

	if survivor_id == -1:
		# Both dead — stop night immediately
		night_running = false
		set_process(false)
		# Last dead player gets death screen then results
		_show_death_screen_then_black.rpc_id(player_id, killer_name)
		# First dead player gets all-dead black screen
		for id in alive_players:
			if id != player_id:
				_show_all_dead_black.rpc_id(id)
	else:
		# One survivor — dead player gets death screen then spectates
		_show_death_screen_then_spectate.rpc_id(player_id, killer_name, survivor_id)


# rpc_id sends to a specific peer; the peer ID is consumed by rpc_id itself,
# so the method signature only declares the remaining arguments.
@rpc("authority", "call_local", "reliable")
func _show_death_screen_then_spectate(killer_name: String, spectate_target_id: int) -> void:
	var my_id := multiplayer.get_unique_id()
	var player_node = get_parent().get_node_or_null(str(my_id))
	if player_node and player_node.has_method("show_death_screen"):
		player_node.show_death_screen(killer_name)

	await get_tree().create_timer(3.0).timeout

	if player_node and player_node.has_method("begin_spectate"):
		player_node.begin_spectate(spectate_target_id)


@rpc("authority", "call_local", "reliable")
func _show_death_screen_then_black(killer_name: String) -> void:
	var my_id := multiplayer.get_unique_id()
	var player_node = get_parent().get_node_or_null(str(my_id))
	if player_node and player_node.has_method("show_death_screen"):
		player_node.show_death_screen(killer_name)

	await get_tree().create_timer(3.0).timeout

	_go_to_result_scene.rpc()


@rpc("authority", "call_local", "reliable")
func _show_all_dead_black() -> void:
	var my_id := multiplayer.get_unique_id()
	var death_screen = get_parent().get_node_or_null("%s/HUD/DeathScreen" % my_id)
	if death_screen and death_screen.has_method("show_all_dead"):
		death_screen.show_all_dead()


func _end_night(survived: bool) -> void:
	night_running = false
	set_process(false)

	var outcomes : Dictionary = {}
	for id in alive_players:
		outcomes[id] = alive_players[id]

	_sync_night_over.rpc(survived, outcomes)
	night_over.emit(survived)


@rpc("authority", "call_local", "reliable")
func _sync_hour(hour: int, ai_levels: Dictionary) -> void:
	current_hour      = hour
	current_ai_levels = ai_levels
	hour_changed.emit(hour)


@rpc("authority", "call_local", "reliable")
func _sync_night_over(survived: bool, outcomes: Dictionary) -> void:
	night_running = false
	night_over.emit(survived)
	GameData.night_result["survived_night"]  = survived
	GameData.night_result["player_outcomes"] = outcomes


@rpc("authority", "call_local", "reliable")
func _broadcast_death(player_id: int, killer_name: String) -> void:
	player_died.emit(player_id, killer_name)


@rpc("authority", "call_local", "reliable")
func _go_to_result_scene() -> void:
	get_tree().change_scene_to_file("res://scenes/result_screen.tscn")
