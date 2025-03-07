extends Node2D

# Core level editor variables
var is_editing = false
var grid = []
var hole_position = Vector2(150, 112)
var level_name = "New Level"
var level_description = "Created with the level editor"
var level_difficulty = "medium"
var level_par = 3
var ball_start_position = Vector2(50, 50)
var temp_level_path = "user://temp_test_level.json"

# Child component references
var ui_controller
var brush_controller
var property_controller
var visualization_controller

func _ready():
	print("LevelEditor: _ready called")
	
	# Initialize an empty grid with cell properties
	initialize_grid()
	
	# Set editor mode before creating components
	is_editing = true
	
	# Set up components in the correct order
	setup_components()
	
	# Force an initial redraw to make elements visible
	queue_redraw()
	print("LevelEditor initialized with grid size: ", Constants.GRID_WIDTH, "x", Constants.GRID_HEIGHT)

func initialize_grid():
	grid = []
	for x in range(Constants.GRID_WIDTH):
		var column = []
		for y in range(Constants.GRID_HEIGHT):
			column.append(EditorCell.create_cell(Constants.CellType.EMPTY))
		grid.append(column)

func setup_components():
	print("LevelEditor: Setting up components...")
	
	# Create controllers first so they can be available for UI
	
	# Create the brush controller
	brush_controller = load("res://assets/scripts/EditorBrushController.gd").new()
	brush_controller.editor = self
	brush_controller.name = "EditorBrushController"
	add_child(brush_controller)
	print("LevelEditor: Brush controller added")
	
	# Create the property controller
	property_controller = load("res://assets/scripts/EditorPropertyController.gd").new()
	property_controller.editor = self
	property_controller.name = "EditorPropertyController"
	add_child(property_controller)
	print("LevelEditor: Property controller added")
	
	# Create the visualization controller
	visualization_controller = load("res://assets/scripts/EditorVisualizationController.gd").new()
	visualization_controller.editor = self
	visualization_controller.name = "EditorVisualizationController"
	add_child(visualization_controller)
	print("LevelEditor: Visualization controller added")
	
	# Create the UI controller last, after all other controllers are initialized
	ui_controller = load("res://assets/scripts/EditorUIController.gd").new()
	ui_controller.editor = self
	ui_controller.name = "EditorUIController"
	add_child(ui_controller)
	print("LevelEditor: UI controller added")
	
	# Now set the UI controller reference in the other controllers
	brush_controller.ui_controller = ui_controller
	property_controller.ui_controller = ui_controller
	visualization_controller.ui_controller = ui_controller
	print("LevelEditor: Set UI controller references in other controllers")

# Create a new empty level
func new_level():
	# Reset grid to empty
	for x in range(Constants.GRID_WIDTH):
		for y in range(Constants.GRID_HEIGHT):
			grid[x][y] = EditorCell.create_cell(Constants.CellType.EMPTY)
	
	# Reset position defaults
	hole_position = Vector2(150, 112)
	ball_start_position = Vector2(50, 50)
	
	# Reset other level properties
	level_name = "New Level"
	level_description = "Created with the level editor"
	level_difficulty = "medium"
	level_par = 3
	
	# Update the UI
	if ui_controller:
		ui_controller.update_status("Created new level")
	
	# Force redraw
	queue_redraw()

# Load an existing level
func load_level():
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = ["*.json ; JSON Level Files"]
	dialog.current_path = "user://levels/"
	
	dialog.file_selected.connect(_on_load_file_selected)
	add_child(dialog)
	
	dialog.popup_centered(Vector2(800, 600))

func _on_load_file_selected(path):
	# Attempt to load the file
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		if ui_controller:
			ui_controller.update_status("Error: Could not open file")
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		if ui_controller:
			ui_controller.update_status("Error: Invalid JSON file")
		return
	
	var level_data = json.get_data()
	
	# Reset grid to empty
	for x in range(Constants.GRID_WIDTH):
		for y in range(Constants.GRID_HEIGHT):
			grid[x][y] = EditorCell.create_cell(Constants.CellType.EMPTY)
	
	# Load level properties
	if level_data.has("name"):
		level_name = level_data.name
	
	if level_data.has("description"):
		level_description = level_data.description
	
	if level_data.has("difficulty"):
		level_difficulty = level_data.difficulty
	
	if level_data.has("par"):
		level_par = level_data.par
	
	# Load hole position
	if level_data.has("hole_position"):
		hole_position = Vector2(level_data.hole_position.x, level_data.hole_position.y)
	
	# Load ball start position
	if level_data.has("starting_position"):
		ball_start_position = Vector2(level_data.starting_position.x, level_data.starting_position.y)
	
	# Load terrain data
	if level_data.has("terrain"):
		for cell in level_data.terrain:
			var x = cell.x
			var y = cell.y
			var cell_type_str = cell.type
			
			if x >= 0 and x < Constants.GRID_WIDTH and y >= 0 and y < Constants.GRID_HEIGHT:
				var type = EditorCell.string_to_cell_type(cell_type_str)
				var new_cell = EditorCell.create_cell(type)
				
				# Load cell properties if they exist
				if cell.has("properties"):
					var props = cell.properties
					if props.has("mass"):
						new_cell.mass = props.mass
					if props.has("dampening"):
						new_cell.dampening = props.dampening
					if props.has("color_r"):
						new_cell.color_variation.x = props.color_r
					if props.has("color_g"):
						new_cell.color_variation.y = props.color_g
				
				grid[x][y] = new_cell
	
	# Update the UI
	if ui_controller:
		ui_controller.update_status("Loaded level: " + level_name)
		ui_controller.update_ui_from_level_data()
	
	# Force redraw
	queue_redraw()

