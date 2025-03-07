extends Node

# Property visualization mode
var property_visualization = false  # When true, cell color reflects properties
var visualize_property = "mass"  # Which property to visualize: "mass", "dampening"

# References
var editor
var ui_controller

# Functions for property visualization
func toggle_property_visualization():
	property_visualization = !property_visualization
	ui_controller.visualization_panel.visible = property_visualization
	
	# Show/hide property labels
	for key in ui_controller.property_labels:
		ui_controller.property_labels[key].visible = property_visualization
	
	if property_visualization:
		ui_controller.update_status("Visualizing " + visualize_property)
	else:
		# Update label to current cell type
		ui_controller.update_type_label(ui_controller.brush_controller.current_cell_type)
	
	# Force redraw to apply visualization
	editor.queue_redraw()

func set_visualization_property(property):
	visualize_property = property
	ui_controller.update_status("Visualizing " + visualize_property)
	editor.queue_redraw()

func update_property_labels(x, y):
	if x >= 0 and x < Constants.GRID_WIDTH and y >= 0 and y < Constants.GRID_HEIGHT:
		var cell = editor.grid[x][y]
		ui_controller.property_labels["position"].text = "Position: " + str(x) + ", " + str(y)
		ui_controller.property_labels["type"].text = "Type: " + EditorCell.get_cell_type_name(cell.type)
		ui_controller.property_labels["mass"].text = "Mass: " + str(snapped(cell.mass, 0.01))
		ui_controller.property_labels["dampening"].text = "Dampening: " + str(snapped(cell.dampening, 0.01))

# Process mouse hovering for property visualization
func _process(delta):
	if property_visualization:
		var mouse_pos = get_viewport().get_mouse_position()
		if not ui_controller.is_point_in_ui(mouse_pos):
			var grid_x = int(mouse_pos.x / Constants.GRID_SIZE)
			var grid_y = int(mouse_pos.y / Constants.GRID_SIZE)
			update_property_labels(grid_x, grid_y)

