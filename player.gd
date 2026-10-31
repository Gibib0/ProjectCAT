extends CharacterBody3D

# НОВОЕ: сигнал, которым игрок «сообщает миру», что произвёл шум.
# Монстры и шкала стресса потом смогут на него подписаться.
signal noise_made(position: Vector3, loudness: float)

@export var speed := 1.5
@export var mouse_sensitivity := 0.002
@export var jump_velocity := 5.5        # НОВОЕ: начальная скорость прыжка
@export var gravity := 14.0             # НОВОЕ: теперь настраиваемая

@onready var head: Node3D = $Head


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	add_to_group("player")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-80), deg_to_rad(80))


func _physics_process(delta: float) -> void:
	var was_on_floor := is_on_floor()   # НОВОЕ: стояли ли мы в прошлом кадре

	if not is_on_floor():
		velocity.y -= gravity * delta

	# НОВОЕ: прыжок возможен только если стоим на поверхности
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	var fall_speed := velocity.y        # НОВОЕ: запоминаем ДО move_and_slide
	move_and_slide()

	# НОВОЕ: если только что приземлились, считаем, насколько это было громко
	if is_on_floor() and not was_on_floor:
		_on_landed(fall_speed)


# НОВОЕ
func _on_landed(fall_speed: float) -> void:
	var impact := absf(fall_speed)
	if impact < 3.0:
		return    # мягкое приземление, шума нет
	var loudness := clampf(impact / 10.0, 0.0, 1.0)
	print("Шум! Громкость: ", loudness)
	noise_made.emit(global_position, loudness)
