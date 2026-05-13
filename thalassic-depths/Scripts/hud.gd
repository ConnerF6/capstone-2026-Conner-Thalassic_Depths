extends Control


@onready var hour_label:  Label = $HourLabel
@onready var timer_label: Label = $TimerLabel

var game_manager: Node = null
var data: Resource = null
var elapsed: float = 0.0
var night_running: bool = false

const HOUR_NAMES := ["12 AM", "1 AM", "2 AM", "3 AM", "4 AM", "5 AM"]


func _ready() -> void:
	data = load("res://Scripts/DataManager.gd").get_or_create()

	timer_label.visible = data.show_timer

	await get_tree().create_timer(0.5).timeout

	var gm_nodes = get_tree().get_nodes_in_group("game_manager")
	if gm_nodes.is_empty():
		push_error("NightClockUI: GameManager not found!")
		return

	game_manager = gm_nodes[0]
	game_manager.hour_changed.connect(_on_hour_changed)
	game_manager.night_over.connect(_on_night_over)

	_on_hour_changed(0)
	night_running = true


func _process(delta: float) -> void:
	if not night_running:
		return

	elapsed += delta

	if data.show_timer:
		timer_label.visible = true
		var minutes   := int(elapsed) / 60
		var seconds   := int(elapsed) % 60
		var centisecs := int(fmod(elapsed, 1.0) * 100)
		timer_label.text = "%02d:%02d:%02d" % [minutes, seconds, centisecs]
	else:
		timer_label.visible = false


func _on_hour_changed(hour: int) -> void:
	if hour < HOUR_NAMES.size():
		hour_label.text = HOUR_NAMES[hour]
	else:
		hour_label.text = ""


func _on_night_over(_survived: bool) -> void:
	night_running = false


func apply_timer_setting(enabled: bool) -> void:
	data.show_timer = enabled
	data.save_game()
	timer_label.visible = enabled
