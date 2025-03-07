extends Node2D

# Variables
var grid = []  # 2D grid to store cell objects
var hole_position = Vector2(150, 82)  # Default hole position in grid coordinates
var current_level_path = ""  # Path to the current level

# Signal to notify the ball of the current grid state
signal grid_updated(grid)

func _ready():
	# Set up the timer for sand simulation
	var timer = Timer.new()
	timer.wait_time = 0.01  # 20 updates per second
	timer.autostart = true
	timer.timeout.connect(_on_sand_update)  # Godot 4.x signal syntax
	add_child(timer)
	
	# Initialize the grid
	initialize_grid()

func initialize_grid():
	var level_data = {}
	
	print("Level path: " + current_level_path)
	# Check if we have a level path set
	if current_level_path != "" and FileAccess.file_exists(current_level_path):
		# Load level from JSON
		level_data = LevelInit.load_from_json(current_level_path)
		grid = convert_grid_to_cells(level_data.grid)
		hole_position = level_data.hole_position
		print("Loaded level from: ", current_level_path)
	else:
		# Use the LevelInit to create our grid procedurally
		var basic_grid = LevelInit.create_grid(hole_position)
		grid = convert_grid_to_cells(basic_grid)
		print("Generated procedural level")
	
	# Ensure the grid has the correct dimensions
	ensure_grid_dimensions()
	
	# Notify listeners about the grid
	emit_signal("grid_updated", grid)

# Convert a basic grid of types to a grid of cell objects
func convert_grid_to_cells(basic_grid):
	var cell_grid = []
	
	for x in range(basic_grid.size()):
		var column = []
		for y in range(basic_grid[x].size()):
			var cell_type = basic_grid[x][y]
			column.append(create_cell(cell_type))
		cell_grid.append(column)
	
	return cell_grid

# Helper function to create a cell with properties
func create_cell(type):
	var cell = {
		"type": type,
		"velocity": Vector2.ZERO,
		"color_variation": Vector2.ZERO,  # Using Vector2 for r,g variation
		"mass": 0.0,
		"dampening": 0.0
	}
	
	# Set properties based on type from defaults
	if Constants.CELL_DEFAULTS.has(type):
		var defaults = Constants.CELL_DEFAULTS[type]
		
		# Add random variations to make each cell unique
		cell.mass = defaults.mass
		if type != Constants.CellType.EMPTY and type != Constants.CellType.HOLE:
			cell.mass += randf_range(-Constants.MASS_VARIATION_RANGE, Constants.MASS_VARIATION_RANGE)
			
		cell.dampening = defaults.dampening
		if type != Constants.CellType.EMPTY and type != Constants.CellType.HOLE:
			cell.dampening += randf_range(-Constants.DAMPENING_VARIATION_RANGE, Constants.DAMPENING_VARIATION_RANGE)
			
		# Add color variation (except for special types)
		if type != Constants.CellType.EMPTY and type != Constants.CellType.HOLE and type != Constants.CellType.BALL:
			var variation = randf_range(-Constants.COLOR_VARIATION_RANGE, Constants.COLOR_VARIATION_RANGE)
			
			# Different variation for different channels based on material
			match type:
				Constants.CellType.SAND:
					cell.color_variation = Vector2(variation, variation * 0.8)
				Constants.CellType.DIRT:
					cell.color_variation = Vector2(variation * 1.2, variation * 0.6)
				Constants.CellType.WATER:
					cell.color_variation = Vector2(variation * 0.5, variation * 0.5)
				Constants.CellType.STONE:
					var gray_var = variation * 0.7
					cell.color_variation = Vector2(gray_var, gray_var)
	
	return cell

# Create an empty cell
func create_empty_cell():
	return create_cell(Constants.CellType.EMPTY)

