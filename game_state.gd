extends Node

var has_checkpoint := false
var checkpoint_position := Vector3.ZERO
var checkpoint_yaw := 0.0


func set_checkpoint(pos: Vector3, yaw: float) -> void:
	has_checkpoint = true
	checkpoint_position = pos
	checkpoint_yaw = yaw


func reset() -> void:
	has_checkpoint = false
