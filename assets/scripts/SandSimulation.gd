extends Node2D

# Variables
var grid = []  # 2D grid to store cell objects
var hole_position = Vector2(150, 82)  # Default hole position in grid coordinates
var current_level_path = ""  # Path to the current level

# Signal to notify the ball of the current grid state
signal grid_updated(grid)

func _ready():
	# Set up the timer for physics simulation
	var timer = Timer.new()
	timer.wait_time = 0.02  # 20 updates per second
	timer.autostart = true
	timer.timeout.connect(_on_simulation_update)  # Godot 4.x signal syntax
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
		"dampening": 0.0,
		"is_top_dirt": false  # Flag to identify top dirt cells for grass rendering
	}
	
	# Set properties based on type from defaults
	if Constants.CELL_DEFAULTS.has(type):
		var defaults = Constants.CELL_DEFAULTS[type]
		
		# Copy all properties from defaults
		for key in defaults:
			cell[key] = defaults[key]
		
		# Add random variations to make each cell unique
		if type != Constants.CellType.EMPTY and type != Constants.CellType.HOLE:
			cell.mass += randf_range(-Constants.MASS_VARIATION_RANGE, Constants.MASS_VARIATION_RANGE)
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
				Constants.CellType.FIRE:
					# Fire uses a float for color variation
					cell.color_variation = variation * 0.3
	
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
	
	# Update grass state for the entire grid
	update_top_dirt_cells()
	
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

func _on_simulation_update():
	# Skip updates if the game is won
	var parent = get_parent()
	if parent and parent.has_method("get") and parent.get("game_won"):
		return
		
	# Update all materials based on their material type
	update_physics()
	
	# Update which dirt cells are top cells (for grass)
	update_top_dirt_cells()
	
	emit_signal("grid_updated", grid)
	queue_redraw()  # Trigger redraw (Godot 4.x)

# Universal physics update function that handles all material types
func update_physics():
	# Process cells from bottom to top, right to left
	for y in range(Constants.GRID_HEIGHT - 2, 0, -1):
		for x in range(Constants.GRID_WIDTH - 1, 0, -1):
			# Skip out-of-bounds cells
			if x >= grid.size() or y >= grid[x].size():
				continue
				
			var cell = grid[x][y]
			var cell_type = cell.type
			
			# Skip empty cells and special types
			if cell_type == Constants.CellType.EMPTY or cell_type == Constants.CellType.HOLE or cell_type == Constants.CellType.BALL:
				continue
				
			# Get material type
			var material_type = Constants.MaterialType.NONE
			if cell.has("material_type"):
				material_type = cell.material_type
			elif Constants.MATERIAL_CATEGORIES.has(cell_type):
				material_type = Constants.MATERIAL_CATEGORIES[cell_type]
			
			# Process based on material type
			match material_type:
				Constants.MaterialType.LIQUID:
					update_liquid_cell(x, y, cell)
				Constants.MaterialType.GRANULAR:
					update_granular_cell(x, y, cell)
				Constants.MaterialType.SOLID:
					# Solids don't move on their own
					pass

# Update a liquid cell (water, lava, fire, etc.)
func update_liquid_cell(x, y, cell):
	# Special handling for fire cells
	if cell.type == Constants.CellType.FIRE:
		update_fire_cell(x, y, cell)
		return
	
	# Apply gravity to velocity based on cell mass and density
	cell.velocity.y += Constants.GRAVITY * 0.005 * cell.mass * cell.density
	
	# Check if space below is empty and within bounds
	if y + 1 < grid[x].size() and grid[x][y + 1].type == Constants.CellType.EMPTY:
		grid[x][y + 1] = cell
		grid[x][y] = create_empty_cell()
		return
	
	# Check if diagonal down-right is empty, using flow_rate to affect probability
	if x + 1 < grid.size() and y + 1 < grid[x + 1].size() and randf() > (0.1 + (1.0 - cell.flow_rate) * 0.2) and grid[x + 1][y + 1].type == Constants.CellType.EMPTY:
		grid[x + 1][y + 1] = cell
		grid[x][y] = create_empty_cell()
		return
	
	# Check if diagonal down-left is empty, using flow_rate to affect probability
	if x - 1 >= 0 and x - 1 < grid.size() and y + 1 < grid[x - 1].size() and randf() > (0.1 + (1.0 - cell.flow_rate) * 0.2) and grid[x - 1][y + 1].type == Constants.CellType.EMPTY:
		grid[x - 1][y + 1] = cell
		grid[x][y] = create_empty_cell()
		return
	
	# Horizontal flow based on flow_rate
	var horizontal_flow_chance = cell.flow_rate * 0.8
	
	# Check horizontal flow right if there's liquid behind
	if x + 1 < grid.size() and randf() > (1.0 - horizontal_flow_chance) and grid[x + 1][y].type == Constants.CellType.EMPTY and \
		 x - 1 >= 0 and x - 1 < grid.size() and is_liquid(grid[x - 1][y]) and \
		 x - 2 >= 0 and x - 2 < grid.size() and is_liquid(grid[x - 2][y]):
		grid[x + 1][y] = cell
		grid[x][y] = create_empty_cell()
		return
	
	# Check horizontal flow left if there's liquid behind
	if x - 1 >= 0 and x - 1 < grid.size() and randf() > (1.0 - horizontal_flow_chance) and grid[x - 1][y].type == Constants.CellType.EMPTY and \
		 x + 1 < grid.size() and is_liquid(grid[x + 1][y]) and \
		 x + 2 < grid.size() and is_liquid(grid[x + 2][y]):
		grid[x - 1][y] = cell
		grid[x][y] = create_empty_cell()
		return
	
	# Apply dampening to velocity based on viscosity
	cell.velocity *= (cell.dampening * (1.0 - cell.viscosity * 0.5))

