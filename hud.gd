extends CanvasLayer

@onready var bar: ProgressBar = $ProgressBar
@onready var vignette: ColorRect = $Vignette


func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var stress := player.get_node("Stress")
	stress.value_changed.connect(_on_stress_changed)


func _on_stress_changed(value: float) -> void:
	bar.value = value
	# Виньетка появляется со стадии 1 (от 50) и достигает максимума к 100
	var t := clampf((value - 50.0) / 50.0, 0.0, 1.0)
	(vignette.material as ShaderMaterial).set_shader_parameter("intensity", t)
