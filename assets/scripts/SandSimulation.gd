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
	timer.wait_time = 0.04  # 20 updates per second
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
		
		# Check if the level_data is a dictionary with 'grid' key or just a grid directly
		if level_data is Dictionary and level_data.has("grid"):
			grid = convert_grid_to_cells(level_data.grid)
			
			# If there are cell properties, apply them to the grid
			if level_data.has("cell_properties"):
				apply_cell_properties(level_data.cell_properties)
		else:
			grid = convert_grid_to_cells(level_data)
			
		hole_position = level_data.hole_position if level_data is Dictionary and level_data.has("hole_position") else hole_position
		print("Loaded level from: ", current_level_path)
	else:
		# Use the LevelInit to create our grid procedurally
		var generated_data = LevelInit.create_varied_properties_level(hole_position)
		
		# Check if the result is a dictionary with grid key or just a grid
		if generated_data is Dictionary and generated_data.has("grid"):
			grid = convert_grid_to_cells(generated_data.grid)
			
			# If there are cell properties, apply them to the grid
			if generated_data.has("cell_properties"):
				apply_cell_properties(generated_data.cell_properties)
		else:
			grid = convert_grid_to_cells(generated_data)
			
		print("Generated procedural level")
	
	# Ensure the grid has the correct dimensions
	ensure_grid_dimensions()
	
	# Notify listeners about the grid
	emit_signal("grid_updated", grid)
	
# Apply cell properties from a properties dictionary to the grid cells
func apply_cell_properties(cell_properties):
	for cell_key in cell_properties.keys():
		var coords = cell_key.split(",")
		if coords.size() == 2:
			var x = coords[0].to_int()
			var y = coords[1].to_int()
			
			if x >= 0 and x < grid.size() and y >= 0 and y < grid[x].size():
				# Apply each property to the cell
				var props = cell_properties[cell_key]
				for prop in props:
					grid[x][y][prop] = props[prop]

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
	# Track affected cells to avoid redundant processing
	var processed_cells = {}
	
	# Single loop implementation to avoid the repeated code in the original
	for x in range(int(position.x - radius), int(position.x + radius + 1)):
		for y in range(int(position.y - radius), int(position.y + radius + 1)):
			# Skip out-of-bound cells or already processed cells
			if x < 0 or x >= Constants.GRID_WIDTH or y < 0 or y >= Constants.GRID_HEIGHT or x >= grid.size() or y >= grid[x].size():
				continue
				
			var cell_key = str(x) + "," + str(y)
			if processed_cells.has(cell_key):
				continue
				
			# Check if cell is within the impact radius
			var distance = Vector2(x, y).distance_to(position)
			if distance > radius:
				continue
				
			# Mark as processed
			processed_cells[cell_key] = true
			
			# Calculate impact properties
			var cell_type = grid[x][y].type
			var impact_force = radius * (1.0 - distance / radius)
			var impact_dir = Vector2(x, y) - position
			if impact_dir.length() > 0:
				impact_dir = impact_dir.normalized()
			else:
				impact_dir = Vector2(0, -1)  # Default upward if at exact center
			
			# Handle different materials
			match cell_type:
				Constants.CellType.STONE:
					# Stone is completely indestructible
					continue
					
				Constants.CellType.DIRT:
					# DIRT - Tunneling material that only responds to impacts
					# Only move dirt with significant force
					if impact_force > 2.0 and randf() > max(0.3, 0.7 - impact_force * 0.1):
						var dirt_properties = grid[x][y].duplicate()
						
						# Apply velocity based on impact
						dirt_properties.velocity = impact_dir * impact_force * 0.75
						
						# Only remove dirt with higher force
						if impact_force > 3.0:
							grid[x][y] = create_empty_cell()
							
							# Calculate new position based on impact direction
							var strength_factor = min(3.0, impact_force * 0.5)
							var new_x = int(x + impact_dir.x * strength_factor)
							var new_y = int(y + impact_dir.y * strength_factor)
							
							# Try to place the dirt in the impact direction
							if new_x >= 0 and new_x < Constants.GRID_WIDTH and new_y >= 0 and new_y < Constants.GRID_HEIGHT and new_x < grid.size() and new_y < grid[new_x].size():
								if grid[new_x][new_y].type == Constants.CellType.EMPTY:
									grid[new_x][new_y] = dirt_properties
						else:
							# Just apply velocity without moving the dirt
							grid[x][y].velocity = impact_dir * impact_force * 0.5
							
				Constants.CellType.SAND:
					# Sand is easily disturbed with varied particle effects
					var sand_properties = grid[x][y].duplicate()
					grid[x][y] = create_empty_cell()
					
					# Higher chance of creating flying sand particles for more dramatic effect
					if randf() > 0.3:
						# Calculate particle direction with some randomness
						var particle_dir = impact_dir.rotated(randf_range(-0.5, 0.5))
						var blast_force = impact_force * (1.0 + randf_range(-0.2, 0.3))
						
						# Add some upward bias for nicer visual effect
						particle_dir.y -= randf_range(0.3, 0.8)
						particle_dir = particle_dir.normalized()
						
						# Calculate new position
						var new_x = int(x + particle_dir.x * blast_force)
						var new_y = int(y + particle_dir.y * blast_force)
						
						# Check bounds and place the sand particle
						if new_x >= 0 and new_x < Constants.GRID_WIDTH and new_y >= 0 and new_y < Constants.GRID_HEIGHT and new_x < grid.size() and new_y < grid[new_x].size():
							if grid[new_x][new_y].type == Constants.CellType.EMPTY:
								grid[new_x][new_y] = sand_properties
								grid[new_x][new_y].velocity = particle_dir * blast_force * sand_properties.mass * 0.5
								
				Constants.CellType.WATER:
					# Water splashes with impact
					if impact_force > 1.5 and randf() > 0.5:
						var water_properties = grid[x][y].duplicate()
						grid[x][y] = create_empty_cell()
						
						# Calculate splash direction with more horizontal spread
						var splash_dir = impact_dir.rotated(randf_range(-1.2, 1.2))
						splash_dir.y *= 0.7  # Less vertical movement for water
						
						# Calculate new position
						var new_x = int(x + splash_dir.x * impact_force * 0.8)
						var new_y = int(y + splash_dir.y * impact_force * 0.8)
						
						# Check bounds and place the water particle
						if new_x >= 0 and new_x < Constants.GRID_WIDTH and new_y >= 0 and new_y < Constants.GRID_HEIGHT and new_x < grid.size() and new_y < grid[new_x].size():
							if grid[new_x][new_y].type == Constants.CellType.EMPTY:
								grid[new_x][new_y] = water_properties
								grid[new_x][new_y].velocity = splash_dir * impact_force * 0.4

