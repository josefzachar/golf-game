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
var mouse_button_pressed = false
var last_drawn_position = Vector2(-1, -1)  # Track last drawn position to avoid redrawing same cell
var needs_redraw = true  # Flag to track when we need to redraw

# Panel dragging variables
var dragging_panel = false
var drag_start_pos = Vector2.ZERO
var panel_start_pos = Vector2.ZERO

# Variable to store JSON data for saving
var pending_save_data = ""

# Variable to track current level path for testing
var temp_level_path = "user://temp_test_level.json"

# UI elements (declare at top level)
var ui_panel: Panel
var cell_label: Label
var save_button: Button

# Brush variables
enum BrushShape { SQUARE, CIRCLE }
var brush_size = 1  # Radius of the brush (1 = 3x3, 2 = 5x5, etc.)
var brush_shape = BrushShape.SQUARE

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
	
	# Force an initial redraw to make elements visible
	needs_redraw = true
	print("LevelEditor initialized with grid size: ", Constants.GRID_WIDTH, "x", Constants.GRID_HEIGHT)

# Create a new empty level
func new_level():
	# Reset grid to empty
	for x in range(Constants.GRID_WIDTH):
		for y in range(Constants.GRID_HEIGHT):
			grid[x][y] = Constants.CellType.EMPTY
	
	# Reset position defaults
	hole_position = Vector2(150, 112)
	ball_start_position = Vector2(50, 50)
	
	# Reset other level properties
	level_name = "New Level"
	level_description = "Created with the level editor"
	level_difficulty = "medium"
	level_par = 3
	
	# Update the UI
	cell_label.text = "Created new level"
	
	# Force redraw
	needs_redraw = true

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
		cell_label.text = "Error: Could not open file"
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		cell_label.text = "Error: Invalid JSON file"
		return
	
	var level_data = json.get_data()
	
	# Reset grid to empty
	for x in range(Constants.GRID_WIDTH):
		for y in range(Constants.GRID_HEIGHT):
			grid[x][y] = Constants.CellType.EMPTY
	
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
			var type = cell.type
			
			if x >= 0 and x < Constants.GRID_WIDTH and y >= 0 and y < Constants.GRID_HEIGHT:
				match type:
					"sand":
						grid[x][y] = Constants.CellType.SAND
					"water":
						grid[x][y] = Constants.CellType.WATER
					"hole":
						grid[x][y] = Constants.CellType.HOLE
					"ball_start":
						grid[x][y] = Constants.CellType.BALL_START
	
	# Update the UI
	cell_label.text = "Loaded level: " + level_name
	
	# Force redraw
	needs_redraw = true

# Test the current level
func test_level():
	# Save current level to a temporary file
	var temp_save_success = save_level_to_path(temp_level_path)
	
	if temp_save_success:
		# Get the level manager singleton if it exists
		var level_manager = get_node_or_null("/root/LevelManager")
		
		if level_manager:
			# Add the temporary level to the level manager
			var level_added = level_manager.add_custom_level(temp_level_path)
			
			if level_added:
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
				cell_label.text = "Error: Failed to add level"
		else:
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
		cell_label.text = "Error: Failed to save temp level"

# Return to the main menu
func return_to_main_menu():
	get_tree().change_scene_to_file("res://assets/scenes/MainMenu.tscn")

# Helper function to save level to a specific path
func save_level_to_path(path):
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
					Constants.CellType.BALL_START:
						cell_type_str = "ball_start"
				
				if cell_type_str != "":
					level_data["terrain"].append({
						"x": x,
						"y": y,
						"type": cell_type_str
					})
	
	# Convert to JSON
	var json_text = JSON.stringify(level_data, "  ")  # Pretty-print with 2-space indentation
	
	# Create directory if it doesn't exist
	var dir_path = path.get_base_dir()
	var dir = DirAccess.open("user://")
	if dir and not dir.dir_exists(dir_path):
		dir.make_dir_recursive(dir_path)
	
	# Save the file
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(json_text)
		file.close()
		print("Level saved to: ", path)
		return true
	else:
		print("Error: Could not save level to ", path)
		return false