# Make sure grid has the correct dimensions
func ensure_grid_dimensions():
	# Ensure the grid has the correct width
	while grid.size() < Constants.GRID_WIDTH:
		var new_column = []
		for y in range(Constants.GRID_HEIGHT):
			new_column.append(create_empty_cell())
		grid.append(new_column)
	
	# Ensure each column has the correct height
	for x in range(grid.size()):
		while grid[x].size() < Constants.GRID_HEIGHT:
			grid[x].append(create_empty_cell())

func load_level(level_path):
	current_level_path = level_path
	print("Level path: " + current_level_path)
	initialize_grid()
	
	var counts = {
		"sand": 0, "dirt": 0, "stone": 0, "water": 0, "hole": 0, "empty": 0, "other": 0
	}
	
	# Count cells of each type
	for x in range(Constants.GRID_WIDTH):
		for y in range(Constants.GRID_HEIGHT):
			if x < grid.size() and y < grid[x].size():
				match grid[x][y].type:
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
					# NEVER affect stone - stone is completely indestructible 
					if grid[x][y].type == Constants.CellType.STONE:
						continue  # Skip stone cells entirely
					
					# EXTREMELY LIMITED DIRT INTERACTION - dirt is now almost as solid as stone
					if grid[x][y].type == Constants.CellType.DIRT:
						# Only affect dirt with EXTREMELY high impacts and very small radius
						if radius > 6.0 and Vector2(x, y).distance_to(position) <= radius * 0.15:
							# Even higher chance to resist impact completely
							if randf() > 0.9:  # 90% chance to resist impact completely (was 0.7)
								var dirt_properties = grid[x][y]
								grid[x][y] = create_empty_cell()
								
								# Almost no dirt particle creation
								if randf() > 0.98:  # Only 2% chance (was 10%)
									var dir_x = randf_range(-0.2, 0.2)  # Extremely limited spread
									var dir_y = randf_range(-0.6, -0.1)  # Minimal motion
									
									var blast_dir = Vector2(dir_x, dir_y)
									
									var new_x = int(x + blast_dir.x)
									var new_y = int(y + blast_dir.y)
									if new_x >= 0 and new_x < Constants.GRID_WIDTH and new_y >= 0 and new_y < Constants.GRID_HEIGHT and new_x < grid.size() and new_y < grid[new_x].size():
										if grid[new_x][new_y].type == Constants.CellType.EMPTY:
											grid[new_x][new_y] = dirt_properties
											grid[new_x][new_y].velocity = blast_dir * dirt_properties.mass * 0.05  # Minimal velocity
						continue  # Always skip the normal processing for dirt
					
					# Handle sand cells with normal physics
					if grid[x][y].type == Constants.CellType.SAND:
						# Store the properties of the sand before clearing
						var sand_properties = grid[x][y]
						grid[x][y] = create_empty_cell()
						
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
								if grid[new_x][new_y].type == Constants.CellType.EMPTY:
									# Transfer the properties from the original sand
									grid[new_x][new_y] = sand_properties
									# Add velocity based on the blast direction
									grid[new_x][new_y].velocity = blast_dir * sand_properties.mass * 0.5
	# Convert sand to empty space in a small radius
	for x in range(int(position.x - radius), int(position.x + radius + 1)):
		for y in range(int(position.y - radius), int(position.y + radius + 1)):
			if x >= 0 and x < Constants.GRID_WIDTH and y >= 0 and y < Constants.GRID_HEIGHT and x < grid.size() and y < grid[x].size():
				if Vector2(x, y).distance_to(position) <= radius:
					# NEVER affect stone - stone is completely indestructible 
					if grid[x][y].type == Constants.CellType.STONE:
						continue  # Skip stone cells entirely
					
					# EXTREMELY LIMITED DIRT INTERACTION - dirt is now almost as solid as stone
					if grid[x][y].type == Constants.CellType.DIRT:
						# Only affect dirt with EXTREME impacts and very small radius
						if radius > 3.0 and Vector2(x, y).distance_to(position) <= radius * 0.3:
							# Even then, only a small chance to actually affect the dirt
							if randf() > 0.7:  # 70% chance to resist impact completely
								var dirt_properties = grid[x][y]
								grid[x][y] = create_empty_cell()
								
								# Very limited dirt particle creation
								if randf() > 0.9:  # Only 10% chance (was 40%)
									var dir_x = randf_range(-0.5, 0.5)  # Very limited spread
									var dir_y = randf_range(-1.0, -0.2)  # Less upward motion
									
									var blast_dir = Vector2(dir_x, dir_y)
									
									var new_x = int(x + blast_dir.x)
									var new_y = int(y + blast_dir.y)
									if new_x >= 0 and new_x < Constants.GRID_WIDTH and new_y >= 0 and new_y < Constants.GRID_HEIGHT and new_x < grid.size() and new_y < grid[new_x].size():
										if grid[new_x][new_y].type == Constants.CellType.EMPTY:
											grid[new_x][new_y] = dirt_properties
											grid[new_x][new_y].velocity = blast_dir * dirt_properties.mass * 0.15
						continue  # Always skip the normal processing for dirt
					
					# Handle sand cells with normal physics
					if grid[x][y].type == Constants.CellType.SAND:
						# Store the properties of the sand before clearing
						var sand_properties = grid[x][y]
						grid[x][y] = create_empty_cell()
						
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
								if grid[new_x][new_y].type == Constants.CellType.EMPTY:
									# Transfer the properties from the original sand
									grid[new_x][new_y] = sand_properties
									# Add velocity based on the blast direction
									grid[new_x][new_y].velocity = blast_dir * sand_properties.mass * 0.5
	# Convert sand to empty space in a small radius
	for x in range(int(position.x - radius), int(position.x + radius + 1)):
		for y in range(int(position.y - radius), int(position.y + radius + 1)):
			if x >= 0 and x < Constants.GRID_WIDTH and y >= 0 and y < Constants.GRID_HEIGHT and x < grid.size() and y < grid[x].size():
				if Vector2(x, y).distance_to(position) <= radius:
					# NEVER affect stone - stone is completely indestructible 
					if grid[x][y].type == Constants.CellType.STONE:
						continue  # Skip stone cells entirely
					
					# EXTREMELY LIMITED DIRT INTERACTION - dirt is now almost as solid as stone
					if grid[x][y].type == Constants.CellType.DIRT:
						# Only affect dirt with EXTREME impacts and very small radius
						if radius > 3.0 and Vector2(x, y).distance_to(position) <= radius * 0.3:
							# Even then, only a small chance to actually affect the dirt
							if randf() > 0.7:  # 70% chance to resist impact completely
								var dirt_properties = grid[x][y]
								grid[x][y] = create_empty_cell()
								
								# Very limited dirt particle creation
								if randf() > 0.9:  # Only 10% chance (was 40%)
									var dir_x = randf_range(-0.5, 0.5)  # Very limited spread
									var dir_y = randf_range(-1.0, -0.2)  # Less upward motion
									
									var blast_dir = Vector2(dir_x, dir_y)
									
									var new_x = int(x + blast_dir.x)
									var new_y = int(y + blast_dir.y)
									if new_x >= 0 and new_x < Constants.GRID_WIDTH and new_y >= 0 and new_y < Constants.GRID_HEIGHT and new_x < grid.size() and new_y < grid[new_x].size():
										if grid[new_x][new_y].type == Constants.CellType.EMPTY:
											grid[new_x][new_y] = dirt_properties
											grid[new_x][new_y].velocity = blast_dir * dirt_properties.mass * 0.15
						continue  # Always skip the normal processing for dirt
					
					# Handle sand cells with normal physics
					if grid[x][y].type == Constants.CellType.SAND:
						# Store the properties of the sand before clearing
						var sand_properties = grid[x][y]
						grid[x][y] = create_empty_cell()
						
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
								if grid[new_x][new_y].type == Constants.CellType.EMPTY:
									# Transfer the properties from the original sand
									grid[new_x][new_y] = sand_properties
									# Add velocity based on the blast direction
									grid[new_x][new_y].velocity = blast_dir * sand_properties.mass * 0.5
	# Convert sand to empty space in a small radius
	for x in range(int(position.x - radius), int(position.x + radius + 1)):
		for y in range(int(position.y - radius), int(position.y + radius + 1)):
			if x >= 0 and x < Constants.GRID_WIDTH and y >= 0 and y < Constants.GRID_HEIGHT and x < grid.size() and y < grid[x].size():
				if Vector2(x, y).distance_to(position) <= radius:
					# NEVER affect stone - stone is completely indestructible 
					if grid[x][y].type == Constants.CellType.STONE:
						continue  # Skip stone cells entirely
					
					# Handle sand cells
					if grid[x][y].type == Constants.CellType.SAND:
						# Store the properties of the sand before clearing
						var sand_properties = grid[x][y]
						grid[x][y] = create_empty_cell()
						
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
								if grid[new_x][new_y].type == Constants.CellType.EMPTY:
									# Transfer the properties from the original sand
									grid[new_x][new_y] = sand_properties
									# Add velocity based on the blast direction
									grid[new_x][new_y].velocity = blast_dir * sand_properties.mass * 0.5
					
					# Handle dirt cells - similar to sand but less particle creation and much smaller radius
					elif grid[x][y].type == Constants.CellType.DIRT:
						# Much more limited radius for dirt - only very close cells are affected
						if Vector2(x, y).distance_to(position) <= radius * 0.4:  # Reduced from 0.6
							# Very small chance of actually displacing dirt based on impact force
							if radius > 1.5 and randf() > 0.7:  # Only large impacts, with low probability
								# Store dirt properties
								var dirt_properties = grid[x][y]
								grid[x][y] = create_empty_cell()
								
								# Create fewer flying dirt particles
								if randf() > 0.8:  # Even lower probability than before (was 0.6)
									var dir_x = randf_range(-0.7, 0.7)  # Very limited spread (was -1.0, 1.0)
									var dir_y = randf_range(-1.5, -0.3)  # Less upward motion (was -2.0, -0.5)
									
									var blast_dir = Vector2(dir_x, dir_y)
									
									var new_x = int(x + blast_dir.x)
									var new_y = int(y + blast_dir.y)
									if new_x >= 0 and new_x < Constants.GRID_WIDTH and new_y >= 0 and new_y < Constants.GRID_HEIGHT and new_x < grid.size() and new_y < grid[new_x].size():
										if grid[new_x][new_y].type == Constants.CellType.EMPTY:
											# Transfer dirt properties
											grid[new_x][new_y] = dirt_properties
											# Even less velocity for dirt particles
											grid[new_x][new_y].velocity = blast_dir * dirt_properties.mass * 0.2
	# Convert sand to empty space in a small radius
	for x in range(int(position.x - radius), int(position.x + radius + 1)):
		for y in range(int(position.y - radius), int(position.y + radius + 1)):
			if x >= 0 and x < Constants.GRID_WIDTH and y >= 0 and y < Constants.GRID_HEIGHT and x < grid.size() and y < grid[x].size():
				if Vector2(x, y).distance_to(position) <= radius:
					# Handle sand cells
					if grid[x][y].type == Constants.CellType.SAND:
						# Store the properties of the sand before clearing
						var sand_properties = grid[x][y]
						grid[x][y] = create_empty_cell()
						
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
								if grid[new_x][new_y].type == Constants.CellType.EMPTY:
									# Transfer the properties from the original sand
									grid[new_x][new_y] = sand_properties
									# Add velocity based on the blast direction
									grid[new_x][new_y].velocity = blast_dir * sand_properties.mass * 0.5
					# Handle dirt cells - similar to sand but less particle creation and smaller radius
					elif grid[x][y].type == Constants.CellType.DIRT and Vector2(x, y).distance_to(position) <= radius * 0.6:
						# Store dirt properties
						var dirt_properties = grid[x][y]
						grid[x][y] = create_empty_cell()
						
						# Create fewer flying dirt particles
						if randf() > 0.6:  # Lower probability than sand
							var dir_x = randf_range(-1.0, 1.0)  # Less spread
							var dir_y = randf_range(-2.0, -0.5)  # Less upward motion
							
							var blast_dir = Vector2(dir_x, dir_y)
							
							var new_x = int(x + blast_dir.x)
							var new_y = int(y + blast_dir.y)
							if new_x >= 0 and new_x < Constants.GRID_WIDTH and new_y >= 0 and new_y < Constants.GRID_HEIGHT and new_x < grid.size() and new_y < grid[new_x].size():
								if grid[new_x][new_y].type == Constants.CellType.EMPTY:
									# Transfer dirt properties
									grid[new_x][new_y] = dirt_properties
									# Less velocity for dirt particles
									grid[new_x][new_y].velocity = blast_dir * dirt_properties.mass * 0.3
	# Convert sand to empty space in a small radius
	for x in range(int(position.x - radius), int(position.x + radius + 1)):
		for y in range(int(position.y - radius), int(position.y + radius + 1)):
			if x >= 0 and x < Constants.GRID_WIDTH and y >= 0 and y < Constants.GRID_HEIGHT and x < grid.size() and y < grid[x].size():
				if Vector2(x, y).distance_to(position) <= radius:
					if grid[x][y].type == Constants.CellType.SAND:
						# Store the properties of the sand before clearing
						var sand_properties = grid[x][y]
						grid[x][y] = create_empty_cell()
						
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
								if grid[new_x][new_y].type == Constants.CellType.EMPTY:
									# Transfer the properties from the original sand
									grid[new_x][new_y] = sand_properties
									# Add velocity based on the blast direction
									grid[new_x][new_y].velocity = blast_dir * sand_properties.mass * 0.5

