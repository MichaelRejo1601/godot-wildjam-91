extends Control


func _ready() -> void:
	if OS.has_feature("web"):
		%ExitButton.hide()


func new_game() -> void:
	GameState.reset()
	load_game_scene()

func load_game_scene() -> void:
	GameState.start_game()
	SceneLoader.load_scene(get_game_scene_path(), false)

func get_game_scene_path() -> String:
	return AppConfig.game_scene_path
	

func _on_new_game_button_pressed() -> void:
	new_game()

func _on_exit_button_pressed() -> void:
	get_tree().quit()
