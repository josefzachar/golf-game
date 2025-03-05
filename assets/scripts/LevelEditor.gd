extends Node2D

# Level Editor variables
var current_cell_type = Constants.CellType.SAND
var is_editing = false
var grid = []
var hole_position = Vector2(150, 112)
var level_name = "New Level"
var level_description = "Created with the level editor"
var level_difficulty = "medium"
var level_par = 3
var ball_start_position = Vector2(50, 50)

# UI elements
var ui_panel
var type_buttons = {}
var save_button
var cell_label

func _ready():
	# Initialize an empty grid
	for x in range(Constants.GRID_WIDTH):
		var column = []
		for y in range(Constants.GRID_HEIGHT):
			column.append(Constants.CellType.EMPTY)
		grid.append(column)
	
	# Create UI
	setup_ui()
	
	# Set editor mode
	is_editing = true

func setup_ui():
	# Create panel
	ui_panel = Panel.new()
	ui_panel.position = Vector2(10, 10)
	ui_panel.size = Vector2(200, 150)
	add_child(ui_panel)
	
	# Create VBoxContainer for controls
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(10, 10)
	vbox.size = Vector2(180, 130)
	ui_panel.add_child(vbox)
	
	# Create label for current tool
	cell_label = Label.new()
	cell_label.text = "Current: Sand"
	vbox.add_child(cell_label)
	
	# Create HBoxContainer for type buttons
	var hbox = HBoxContainer.new()
	vbox.add_child(hbox)
	
	# Add type buttons
	var sand_button = Button.new()
	sand_button.text = "Sand"
	sand_button.pressed.connect(func(): set_current_type(Constants.CellType.SAND))
	hbox.add_child(sand_button)
	
	var water_button = Button.new()
	water_button.text = "Water"
	water_button.pressed.connect(func(): set_current_type(Constants.CellType.WATER))
	hbox.add_child(water_button)
	
	var empty_button = Button.new()
	empty_button.text = "Empty"
	empty_button.pressed.connect(func(): set_current_type(Constants.CellType.EMPTY))
	hbox.add_child(empty_button)
	
	var hole_button = Button.new()
	hole_button.text = "Hole"
	hole_button.pressed.connect(func(): set_current_type(Constants.CellType.HOLE))
	hbox.add_child(hole_button)
	
	# Add special functions
	var set_start_button = Button.new()
	set_start_button.text = "Set Ball Start"
	set_start_button.pressed.connect(func(): set_current_type("ball_start"))
	vbox.add_child(set_start_button)
	
	# Add metadata inputs
	var metadata_grid = GridContainer.new()
	metadata_grid.columns = 2
	vbox.add_child(metadata_grid)
	
	# Level name
	var name_label = Label.new()
	name_label.text = "Level Name:"
	metadata_grid.add_child(name_label)
	
	var name_input = LineEdit.new()
	name_input.text = level_name
	name_input.text_changed.connect(func(new_text): level_name = new_text)
	metadata_grid.add_child(name_input)
	
	# Par
	var par_label = Label.new()
	par_label.text = "Par:"
	metadata_grid.add_child(par_label)
	
	var par_input = SpinBox.new()
	par_input.min_value = 1
	par_input.max_value = 10
	par_input.value = level_par
	par_input.value_changed.connect(func(new_value): level_par = int(new_value))
	metadata_grid.add_child(par_input)
	
	# Save button
	save_button = Button.new()
	save_button.text = "Save Level"
	save_button.pressed.connect(save_level)
	vbox.add_child(save_button)

func set_current_type(type):
	current_cell_type = type
	match type:
		Constants.CellType.SAND:
			cell_label.text = "Current: Sand"
		Constants.CellType.WATER:
			cell_label.text = "Current: Water"
		Constants.CellType.EMPTY:
			cell_label.text = "Current: Empty"
		Constants.CellType.HOLE:
			cell_label.text = "Current: Hole"
		"ball_start":
			cell_label.text = "Click to set ball start"