func update_sand_physics():
	# Update from bottom to top, right to left
	for y in range(Constants.GRID_HEIGHT - 2, 0, -1):
		for x in range(Constants.GRID_WIDTH - 1, 0, -1):
			# First check if the current cell exists and is sand
			if x < grid.size() and y < grid[x].size() and grid[x][y].type == Constants.CellType.SAND:
				var cell = grid[x][y]
				
				# Apply gravity to velocity based on cell mass
				cell.velocity.y += Constants.GRAVITY * 0.01 * cell.mass
				
				# Check if space below is empty and within bounds - SAND FALLS QUICKLY
				if y + 1 < grid[x].size() and grid[x][y + 1].type == Constants.CellType.EMPTY:
					# Sand always falls straight down through empty space (100% chance)
					grid[x][y + 1] = cell
					grid[x][y] = create_empty_cell()
					continue
				
				# NEW CODE: Check if space below is water - sand sinks in water just like dirt
				elif y + 1 < grid[x].size() and grid[x][y + 1].type == Constants.CellType.WATER:
					var water_cell = grid[x][y + 1]
					grid[x][y] = water_cell  # Replace sand with water
					grid[x][y + 1] = cell    # Sand sinks
					continue
				
				# If blocked below, try diagonal paths - SAND SPREADS EASILY
				# Check if bottom right is empty
				elif x + 1 < grid.size() and y + 1 < grid[x + 1].size() and grid[x + 1][y + 1].type == Constants.CellType.EMPTY:
					grid[x + 1][y + 1] = cell
					grid[x][y] = create_empty_cell()
					continue
				
				# Check if bottom left is empty
				elif x - 1 >= 0 and x - 1 < grid.size() and y + 1 < grid[x - 1].size() and grid[x - 1][y + 1].type == Constants.CellType.EMPTY:
					grid[x - 1][y + 1] = cell
					grid[x][y] = create_empty_cell()
					continue
				
				# Additional random spread for natural sand flow - MORE RANDOM MOVEMENT
				elif randf() > 0.7:  # 30% chance of random movement
					# Try random diagonal movement with even higher probability if there's sand nearby
					if x + 1 < grid.size() and y < grid[x + 1].size() and grid[x + 1][y].type == Constants.CellType.SAND:
						if x + 2 < grid.size() and y + 1 < grid[x + 2].size() and grid[x + 2][y + 1].type == Constants.CellType.EMPTY:
							grid[x + 2][y + 1] = cell
							grid[x][y] = create_empty_cell()
							continue
					
					# Check left as well
					if x - 1 >= 0 and x - 1 < grid.size() and y < grid[x - 1].size() and grid[x - 1][y].type == Constants.CellType.SAND:
						if x - 2 >= 0 and x - 2 < grid.size() and y + 1 < grid[x - 2].size() and grid[x - 2][y + 1].type == Constants.CellType.EMPTY:
							grid[x - 2][y + 1] = cell
							grid[x][y] = create_empty_cell()
							continue
				
				# Apply dampening to velocity
				cell.velocity *= cell.dampening

