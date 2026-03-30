extends Node3D

const OPEN_Y = 0
const CLOSED_Y = -4.0
const TWEEN_DURATION = 0.2

var is_closed: bool = false

func toggle():
	print("toggled")
	is_closed = !is_closed
	var target_y = CLOSED_Y if is_closed else OPEN_Y
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position:y", target_y, TWEEN_DURATION)