func setup_ui():
	# Create panel
	ui_panel = Panel.new()
	ui_panel.position = Vector2(10, 10)
	ui_panel.size = Vector2(250, 480) # Made panel taller for additional controls
	add_child(ui_panel)
	
	# Create VBoxContainer for controls
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(10, 30)  # Moved down to make room for drag handle
	vbox.size = Vector2(230, 440)
	ui_panel.add_child(vbox)
	
	# Add drag handle/title bar
	var drag_handle = Panel.new()
	drag_handle.position = Vector2(0, 0)
	drag_handle.size = Vector2(250, 25)
	drag_handle.modulate = Color(0.7, 0.7, 0.8)  # Slightly different color for visibility
	ui_panel.add_child(drag_handle)
	
	# Add title label to drag handle
	var title_label = Label.new()
	title_label.position = Vector2(10, 4)
	title_label.text = "Editor Tools - Drag to move"
	title_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	drag_handle.add_child(title_label)
	
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
	set_start_button.pressed.connect(func(): set_current_type(Constants.CellType.BALL_START))
	vbox.add_child(set_start_button)
	
	# Add separator
	var separator = HSeparator.new()
	vbox.add_child(separator)
	
	# Add brush controls header
	var brush_label = Label.new()
	brush_label.text = "Brush Settings"
	vbox.add_child(brush_label)
	
	# Add brush size control
	var brush_size_hbox = HBoxContainer.new()
	vbox.add_child(brush_size_hbox)
	
	var brush_size_label = Label.new()
	brush_size_label.text = "Size:"
	brush_size_hbox.add_child(brush_size_label)
	
	var brush_size_slider = HSlider.new()
	brush_size_slider.min_value = 1
	brush_size_slider.max_value = 10
	brush_size_slider.step = 1
	brush_size_slider.value = brush_size
	brush_size_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brush_size_slider.value_changed.connect(func(new_value): set_brush_size(int(new_value)))
	brush_size_hbox.add_child(brush_size_slider)
	
	var brush_size_value = Label.new()
	brush_size_value.text = str(brush_size)
	brush_size_value.custom_minimum_size.x = 25
	brush_size_slider.value_changed.connect(func(new_value): brush_size_value.text = str(int(new_value)))
	brush_size_hbox.add_child(brush_size_value)
	
	# Add brush shape control
	var brush_shape_hbox = HBoxContainer.new()
	vbox.add_child(brush_shape_hbox)
	
	var brush_shape_label = Label.new()
	brush_shape_label.text = "Shape:"
	brush_shape_hbox.add_child(brush_shape_label)
	
	var square_button = Button.new()
	square_button.text = "Square"
	square_button.pressed.connect(func(): set_brush_shape(BrushShape.SQUARE))
	brush_shape_hbox.add_child(square_button)
	
	var circle_button = Button.new()
	circle_button.text = "Circle"
	circle_button.pressed.connect(func(): set_brush_shape(BrushShape.CIRCLE))
	brush_shape_hbox.add_child(circle_button)
	
	# Add a second separator
	var separator2 = HSeparator.new()
	vbox.add_child(separator2)
	
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
	
	# Add a file operations separator
	var separator3 = HSeparator.new()
	vbox.add_child(separator3)
	
	# Add file operations header
	var file_label = Label.new()
	file_label.text = "File Operations"
	vbox.add_child(file_label)
	
	# Add file operation buttons
	var file_buttons_hbox = HBoxContainer.new()
	vbox.add_child(file_buttons_hbox)
	
	var new_button = Button.new()
	new_button.text = "New"
	new_button.pressed.connect(new_level)
	file_buttons_hbox.add_child(new_button)
	
	var load_button = Button.new()
	load_button.text = "Load"
	load_button.pressed.connect(load_level)
	file_buttons_hbox.add_child(load_button)
	
	save_button = Button.new()
	save_button.text = "Save"
	save_button.pressed.connect(save_level)
	file_buttons_hbox.add_child(save_button)
	
	# Add a navigation separator
	var separator4 = HSeparator.new()
	vbox.add_child(separator4)
	
	# Add navigation buttons
	var test_button = Button.new()
	test_button.text = "Test Play Level"
	test_button.pressed.connect(test_level)
	vbox.add_child(test_button)
	
	var menu_button = Button.new()
	menu_button.text = "Return to Main Menu"
	menu_button.pressed.connect(return_to_main_menu)
	vbox.add_child(menu_button)
	
	print("UI setup completed with brush controls and draggable panel")

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
		Constants.CellType.BALL_START:
			cell_label.text = "Click to set ball start"
	
	print("Current cell type set to: ", current_cell_type)

