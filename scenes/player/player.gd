class_name Player
extends KinematicBody

signal state_changed
signal aim_changed
signal crouch_changed
signal direction_changed

export var max_walk_speed := 3
export var max_crouch_speed := 2
export var max_sprint_speed := 7
export var max_roll_speed := 8
export var acceleration := 10
export var ground_friction := 13
export var jump_force := 6
export var camera_rotation_speed := 0.0015
export var min_camera_rotation := -70
export var max_camera_rotation := 70
export var min_camera_zoom := 1
export var max_camera_zoom := 5
export var camera_zoom_factor := 0.5
export var camera_zoom_speed := 10

enum STATE {
	IDLE,
	WALK,
	SPRINT,
	JUMP,
	ROLL,
	FALL,
}

var state: int = STATE.IDLE setget set_state, get_state
var aim := false setget set_aim, get_aim
var crouch := false setget set_crouch, get_crouch
var max_speed := max_walk_speed
var direction := Vector3() setget set_direction, get_direction
var orientation := Transform()
var velocity := Vector3()
var snap := Vector3.DOWN
var camera_x_rotation := 0.0
var collision_shape_translation := Vector3()
var collision_shape_height := 0.0

onready var gravity = ProjectSettings.get_setting("physics/3d/default_gravity") * ProjectSettings.get_setting("physics/3d/default_gravity_vector")
onready var animation_tree = $AnimationTree
onready var model = $Model
onready var collision_shape = $CollisionShape
onready var camera_y = $CameraY
onready var camera_x = $CameraY/CameraX
onready var camera_spring_arm = $CameraY/CameraX/SpringArm
onready var camera = $CameraY/CameraX/SpringArm/Camera


#### ACCESSORS ####

func set_state(value: int) -> void:
	if state != value:
		state = value
		emit_signal("state_changed")


func get_state() -> int:
	return state


func set_aim(value: bool) -> void:
	if aim != value:
		aim = value
		emit_signal("aim_changed")


func get_aim() -> bool:
	return aim


func set_crouch(value: bool) -> void:
	if crouch != value:
		crouch = value
		emit_signal("crouch_changed")


func get_crouch() -> bool:
	return crouch


func set_direction(value: Vector3) -> void:
	if direction != value:
		direction = value
		emit_signal("direction_changed")


func get_direction() -> Vector3:
	return direction


#### BUILT-IN ####

func _ready() -> void:
	_orientation_init()
	_collision_shape_init()


func _physics_process(delta: float) -> void:
	_state_factory()
	_movement(delta)
	_orientation(delta)


func _input(event: InputEvent) -> void:
	_direction()
	_camera_rotation(event)
	_camera_zoom(event)


#### LOGIC ####

func _orientation_init() -> void:
	orientation = model.global_transform
	orientation.origin = Vector3()


func _collision_shape_init() -> void:
	collision_shape_translation = collision_shape.translation
	collision_shape_height = collision_shape.shape.height


func _state_factory() -> void:
	# AIM
	if Input.is_action_just_pressed("aim"):
		set_crouch(false)
		set_aim(true)
	elif Input.is_action_just_released("aim"):
		set_aim(false)

	# Crouch
	if Input.is_action_just_pressed("crouch") and !get_aim():
		set_crouch(!get_crouch())

	# State
	if animation_tree["parameters/state/current"] != 10: # Waits for the end of the rolling animation
		if is_on_floor():
			if get_direction() and Input.is_action_just_pressed("jump") and get_aim():
				set_crouch(false)
				set_state(STATE.ROLL)
			elif Input.is_action_just_pressed("jump") and !get_aim():
				set_crouch(false)
				set_state(STATE.JUMP)
			elif Input.is_action_pressed("sprint") and get_direction() and !get_aim():
				set_crouch(false)
				set_state(STATE.SPRINT)
			elif Vector3(velocity.x, 0, velocity.z).length_squared() > 0.01 and get_direction():
				set_state(STATE.WALK)
			else:
				set_state(STATE.IDLE)
		else:
			set_crouch(false)
			set_state(STATE.FALL)


