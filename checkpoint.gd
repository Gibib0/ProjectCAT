extends Area3D

var activated := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if activated or not body.is_in_group("player"):
		return
	activated = true
	GameState.set_checkpoint(global_position, body.rotation.y)
	print("Контрольная точка сохранена")