# Update a fire cell - special behavior for fire
func update_fire_cell(x, y, cell):
	# Decrease lifetime
	if not cell.has("lifetime"):
		cell.lifetime = 2.0
	
	cell.lifetime -= 0.05
	
	# If lifetime is up, remove the fire
	if cell.lifetime <= 0:
		grid[x][y] = create_empty_cell()
		return
	
	# Update color based on lifetime (gets more red/yellow as it burns out)
	var life_ratio = cell.lifetime / 2.0  # Assuming 2.0 is the max lifetime
	var base_color = Constants.FIRE_COLOR
	
	# Shift color from orange to red as it burns out
	cell.base_color = Color(
		base_color.r,
		base_color.g * life_ratio,
		base_color.b * (life_ratio * 0.5),
		base_color.a * life_ratio
	)
	
	# Fire rises upward
	if y > 0 and grid[x][y-1].type == Constants.CellType.EMPTY and randf() < 0.7:
		grid[x][y-1] = cell
		grid[x][y] = create_empty_cell()
		return
	
	# Fire can also spread diagonally upward
	if randf() < 0.3:
		var spread_dir = 1 if randf() < 0.5 else -1
		if x + spread_dir >= 0 and x + spread_dir < grid.size() and y > 0 and grid[x + spread_dir][y-1].type == Constants.CellType.EMPTY:
			grid[x + spread_dir][y-1] = cell
			grid[x][y] = create_empty_cell()
			return
	
	# Fire can spread horizontally
	if randf() < 0.2:
		var spread_dir = 1 if randf() < 0.5 else -1
		if x + spread_dir >= 0 and x + spread_dir < grid.size() and grid[x + spread_dir][y].type == Constants.CellType.EMPTY:
			grid[x + spread_dir][y] = cell
			grid[x][y] = create_empty_cell()
			return
	
	# Random chance to create a new fire cell nearby (spreading the fire)
	if randf() < cell.spread_chance * life_ratio:
		var spread_x = x + (randi() % 3 - 1)  # -1, 0, or 1
		var spread_y = y + (randi() % 2 - 1)  # -1, 0
		
		if spread_x >= 0 and spread_x < grid.size() and spread_y >= 0 and spread_y < grid[spread_x].size():
			if grid[spread_x][spread_y].type == Constants.CellType.EMPTY:
				var new_fire = create_cell(Constants.CellType.FIRE)
				new_fire.lifetime = cell.lifetime * 0.8  # Shorter lifetime for spread fire
				grid[spread_x][spread_y] = new_fire

