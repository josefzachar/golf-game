extends Node

# Editor brush variables
var current_cell_type = Constants.CellType.SAND
var brush_size = 1
var last_drawn_position = Vector2(-1, -1)  # Track last drawn position to avoid redrawing same cell
var mouse_button_pressed = false
var mouse_position = Vector2.ZERO  # Track current mouse position for preview

enum BrushShape { SQUARE, CIRCLE }
var brush_shape = BrushShape.SQUARE

# References
var editor
var ui_controller

# Input handling
func _input(event):
	# Add a null check to ensure editor is set before accessing its properties
	if not editor or not editor.is_editing:
		return
	
	# Always update mouse position for preview
	if event is InputEventMouseMotion:
		mouse_position = event.position
		editor.queue_redraw()  # Request redraw to update preview
	
	# Get mouse position
	var mouse_pos = get_viewport().get_mouse_position()
	
	# Check if we're clicking on the UI panel
	if not ui_controller or not ui_controller.is_point_in_ui(mouse_pos):
		# Handle mouse button press for drawing
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			mouse_button_pressed = event.pressed
			
			if event.pressed:
				# When first pressing, draw at the initial position
				draw_at_position(mouse_pos)
		
		# Handle mouse motion while button is pressed for drawing
		elif event is InputEventMouseMotion and mouse_button_pressed:
			draw_at_position(mouse_pos)
	else:
		# We're clicking on UI, don't handle input
		return

# Called during the processing step - ensures preview is always updated
func _process(delta):
	if editor:
		editor.queue_redraw()  # Request redraw every frame to always show preview

# Helper function to draw at a given position
func draw_at_position(mouse_pos):
	# Make sure editor is valid
	if not editor:
		return
		
	var grid_x = int(mouse_pos.x / Constants.GRID_SIZE)
	var grid_y = int(mouse_pos.y / Constants.GRID_SIZE)
	
	# Skip if this is the same cell we just drew on (center point)
	if last_drawn_position.x == grid_x and last_drawn_position.y == grid_y:
		return
	
	last_drawn_position = Vector2(grid_x, grid_y)
	
	# Handle special BALL_START cell type separately (always size 1)
	if current_cell_type == Constants.CellType.BALL_START:
		if grid_x >= 0 and grid_x < Constants.GRID_WIDTH and grid_y >= 0 and grid_y < Constants.GRID_HEIGHT:
			editor.ball_start_position = Vector2(grid_x, grid_y)
			print("Set ball start position to: ", editor.ball_start_position)
			if ui_controller:
				ui_controller.update_status("Ball start position set!")
			editor.queue_redraw()
		return
		
	# Handle HOLE separately (always size 1)
	if current_cell_type == Constants.CellType.HOLE:
		if grid_x >= 0 and grid_x < Constants.GRID_WIDTH and grid_y >= 0 and grid_y < Constants.GRID_HEIGHT:
			editor.hole_position = Vector2(grid_x, grid_y)
			editor.grid[grid_x][grid_y] = EditorCell.create_cell(current_cell_type)
			print("Set hole position to: ", editor.hole_position)
			editor.queue_redraw()
		return
		
	# For regular cell types, apply brush with size and shape
	apply_brush(grid_x, grid_y)
	
	# Redraw
	editor.queue_redraw()

# Apply brush with current size and shape at the given position
func apply_brush(center_x, center_y):
	# Make sure editor and ui_controller are valid
	if not editor or not ui_controller:
		return
		
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
			
			# Create a new cell with proper properties
			var new_cell = EditorCell.create_cell(current_cell_type)
			
			# Apply custom property modifiers if in custom property mode
			if ui_controller.property_controller and ui_controller.property_controller.custom_property_mode and current_cell_type != Constants.CellType.EMPTY and current_cell_type != Constants.CellType.HOLE:
				new_cell = EditorCell.apply_modifiers_to_cell(
					new_cell,
					ui_controller.property_controller.current_mass_modifier,
					ui_controller.property_controller.current_dampening_modifier,
					ui_controller.property_controller.current_color_modifier
				)
			
			# Set the cell
			editor.grid[x][y] = new_cell
	
	print("Applied brush at (", center_x, ",", center_y, ") with size ", radius)

# Set current cell type
func set_current_type(type):
	current_cell_type = type
	if ui_controller:
		ui_controller.update_type_label(type)
	print("Current cell type set to: ", type)

# Set brush size
func set_brush_size(size):
	brush_size = size
	print("Brush size set to: ", brush_size)
	
# Set brush shape
func set_brush_shape(shape):
	brush_shape = shape
	var shape_name = "Square" if shape == BrushShape.SQUARE else "Circle"
	print("Brush shape set to: ", shape_name)

# Draw brush preview
func draw_brush_preview(canvas):
	# Also add a null check for ui_controller
	if not ui_controller:
		return
	
	# Use stored mouse_position instead of getting it every time
	var mouse_pos = mouse_position
	
	# Only draw brush preview when not over UI
	if not ui_controller.is_point_in_ui(mouse_pos):
		var grid_x = int(mouse_pos.x / Constants.GRID_SIZE)
		var grid_y = int(mouse_pos.y / Constants.GRID_SIZE)
		
		# Get preview color based on current cell type
		var preview_color = Color(1, 1, 1, 0.3)  # Default semi-transparent white
		
		if Constants.CELL_DEFAULTS.has(current_cell_type):
			preview_color = Constants.CELL_DEFAULTS[current_cell_type].base_color
			preview_color.a = 0.5
			
		if current_cell_type == Constants.CellType.BALL_START:
			preview_color = Color(1, 1, 0, 0.5)  # Yellow semi-transparent
		
		# If in custom property mode, show property color preview
		# Add null check for property_controller
		if ui_controller.property_controller and ui_controller.property_controller.custom_property_mode and current_cell_type != Constants.CellType.EMPTY and current_cell_type != Constants.CellType.HOLE:
			# Apply color modifiers to preview
			var color_mod = ui_controller.property_controller.current_color_modifier
			if current_cell_type == Constants.CellType.SAND or current_cell_type == Constants.CellType.DIRT:
				preview_color.r += color_mod.x
				preview_color.g += color_mod.y
			elif current_cell_type == Constants.CellType.WATER:
				preview_color.b += color_mod.x
				preview_color.g += color_mod.y
		
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
			canvas.draw_rect(rect, preview_color, true)
			canvas.draw_rect(rect, Color(1, 1, 1, 0.7), false)  # White border
			
		else:  # Circle brush
			# Draw a circle
			var center = Vector2(
				(grid_x + 0.5) * Constants.GRID_SIZE,
				(grid_y + 0.5) * Constants.GRID_SIZE
			)
			var radius = brush_size * Constants.GRID_SIZE
			canvas.draw_circle(center, radius, preview_color)
			canvas.draw_arc(center, radius, 0, TAU, 32, Color(1, 1, 1, 0.7), 1.0)  # White border
