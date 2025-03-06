extends Node2D

# Variables
var grid = []  # 2D grid to store cell types
var hole_position = Vector2(150, 82)  # Default hole position in grid coordinates
var current_level_path = ""  # Path to the current level

# Signal to notify the ball of the current grid state
signal grid_updated(grid)

func _ready():
	# Set up the timer for sand simulation
	var timer = Timer.new()
	timer.wait_time = 0.05  # 20 updates per second
	timer.autostart = true
	timer.timeout.connect(_on_sand_update)  # Godot 4.x signal syntax
	add_child(timer)
	
	# Initialize the grid
	initialize_grid()

func initialize_grid():
	var level_data = {}
	
	print("Level path" + current_level_path)
	# Check if we have a level path set
	if current_level_path != "" and FileAccess.file_exists(current_level_path):
		# Load level from JSON
		level_data = LevelInit.load_from_json(current_level_path)
		grid = level_data.grid
		hole_position = level_data.hole_position
		print("Loaded level from: ", current_level_path)
	else:
		# Use the LevelInit to create our grid procedurally
		grid = LevelInit.create_grid(hole_position)
		print("Generated procedural level")
	
	# Ensure the grid has the correct dimensions
	ensure_grid_dimensions()
	
	# Notify listeners about the grid
	emit_signal("grid_updated", grid)

# Make sure grid has the correct dimensions
func ensure_grid_dimensions():
	# Ensure the grid has the correct width
	while grid.size() < Constants.GRID_WIDTH:
		var new_column = []
		for y in range(Constants.GRID_HEIGHT):
			new_column.append(Constants.CellType.EMPTY)
		grid.append(new_column)
	
	# Ensure each column has the correct height
	for x in range(grid.size()):
		while grid[x].size() < Constants.GRID_HEIGHT:
			grid[x].append(Constants.CellType.EMPTY)

func load_level(level_path):
	current_level_path = level_path
	print("Level path" + current_level_path)
	initialize_grid()
	
	var counts = {
		"sand": 0, "dirt": 0, "stone": 0, "water": 0, "hole": 0, "empty": 0, "other": 0
	}
	
	for x in range(Constants.GRID_WIDTH):
		for y in range(Constants.GRID_HEIGHT):
			if x < grid.size() and y < grid[x].size():
				match grid[x][y]:
					Constants.CellType.SAND:
						counts["sand"] += 1
					Constants.CellType.DIRT:
						counts["dirt"] += 1
					Constants.CellType.STONE:
						counts["stone"] += 1
					Constants.CellType.WATER:
						counts["water"] += 1
					Constants.CellType.HOLE:
						counts["hole"] += 1
					Constants.CellType.EMPTY:
						counts["empty"] += 1
					_:
						counts["other"] += 1
	
	print("Material counts after loading: ", counts)
	
	return hole_position  # Return hole position for ball placement

func _on_sand_update():
	# Skip sand updates if the game is won
	var parent = get_parent()
	if parent and parent.has_method("get") and parent.get("game_won"):
		return
		
	update_sand_physics()
	update_water_physics()
	update_dirt_physics()
	emit_signal("grid_updated", grid)
	queue_redraw()  # Trigger redraw (Godot 4.x)

func create_sand_crater(position, radius):
	# Convert sand to empty space in a small radius
	for x in range(int(position.x - radius), int(position.x + radius + 1)):
		for y in range(int(position.y - radius), int(position.y + radius + 1)):
			if x >= 0 and x < Constants.GRID_WIDTH and y >= 0 and y < Constants.GRID_HEIGHT and x < grid.size() and y < grid[x].size():
				if Vector2(x, y).distance_to(position) <= radius:
					if grid[x][y] == Constants.CellType.SAND:
						grid[x][y] = Constants.CellType.EMPTY
						
						# Create flying sand particles - more flying sand for more dramatic effect
						if randf() > 0.3:  # Increased probability of flying sand (was 0.7)
							# Calculate direction vector based on impact position
							var dir_x = randf_range(-1.5, 1.5)  # Wider spread
							var dir_y = randf_range(-3.0, -0.5)  # More upward motion
							
							# Add a bias in the direction of ball movement
							var blast_dir = Vector2(dir_x, dir_y)
							
							var new_x = int(x + blast_dir.x)
							var new_y = int(y + blast_dir.y)
							if new_x >= 0 and new_x < Constants.GRID_WIDTH and new_y >= 0 and new_y < Constants.GRID_HEIGHT and new_x < grid.size() and new_y < grid[new_x].size():
								if grid[new_x][new_y] == Constants.CellType.EMPTY:
									grid[new_x][new_y] = Constants.CellType.SAND

