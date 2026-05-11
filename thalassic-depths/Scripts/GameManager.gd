extends Node
 
# ─────────────────────────────────────────────
#  GameManager.gd
#  Attach to a Node named "GameManager" in your
#  Game scene. Add it to the group "game_manager".
# ─────────────────────────────────────────────
 
signal hour_changed(new_hour: int)
signal night_over(survived: bool)
signal player_died(player_id: int, killer_name: String)
 
# ── Night timing ──────────────────────────────
# 5 real minutes = 6 in-game hours (12 am → 5 am)
# 50 real seconds per in-game hour
const NIGHT_DURATION   : float = 300.0   # 5:00 in seconds
const HOUR_DURATION    : float = 50.0    # seconds per in-game hour
const HOURS_IN_NIGHT   : int   = 6       # 12 am, 1 am, 2 am, 3 am, 4 am, 5 am
 
# ── Night state ───────────────────────────────
var current_night  : int   = 1
var night_timer    : float = 0.0
var current_hour   : int   = 0           # 0 = 12 am, 1 = 1 am … 5 = 5 am
var night_running  : bool  = false
 
# ── Death tracking ────────────────────────────
# Peer IDs of players who are still alive
var alive_players  : Array = []
 
# ── AI Level schedules ────────────────────────
# Each entry is [min_level, max_level] per hour index (0–5).
# A range like [1,2] picks randomly at the start of that hour.
# Add more entities here as you create them.
var ai_schedules : Dictionary = {
	# night_number -> [ [min,max] × 6 hours ]
	"Sludge": {
		1: [[0,0],[0,0],[1,2],[2,2],[2,3],[3,3]],
		# Add future nights below:
		# 2: [[0,0],[1,1],[2,2],[2,3],[3,4],[4,4]],
	}
}
 
# Live AI levels for this night, keyed by entity name
var current_ai_levels : Dictionary = {}
 
 
# ═════════════════════════════════════════════
func _ready() -> void:
	add_to_group("game_manager")
 
 
# ─────────────────────────────────────────────
#  Public API
# ─────────────────────────────────────────────
 
func start_night(night_num: int, player_ids: Array) -> void:
	current_night  = night_num
	night_timer    = 0.0
	current_hour   = 0
	night_running  = true
	alive_players  = player_ids.duplicate()
 
	_resolve_ai_levels(0)
	hour_changed.emit(0)
	set_process(true)
 
 
func get_ai_level(entity_name: String) -> int:
	return current_ai_levels.get(entity_name, 0)
 
 
# Called by Sludge (or any entity) via RPC when it kills a player.
# Only the server should call this.
@rpc("authority", "call_local", "reliable")
func notify_player_death(player_id: int, killer_name: String) -> void:
	if not multiplayer.is_server():
		return
 
	alive_players.erase(player_id)
	player_died.emit(player_id, killer_name)
	_broadcast_death.rpc(player_id, killer_name)
 
	if alive_players.is_empty():
		_end_night(false)
 
 
# ─────────────────────────────────────────────
#  Internal – tick
# ─────────────────────────────────────────────
 
func _process(delta: float) -> void:
	if not night_running:
		return
	if not multiplayer.is_server():
		return
 
	night_timer += delta
 
	# Hour advancement
	var new_hour = int(night_timer / HOUR_DURATION)
	if new_hour != current_hour and new_hour < HOURS_IN_NIGHT:
		current_hour = new_hour
		_resolve_ai_levels(current_hour)
		_sync_hour.rpc(current_hour, current_ai_levels)
		hour_changed.emit(current_hour)
 
	# Night complete (survived)
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
 
 
func _end_night(survived: bool) -> void:
	night_running = false
	set_process(false)
	_sync_night_over.rpc(survived)
	night_over.emit(survived)
 
 
# ─────────────────────────────────────────────
#  RPCs – keep all peers in sync
# ─────────────────────────────────────────────
 
@rpc("authority", "call_local", "reliable")
func _sync_hour(hour: int, ai_levels: Dictionary) -> void:
	current_hour       = hour
	current_ai_levels  = ai_levels
	hour_changed.emit(hour)
 
 
@rpc("authority", "call_local", "reliable")
func _sync_night_over(survived: bool) -> void:
	night_running = false
	night_over.emit(survived)
 
 
@rpc("authority", "call_local", "reliable")
func _broadcast_death(player_id: int, killer_name: String) -> void:
	player_died.emit(player_id, killer_name)