func update_sand_physics():
	# Process sand in chunks - divide the grid into sections and process one per frame
	var start_y = (Engine.get_frames_drawn() % 3) * (Constants.GRID_HEIGHT / 3)
	var end_y = start_y + (Constants.GRID_HEIGHT / 3)
	
	# Update from bottom to top, right to left
	for y in range(min(int(end_y), Constants.GRID_HEIGHT - 2), max(int(start_y), 0), -1):
		for x in range(Constants.GRID_WIDTH - 1, 0, -1):
			# Skip cells that don't need processing
			if x >= grid.size() or y >= grid[x].size() or grid[x][y].type != Constants.CellType.SAND:
				continue
				
			var cell = grid[x][y]
			
			# Apply gravity to velocity based on cell mass
			cell.velocity.y += Constants.GRAVITY * 0.01 * cell.mass
			
			# Fast path for most common case - falling straight down
			if y + 1 < grid[x].size():
				var below_type = grid[x][y + 1].type
				
				# Check if space below is empty - SAND FALLS QUICKLY
				if below_type == Constants.CellType.EMPTY:
					# Sand always falls straight down through empty space
					grid[x][y + 1] = cell
					grid[x][y] = create_empty_cell()
					continue
				
				# Check if space below is water - sand sinks in water
				elif below_type == Constants.CellType.WATER:
					var water_cell = grid[x][y + 1]
					grid[x][y] = water_cell  # Replace sand with water
					grid[x][y + 1] = cell    # Sand sinks
					continue
				
				# If blocked below, try diagonal paths - check both at once for efficiency
				var can_move_right = x + 1 < grid.size() and y + 1 < grid[x + 1].size() and grid[x + 1][y + 1].type == Constants.CellType.EMPTY
				var can_move_left = x - 1 >= 0 and x - 1 < grid.size() and y + 1 < grid[x - 1].size() and grid[x - 1][y + 1].type == Constants.CellType.EMPTY
				
				if can_move_right and can_move_left:
					# If both diagonals are available, randomly choose one with bias based on neighbors
					if randf() > 0.5:
						grid[x + 1][y + 1] = cell
						grid[x][y] = create_empty_cell()
					else:
						grid[x - 1][y + 1] = cell
						grid[x][y] = create_empty_cell()
					continue
				elif can_move_right:
					grid[x + 1][y + 1] = cell
					grid[x][y] = create_empty_cell()
					continue
				elif can_move_left:
					grid[x - 1][y + 1] = cell
					grid[x][y] = create_empty_cell()
					continue
				
				# Additional random spread for natural sand flow - only do for a small percentage
				elif randf() > 0.9:  # Reduced from 0.7 to 0.9 (only 10% chance now)
					# Only check extended diagonals if we have sand neighbors
					var has_right_neighbor = x + 1 < grid.size() and y < grid[x + 1].size() and grid[x + 1][y].type == Constants.CellType.SAND
					var has_left_neighbor = x - 1 >= 0 and x - 1 < grid.size() and y < grid[x - 1].size() and grid[x - 1][y].type == Constants.CellType.SAND
					
					if has_right_neighbor and x + 2 < grid.size() and y + 1 < grid[x + 2].size() and grid[x + 2][y + 1].type == Constants.CellType.EMPTY:
						grid[x + 2][y + 1] = cell
						grid[x][y] = create_empty_cell()
						continue
					
					if has_left_neighbor and x - 2 >= 0 and x - 2 < grid.size() and y + 1 < grid[x - 2].size() and grid[x - 2][y + 1].type == Constants.CellType.EMPTY:
						grid[x - 2][y + 1] = cell
						grid[x][y] = create_empty_cell()
						continue
			
			# Apply dampening to velocity
			cell.velocity *= cell.dampening