# Update a granular cell (sand, dirt, etc.)
func update_granular_cell(x, y, cell):
	# Check if this is a stable material that only moves when disturbed
	var is_stable_material = cell.type == Constants.CellType.DIRT
	var cell_in_motion = cell.velocity.length_squared() > 0.01
	
	# If it's a stable material and not in motion, skip physics
	if is_stable_material and not cell_in_motion:
		return
	
	# Apply gravity to velocity based on cell mass and density
	var gravity_factor = 0.01
	if cell.has("flow_rate"):
		gravity_factor *= cell.flow_rate * 2.0  # Faster falling for higher flow rate
	
	cell.velocity.y += Constants.GRAVITY * gravity_factor * cell.mass * cell.density
	
	# Fast path for most common case - falling straight down
	if y + 1 < grid[x].size():
		var below_type = grid[x][y + 1].type
		
		# Check if space below is empty
		if below_type == Constants.CellType.EMPTY:
			grid[x][y + 1] = cell
			grid[x][y] = create_empty_cell()
			return
		
		# Check if space below is liquid - granular materials sink in liquids
		elif is_liquid(grid[x][y + 1]):
			var liquid_cell = grid[x][y + 1]
			grid[x][y] = liquid_cell  # Replace granular with liquid
			grid[x][y + 1] = cell     # Granular sinks
			return
		
		# If blocked below, try diagonal paths based on flow_rate
		var diagonal_chance = 0.5
		if cell.has("flow_rate"):
			diagonal_chance = cell.flow_rate
		
		# Check both diagonals at once for efficiency
		var can_move_right = x + 1 < grid.size() and y + 1 < grid[x + 1].size() and grid[x + 1][y + 1].type == Constants.CellType.EMPTY
		var can_move_left = x - 1 >= 0 and x - 1 < grid.size() and y + 1 < grid[x - 1].size() and grid[x - 1][y + 1].type == Constants.CellType.EMPTY
		
		if can_move_right and can_move_left:
			# If both diagonals are available, randomly choose one
			if randf() > 0.5:
				grid[x + 1][y + 1] = cell
				grid[x][y] = create_empty_cell()
			else:
				grid[x - 1][y + 1] = cell
				grid[x][y] = create_empty_cell()
			return
		elif can_move_right and randf() < diagonal_chance:
			grid[x + 1][y + 1] = cell
			grid[x][y] = create_empty_cell()
			return
		elif can_move_left and randf() < diagonal_chance:
			grid[x - 1][y + 1] = cell
			grid[x][y] = create_empty_cell()
			return
		
		# Additional random spread for natural flow - only do for a small percentage
		# Higher flow_rate increases chance of extended movement
		var extended_flow_chance = 0.1
		if cell.has("flow_rate"):
			extended_flow_chance = 0.1 * cell.flow_rate
		
		if randf() > (1.0 - extended_flow_chance):
			# Only check extended diagonals if we have neighbors of same type
			var has_right_neighbor = x + 1 < grid.size() and y < grid[x + 1].size() and grid[x + 1][y].type == cell.type
			var has_left_neighbor = x - 1 >= 0 and x - 1 < grid.size() and y < grid[x - 1].size() and grid[x - 1][y].type == cell.type
			
			if has_right_neighbor and x + 2 < grid.size() and y + 1 < grid[x + 2].size() and grid[x + 2][y + 1].type == Constants.CellType.EMPTY:
				grid[x + 2][y + 1] = cell
				grid[x][y] = create_empty_cell()
				return
			
			if has_left_neighbor and x - 2 >= 0 and x - 2 < grid.size() and y + 1 < grid[x - 2].size() and grid[x - 2][y + 1].type == Constants.CellType.EMPTY:
				grid[x - 2][y + 1] = cell
				grid[x][y] = create_empty_cell()
				return
	
	# Apply dampening to velocity
	cell.velocity *= cell.dampening
	
	# If velocity is very small, stop the motion completely
	if cell.velocity.length_squared() < 0.01:
		cell.velocity = Vector2.ZERO

# Helper function to check if a cell is a liquid
func is_liquid(cell):
	if cell.has("material_type"):
		return cell.material_type == Constants.MaterialType.LIQUID
	elif Constants.MATERIAL_CATEGORIES.has(cell.type):
		return Constants.MATERIAL_CATEGORIES[cell.type] == Constants.MaterialType.LIQUID
	return false

# Find the top 1-3 cells of dirt for grass rendering (only on exposed dirt)
func update_top_dirt_cells():
	# Reset all dirt cells
	for x in range(Constants.GRID_WIDTH):
		for y in range(Constants.GRID_HEIGHT):
			if x < grid.size() and y < grid[x].size() and grid[x][y].type == Constants.CellType.DIRT:
				grid[x][y].is_top_dirt = false
	
	# Find the top exposed dirt cells in each column
	for x in range(Constants.GRID_WIDTH):
		# Use the column position for consistent randomization
		var column_seed = x * 1731 + 947
		var rand_state = RandomNumberGenerator.new()
		rand_state.seed = column_seed
		
		# Randomly decide how many top dirt cells should be grass (1-3)
		var max_grass_cells = rand_state.randi_range(1, 3)
		
		var found_exposed_dirt = false
		var grass_cell_count = 0
		
		# Scan from top to bottom
		for y in range(Constants.GRID_HEIGHT):
			if x < grid.size() and y < grid[x].size():
				# Current cell is dirt
				if grid[x][y].type == Constants.CellType.DIRT:
					# First dirt cell we've found in this column
					if not found_exposed_dirt:
						# Check if it's exposed to air (cell above is empty)
						var is_exposed = false
						if y > 0 and grid[x][y-1].type == Constants.CellType.EMPTY:
							is_exposed = true
						
						# Only start adding grass if this dirt is exposed
						if is_exposed:
							found_exposed_dirt = true
							grid[x][y].is_top_dirt = true
							grass_cell_count = 1
					# Subsequent dirt cells after the first exposed one
					elif found_exposed_dirt and grass_cell_count < max_grass_cells:
						grid[x][y].is_top_dirt = true
						grass_cell_count += 1
				# If we hit any non-dirt cell after finding exposed dirt, we're done with this column
				elif found_exposed_dirt:
					break