func update_sand_physics():
	# Update from bottom to top, right to left
	for y in range(Constants.GRID_HEIGHT - 2, 0, -1):
		for x in range(Constants.GRID_WIDTH - 1, 0, -1):
			# First check if the current cell exists and is sand
			if x < grid.size() and y < grid[x].size() and grid[x][y] == Constants.CellType.SAND:
				# Check if space below is empty and within bounds
				if y + 1 < grid[x].size() and grid[x][y + 1] == Constants.CellType.EMPTY:
					grid[x][y] = Constants.CellType.EMPTY
					grid[x][y + 1] = Constants.CellType.SAND
				# Check if bottom right is empty and safe to move to
				elif x + 1 < grid.size() and y + 1 < grid[x + 1].size() and y + 2 < grid[x + 1].size() and \
					 grid[x + 1][y + 1] == Constants.CellType.EMPTY and grid[x + 1][y + 2] == Constants.CellType.EMPTY:
					grid[x][y] = Constants.CellType.EMPTY
					grid[x + 1][y + 1] = Constants.CellType.SAND
				# Check if bottom left is empty and safe to move to
				elif x - 1 >= 0 and x - 1 < grid.size() and y + 1 < grid[x - 1].size() and y + 2 < grid[x - 1].size() and \
					 grid[x - 1][y + 1] == Constants.CellType.EMPTY and grid[x - 1][y + 2] == Constants.CellType.EMPTY:
					grid[x][y] = Constants.CellType.EMPTY
					grid[x - 1][y + 1] = Constants.CellType.SAND
				# Random spread to bottom right
				elif x + 1 < grid.size() and y + 1 < grid[x + 1].size() and randf() > 0.8 and grid[x + 1][y + 1] == Constants.CellType.EMPTY:
					grid[x][y] = Constants.CellType.EMPTY
					grid[x + 1][y + 1] = Constants.CellType.SAND
				# Random spread to bottom left
				elif x - 1 >= 0 and x - 1 < grid.size() and y + 1 < grid[x - 1].size() and randf() > 0.8 and grid[x - 1][y + 1] == Constants.CellType.EMPTY:
					grid[x][y] = Constants.CellType.EMPTY
					grid[x - 1][y + 1] = Constants.CellType.SAND
					
