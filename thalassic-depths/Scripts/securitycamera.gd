extends Node3D

@export var cam_label: String = "CAM 1"
@export var floor_group: String = "top"

const PAN_ANGLE = 12.0
const PAN_DURATION = 5.5

@onready var camera_rig: Node3D = $CameraRig
@onready var source_cam: Camera3D = $CameraRig/Camera3D

var viewport_container: SubViewportContainer
var viewport: SubViewport
var pan_tween: Tween

func _ready():
	_setup_viewport()
	_pan_to(PAN_ANGLE)

func _setup_viewport():
	viewport_container = SubViewportContainer.new()
	viewport_container.visible = false
	viewport_container.size = Vector2(320, 180)
	get_tree().root.add_child(viewport_container)

	viewport = SubViewport.new()
	viewport.size = Vector2i(320, 180)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.world_3d = get_tree().root.get_viewport().world_3d
	viewport_container.add_child(viewport)

	# Reparent the actual camera into the SubViewport
	# This preserves all its settings, attributes, and effects
	source_cam.reparent(viewport)

func get_texture() -> ViewportTexture:
	return viewport.get_texture()

func activate():
	print("Camera activated: ", cam_label)
	source_cam.current = true

func deactivate():
	print("Camera deactivated: ", cam_label)
	source_cam.current = false

func _exit_tree():
	if viewport_container:
		viewport_container.queue_free()

func _pan_to(target: float):
	if pan_tween:
		pan_tween.kill()
	pan_tween = create_tween()
	pan_tween.set_ease(Tween.EASE_IN_OUT)
	pan_tween.set_trans(Tween.TRANS_SINE)
	pan_tween.tween_property(camera_rig, "rotation_degrees:y", target, PAN_DURATION)
	pan_tween.tween_interval(0.8)
	pan_tween.tween_callback(func(): _pan_to(-target))