# Test the current level - Fixed implementation using singleton
func test_level():
	print("LevelEditor: Testing level...")
	
	# First ensure the LevelSaver class is loaded
	if not ResourceLoader.exists("res://assets/scripts/LevelSaver.gd"):
		# Create and use LevelSaver as a script class
		var level_saver_script = load("res://assets/scripts/LevelSaver.gd")
		if not level_saver_script:
			if ui_controller:
				ui_controller.update_status("Error: LevelSaver script not found")
			print("LevelEditor: ERROR - LevelSaver script not found")
			return
	
	# Make sure temp directory exists
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("temp"):
		dir.make_dir("temp")
	
	# Save current level to a temporary file with more reliable path
	var temp_level_path = "user://temp/temp_test_level.json"
	var LevelSaver = load("res://assets/scripts/LevelSaver.gd")
	var temp_save_success = LevelSaver.save_level_to_path(self, temp_level_path)
	
	# Debug information
	print("Saving temporary level with cell counts: ")
	var material_counts = count_materials()
	print(material_counts)
	
	if temp_save_success:
		print("LevelEditor: Successfully saved temp level, preparing to test")
		
		# Create a simple level info dictionary
		var level_info = {
			"name": level_name,
			"path": temp_level_path,
			"type": "custom"
		}
		
		# Use the LevelTransfer singleton to pass level data
		var level_transfer = get_node("/root/LevelTransfer")
		if level_transfer:
			level_transfer.set_level_for_transfer(level_info)
			
			# Use a simpler approach to change scenes
			var result = get_tree().change_scene_to_file("res://assets/scenes/Main.tscn")
			if result != OK:
				print("LevelEditor: ERROR - Failed to change scene: ", result)
				if ui_controller:
					ui_controller.update_status("Error: Failed to load game scene")
		else:
			print("LevelEditor: ERROR - LevelTransfer singleton not found")
			if ui_controller:
				ui_controller.update_status("Error: Level transfer not available")
	else:
		if ui_controller:
			ui_controller.update_status("Error: Failed to save temp level")
		print("LevelEditor: ERROR - Failed to save temp level")

# Helper function to change scenes safely
func _change_to_game_scene(level_info):
	print("LevelEditor: Changing to game scene with level: ", level_info.name)
	
	# Create a minimal singleton to pass level data between scenes
	if not get_tree().root.has_node("CurrentLevelInfo"):
		var level_info_node = Node.new()
		level_info_node.name = "CurrentLevelInfo"
		level_info_node.set_meta("level_info", level_info)
		get_tree().root.add_child(level_info_node)
	
	# Safely change to the main game scene
	var result = get_tree().change_scene_to_file("res://assets/scenes/Main.tscn")
	if result != OK:
		print("LevelEditor: ERROR - Failed to change to Main scene")
		return
	
	# The cleanup will happen automatically when this scene is freed
	# Save current level to a temporary file
	var temp_save_success = LevelSaver.save_level_to_path(self, temp_level_path)
	
	# Add debug information
	print("Saving temporary level with cell counts: ")
	var material_counts = count_materials()
	print(material_counts)
	
	if temp_save_success:
		# Get the level manager singleton if it exists
		var level_manager = get_node_or_null("/root/LevelManager")
		
		if level_manager:
			# Add the temporary level to the level manager
			var level_added = level_manager.add_custom_level(temp_level_path)
			
			if level_added:
				# Clean up before changing scenes
				cleanup_editor(true)
				
				# Change to the main game scene
				var main_scene = load("res://assets/scenes/Main.tscn").instantiate()
				get_tree().root.add_child(main_scene)
				
				# Get the current level info from the level manager
				var current_level = level_manager.get_current_level()
				
				# Set the level in the main scene
				if main_scene.has_method("load_level"):
					main_scene.load_level(current_level)
				
				# Remove this editor scene
				get_tree().current_scene = main_scene
				queue_free()
			else:
				if ui_controller:
					ui_controller.update_status("Error: Failed to add level")
		else:
			# Clean up before changing scenes
			cleanup_editor(true)
			
			# If LevelManager isn't available, try direct approach
			var main_scene = load("res://assets/scenes/Main.tscn").instantiate()
			get_tree().root.add_child(main_scene)
			
			# Try to load the level directly in the main scene
			if main_scene.has_node("SandSimulation"):
				var sand_sim = main_scene.get_node("SandSimulation")
				if sand_sim and sand_sim.has_method("load_level"):
					sand_sim.load_level(temp_level_path)
			
			# Remove this editor scene
			get_tree().current_scene = main_scene
			queue_free()
	else:
		if ui_controller:
			ui_controller.update_status("Error: Failed to save temp level")