func _movement(delta: float) -> void:
	# Speed
	if get_crouch():
		max_speed = max_crouch_speed
	elif get_state() == STATE.SPRINT:
		max_speed = max_sprint_speed
	elif get_state() == STATE.ROLL:
		max_speed = max_roll_speed
	else:
		max_speed = max_walk_speed

	# Velocity
	if get_direction() and not is_on_wall():
		var camera_basis = camera_y.global_transform.basis
		var new_velocity = -(camera_basis.x * get_direction().x + camera_basis.z * get_direction().z) * max_speed
		new_velocity = velocity.linear_interpolate(new_velocity, acceleration * delta)
		velocity.x = new_velocity.x
		velocity.z = new_velocity.z

	# Friction
	if not get_direction():
		var new_velocity = velocity.linear_interpolate(Vector3.ZERO, ground_friction * delta)
		velocity.x = new_velocity.x
		velocity.z = new_velocity.z

	# Gravity
	velocity += gravity * delta

	# Jump
	if get_state() == STATE.JUMP:
		velocity.y = jump_force
		snap = Vector3.ZERO

	# Apply movement
	velocity = move_and_slide_with_snap(velocity, snap, Vector3.UP, true)
	snap = Vector3.DOWN


func _orientation(delta: float) -> void:
	var camera_basis = camera_y.global_transform.basis
	var new_orientation = camera_basis.x * get_direction().x + camera_basis.z * get_direction().z
	if get_aim() and get_state() != STATE.ROLL:
		new_orientation = -camera_y.global_transform.basis.z
	if new_orientation:
		orientation.basis = orientation.basis.slerp(orientation.looking_at(new_orientation, Vector3.UP).basis, delta * 10)
		model.global_transform.basis = orientation.basis


func _direction() -> void:
	var new_direction = Vector3(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		0,
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)
	set_direction(new_direction.normalized())


func _camera_rotation(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var target = event.relative * camera_rotation_speed
		camera_y.rotate_y(-target.x)
		camera_y.orthonormalize()
		camera_x_rotation += target.y
		camera_x_rotation = clamp(camera_x_rotation, deg2rad(min_camera_rotation), deg2rad(max_camera_rotation))
		camera_x.rotation.x = camera_x_rotation


func _camera_zoom(event: InputEvent) -> void:
	var spring_length = camera_spring_arm.spring_length
	if event.is_action_pressed("zoom_in"):
		camera_spring_arm.spring_length = clamp(spring_length - camera_zoom_factor, min_camera_zoom, max_camera_zoom)
	elif event.is_action_pressed("zoom_out"):
		camera_spring_arm.spring_length = clamp(spring_length + camera_zoom_factor, min_camera_zoom, max_camera_zoom)


func _update_animation() -> void:
	match get_state():
		STATE.JUMP:
			animation_tree["parameters/state/current"] = 3
		STATE.ROLL:
			animation_tree["parameters/state/current"] = 10
		STATE.SPRINT:
			animation_tree["parameters/state/current"] = 2
		STATE.WALK:
			if get_crouch():
				animation_tree["parameters/state/current"] = 9
			elif get_aim():
				if get_direction().x < 0:
					animation_tree["parameters/state/current"] = 5
				elif get_direction().x > 0:
					animation_tree["parameters/state/current"] = 6
				elif get_direction().z < 0:
					animation_tree["parameters/state/current"] = 1
				elif get_direction().z > 0:
					animation_tree["parameters/state/current"] = 7
			else:
				animation_tree["parameters/state/current"] = 1
		STATE.IDLE:
			if get_crouch():
				animation_tree["parameters/state/current"] = 8
			elif get_aim():
				animation_tree["parameters/state/current"] = 0
			else:
				animation_tree["parameters/state/current"] = 0
		STATE.FALL:
			animation_tree["parameters/state/current"] = 4


func _update_collision_shape() -> void:
	if get_crouch() or get_state() == STATE.ROLL:
		collision_shape.translation = collision_shape_translation - Vector3(0, 0.2, 0)
		collision_shape.shape.height = collision_shape_height / 2
	else:
		collision_shape.translation = collision_shape_translation
		collision_shape.shape.height = collision_shape_height


#### SIGNAL RESPONSES ####

func _on_Player_state_changed() -> void:
	_update_animation()
	_update_collision_shape()


func _on_Player_direction_changed() -> void:
	_update_animation()


func _on_Player_crouch_changed() -> void:
	_update_animation()
	_update_collision_shape()


func _on_Player_aim_changed() -> void:
	_update_animation()
