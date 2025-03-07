extends Node2D

# Variables
var stroke_count = 0
var game_won = false
var current_level = ""  # Default level (procedurally generated)
var level_json_path = ""
var pause_menu

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
			# Connect UI signals
			ui_instance.restart_game.connect(_on_restart_game)
		else:
			print("UI scene not found or not loaded correctly")
			
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
			if has_node("UI") and level_info.has("name"):
				$UI.update_level_name(level_info.name)
			
			# Clear the transfer data so it doesn't persist
			level_transfer.clear_level_info()
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
	if current_level:
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
				ball.update_ball_in_grid()
				print("Set ball starting position to: ", start_pos)
	else:
		# Use default procedural generation
		sand_simulation.initialize_grid()
	
	# Reset game state
	game_won = false
	stroke_count = 0

# FIX THIS
func load_level(level_info):
	current_level = level_info
	level_json_path = level_info.path
	initialize_level()
	
	# Update UI if it exists
	if has_node("UI"):
		$UI.update_level_name(level_info.name)

func _on_ball_in_hole():
	game_won = true
	print("You won! Total strokes: ", stroke_count)
	
	# Pause all physics
	var victory_label_text = "Victory! Strokes: " + str(stroke_count) + "\nPress R to restart"
	
	# Update UI if it exists
	if has_node("UI"):
		$UI.show_win_message(stroke_count)
	else:
		# Show a simple on-screen message if UI doesn't exist
		print(victory_label_text)

func _on_restart_game():
	initialize_level()
	ball.reset_position()

func _draw():
	# Draw UI
	draw_string(ThemeDB.fallback_font, Vector2(20, 30), "Strokes: " + str(stroke_count))
	
	if game_won:
		draw_string(ThemeDB.fallback_font, 
					Vector2(Constants.GRID_WIDTH * Constants.GRID_SIZE / 2 - 100, Constants.GRID_HEIGHT * Constants.GRID_SIZE / 2), 
					"You Won! Strokes: " + str(stroke_count))
		draw_string(ThemeDB.fallback_font, 
					Vector2(Constants.GRID_WIDTH * Constants.GRID_SIZE / 2 - 100, Constants.GRID_HEIGHT * Constants.GRID_SIZE / 2 + 30), 
					"Press R to restart")

func _input(event):
	if game_won and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		# Restart game
		initialize_level()
		ball.reset_position()
		
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
			
func _on_return_to_main_menu():
	# Unpause the game before changing scenes
	get_tree().paused = false
	
	# Change to the main menu scene
	get_tree().change_scene_to_file("res://assets/scenes/MainMenu.tscn")

func _on_level_file_selected(path):
	print("Selected level: ", path)
	level_json_path = path
	initialize_level()

func _process(_delta):
	# Update UI stroke count
	if has_node("UI"):
		$UI.update_stroke_count(stroke_count)
	
	queue_redraw() # Redraw UI every frame (Godot 4.x uses queue_redraw instead of update)
