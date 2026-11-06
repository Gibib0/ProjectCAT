extends CharacterBody3D

enum State { PATROL, INVESTIGATE, CHASE }

@export var patrol_root: Node3D          # сюда перетащим PatrolPoints
@export var patrol_speed := 1.2
@export var chase_speed := 2.0
@export var vision_range := 10.0         # как далеко видит (м)
@export var vision_angle := 100.0        # ширина конуса зрения (градусы)
@export var hearing_range := 14.0        # слышимость при максимальной громкости
@export var catch_distance := 1.0
@export var lose_sight_time := 3.0       # сколько секунд помнит кота после потери
@export var gravity := 14.0
@export var freeze_vision_factor := 0.3    # во сколько раз падает дальность зрения для замершего кота


var state: State = State.PATROL
var player: CharacterBody3D
var patrol_points: Array[Vector3] = []
var patrol_index := 0
var wait_timer := 0.0
var time_since_seen := 0.0
var investigate_target := Vector3.ZERO
var active := true    # false на время катсцен: монстр стоит на месте

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var eyes: Marker3D = $Eyes


func _ready() -> void:
	set_physics_process(false)      # пока навигация не готова, ничего не делаем
	player = get_tree().get_first_node_in_group("player")
	add_to_group("monster")
	player.noise_made.connect(_on_noise_made)   # подписка на сигнал шума

	for point in patrol_root.get_children():
		patrol_points.append(point.global_position)

	# Навигация в Godot готова только после первого физического кадра
	await get_tree().physics_frame
	set_physics_process(true)
	_set_state(State.PATROL)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if not active:           # ← НОВОЕ: на время катсцены просто стоим
		_stop()
		move_and_slide()     # чтобы гравитация продолжала работать
		return

	var sees_player := _can_see_player()

	match state:
		State.PATROL:
			_do_patrol(delta)
			if sees_player:
				_set_state(State.CHASE)
		State.INVESTIGATE:
			_do_investigate(delta)
			if sees_player:
				_set_state(State.CHASE)
		State.CHASE:
			_do_chase(delta, sees_player)

	move_and_slide()


# ---------- Поведение в каждом состоянии ----------

func _do_patrol(delta: float) -> void:
	if patrol_points.is_empty():
		_stop()
		return
	if wait_timer > 0.0:                    # пауза на точке
		wait_timer -= delta
		_stop()
		return
	_move_towards(patrol_points[patrol_index], patrol_speed, delta)
	if nav_agent.is_navigation_finished():  # дошёл — следующая точка
		patrol_index = (patrol_index + 1) % patrol_points.size()
		wait_timer = 2.0


func _do_investigate(delta: float) -> void:
	if wait_timer > 0.0:                    # осматривается на месте
		wait_timer -= delta
		_stop()
		if wait_timer <= 0.0:
			_set_state(State.PATROL)
		return
	_move_towards(investigate_target, patrol_speed * 1.3, delta)
	if nav_agent.is_navigation_finished():
		wait_timer = 3.0


func _do_chase(delta: float, sees_player: bool) -> void:
	if sees_player:
		time_since_seen = 0.0
		investigate_target = player.global_position   # запоминаем, где видели
	else:
		time_since_seen += delta

	_move_towards(investigate_target, chase_speed, delta)

	var close_enough := global_position.distance_to(player.global_position) < catch_distance
	if close_enough and not player.is_hidden:
		_caught()
	elif time_since_seen > lose_sight_time:
		_set_state(State.INVESTIGATE)


# ---------- Чувства ----------

func _can_see_player() -> bool:
	if player.is_hidden:
		return false

	var target := player.global_position + Vector3(0, 0.2, 0)
	var to_player := target - eyes.global_position

	var range_now := vision_range
	if player.is_frozen:
		range_now *= freeze_vision_factor    # неподвижного в темноте заметить трудно
	if to_player.length() > range_now:
		return false

	# Угол считаем в горизонтали, иначе близкий кот «слишком низко» и выпадает из конуса
	var flat := Vector3(to_player.x, 0, to_player.z)
	var forward := -global_transform.basis.z
	if rad_to_deg(forward.angle_to(flat)) > vision_angle / 2.0:
		return false

	# Луч от глаз до кота: если что-то по пути, то не видит
	var query := PhysicsRayQueryParameters3D.create(eyes.global_position, target)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == player


func _on_noise_made(pos: Vector3, loudness: float) -> void:
	if not active or state == State.CHASE:
		return
	# Чем громче шум, тем дальше он слышен
	if global_position.distance_to(pos) <= hearing_range * loudness:
		investigate_target = pos
		_set_state(State.INVESTIGATE)


# ---------- Вспомогательное ----------

func _move_towards(target: Vector3, move_speed: float, delta: float) -> void:
	nav_agent.target_position = target
	var next_pos := nav_agent.get_next_path_position()
	var direction := next_pos - global_position
	direction.y = 0.0
	direction = direction.normalized()

	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed

	if direction.length() > 0.01:       # плавно поворачиваемся по ходу движения
		var target_yaw := atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 6.0 * delta)


func _stop() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func _set_state(new_state: State) -> void:
	state = new_state
	wait_timer = 0.0
	time_since_seen = 0.0
	print("Монстр: ", State.keys()[new_state])


func _caught() -> void:
	print("ПОЙМАН!")
	set_physics_process(false)
	get_tree().get_first_node_in_group("caught_screen").show_screen()
	
func set_active(value: bool) -> void:
	active = value
	if not value:
		_stop()
	else:
		_set_state(State.PATROL)    # начинаем с чистого листа, без «погони» из прошлого
	print("Монстр активен: ", value)