func update_dirt_physics():
	# Update from bottom to top, right to left for consistent physics
	for y in range(Constants.GRID_HEIGHT - 2, 0, -1):
		for x in range(Constants.GRID_WIDTH - 1, 0, -1):
			# Check if the current cell exists and is dirt
			if x < grid.size() and y < grid[x].size() and grid[x][y].type == Constants.CellType.DIRT:
				var cell = grid[x][y]
				
				# Count dirt neighbors for cohesion mechanics
				var dirt_neighbors = 0
				for nx in range(max(0, x-1), min(Constants.GRID_WIDTH, x+2)):
					for ny in range(max(0, y-1), min(Constants.GRID_HEIGHT, y+2)):
						if nx != x or ny != y:  # Skip the cell itself
							if nx < grid.size() and ny < grid[nx].size() and grid[nx][ny].type == Constants.CellType.DIRT:
								dirt_neighbors += 1
				
				# Apply gravity to velocity based on cell mass
				cell.velocity.y += Constants.GRAVITY * 0.01 * cell.mass
				
				# Check if we're on top of stone - dirt doesn't move when on stone
				if y + 1 < grid[x].size() and grid[x][y + 1].type == Constants.CellType.STONE:
					continue
				
				# Determine if this is part of a chunk or an isolated dirt piece
				var is_chunk = dirt_neighbors >= 3  # Consider 3+ neighbors as part of a chunk
				
				# Check if space below is EMPTY
				if y + 1 < grid[x].size() and grid[x][y + 1].type == Constants.CellType.EMPTY:
					if is_chunk:
						# Chunk behavior: always fall straight down like sand
						grid[x][y + 1] = cell
						grid[x][y] = create_empty_cell()
						continue
					else:
						# Isolated dirt: limited falling with cohesion
						var cohesion_factor = min(0.7, dirt_neighbors * 0.15)
						if randf() > cohesion_factor:
							grid[x][y + 1] = cell
							grid[x][y] = create_empty_cell()
							continue
				
				# Check if space below is water - dirt sinks in water
				if y + 1 < grid[x].size() and grid[x][y + 1].type == Constants.CellType.WATER:
					var water_cell = grid[x][y + 1]
					grid[x][y] = water_cell  # Replace dirt with water
					grid[x][y + 1] = cell  # Dirt sinks
					continue
				
				# Diagonal movement depends on chunk status
				if is_chunk:
					# Chunk behavior: act like sand for diagonals
					# Check if bottom right is empty
					if x + 1 < grid.size() and y + 1 < grid[x + 1].size() and grid[x + 1][y + 1].type == Constants.CellType.EMPTY:
						grid[x + 1][y + 1] = cell
						grid[x][y] = create_empty_cell()
						continue
					
					# Check if bottom left is empty
					if x - 1 >= 0 and x - 1 < grid.size() and y + 1 < grid[x - 1].size() and grid[x - 1][y + 1].type == Constants.CellType.EMPTY:
						grid[x - 1][y + 1] = cell
						grid[x][y] = create_empty_cell()
						continue
					
					# For chunks: add some random spread like sand but with lower probability
					elif randf() > 0.8:  # 20% chance (vs 30% for sand) to maintain more structure
						# Try random diagonal movement if there's dirt nearby
						if x + 1 < grid.size() and y < grid[x + 1].size() and grid[x + 1][y].type == Constants.CellType.DIRT:
							if x + 2 < grid.size() and y + 1 < grid[x + 2].size() and grid[x + 2][y + 1].type == Constants.CellType.EMPTY:
								grid[x + 2][y + 1] = cell
								grid[x][y] = create_empty_cell()
								continue
						
						# Check left as well
						if x - 1 >= 0 and x - 1 < grid.size() and y < grid[x - 1].size() and grid[x - 1][y].type == Constants.CellType.DIRT:
							if x - 2 >= 0 and x - 2 < grid.size() and y + 1 < grid[x - 2].size() and grid[x - 2][y + 1].type == Constants.CellType.EMPTY:
								grid[x - 2][y + 1] = cell
								grid[x][y] = create_empty_cell()
								continue
				else:
					# Isolated dirt: very limited diagonal movement
					var diagonal_probability = 0.85  # Only 15% chance to move diagonally
					diagonal_probability += dirt_neighbors * 0.03  # Even less likely with neighbors
					
					if randf() > diagonal_probability and x + 1 < grid.size() and y + 1 < grid[x + 1].size() and grid[x + 1][y + 1].type == Constants.CellType.EMPTY:
						grid[x + 1][y + 1] = cell
						grid[x][y] = create_empty_cell()
						continue
					
					if randf() > diagonal_probability and x - 1 >= 0 and x - 1 < grid.size() and y + 1 < grid[x - 1].size() and grid[x - 1][y + 1].type == Constants.CellType.EMPTY:
						grid[x - 1][y + 1] = cell
						grid[x][y] = create_empty_cell()
						continue
				
				# Apply dampening to velocity
				cell.velocity *= cell.dampening