func _input(event):
	if not is_editing:
		return
	
	# Get mouse position
	var mouse_pos = get_viewport().get_mouse_position()
	
	# Check for panel dragging
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Check if clicking on the panel's drag handle (top bar)
			var handle_rect = Rect2(ui_panel.position, Vector2(ui_panel.size.x, 25))
			if handle_rect.has_point(mouse_pos):
				dragging_panel = true
				drag_start_pos = mouse_pos
				panel_start_pos = ui_panel.position
				return  # Don't process any other input
		else:  # Button released
			dragging_panel = false
	
	# Handle panel dragging
	if event is InputEventMouseMotion and dragging_panel:
		var offset = mouse_pos - drag_start_pos
		ui_panel.position = panel_start_pos + offset
		return  # Don't process any other input while dragging panel
	
	# Check if we're clicking on the UI panel
	if is_point_in_ui(mouse_pos):
		return # Skip input handling for UI elements
	
	# Handle mouse button press for drawing
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_button_pressed = event.pressed
		
		if event.pressed:
			# When first pressing, draw at the initial position
			draw_at_position(mouse_pos)
	
	# Handle mouse motion while button is pressed for drawing
	elif event is InputEventMouseMotion and mouse_button_pressed:
		draw_at_position(mouse_pos)

# Check if a point is inside any UI element
func is_point_in_ui(point: Vector2) -> bool:
	# Check if within panel boundaries
	var panel_rect = Rect2(ui_panel.position, ui_panel.size)
	return panel_rect.has_point(point)

# Helper function to draw at a given position
func draw_at_position(mouse_pos):
	var grid_x = int(mouse_pos.x / Constants.GRID_SIZE)
	var grid_y = int(mouse_pos.y / Constants.GRID_SIZE)
	
	# Skip if this is the same cell we just drew on (center point)
	if last_drawn_position.x == grid_x and last_drawn_position.y == grid_y:
		return
	
	last_drawn_position = Vector2(grid_x, grid_y)
	
	# Handle special BALL_START cell type separately (always size 1)
	if current_cell_type == Constants.CellType.BALL_START:
		if grid_x >= 0 and grid_x < Constants.GRID_WIDTH and grid_y >= 0 and grid_y < Constants.GRID_HEIGHT:
			ball_start_position = Vector2(grid_x, grid_y)
			print("Set ball start position to: ", ball_start_position)
			cell_label.text = "Ball start position set!"
			needs_redraw = true
		return
		
	# Handle HOLE separately (always size 1)
	if current_cell_type == Constants.CellType.HOLE:
		if grid_x >= 0 and grid_x < Constants.GRID_WIDTH and grid_y >= 0 and grid_y < Constants.GRID_HEIGHT:
			hole_position = Vector2(grid_x, grid_y)
			grid[grid_x][grid_y] = current_cell_type
			print("Set hole position to: ", hole_position)
			needs_redraw = true
		return
		
	# For regular cell types, apply brush with size and shape
	apply_brush(grid_x, grid_y)
	
	# Redraw
	needs_redraw = true
	
# Apply brush with current size and shape at the given position
func apply_brush(center_x, center_y):
	var radius = brush_size
	
	for x in range(center_x - radius, center_x + radius + 1):
		for y in range(center_y - radius, center_y + radius + 1):
			# Skip if outside grid boundaries
			if x < 0 or x >= Constants.GRID_WIDTH or y < 0 or y >= Constants.GRID_HEIGHT:
				continue
				
			# For circle shape, check if point is within the radius
			if brush_shape == BrushShape.CIRCLE:
				var distance = Vector2(center_x, center_y).distance_to(Vector2(x, y))
				if distance > radius:
					continue
			
			# Set the cell
			grid[x][y] = current_cell_type
	
	print("Applied brush at (", center_x, ",", center_y, ") with size ", radius)

# Set brush size
func set_brush_size(size):
	brush_size = size
	print("Brush size set to: ", brush_size)
	
# Set brush shape
func set_brush_shape(shape):
	brush_shape = shape
	var shape_name = "Square" if shape == BrushShape.SQUARE else "Circle"
	print("Brush shape set to: ", shape_name)
	