func create_impact_crater(position, radius):
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
			
			# Get the cell and its properties
			var cell = grid[x][y]
			var cell_type = cell.type
			
			# Calculate impact properties
			var impact_force = radius * (1.0 - distance / radius)
			var impact_dir = Vector2(x, y) - position
			if impact_dir.length() > 0:
				impact_dir = impact_dir.normalized()
			else:
				impact_dir = Vector2(0, -1)  # Default upward if at exact center
			
			# Store the grass state before processing
			var is_grass = false
			if cell_type == Constants.CellType.DIRT:
				is_grass = cell.is_top_dirt
			
			# Get material type
			var material_type = Constants.MaterialType.NONE
			if cell.has("material_type"):
				material_type = cell.material_type
			elif Constants.MATERIAL_CATEGORIES.has(cell_type):
				material_type = Constants.MATERIAL_CATEGORIES[cell_type]
			
			# Skip processing for NONE material type
			if material_type == Constants.MaterialType.NONE:
				continue
			
			# Get material strength and displacement properties
			var strength = 0.5  # Default strength
			var displacement = 0.5  # Default displacement
			
			if cell.has("strength"):
				strength = cell.strength
			
			if cell.has("displacement"):
				displacement = cell.displacement
			
			# Calculate resistance threshold based on material strength
			var resistance_threshold = 1.5 + (strength * 3.0)
			
			# Calculate displacement factor based on material displacement property
			var displacement_factor = 0.5 + (displacement * 3.0)
			
			# Process based on material type
			match material_type:
				Constants.MaterialType.SOLID:
					# Solids are very resistant to impacts
					if strength < 0.8:  # Only non-stone solids can be affected
						if impact_force > resistance_threshold * 1.5:
							# Even strong impacts only apply velocity to solid materials
							grid[x][y].velocity = impact_dir * impact_force * 0.3
					
				Constants.MaterialType.GRANULAR:
					# Granular materials (sand, dirt) can be moved by impacts
					if impact_force > resistance_threshold and randf() > max(0.2, 0.6 - impact_force * 0.15):
						var cell_properties = cell.duplicate()
						
						# Apply velocity based on impact and material properties
						var velocity_factor = 0.8 - (strength * 0.3)
						cell_properties.velocity = impact_dir * impact_force * velocity_factor
						
						# Only remove material with higher force
						if impact_force > resistance_threshold * 1.3:
							grid[x][y] = create_empty_cell()
							
							# Calculate new position based on impact direction and displacement
							var strength_factor = min(4.0, impact_force * displacement_factor)
							var new_x = int(x + impact_dir.x * strength_factor)
							var new_y = int(y + impact_dir.y * strength_factor)
							
							# Try to place the material in the impact direction
							if new_x >= 0 and new_x < Constants.GRID_WIDTH and new_y >= 0 and new_y < Constants.GRID_HEIGHT and new_x < grid.size() and new_y < grid[new_x].size():
								if grid[new_x][new_y].type == Constants.CellType.EMPTY:
									grid[new_x][new_y] = cell_properties
									# Preserve grass state if it was dirt and had grass
									if is_grass and cell_type == Constants.CellType.DIRT:
										grid[new_x][new_y].is_top_dirt = true
						else:
							# Just apply velocity without moving the material
							grid[x][y].velocity = impact_dir * impact_force * velocity_factor
							# Preserve grass state
							if is_grass and cell_type == Constants.CellType.DIRT:
								grid[x][y].is_top_dirt = true
				
				Constants.MaterialType.LIQUID:
					# Liquids are easily displaced by impacts
					if impact_force > resistance_threshold * 0.5:
						var cell_properties = cell.duplicate()
						
						# Apply velocity based on impact (liquids move more)
						cell_properties.velocity = impact_dir * impact_force * 1.2
						
						# Always remove liquid with sufficient force
						if impact_force > resistance_threshold * 0.8:
							grid[x][y] = create_empty_cell()
							
							# Calculate new position based on impact direction
							var strength_factor = min(5.0, impact_force * displacement_factor * 1.5)
							var new_x = int(x + impact_dir.x * strength_factor)
							var new_y = int(y + impact_dir.y * strength_factor)
							
							# Try to place the liquid in the impact direction
							if new_x >= 0 and new_x < Constants.GRID_WIDTH and new_y >= 0 and new_y < Constants.GRID_HEIGHT and new_x < grid.size() and new_y < grid[new_x].size():
								if grid[new_x][new_y].type == Constants.CellType.EMPTY:
									grid[new_x][new_y] = cell_properties
						else:
							# Just apply velocity without moving the liquid
							grid[x][y].velocity = impact_dir * impact_force * 1.0

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