func update_water_physics():
	# Update from bottom to top, right to left
	for y in range(Constants.GRID_HEIGHT - 2, 0, -1):
		for x in range(Constants.GRID_WIDTH - 1, 0, -1):
			# First check if the current cell exists and is water
			if x < grid.size() and y < grid[x].size() and grid[x][y].type == Constants.CellType.WATER:
				var cell = grid[x][y]
				
				# Apply gravity to velocity based on cell mass (water is affected less by gravity)
				cell.velocity.y += Constants.GRAVITY * 0.005 * cell.mass
				
				# Check if space below is empty and within bounds
				if y + 1 < grid[x].size() and grid[x][y + 1].type == Constants.CellType.EMPTY:
					grid[x][y + 1] = cell
					grid[x][y] = create_empty_cell()
				
				# Check if diagonal down-right is empty, using mass to affect probability
				elif x + 1 < grid.size() and y + 1 < grid[x + 1].size() and randf() > (0.1 + cell.mass * 0.05) and grid[x + 1][y + 1].type == Constants.CellType.EMPTY:
					grid[x + 1][y + 1] = cell
					grid[x][y] = create_empty_cell()
				
				# Check if diagonal down-left is empty, using mass to affect probability
				elif x - 1 >= 0 and x - 1 < grid.size() and y + 1 < grid[x - 1].size() and randf() > (0.1 + cell.mass * 0.05) and grid[x - 1][y + 1].type == Constants.CellType.EMPTY:
					grid[x - 1][y + 1] = cell
					grid[x][y] = create_empty_cell()
				
				# Check horizontal water flow right if there's water behind
				elif x + 1 < grid.size() and randf() > (0.4 + cell.mass * 0.1) and grid[x + 1][y].type == Constants.CellType.EMPTY and \
					 x - 1 >= 0 and x - 1 < grid.size() and grid[x - 1][y].type == Constants.CellType.WATER and \
					 x - 2 >= 0 and x - 2 < grid.size() and grid[x - 2][y].type == Constants.CellType.WATER:
					grid[x + 1][y] = cell
					grid[x][y] = create_empty_cell()
				
				# Check horizontal water flow left if there's water behind
				elif x - 1 >= 0 and x - 1 < grid.size() and randf() > (0.4 + cell.mass * 0.1) and grid[x - 1][y].type == Constants.CellType.EMPTY and \
					 x + 1 < grid.size() and grid[x + 1][y].type == Constants.CellType.WATER and \
					 x + 2 < grid.size() and grid[x + 2][y].type == Constants.CellType.WATER:
					grid[x - 1][y] = cell
					grid[x][y] = create_empty_cell()
				
				# Apply dampening to velocity (water has high dampening)
				cell.velocity *= cell.dampening