# Function to draw the brush preview at the current mouse position
func _process(delta):
	if is_editing:
		# Only show brush preview when not over UI
		var mouse_pos = get_viewport().get_mouse_position()
		if not is_point_in_ui(mouse_pos):
			needs_redraw = true  # Request redraw for brush preview
	
	# Handle redraw if needed
	if needs_redraw:
		# Try different redraw methods for compatibility
		if has_method("queue_redraw"):
			call("queue_redraw")
		elif has_method("update"):
			call("update")
		else:
			# Force _draw() to be called directly
			_draw()
		
		needs_redraw = false

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
					Constants.CellType.BALL_START:
						# Draw any ball start cells in the grid
						draw_rect(rect, Color(0.8, 0.8, 0.2, 0.8), true)
	
	# Draw the ball start position indicator
	var ball_start_rect = Rect2(
		ball_start_position.x * Constants.GRID_SIZE,
		ball_start_position.y * Constants.GRID_SIZE,
		Constants.GRID_SIZE,
		Constants.GRID_SIZE
	)
	draw_rect(ball_start_rect, Color(1, 1, 1, 0.5), true)  # Semi-transparent white
	
	# Draw a grid overlay for better visualization
	var grid_color = Color(0.5, 0.5, 0.5, 0.2)  # Light gray, semi-transparent
	for x in range(0, Constants.GRID_WIDTH * Constants.GRID_SIZE, Constants.GRID_SIZE * 10):
		draw_line(Vector2(x, 0), Vector2(x, Constants.GRID_HEIGHT * Constants.GRID_SIZE), grid_color)
	
	for y in range(0, Constants.GRID_HEIGHT * Constants.GRID_SIZE, Constants.GRID_SIZE * 10):
		draw_line(Vector2(0, y), Vector2(Constants.GRID_WIDTH * Constants.GRID_SIZE, y), grid_color)
		
	# Draw brush preview at mouse position
	if is_editing:
		var mouse_pos = get_viewport().get_mouse_position()
		
		# Only draw brush preview when not over UI
		if not is_point_in_ui(mouse_pos):
			var grid_x = int(mouse_pos.x / Constants.GRID_SIZE)
			var grid_y = int(mouse_pos.y / Constants.GRID_SIZE)
			
			# Get preview color based on current cell type
			var preview_color = Color(1, 1, 1, 0.3)  # Default semi-transparent white
			match current_cell_type:
				Constants.CellType.SAND:
					preview_color = Constants.SAND_COLOR
					preview_color.a = 0.5
				Constants.CellType.WATER:
					preview_color = Constants.WATER_COLOR
					preview_color.a = 0.5
				Constants.CellType.HOLE:
					preview_color = Constants.HOLE_COLOR
					preview_color.a = 0.6
				Constants.CellType.BALL_START:
					preview_color = Color(1, 1, 0, 0.5)  # Yellow semi-transparent
			
			# Draw brush preview based on current shape and size
			if brush_shape == BrushShape.SQUARE:
				# Draw a square
				var rect_size = (brush_size * 2 + 1) * Constants.GRID_SIZE
				var rect = Rect2(
					(grid_x - brush_size) * Constants.GRID_SIZE,
					(grid_y - brush_size) * Constants.GRID_SIZE,
					rect_size,
					rect_size
				)
				draw_rect(rect, preview_color, true)
				draw_rect(rect, Color(1, 1, 1, 0.7), false)  # White border
				
			else:  # Circle brush
				# Draw a circle
				var center = Vector2(
					(grid_x + 0.5) * Constants.GRID_SIZE,
					(grid_y + 0.5) * Constants.GRID_SIZE
				)
				var radius = brush_size * Constants.GRID_SIZE
				draw_circle(center, radius, preview_color)
				draw_arc(center, radius, 0, TAU, 32, Color(1, 1, 1, 0.7), 1.0)  # White border

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
					Constants.CellType.BALL_START:
						cell_type_str = "ball_start"
				
				if cell_type_str != "":
					level_data["terrain"].append({
						"x": x,
						"y": y,
						"type": cell_type_str
					})
	
	# Convert to JSON
	pending_save_data = JSON.stringify(level_data, "  ")  # Pretty-print with 2-space indentation
	
	# Show file dialog to save
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = ["*.json ; JSON Level Files"]
	dialog.current_path = "user://levels/" + level_name.to_lower().replace(" ", "_") + ".json"
	
	dialog.file_selected.connect(_on_save_file_selected)
	add_child(dialog)
	
	dialog.popup_centered(Vector2(800, 600))

func _on_save_file_selected(path):
	if pending_save_data != "":
		# Create directory if it doesn't exist
		var dir = DirAccess.open("user://")
		if dir:
			var dir_path = path.get_base_dir()
			if not dir.dir_exists(dir_path):
				dir.make_dir_recursive(dir_path)
		
		# Save the file
		var file = FileAccess.open(path, FileAccess.WRITE)
		if file:
			file.store_string(pending_save_data)
			file.close()
			print("Level saved to: ", path)
			
			# Show confirmation
			cell_label.text = "Level saved successfully!"
		else:
			print("Error: Could not save level to ", path)
			cell_label.text = "Error saving level!"
			
		# Clear pending save data
		pending_save_data = ""