func update_dirt_physics():
	# Update from bottom to top, right to left for consistent physics
	for y in range(Constants.GRID_HEIGHT - 2, 0, -1):
		for x in range(Constants.GRID_WIDTH - 1, 0, -1):
			# Check if the current cell exists and is dirt
			if x < grid.size() and y < grid[x].size() and grid[x][y] == Constants.CellType.DIRT:
				# Dirt moves less often than sand - random check to simulate rigidity
				if randf() > 0.7:  # 30% chance to evaluate movement (more rigid than sand)
					continue
				
				# Check if we're on top of stone - dirt doesn't move when on stone
				if y + 1 < grid[x].size() and grid[x][y + 1] == Constants.CellType.STONE:
					continue
					
				# Check if space below is empty and within bounds - basic gravity
				if y + 1 < grid[x].size() and grid[x][y + 1] == Constants.CellType.EMPTY:
					grid[x][y] = Constants.CellType.EMPTY
					grid[x][y + 1] = Constants.CellType.DIRT
					continue
				
				# Check if space below is water - dirt sinks in water
				if y + 1 < grid[x].size() and grid[x][y + 1] == Constants.CellType.WATER:
					grid[x][y] = Constants.CellType.WATER  # Replace dirt with water
					grid[x][y + 1] = Constants.CellType.DIRT  # Dirt sinks
					continue
					
				# Dirt has limited diagonal movement - only when on unstable surface
				# First check if we're on sand or another dirt (can slide off)
				var on_unstable = false
				if y + 1 < grid[x].size():
					var below_cell = grid[x][y + 1]
					if below_cell == Constants.CellType.SAND or below_cell == Constants.CellType.DIRT or below_cell == Constants.CellType.WATER:
						on_unstable = true
				
				# Limited lateral movement - only when on unstable surface
				if on_unstable:
					# Bottom-right check
					if x + 1 < grid.size() and y + 1 < grid[x + 1].size() and randf() > 0.6 and grid[x + 1][y + 1] == Constants.CellType.EMPTY:
						# Move if there's empty space diagonally
						grid[x][y] = Constants.CellType.EMPTY
						grid[x + 1][y + 1] = Constants.CellType.DIRT
						continue
						
					# Bottom-left check
					elif x - 1 >= 0 and x - 1 < grid.size() and y + 1 < grid[x - 1].size() and randf() > 0.6 and grid[x - 1][y + 1] == Constants.CellType.EMPTY:
						# Move if there's empty space diagonally
						grid[x][y] = Constants.CellType.EMPTY
						grid[x - 1][y + 1] = Constants.CellType.DIRT
						continue
				
				# Very limited horizontal spread - dirt barely moves sideways without support
				# Only if there's a column of at least 3 dirt blocks
				var dirt_column_height = 0
				for check_y in range(y, min(y + 3, Constants.GRID_HEIGHT)):
					if check_y < grid[x].size() and grid[x][check_y] == Constants.CellType.DIRT:
						dirt_column_height += 1
					else:
						break
				
				# Horizontal movement if dirt column is high enough (pressure based)
				if dirt_column_height >= 3:
					var horizontal_move_chance = 0.15  # Very low probability
					
					# Check right
					if x + 1 < grid.size() and grid[x + 1][y] == Constants.CellType.EMPTY and randf() < horizontal_move_chance:
						# Only move if there's support below or sand/dirt beside
						if y + 1 < grid[x + 1].size() and grid[x + 1][y + 1] != Constants.CellType.EMPTY:
							grid[x][y] = Constants.CellType.EMPTY
							grid[x + 1][y] = Constants.CellType.DIRT
							continue
					
					# Check left
					if x - 1 >= 0 and x - 1 < grid.size() and grid[x - 1][y] == Constants.CellType.EMPTY and randf() < horizontal_move_chance:
						# Only move if there's support below or sand/dirt beside
						if y + 1 < grid[x - 1].size() and grid[x - 1][y + 1] != Constants.CellType.EMPTY:
							grid[x][y] = Constants.CellType.EMPTY
							grid[x - 1][y] = Constants.CellType.DIRT
							continue
							
func update_water_physics():
	# Update from bottom to top, right to left
	for y in range(Constants.GRID_HEIGHT - 2, 0, -1):
		for x in range(Constants.GRID_WIDTH - 1, 0, -1):
			# First check if the current cell exists and is water
			if x < grid.size() and y < grid[x].size() and grid[x][y] == Constants.CellType.WATER:
				# Check if space below is empty and within bounds
				if y + 1 < grid[x].size() and grid[x][y + 1] == Constants.CellType.EMPTY:
					grid[x][y] = Constants.CellType.EMPTY
					grid[x][y + 1] = Constants.CellType.WATER
				# Check if diagonal down-right is empty and within bounds
				elif x + 1 < grid.size() and y + 1 < grid[x + 1].size() and randf() > 0.1 and grid[x + 1][y + 1] == Constants.CellType.EMPTY:
					grid[x][y] = Constants.CellType.EMPTY
					grid[x + 1][y + 1] = Constants.CellType.WATER
				# Check if diagonal down-left is empty and within bounds
				elif x - 1 >= 0 and x - 1 < grid.size() and y + 1 < grid[x - 1].size() and randf() > 0.1 and grid[x - 1][y + 1] == Constants.CellType.EMPTY:
					grid[x][y] = Constants.CellType.EMPTY
					grid[x - 1][y + 1] = Constants.CellType.WATER
				# Check horizontal water flow right if there's water behind
				elif x + 1 < grid.size() and randf() > 0.4 and grid[x + 1][y] == Constants.CellType.EMPTY and \
					 x - 1 >= 0 and x - 1 < grid.size() and grid[x - 1][y] == Constants.CellType.WATER and \
					 x - 2 >= 0 and x - 2 < grid.size() and grid[x - 2][y] == Constants.CellType.WATER:
					grid[x][y] = Constants.CellType.EMPTY
					grid[x + 1][y] = Constants.CellType.WATER
				# Check horizontal water flow left if there's water behind
				elif x - 1 >= 0 and x - 1 < grid.size() and randf() > 0.4 and grid[x - 1][y] == Constants.CellType.EMPTY and \
					 x + 1 < grid.size() and grid[x + 1][y] == Constants.CellType.WATER and \
					 x + 2 < grid.size() and grid[x + 2][y] == Constants.CellType.WATER:
					grid[x][y] = Constants.CellType.EMPTY
					grid[x - 1][y] = Constants.CellType.WATER

