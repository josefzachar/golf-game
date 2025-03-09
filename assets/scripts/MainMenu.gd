extends Node2D

# Main menu for the game
var buttons = {}
var current_screen = null

func _ready():
	# Set up buttons
	buttons["play"] = $VBoxContainer/PlayButton
	buttons["editor"] = $VBoxContainer/EditorButton
	buttons["options"] = $VBoxContainer/OptionsButton
	buttons["quit"] = $VBoxContainer/QuitButton
	
	# Connect button signals
	buttons["play"].pressed.connect(_on_play_pressed)
	buttons["editor"].pressed.connect(_on_editor_pressed)
	buttons["options"].pressed.connect(_on_options_pressed)
	buttons["quit"].pressed.connect(_on_quit_pressed)
	
	# Make sure the level manager is loaded
	if not ResourceLoader.exists("res://assets/scenes/LevelManager.tscn"):
		var level_manager = Node.new()
		level_manager.name = "LevelManager"
		level_manager.set_script(load("res://assets/scripts/LevelManager.gd"))
		get_tree().root.add_child.call_deferred(level_manager)

func _on_play_pressed():
	# Show level selection screen
	var level_select = load("res://assets/scenes/LevelSelect.tscn").instantiate()
	add_child(level_select)
	
	# Connect level selection signals
	level_select.level_selected.connect(_on_level_selected)
	level_select.back_pressed.connect(func(): _close_screen(level_select))
	
	level_select.level_manager.scan_levels()
	level_select.populate_levels()
	
	current_screen = level_select

func _on_level_selected(level_info):
	print("Selected level: ", level_info.name)
	
	# Close level selection screen
	if current_screen:
		_close_screen(current_screen)
	
	# Start the game with selected level
	if level_info.type == "procedural":
		# Start with procedural level
		get_tree().change_scene_to_file("res://assets/scenes/Main.tscn")
	else:
		# Start with custom level
		var main_scene = load("res://assets/scenes/Main.tscn").instantiate()
		get_tree().root.add_child(main_scene)
		
		# Set the level path
		if main_scene.has_method("load_level"):
			main_scene.load_level(level_info)
		
		# Remove the main menu scene
		get_tree().current_scene = main_scene
		queue_free()

func _on_editor_pressed():
	# Load the level editor
	get_tree().change_scene_to_file("res://assets/scenes/LevelEditor.tscn")

func _on_options_pressed():
	# Show options screen (placeholder)
	print("Options not implemented yet")

func _on_quit_pressed():
	# Quit the game
	get_tree().quit()

func _close_screen(screen):
	if screen:
		screen.queue_free()
	current_screen = null