# Helper function to count materials for debugging
func count_materials():
	var counts = {
		"sand": 0,
		"dirt": 0,
		"stone": 0,
		"water": 0,
		"hole": 0,
		"empty": 0,
		"other": 0
	}
	
	for x in range(Constants.GRID_WIDTH):
		for y in range(Constants.GRID_HEIGHT):
			if x < grid.size() and y < grid[x].size():
				match grid[x][y].type:
					Constants.CellType.SAND:
						counts.sand += 1
					Constants.CellType.DIRT:
						counts.dirt += 1
					Constants.CellType.STONE:
						counts.stone += 1
					Constants.CellType.WATER:
						counts.water += 1
					Constants.CellType.HOLE:
						counts.hole += 1
					Constants.CellType.EMPTY:
						counts.empty += 1
					_:
						counts.other += 1
	
	return counts

# Return to the main menu - Safely without manual cleanup
func return_to_main_menu():
	print("LevelEditor: Returning to main menu...")
	
	# First disconnect all signals
	if ui_controller:
		if ui_controller.ui_panel:
			# Make sure any buttons don't trigger further actions during transition
			for child in ui_controller.ui_panel.get_children():
				if child is Button:
					for signal_name in child.get_signal_list():
						var connections = child.get_signal_connection_list(signal_name.name)
						for connection in connections:
							child.disconnect(signal_name.name, connection.callable)
		
		# Update UI status
		ui_controller.update_status("Returning to main menu...")
	
	# Let Godot handle the scene transition and cleanup
	var main_menu_scene = "res://assets/scenes/MainMenu.tscn"
	
	# Use a timer to slightly delay the scene transition
	# This gives time for the current frame to complete
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 0.05  # 50ms delay
	timer.one_shot = true
	timer.timeout.connect(func():
		print("LevelEditor: Timer expired, changing scene...")
		var result = get_tree().change_scene_to_file(main_menu_scene)
		if result != OK:
			print("LevelEditor: ERROR - Failed to change to main menu scene: ", result)
	)
	timer.start()
	
	print("LevelEditor: Scene change timer started")

# Properly clean up all UI and controllers before freeing the editor
# immediate=true will force immediate deletion instead of queueing
func cleanup_editor(immediate = false):
	print("LevelEditor: Cleaning up editor...")
	
	# First, make sure the UI panel is removed from its parent
	if ui_controller and ui_controller.ui_panel:
		print("LevelEditor: Removing UI panel")
		
		if ui_controller.ui_panel.get_parent():
			# Use call_deferred to safely remove child
			ui_controller.ui_panel.get_parent().call_deferred("remove_child", ui_controller.ui_panel)
		
		# Always use queue_free for UI components during cleanup
		ui_controller.ui_panel.queue_free()
		ui_controller.ui_panel = null
	
	# Clean up other controllers - always use queue_free for safety
	if brush_controller:
		brush_controller.queue_free()
		brush_controller = null
	
	if property_controller:
		property_controller.queue_free()
		property_controller = null
	
	if visualization_controller:
		visualization_controller.queue_free()
		visualization_controller = null
	
	if ui_controller:
		ui_controller.queue_free()
		ui_controller = null
	
	# Clear any other scene-specific nodes
	var children_to_remove = []
	for child in get_children():
		if child.name.begins_with("Editor") or child.name.begins_with("UI"):
			children_to_remove.append(child)
	
	# Remove children using queue_free for safety
	for child in children_to_remove:
		child.queue_free()
	
	print("LevelEditor: Cleanup complete")

# Free all resources properly when this scene is removed
func _exit_tree():
	print("LevelEditor: _exit_tree called")
	cleanup_editor(true)  # Use immediate cleanup

func save_level():
	# Create file dialog for saving
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = ["*.json ; JSON Level Files"]
	dialog.current_path = "user://levels/" + level_name.to_lower().replace(" ", "_") + ".json"
	
	dialog.file_selected.connect(_on_save_file_selected)
	add_child(dialog)
	
	dialog.popup_centered(Vector2(800, 600))

func _on_save_file_selected(path):
	var save_success = LevelSaver.save_level_to_path(self, path)
	if save_success:
		if ui_controller:
			ui_controller.update_status("Level saved successfully!")
	else:
		if ui_controller:
			ui_controller.update_status("Error saving level!")

# Handle custom drawing
func _draw():
	# Draw the grid first
	if visualization_controller:
		visualization_controller.draw_grid(self)
	
	# Let the brush controller draw its preview
	if brush_controller:
		brush_controller.draw_brush_preview(self)
