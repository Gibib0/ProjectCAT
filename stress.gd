extends Node

signal value_changed(value: float)
signal stage_changed(stage: int)
signal panicked

@export var sense_range := 8.0       # с какого расстояния кот «чует» монстра
@export var rise_rate := 25.0        # скорость роста вплотную к монстру (ед/с)
@export var calm_rate := 3.0         # медленное успокоение, когда монстров рядом нет
@export var safe_calm_rate := 15.0   # быстрое успокоение в укрытии
@export var freeze_rise_factor := 0.5

var base := 0.0                      # медленная часть стресса
var safe := false                    # true, пока кот в укрытии (включим позже)
var value := 0.0                     # итог: base + скачки
var stage := 0
var spikes: Array[Dictionary] = []   # активные скачки от шума
var _panic_fired := false
var paused := false    # true на время катсцен: базовый стресс не меняется

@onready var player: CharacterBody3D = get_parent()


func _ready() -> void:
	player.noise_made.connect(_on_player_noise)


func _process(delta: float) -> void:
	if not paused:
		_update_base(delta)
	value = clampf(base + _update_spikes(delta), 0.0, 100.0)
	value_changed.emit(value)
	_check_stage()


# ---------- Публичные методы: их будут вызывать другие части игры ----------

# Скачок стресса: на amount единиц, затухает за duration секунд
func add_spike(amount: float, duration: float) -> void:
	spikes.append({"amount": amount, "duration": duration, "time": duration})

# Мгновенно снизить базовый стресс (для предметов-воспоминаний)
func reduce(amount: float) -> void:
	base = maxf(base - amount, 0.0)


# ---------- Внутренняя логика ----------

func _update_base(delta: float) -> void:
	var nearest := INF
	for monster in get_tree().get_nodes_in_group("monster"):
		nearest = minf(nearest, player.global_position.distance_to(monster.global_position))

		if safe:
			base -= safe_calm_rate * delta
		elif nearest < sense_range:
			var closeness := 1.0 - nearest / sense_range
			var rate := rise_rate * closeness
			if player.is_frozen:
				rate *= freeze_rise_factor    # замерев, стресс растёт медленнее
			base += rate * delta
		elif not player.is_frozen:
			base -= calm_rate * delta         # замерев, стресс не падает

	base = clampf(base, 0.0, 100.0)


func _update_spikes(delta: float) -> float:
	var total := 0.0
	# Идём с конца, чтобы безопасно удалять элементы во время обхода
	for i in range(spikes.size() - 1, -1, -1):
		var s := spikes[i]
		s["time"] -= delta
		if s["time"] <= 0.0:
			spikes.remove_at(i)
		else:
			total += s["amount"] * (s["time"] / s["duration"])   # линейное затухание
	return total


func _check_stage() -> void:
	var new_stage := 0
	if value >= 75.0:
		new_stage = 2
	elif value >= 50.0:
		new_stage = 1

	if new_stage != stage:
		stage = new_stage
		print("Стресс: стадия ", stage)
		stage_changed.emit(stage)

	if value >= 100.0 and not _panic_fired:
		_panic_fired = true
		print("ПАНИКА!")
		panicked.emit()
	elif value < 75.0:
		_panic_fired = false    # паника может повториться, только если стресс заметно упал


func _on_player_noise(_pos: Vector3, loudness: float) -> void:
	add_spike(loudness * 30.0, 1.5)    # короткий скачок от приземления