func _input(event):
	if not is_editing:
		return
		
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		var grid_x = int(mouse_pos.x / Constants.GRID_SIZE)
		var grid_y = int(mouse_pos.y / Constants.GRID_SIZE)
		
		# Check if we're within grid bounds
		if grid_x >= 0 and grid_x < Constants.GRID_WIDTH and grid_y >= 0 and grid_y < Constants.GRID_HEIGHT:
			# Handle special types
			if current_cell_type == "ball_start":
				ball_start_position = Vector2(grid_x, grid_y)
				print("Set ball start position to: ", ball_start_position)
				cell_label.text = "Ball start position set!"
				return
			
			# Set the grid cell
			grid[grid_x][grid_y] = current_cell_type
			
			# If we're placing a hole, update hole position
			if current_cell_type == Constants.CellType.HOLE:
				hole_position = Vector2(grid_x, grid_y)
				print("Set hole position to: ", hole_position)
		
		# Redraw
		queue_redraw()

func _draw():
	# Draw the grid cells
	for x in range(Constants.GRID_WIDTH):
		for y in range(Constants.GRID_HEIGHT):
			if x < grid.size() and y < grid[x].size():
				var cell_type = grid[x][y]
				var rect = Rect2(x * Constants.GRID_SIZE, y * Constants.GRID_SIZE, Constants.GRID_SIZE, Constants.GRID_SIZE)
				
				match cell_type:
					Constants.CellType.EMPTY:
						# Sky color
						draw_rect(rect, Color(0.2, 0.3, 0.4), true)
					Constants.CellType.SAND:
						draw_rect(rect, Constants.SAND_COLOR, true)
					Constants.CellType.HOLE:
						# Draw hole with a thicker border to make it more visible
						draw_rect(rect, Constants.HOLE_COLOR, true)
					Constants.CellType.WATER:
						# Draw water color
						draw_rect(rect, Constants.WATER_COLOR, true)
	
	# Draw the ball start position indicator
	var ball_start_rect = Rect2(
		ball_start_position.x * Constants.GRID_SIZE,
		ball_start_position.y * Constants.GRID_SIZE,
		Constants.GRID_SIZE,
		Constants.GRID_SIZE
	)
	draw_rect(ball_start_rect, Color(1, 1, 1, 0.5), true)  # Semi-transparent white

func save_level():
	# Create level data structure
	var level_data = {
		"name": level_name,
		"description": level_description,
		"difficulty": level_difficulty,
		"par": level_par,
		"hole_position": {
			"x": hole_position.x,
			"y": hole_position.y
		},
		"starting_position": {
			"x": ball_start_position.x,
			"y": ball_start_position.y
		},
		"terrain": []
	}
	
	# Add all non-empty cells to terrain array
	for x in range(Constants.GRID_WIDTH):
		for y in range(Constants.GRID_HEIGHT):
			if grid[x][y] != Constants.CellType.EMPTY:
				var cell_type_str = ""
				match grid[x][y]:
					Constants.CellType.SAND:
						cell_type_str = "sand"
					Constants.CellType.WATER:
						cell_type_str = "water"
					Constants.CellType.HOLE:
						cell_type_str = "hole"
				
				if cell_type_str != "":
					level_data["terrain"].append({
						"x": x,
						"y": y,
						"type": cell_type_str
					})
	
	# Convert to JSON
	var json_text = JSON.stringify(level_data, "  ")  # Pretty-print with 2-space indentation
	
	# Show file dialog to save
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = ["*.json ; JSON Level Files"]
	dialog.current_path = "user://levels/" + level_name.to_lower().replace(" ", "_") + ".json"
	
	dialog.connect("file_selected", Callable(self, "_on_save_file_selected"))
	add_child(dialog)
	
	# Store JSON data to be saved when a file is selected
	dialog.meta = json_text
	
	dialog.popup_centered(Vector2(800, 600))

func _on_save_file_selected(path):
	var dialog = get_node_or_null("FileDialog")
	if dialog and dialog.meta:
		var json_text = dialog.meta
		
		# Create directory if it doesn't exist
		var dir = DirAccess.open("user://")
		if dir:
			var dir_path = path.get_base_dir()
			if not dir.dir_exists(dir_path):
				dir.make_dir_recursive(dir_path)
		
		# Save the file
		var file = FileAccess.open(path, FileAccess.WRITE)
		if file:
			file.store_string(json_text)
			file.close()
			print("Level saved to: ", path)
			
			# Show confirmation
			cell_label.text = "Level saved successfully!"
		else:
			print("Error: Could not save level to ", path)
			cell_label.text = "Error saving level!"
