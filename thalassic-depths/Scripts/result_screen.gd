extends Control

@onready var verdict_label     : Label        = $VerdictLabel
@onready var night_label       : Label        = $NightLabel
@onready var outcomes_container: VBoxContainer = $OutcomesContainer
@onready var lobby_button      : Button       = $LobbyButton
 
const KILLER_DISPLAY_NAMES : Dictionary = {
	"Sludge": "Sludge",
}
 
func _ready() -> void:
	_populate()
	lobby_button.pressed.connect(_on_lobby_pressed)
 
 
func _populate() -> void:
	var result : Dictionary = GameData.night_result
 
	var survived_night : bool       = result.get("survived_night", false)
	var player_outcomes: Dictionary = result.get("player_outcomes", {})
	var night_num      : int        = result.get("night_number", 1)
 
	# ── Verdict ────────────────────────────────
	if survived_night:
		verdict_label.text            = "VICTORY"
		verdict_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))
	else:
		verdict_label.text            = "FAILURE"
		verdict_label.add_theme_color_override("font_color", Color(0.9, 0.15, 0.15))
 
	# ── Night number ───────────────────────────
	night_label.text = "Night %d" % night_num
 
	# ── Per-player rows ────────────────────────
	for child in outcomes_container.get_children():
		child.queue_free()
 
	# Sort by peer ID so order is deterministic
	var sorted_ids : Array = player_outcomes.keys()
	sorted_ids.sort()
 
	for peer_id in sorted_ids:
		var alive   : bool   = player_outcomes[peer_id]
		var row     : HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
 
		# Player name label
		var name_lbl : Label = Label.new()
		name_lbl.text        = "Player %d" % peer_id
		name_lbl.custom_minimum_size.x = 120
		row.add_child(name_lbl)
 
		# Status label
		var status_lbl : Label = Label.new()
		if alive:
			status_lbl.text = "Survived"
			status_lbl.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))
		else:
			# Try to find who killed this player from night_result
			var killer : String = result.get("killer_%d" % peer_id, "")
			if killer != "":
				var display_killer : String = KILLER_DISPLAY_NAMES.get(killer, killer)
				status_lbl.text = "Killed by %s" % display_killer
			else:
				status_lbl.text = "Did not survive"
			status_lbl.add_theme_color_override("font_color", Color(0.9, 0.15, 0.15))
 
		row.add_child(status_lbl)
		outcomes_container.add_child(row)
 
 
func _on_lobby_pressed() -> void:
	# Reset result data so stale info never bleeds into the next game
	GameData.night_result = {
		"survived_night"  : false,
		"player_outcomes" : {},
	}
	get_tree().change_scene_to_file("res://Scenes/title_screen.tscn")
 
