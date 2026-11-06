extends Control

const GAME_SCENE := "res://Main.tscn"


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$Menu/NewGame.pressed.connect(_on_new_game)
	$Menu/Settings.pressed.connect(func(): print("Настройки: пока не сделано"))
	$Menu/Credits.pressed.connect(func(): print("Создатели: пока не сделано"))
	$Menu/Quit.pressed.connect(func(): get_tree().quit())


func _on_new_game() -> void:
	print("Нажали «Новая игра»")
	print("Путь к сцене: ", GAME_SCENE)
	print("Сцена существует: ", ResourceLoader.exists(GAME_SCENE))
	GameState.reset()
	var err := get_tree().change_scene_to_file(GAME_SCENE)
	print("Результат загрузки: ", err)    # 0 означает «успешно»