func set_cell(x, y, type):
	if x >= 0 and x < Constants.GRID_WIDTH and y >= 0 and y < Constants.GRID_HEIGHT and x < grid.size() and y < grid[x].size():
		grid[x][y] = type

func get_cell(x, y):
	if x >= 0 and x < Constants.GRID_WIDTH and y >= 0 and y < Constants.GRID_HEIGHT and x < grid.size() and y < grid[x].size():
		return grid[x][y]
	return Constants.CellType.EMPTY

func get_hole_position():
	return hole_position

func _draw():
	# Draw the grid cells
	for x in range(Constants.GRID_WIDTH):
		for y in range(Constants.GRID_HEIGHT):
			if x < grid.size() and y < grid[x].size():  # Add bounds check
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
						# Draw water with a slightly animated effect
						var water_variation = randf() * 0.1
						var water_color = Constants.WATER_COLOR
						water_color.b += water_variation
						draw_rect(rect, water_color, true)
					Constants.CellType.STONE:
						# Draw stone with a solid color and texture effect
						var stone_base = Constants.STONE_COLOR
						# Add random subtle shade variations for texture
						var shade_variation = (randf() * 0.1) - 0.05
						stone_base = stone_base.lightened(shade_variation)
						draw_rect(rect, stone_base, true)
						
						# Add a darker border for definition
						var border_rect = Rect2(
							x * Constants.GRID_SIZE, 
							y * Constants.GRID_SIZE, 
							Constants.GRID_SIZE, 
							Constants.GRID_SIZE
						)
						draw_rect(border_rect, Constants.STONE_COLOR.darkened(0.3), false)
						
						# Add inner texture lines for stone effect (only for some stones)
						if (x + y) % 4 == 0:
							var line_start = Vector2(
								x * Constants.GRID_SIZE + 2, 
								y * Constants.GRID_SIZE + 2
							)
							var line_end = Vector2(
								x * Constants.GRID_SIZE + Constants.GRID_SIZE - 2, 
								y * Constants.GRID_SIZE + Constants.GRID_SIZE - 2
							)
							draw_line(line_start, line_end, Constants.STONE_COLOR.darkened(0.2), 1)
							
					Constants.CellType.DIRT:
						# Draw dirt with organic variations
						var dirt_base = Constants.DIRT_COLOR
						# Apply random subtle color variations
						var r_var = randf() * 0.08 - 0.04
						var g_var = randf() * 0.06 - 0.03
						dirt_base.r += r_var
						dirt_base.g += g_var
						draw_rect(rect, dirt_base, true)
						
						# Add small occasional dots for texture
						if randf() > 0.8:
							var dot_size = 2
							var dot_pos = Vector2(
								x * Constants.GRID_SIZE + randf() * (Constants.GRID_SIZE - dot_size),
								y * Constants.GRID_SIZE + randf() * (Constants.GRID_SIZE - dot_size)
							)
							var dot_rect = Rect2(dot_pos, Vector2(dot_size, dot_size))
							draw_rect(dot_rect, dirt_base.darkened(0.2), true)
					# Ball is drawn by the Ball node
