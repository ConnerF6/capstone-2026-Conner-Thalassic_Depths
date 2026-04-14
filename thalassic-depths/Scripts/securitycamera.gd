extends Node3D

@export var cam_label: String = "CAM 1"
@export var floor_group: String = "top"

const PAN_ANGLE = 12.0
const PAN_DURATION = 5.5

@onready var camera_rig: Node3D = $CameraRig
@onready var cam: Camera3D = $CameraRig/Camera3D
@onready var viewport: SubViewport = $SubViewport

var pan_tween: Tween

func _ready():
	# Move the camera into the SubViewport so it renders independently
	camera_rig.reparent(viewport)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_pan_to(PAN_ANGLE)

func get_texture() -> ViewportTexture:
	return viewport.get_texture()

func activate():
	print("Camera activated: ", cam_label)

func deactivate():
	print("Camera deactivated: ", cam_label)

func _pan_to(target: float):
	if pan_tween:
		pan_tween.kill()
	pan_tween = create_tween()
	pan_tween.set_ease(Tween.EASE_IN_OUT)
	pan_tween.set_trans(Tween.TRANS_SINE)
	pan_tween.tween_property(camera_rig, "rotation_degrees:y", target, PAN_DURATION)
	pan_tween.tween_interval(0.8)
	pan_tween.tween_callback(func(): _pan_to(-target))
