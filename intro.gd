extends Node

@export var enabled := true                       # галочка для тестов: можно выключить вступление
@export var fade_rect: ColorRect                  # узел Fade из HUD
@export var noise_source: Marker3D                # откуда придёт шум
@export var noise_sound: AudioStreamPlayer3D      # сам звук
@export var dark_pause := 1.5                     # секунды в полной темноте
@export var fade_time := 3.0                      # сколько «открываются глаза»
@export var quiet_time := 2.0                     # тишина перед шумом


func _ready() -> void:
	await get_tree().process_frame               # ждём, пока игрок точно появится
	var player := get_tree().get_first_node_in_group("player")

	# Если перезапуск с контрольной точки или вступление выключено: пропускаем
	if GameState.has_checkpoint or not enabled:
		fade_rect.color.a = 0.0
		return

	await _play_intro(player)


func _play_intro(player: Node) -> void:
	var stress := player.get_node("Stress")
	player.controls_enabled = false
	stress.base = 0.0           # сбрасываем накопленное
	stress.paused = true        # и не даём расти
	_set_monsters_active(false)           # ← НОВОЕ: монстры замирают
	fade_rect.color.a = 1.0

	# Только проснулись: голова чуть опущена
	var head: Node3D = player.get_node("Head")
	head.rotation.x = deg_to_rad(-25)

	await get_tree().create_timer(dark_pause).timeout

	# «Открываем глаза»: экран светлеет, голова поднимается
	var wake := create_tween().set_parallel(true)
	wake.tween_property(fade_rect, "color:a", 0.0, fade_time)
	wake.tween_property(head, "rotation:x", 0.0, fade_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await wake.finished

	await get_tree().create_timer(quiet_time).timeout

	# Шум из другой комнаты
	noise_sound.play()
	player.get_node("Stress").add_spike(25.0, 4.0)

	# Кот сам поворачивается в сторону шума
	var to_noise: Vector3 = noise_source.global_position - player.global_position
	var target_yaw := atan2(-to_noise.x, -to_noise.z)
	var turn_to: float = player.rotation.y + angle_difference(player.rotation.y, target_yaw)
	var turn := create_tween()
	turn.tween_property(player, "rotation:y", turn_to, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await turn.finished

	player.controls_enabled = true
	stress.paused = false
	_set_monsters_active(true)        # ← НОВОЕ: монстры оживают вместе с игроком
	
func _set_monsters_active(active: bool) -> void:
	for monster in get_tree().get_nodes_in_group("monster"):
		monster.set_active(active)