func set_cell(x, y, type):
	if x >= 0 and x < Constants.GRID_WIDTH and y >= 0 and y < Constants.GRID_HEIGHT and x < grid.size() and y < grid[x].size():
		# CRITICAL: Prevent any modification of stone cells except by explicit level loading
		if grid[x][y].type == Constants.CellType.STONE and type != Constants.CellType.STONE:
			# Never allow stone to be converted to any other type
			return
		
		# Even more protection - never allow creation of stone cells except during level loading
		if type == Constants.CellType.STONE and grid[x][y].type != Constants.CellType.STONE:
			return
		
		# NEW: Preserve grass state when changing cells
		var is_grass = false
		if grid[x][y].type == Constants.CellType.DIRT:
			is_grass = grid[x][y].is_top_dirt
		
		if grid[x][y].type != type:
			# Create new cell of the specified type
			grid[x][y] = create_cell(type)
			
			# If we're converting to dirt and the cell was previously grass,
			# preserve the grass appearance
			if type == Constants.CellType.DIRT and is_grass:
				grid[x][y].is_top_dirt = true

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
				var rect = Rect2(
					Vector2(x * Constants.GRID_SIZE, y * Constants.GRID_SIZE),
					Vector2(Constants.GRID_SIZE, Constants.GRID_SIZE)
				)
				
				# Get the base color from cell properties or defaults
				var base_color = Color(0.5, 0.5, 0.5)  # Default gray if no color defined
				
				if cell.has("base_color"):
					base_color = cell.base_color
				elif Constants.CELL_DEFAULTS.has(cell.type) and Constants.CELL_DEFAULTS[cell.type].has("base_color"):
					base_color = Constants.CELL_DEFAULTS[cell.type].base_color
				
				# Apply color variations based on material type
				if cell.type != Constants.CellType.EMPTY and cell.type != Constants.CellType.HOLE and cell.type != Constants.CellType.BALL:
					# Get material type
					var material_type = Constants.MaterialType.NONE
					if cell.has("material_type"):
						material_type = cell.material_type
					elif Constants.MATERIAL_CATEGORIES.has(cell.type):
						material_type = Constants.MATERIAL_CATEGORIES[cell.type]
					
					# Apply color variation based on material type
					if cell.color_variation is Vector2:
						# Use Vector2 color variation
						match material_type:
							Constants.MaterialType.LIQUID:
								# Liquids get more blue/green variation
								base_color.b += cell.color_variation.x
								base_color.g += cell.color_variation.y
							
							Constants.MaterialType.GRANULAR:
								# Granular materials get more red/yellow variation
								base_color.r += cell.color_variation.x
								base_color.g += cell.color_variation.y
								
								# Special case for dirt with grass
								if cell.type == Constants.CellType.DIRT and cell.is_top_dirt:
									# Make it more green and less red for grass effect
									base_color.r *= 0.7  # Reduce red
									base_color.g *= 1.5  # Increase green
							
							Constants.MaterialType.SOLID:
								# Solids get more uniform gray variation
								base_color.r += cell.color_variation.x
								base_color.g += cell.color_variation.y
								base_color.b += (cell.color_variation.x + cell.color_variation.y) / 2
					elif cell.color_variation is float:
						# Use float color variation (for fire and other special types)
						match material_type:
							Constants.MaterialType.LIQUID:
								# For fire and other special liquids
								base_color.r += cell.color_variation * 0.1
								base_color.g += cell.color_variation * 0.05
								base_color.b += cell.color_variation * 0.02
							_:
								# Default variation for all other types
								var variation = cell.color_variation
								base_color.r += variation
								base_color.g += variation
								base_color.b += variation
				
				# Draw the cell with its final color
				draw_rect(rect, base_color, true)