func update_dirt_physics():
	# For dirt, we'll only update cells that have been recently impacted
	# This allows dirt to form stable tunnels and structures
	
	for y in range(Constants.GRID_HEIGHT - 2, 0, -1):
		for x in range(Constants.GRID_WIDTH - 1, 0, -1):
			# Skip cells that don't need processing
			if x >= grid.size() or y >= grid[x].size() or grid[x][y].type != Constants.CellType.DIRT:
				continue
			
			var cell = grid[x][y]
			
			# If this dirt cell has velocity, it's already in motion from an impact
			var cell_in_motion = cell.velocity.length_squared() > 0.01
			
			# If dirt is not in motion, skip all physics (stays suspended in air)
			if not cell_in_motion:
				continue
			
			# For dirt in motion, apply similar physics to sand but with more cohesion
			# Apply gravity to velocity based on cell mass
			cell.velocity.y += Constants.GRAVITY * 0.01 * cell.mass
			
			# Check if space below is empty and we're moving
			if y + 1 < grid[x].size() and grid[x][y + 1].type == Constants.CellType.EMPTY:
				grid[x][y + 1] = cell
				grid[x][y] = create_empty_cell()
				continue
			
			# Check if space below is water - dirt sinks in water
			elif y + 1 < grid[x].size() and grid[x][y + 1].type == Constants.CellType.WATER:
				var water_cell = grid[x][y + 1]
				grid[x][y] = water_cell  # Replace dirt with water
				grid[x][y + 1] = cell  # Dirt sinks
				continue
			
			# Only allow diagonal movement for dirt in motion with reduced probability
			var diagonal_probability = 0.3  # 30% chance to move diagonally when in motion
			
			if randf() > diagonal_probability:
				# Try right diagonal
				if x + 1 < grid.size() and y + 1 < grid[x + 1].size() and grid[x + 1][y + 1].type == Constants.CellType.EMPTY:
					grid[x + 1][y + 1] = cell
					grid[x][y] = create_empty_cell()
					continue
				
				# Try left diagonal
				if x - 1 >= 0 and x - 1 < grid.size() and y + 1 < grid[x - 1].size() and grid[x - 1][y + 1].type == Constants.CellType.EMPTY:
					grid[x - 1][y + 1] = cell
					grid[x][y] = create_empty_cell()
					continue
			
			# Apply dampening to velocity
			cell.velocity *= cell.dampening
			
			# If velocity is very small, stop the motion completely
			if cell.velocity.length_squared() < 0.01:
				cell.velocity = Vector2.ZERO

# Helper function to efficiently count dirt neighbors
func count_dirt_neighbors(x, y):
	var count = 0
	# Use a simpler neighbor check pattern - just check the 4 adjacent cells first
	var adjacent_coords = [
		Vector2(x-1, y), Vector2(x+1, y),  # Left, Right
		Vector2(x, y-1), Vector2(x, y+1)   # Up, Down
	]
	
	for coord in adjacent_coords:
		var nx = int(coord.x)
		var ny = int(coord.y)
		if nx >= 0 and nx < grid.size() and ny >= 0 and ny < grid[nx].size():
			if grid[nx][ny].type == Constants.CellType.DIRT:
				count += 1
				# Early exit option: if we just need to know if there are 3+ neighbors
				if count >= 3:
					return count
	
	# Only check diagonals if we haven't found 3 neighbors yet
	if count < 3:
		var diagonal_coords = [
			Vector2(x-1, y-1), Vector2(x+1, y-1),
			Vector2(x-1, y+1), Vector2(x+1, y+1)
		]
		
		for coord in diagonal_coords:
			var nx = int(coord.x)
			var ny = int(coord.y)
			if nx >= 0 and nx < grid.size() and ny >= 0 and ny < grid[nx].size():
				if grid[nx][ny].type == Constants.CellType.DIRT:
					count += 1
					if count >= 3:
						return count
	
	return count

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
