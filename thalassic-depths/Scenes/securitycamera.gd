extends Node3D

@export var cam_label: String = "CAM 1"
@export var floor_group: String = "top"  # "top" or "bottom"

const PAN_ANGLE = 12.0   # degrees either side
const PAN_DURATION = 5.5 # seconds per sweep

@onready var camera_rig: Node3D = $CameraRig
@onready var cam: Camera3D = $CameraRig/Camera3D

var pan_tween: Tween

func _ready():
	cam.current = false
	_start_pan()

func activate(viewport: SubViewport):
	# Reparent camera to the given viewport temporarily
	cam.current = true

func deactivate():
	cam.current = false

func _start_pan():
	_pan_to(PAN_ANGLE)

func _pan_to(target: float):
	if pan_tween:
		pan_tween.kill()
	pan_tween = create_tween()
	pan_tween.set_ease(Tween.EASE_IN_OUT)
	pan_tween.set_trans(Tween.TRANS_SINE)
	pan_tween.tween_property(camera_rig, "rotation_degrees:y", target, PAN_DURATION)
	# Pause at edge then sweep back
	pan_tween.tween_interval(0.8)
	pan_tween.tween_callback(func(): _pan_to(-target))
