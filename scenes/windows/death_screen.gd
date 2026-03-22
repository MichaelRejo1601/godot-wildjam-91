extends Control

signal play_again_pressed
signal main_menu_pressed

@onready var coins_label: Label = %CoinsLabel
@onready var time_label: Label = %TimeLabel
@onready var animation_player: AnimationPlayer = %AnimationPlayer


func _ready() -> void:
	# Make sure the death screen is on top
	z_index = 9999

	# Get the player to retrieve coins collected
	var player = _get_player()

	var coins = 0
	if player != null:
		if player.has_meta("current_coins"):
			coins = player.get_meta("current_coins")
		elif "current_coins" in player:
			coins = player.current_coins

	coins_label.text = "💰 Coins Collected: %d" % coins

	# Calculate time survived
	var time_survived = _calculate_time_survived()
	time_label.text = "⏱ Time Survived: %ds" % time_survived

	# Play YOU DIED flicker animation
	if animation_player != null:
		animation_player.play("title_pulse")


func _calculate_time_survived() -> int:
	# Check if we stored a start time in metadata
	if get_tree().root.has_meta("level_start_time"):
		var start_time = get_tree().root.get_meta("level_start_time")
		var elapsed = Time.get_ticks_msec() - start_time
		return int(elapsed / 1000.0)

	return 0


func _on_play_again_button_pressed() -> void:
	play_again_pressed.emit()

	# Get the level path that was stored before loading this death screen
	var level_path = AppConfig.game_scene_path
	SceneLoader.load_scene(level_path, false)


func _on_main_menu_button_pressed() -> void:
	main_menu_pressed.emit()
	GameState.reset()
	SceneLoader.load_scene(AppConfig.main_menu_scene_path, false)


func _get_player() -> Node:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		# Fallback: try to find it by path
		var scene = get_tree().current_scene
		if scene != null:
			player = scene.get_node_or_null("Player/Player")
			if player == null:
				player = scene.get_node_or_null("Player/CharacterBody2D")
	return player
