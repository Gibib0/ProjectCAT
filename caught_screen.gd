extends CanvasLayer

@onready var retry_button: Button = $Root/Center/Menu/RetryButton
@onready var menu_button: Button = $Root/Center/Menu/MenuButton


func _ready() -> void:
	add_to_group("caught_screen")
	hide()
	retry_button.pressed.connect(_on_retry)
	menu_button.pressed.connect(_on_menu)


func show_screen() -> void:
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # возвращаем курсор, чтобы нажимать кнопки
	get_tree().paused = true                      # замораживаем игру за экраном


func _on_retry() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()             # игрок сам возьмёт позицию из GameState


func _on_menu() -> void:
	get_tree().paused = false
	GameState.reset()
	get_tree().change_scene_to_file("res://main_menu.tscn")