# Draw the grid with appropriate visualization
func draw_grid(canvas):
	# Draw the grid cells
	for x in range(Constants.GRID_WIDTH):
		for y in range(Constants.GRID_HEIGHT):
			if x < editor.grid.size() and y < editor.grid[x].size():
				var cell = editor.grid[x][y]
				var rect = Rect2(x * Constants.GRID_SIZE, y * Constants.GRID_SIZE, Constants.GRID_SIZE, Constants.GRID_SIZE)
				
				# Determine if we're in visualization mode and should color code cells
				var use_property_color = property_visualization and cell.type != Constants.CellType.EMPTY and cell.type != Constants.CellType.HOLE
				
				match cell.type:
					Constants.CellType.EMPTY:
						# Sky color
						canvas.draw_rect(rect, Constants.CELL_DEFAULTS[Constants.CellType.EMPTY].base_color, true)
					
					Constants.CellType.SAND:
						# Apply color variation or property visualization
						var sand_color = Constants.SAND_COLOR
						
						if use_property_color:
							# Color code based on selected property
							if visualize_property == "mass":
								# Scale from red (heavy) to yellow (light)
								var intensity = clamp((cell.mass - 0.5) / 1.5, 0.0, 1.0)
								sand_color = Color(1.0, 1.0 - intensity * 0.8, 0.3)
							elif visualize_property == "dampening":
								# Scale from blue (low dampening) to green (high dampening)
								var intensity = clamp((cell.dampening - 0.7) / 0.6, 0.0, 1.0)
								sand_color = Color(0.3, 0.7 + intensity * 0.3, 1.0 - intensity * 0.7)
						else:
							# Normal cell coloring with individual variation
							sand_color.r += cell.color_variation.x
							sand_color.g += cell.color_variation.y
						
						canvas.draw_rect(rect, sand_color, true)
					
					Constants.CellType.DIRT:
						# Draw dirt with visual property indicators or organic variations
						var dirt_color = Constants.DIRT_COLOR
						
						if use_property_color:
							# Color code based on selected property
							if visualize_property == "mass":
								var intensity = clamp((cell.mass - 1.0) / 1.5, 0.0, 1.0)
								dirt_color = Color(0.8 + intensity * 0.2, 0.4 - intensity * 0.2, 0.2)
							elif visualize_property == "dampening":
								var intensity = clamp((cell.dampening - 0.7) / 0.6, 0.0, 1.0)
								dirt_color = Color(0.6, 0.4 + intensity * 0.3, 0.2 + intensity * 0.6)
						else:
							# Normal cell coloring
							dirt_color.r += cell.color_variation.x
							dirt_color.g += cell.color_variation.y
						
						canvas.draw_rect(rect, dirt_color, true)
					
					Constants.CellType.STONE:
						# Draw stone with property visualizations or standard coloring
						var stone_color = Constants.STONE_COLOR
						
						if use_property_color:
							# Color code based on selected property
							if visualize_property == "mass":
								var intensity = clamp((cell.mass - 2.0) / 1.5, 0.0, 1.0)
								stone_color = Color(0.5 - intensity * 0.3, 0.5 - intensity * 0.3, 0.5 + intensity * 0.3)
							elif visualize_property == "dampening":
								var intensity = clamp((cell.dampening - 0.8) / 0.4, 0.0, 1.0)
								stone_color = Color(0.5 + intensity * 0.3, 0.5, 0.5 - intensity * 0.2)
						else:
							# Normal cell coloring
							stone_color.r += cell.color_variation.x
							stone_color.g += cell.color_variation.y
							stone_color.b += (cell.color_variation.x + cell.color_variation.y) / 2
						
						canvas.draw_rect(rect, stone_color, true)
					
					Constants.CellType.HOLE:
						# Draw hole with a thicker border to make it more visible
						canvas.draw_rect(rect, Constants.HOLE_COLOR, true)
					
					Constants.CellType.WATER:
						# Draw water with property visualization or color variation
						var water_color = Constants.WATER_COLOR
						
						if use_property_color:
							# Color code based on selected property
							if visualize_property == "mass":
								var intensity = clamp((cell.mass - 0.6) / 0.8, 0.0, 1.0)
								water_color = Color(0.2, 0.4 - intensity * 0.2, 0.8 + intensity * 0.2)
							elif visualize_property == "dampening":
								var intensity = clamp((cell.dampening - 0.6) / 0.6, 0.0, 1.0)
								water_color = Color(0.2 - intensity * 0.1, 0.4 + intensity * 0.2, 0.8 - intensity * 0.4)
						else:
							# Normal cell coloring
							water_color.b += cell.color_variation.x
							water_color.g += cell.color_variation.y
						
						canvas.draw_rect(rect, water_color, true)
					
					Constants.CellType.BALL_START:
						# Draw any ball start cells in the grid
						canvas.draw_rect(rect, Color(0.8, 0.8, 0.2, 0.8), true)
	
	# Draw the ball start position indicator
	var ball_start_rect = Rect2(
		editor.ball_start_position.x * Constants.GRID_SIZE,
		editor.ball_start_position.y * Constants.GRID_SIZE,
		Constants.GRID_SIZE,
		Constants.GRID_SIZE
	)
	canvas.draw_rect(ball_start_rect, Color(1, 1, 1, 0.5), true)  # Semi-transparent white
	
	# Draw a grid overlay for better visualization
	var grid_color = Color(0.5, 0.5, 0.5, 0.2)  # Light gray, semi-transparent
	for x in range(0, Constants.GRID_WIDTH * Constants.GRID_SIZE, Constants.GRID_SIZE * 10):
		canvas.draw_line(Vector2(x, 0), Vector2(x, Constants.GRID_HEIGHT * Constants.GRID_SIZE), grid_color)
	
	for y in range(0, Constants.GRID_HEIGHT * Constants.GRID_SIZE, Constants.GRID_SIZE * 10):
		canvas.draw_line(Vector2(0, y), Vector2(Constants.GRID_WIDTH * Constants.GRID_SIZE, y), grid_color)
