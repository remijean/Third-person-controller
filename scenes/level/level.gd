extends Spatial


#### BUILT-IN ####

func _ready() -> void:
	_mouse_capture_init()


func _input(event: InputEvent) -> void:
	_mouse_capture_toggle(event)
	_fullscreen_toggle(event)


#### LOGIC ####

func _mouse_capture_init() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _mouse_capture_toggle(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _fullscreen_toggle(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		OS.window_fullscreen = !OS.window_fullscreen
