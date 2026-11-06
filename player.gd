extends CharacterBody3D

# НОВОЕ: сигнал, которым игрок «сообщает миру», что произвёл шум.
# Монстры и шкала стресса потом смогут на него подписаться.
signal noise_made(position: Vector3, loudness: float)

var is_hidden := false
var is_frozen := false

@export var speed := 1.5
@export var mouse_sensitivity := 0.002
@export var jump_velocity := 5.5
@export var gravity := 14.0

@onready var head: Node3D = $Head
@onready var stress: Node = $Stress


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	add_to_group("player")
	if GameState.has_checkpoint:
		global_position = GameState.checkpoint_position + Vector3(0, 0.1, 0)
		rotation.y = GameState.checkpoint_yaw


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-80), deg_to_rad(80))


func _physics_process(delta: float) -> void:
	var was_on_floor := is_on_floor()

	# Замереть можно, только стоя на земле и пока не наступила паника
	is_frozen = Input.is_action_pressed("freeze") and is_on_floor() and stress.value < 100.0

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_frozen:
		velocity.y = jump_velocity

	# Замерший кот не двигается: ввод считаем нулевым
	var input_dir := Vector2.ZERO
	if not is_frozen:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	var fall_speed := velocity.y
	move_and_slide()

	if is_on_floor() and not was_on_floor:
		_on_landed(fall_speed)


# Вызывается укрытием (HidingSpot)
func set_hidden(value: bool) -> void:
	is_hidden = value
	stress.safe = value    # в укрытии стресс падает быстро


# НОВОЕ
func _on_landed(fall_speed: float) -> void:
	var impact := absf(fall_speed)
	if impact < 3.0:
		return    # мягкое приземление, шума нет
	var loudness := clampf(impact / 10.0, 0.0, 1.0)
	print("Шум! Громкость: ", loudness)
	noise_made.emit(global_position, loudness)
