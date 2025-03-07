extends Node2D

# Variables
var stroke_count = 0
var game_won = false
var current_level = ""  # Default level (procedurally generated)
var level_json_path = ""
var pause_menu
var ui

# References to other nodes
var sand_simulation
var ball

func _ready():
	# Get references to nodes
	sand_simulation = $SandSimulation
	ball = $Ball
	
	# Add UI if it doesn't exist
	if not has_node("UI"):
		var ui_scene = load("res://assets/scenes/UI.tscn")
		if ui_scene:
			var ui_instance = ui_scene.instantiate()
			add_child(ui_instance)
			ui = ui_instance
			
			# Connect UI signals
			ui.restart_game.connect(_on_restart_game)
			ui.edit_level.connect(_on_edit_level)
			ui.return_to_menu.connect(_on_return_to_main_menu)
		else:
			print("UI scene not found or not loaded correctly")
	else:
		ui = $UI
		# Connect UI signals if it already exists
		if not ui.restart_game.is_connected(_on_restart_game):
			ui.restart_game.connect(_on_restart_game)
		if not ui.edit_level.is_connected(_on_edit_level):
			ui.edit_level.connect(_on_edit_level)
		if not ui.return_to_menu.is_connected(_on_return_to_main_menu):
			ui.return_to_menu.connect(_on_return_to_main_menu)
			
	pause_menu = load("res://assets/scenes/PauseMenu.tscn").instantiate()
	add_child(pause_menu)
	
	# Check for level from LevelTransfer singleton
	var level_transfer = get_node_or_null("/root/LevelTransfer")
	if level_transfer and level_transfer.is_level_from_editor():
		var level_info = level_transfer.get_level_info()
		if level_info:
			print("Main: Loading level from LevelTransfer: ", level_info)
			current_level = level_info
			level_json_path = level_info.path
			
			# Update UI if available
			if ui and level_info.has("name"):
				ui.update_level_name(level_info.name)
			
			# Don't clear the transfer data - we need it to know if we can edit this level
	else:
		# Look for level command line arguments or level selection
		var args = OS.get_cmdline_args()
		for arg in args:
			if arg.begins_with("--level="):
				var level_name = arg.split("=")[1]
				level_json_path = "res://assets/levels/" + level_name + ".json"
				print("Loading level from command line: ", level_json_path)
	
	# Initialize the simulation with level data
	initialize_level()
	
	# Connect signals
	ball.ball_in_hole.connect(_on_ball_in_hole)
	pause_menu.resume_game.connect(func(): pause_menu.hide_menu())
	pause_menu.return_to_main_menu.connect(_on_return_to_main_menu)

func initialize_level():
	if current_level is Dictionary and current_level.has("path"):
		level_json_path = current_level.path
	
	if level_json_path != "" and FileAccess.file_exists(level_json_path):
		# Load level from JSON
		var hole_pos = sand_simulation.load_level(level_json_path)
		
		# Read starting position from the JSON if we have a custom level
		var file = FileAccess.open(level_json_path, FileAccess.READ)
		var json_text = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(json_text)
		if error == OK:
			var level_data = json.get_data()
			if level_data.has("starting_position"):
				var start_pos = Vector2(level_data.starting_position.x, level_data.starting_position.y)
				ball.ball_position = start_pos
				ball.default_position = start_pos  # Set the default position too
				ball.update_ball_in_grid()
				print("Set ball starting position to: ", start_pos)
	else:
		# Use default procedural generation
		sand_simulation.initialize_grid()
	
	# Reset game state
	game_won = false
	stroke_count = 0

func load_level(level_info):
	current_level = level_info
	level_json_path = level_info.path if level_info is Dictionary and level_info.has("path") else level_info
	initialize_level()
	
	# Update UI if it exists
	if ui and current_level is Dictionary and current_level.has("name"):
		ui.update_level_name(current_level.name)

func _on_ball_in_hole():
	game_won = true
	print("You won! Total strokes: ", stroke_count)
	
	# Update UI if it exists
	if ui:
		ui.show_win_message(stroke_count)

func _on_restart_game():
	initialize_level()
	ball.reset_position()
	
	# Reset the stroke count
	stroke_count = 0
	
	# Reset game state
	game_won = false

func _on_edit_level():
	# Only allow editing if we have a valid level from editor
	var level_transfer = get_node_or_null("/root/LevelTransfer")
	if level_transfer and level_transfer.is_level_from_editor():
		# Get the current level info and pass it back to the editor
		var level_info = level_transfer.get_level_info()
		
		# Set the level to be loaded in the editor
		level_transfer.set_level_for_transfer(level_info)
		
		# Change to the level editor scene
		get_tree().change_scene_to_file("res://assets/scenes/LevelEditor.tscn")
	else:
		# No editable level - show a message
		if ui:
			ui.message_label.text = "This level cannot be edited"
			ui.message_label.show()
			
			# Create a timer to hide the message
			var timer = Timer.new()
			add_child(timer)
			timer.wait_time = 2.0
			timer.one_shot = true
			timer.timeout.connect(func(): ui.message_label.hide())
			timer.start()

func _on_return_to_main_menu():
	# Unpause the game before changing scenes
	get_tree().paused = false
	
	# Change to the main menu scene
	get_tree().change_scene_to_file("res://assets/scenes/MainMenu.tscn")

func _input(event):
	if game_won and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		# Restart game
		_on_restart_game()
		
	if not game_won and ball.can_shoot() and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Start shooting
			ball.start_shooting()
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and ball.is_shooting:
			# Release shot
			ball.end_shooting()
			stroke_count += 1
	
	# Debug key to load a specific level when L is pressed
	if event is InputEventKey and event.pressed and event.keycode == KEY_L:
		print("Loading level...")
		var dialog = FileDialog.new()
		dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		dialog.access = FileDialog.ACCESS_FILESYSTEM
		dialog.filters = ["*.json ; JSON Level Files"]
		
		dialog.connect("file_selected", Callable(self, "_on_level_file_selected"))
		add_child(dialog)
		dialog.popup_centered(Vector2(800, 600))
		
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if pause_menu.visible:
			pause_menu.hide_menu()
		else:
			pause_menu.show_menu()

func _on_level_file_selected(path):
	print("Selected level: ", path)
	level_json_path = path
	initialize_level()

func _process(_delta):
	# Update UI stroke count
	if ui:
		ui.update_stroke_count(stroke_count)
	
	queue_redraw() # Redraw UI every frame