func set_cell(x, y, type):
	if x >= 0 and x < Constants.GRID_WIDTH and y >= 0 and y < Constants.GRID_HEIGHT and x < grid.size() and y < grid[x].size():
		# CRITICAL: Prevent any modification of stone cells except by explicit level loading
		if grid[x][y].type == Constants.CellType.STONE and type != Constants.CellType.STONE:
			# Never allow stone to be converted to any other type
			return
		
		# Even more protection - never allow creation of stone cells except during level loading
		if type == Constants.CellType.STONE and grid[x][y].type != Constants.CellType.STONE:
			return
		
		if grid[x][y].type != type:
			grid[x][y] = create_cell(type)

func get_cell(x, y):
	if x >= 0 and x < Constants.GRID_WIDTH and y >= 0 and y < Constants.GRID_HEIGHT and x < grid.size() and y < grid[x].size():
		return grid[x][y].type
	return Constants.CellType.EMPTY

func get_cell_properties(x, y):
	if x >= 0 and x < Constants.GRID_WIDTH and y >= 0 and y < Constants.GRID_HEIGHT and x < grid.size() and y < grid[x].size():
		return grid[x][y]
	return null

func get_hole_position():
	return hole_position

func _draw():
	# Draw the grid cells
	for x in range(Constants.GRID_WIDTH):
		for y in range(Constants.GRID_HEIGHT):
			if x < grid.size() and y < grid[x].size():  # Add bounds check
				var cell = grid[x][y]
				var rect = Rect2(x * Constants.GRID_SIZE, y * Constants.GRID_SIZE, Constants.GRID_SIZE, Constants.GRID_SIZE)
				
				match cell.type:
					Constants.CellType.EMPTY:
						# Sky color
						draw_rect(rect, Constants.CELL_DEFAULTS[Constants.CellType.EMPTY].base_color, true)
					
					Constants.CellType.SAND:
						# Apply color variation
						var sand_color = Constants.SAND_COLOR
						sand_color.r += cell.color_variation.x
						sand_color.g += cell.color_variation.y
						draw_rect(rect, sand_color, true)
					
					Constants.CellType.HOLE:
						# Draw hole with a thicker border to make it more visible
						draw_rect(rect, Constants.HOLE_COLOR, true)
					
					Constants.CellType.WATER:
						# Draw water with color variation
						var water_color = Constants.WATER_COLOR
						water_color.b += cell.color_variation.x
						water_color.g += cell.color_variation.y
						draw_rect(rect, water_color, true)
					
					Constants.CellType.STONE:
						# Draw stone with color variation and texture
						var stone_color = Constants.STONE_COLOR
						stone_color.r += cell.color_variation.x
						stone_color.g += cell.color_variation.y
						stone_color.b += (cell.color_variation.x + cell.color_variation.y) / 2
						draw_rect(rect, stone_color, true)
							
					Constants.CellType.DIRT:
						# Draw dirt with organic variations
						var dirt_color = Constants.DIRT_COLOR
						dirt_color.r += cell.color_variation.x
						dirt_color.g += cell.color_variation.y
						draw_rect(rect, dirt_color, true)
						
					# Ball is drawn by the Ball node
