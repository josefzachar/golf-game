extends Node

# Static function to initialize a new grid
static func create_grid(hole_position):
	var grid = []
	
	# Create empty grid with basic cell types (not full property objects yet)
	for x in range(Constants.GRID_WIDTH):
		var column = []
		for y in range(Constants.GRID_HEIGHT):
			column.append(Constants.CellType.EMPTY)
		grid.append(column)
	
	# Add sand terrain and determine ground level
	var ground_levels = []  # Store the ground level for each x position
	
	for x in range(Constants.GRID_WIDTH):
		# Create ground level (flat with some variations)
		var ground_height = Constants.GRID_HEIGHT - 40 + randi() % 5
		ground_levels.append(ground_height)  # Store for later use
		
		for y in range(ground_height, Constants.GRID_HEIGHT):
			if x < grid.size() and y < grid[x].size():  # Bounds check
				grid[x][y] = Constants.CellType.SAND
	
	# Create a water pond - replacing sand instead of sitting on top
	var pond_center_x = Constants.GRID_WIDTH / 2
	var pond_center_y = Constants.GRID_HEIGHT - 38  # Position within the sandy area
	var pond_width = 50
	var pond_depth = 20
	
	for x in range(int(pond_center_x - pond_width/2), int(pond_center_x + pond_width/2)):
		if x >= 0 and x < Constants.GRID_WIDTH:
			# Define the pond surface using a sine wave for natural shape
			var surface_height = pond_center_y - 3 * sin((x - pond_center_x) * 0.3)
			
			# Replace sand with water down to a certain depth
			for y in range(int(surface_height), int(surface_height + pond_depth)):
				if y >= 0 and y < Constants.GRID_HEIGHT and x < grid.size() and y < grid[x].size():
					if grid[x][y] == Constants.CellType.SAND:  # Only replace sand
						grid[x][y] = Constants.CellType.WATER
	
	# Make sure hole is not buried in sand
	for x in range(hole_position.x - 2, hole_position.x + 2):
		for y in range(hole_position.y - 2, hole_position.y + 2):
			if x >= 0 and x < Constants.GRID_WIDTH and y >= 0 and y < Constants.GRID_HEIGHT and x < grid.size() and y < grid[x].size():
				if Vector2(x, y).distance_to(hole_position) < 6:
					grid[x][y] = Constants.CellType.EMPTY
	
	# Set the hole itself
	if hole_position.x < grid.size() and hole_position.y < grid[hole_position.x].size():
		grid[hole_position.x][hole_position.y] = Constants.CellType.HOLE
		
		# Add a few more hole cells to make it more visible
		for x in range(hole_position.x - 1, hole_position.x + 2):
			for y in range(hole_position.y - 1, hole_position.y + 2):
				if x >= 0 and x < Constants.GRID_WIDTH and y >= 0 and y < Constants.GRID_HEIGHT and x < grid.size() and y < grid[x].size():
					if Vector2(x, y).distance_to(hole_position) < 1.5:
						grid[x][y] = Constants.CellType.HOLE
	
	# Print debug info about the hole
	print("Hole position: ", hole_position)
	if hole_position.x < grid.size() and hole_position.y < grid[hole_position.x].size():
		print("Cell type at hole position: ", grid[hole_position.x][hole_position.y])
	
	return grid

# Load a map from JSON file with cell properties support
static func load_from_json(file_path):
	print("Loading from JSON with cell properties")
	var grid = []
	var hole_position = Vector2.ZERO
	
	# Initialize empty grid with basic types (SandSimulation will convert to full cell objects)
	for x in range(Constants.GRID_WIDTH):
		var column = []
		for y in range(Constants.GRID_HEIGHT):
			column.append(Constants.CellType.EMPTY)
		grid.append(column)
	
	# Load and parse JSON file
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	var default = {"grid": create_grid(Vector2(0, 10)), "hole_position": Vector2(0, 10), "cell_properties": {}}
	
	if not file:
		print("Error: Could not open file ", file_path)
		return default
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		print("JSON Parse Error: ", json.get_error_message(), " at line ", json.get_error_line())
		return default
	
	var map_data = json.get_data()
	
	# Check if the expected data exists
	if not map_data.has("terrain") or not map_data.has("hole_position"):
		print("Error: JSON file missing required fields (terrain and/or hole_position)")
		return default
	
	# Set hole position
	hole_position = Vector2(map_data.hole_position.x, map_data.hole_position.y)
	
	# Process terrain data
	for cell in map_data.terrain:
		var x = cell.x
		var y = cell.y
		var type = cell.type
		
		if x >= 0 and x < Constants.GRID_WIDTH and y >= 0 and y < Constants.GRID_HEIGHT:
			match type:
				"sand":
					grid[x][y] = Constants.CellType.SAND
				"dirt":
					grid[x][y] = Constants.CellType.DIRT
				"stone":
					grid[x][y] = Constants.CellType.STONE
				"water":
					grid[x][y] = Constants.CellType.WATER
				"hole":
					grid[x][y] = Constants.CellType.HOLE
				"ball_start":
					grid[x][y] = Constants.CellType.BALL_START
				_:
					grid[x][y] = Constants.CellType.EMPTY
	
	# Create storage for individual cell properties if they exist
	var cell_properties = {}
	
	# Process cell properties if they exist
	if map_data.has("terrain"):
		for cell in map_data.terrain:
			if cell.has("properties"):
				var x = cell.x
				var y = cell.y
				
				# Create a key for this cell position
				var cell_key = str(x) + "," + str(y)
				
				# Store properties for this cell
				cell_properties[cell_key] = {
					"mass": cell.properties.get("mass", 1.0),
					"dampening": cell.properties.get("dampening", 1.0),
					"color_r": cell.properties.get("color_r", 0.0),
					"color_g": cell.properties.get("color_g", 0.0)
				}
	
	# Debug output to verify loaded materials
	var material_counts = {
		"sand": 0,
		"dirt": 0, 
		"stone": 0,
		"water": 0,
		"hole": 0,
		"ball_start": 0
	}
	
	# Count cells of each type
	for x in range(Constants.GRID_WIDTH):
		for y in range(Constants.GRID_HEIGHT):
			match grid[x][y]:
				Constants.CellType.SAND:
					material_counts["sand"] += 1
				Constants.CellType.DIRT:
					material_counts["dirt"] += 1
				Constants.CellType.STONE:
					material_counts["stone"] += 1
				Constants.CellType.WATER:
					material_counts["water"] += 1
				Constants.CellType.HOLE:
					material_counts["hole"] += 1
				Constants.CellType.BALL_START:
					material_counts["ball_start"] += 1
	
	# Print material counts for debugging
	print("Loaded materials: ", material_counts)
	
	# Make sure the hole is properly set
	if hole_position.x >= 0 and hole_position.x < Constants.GRID_WIDTH and hole_position.y >= 0 and hole_position.y < Constants.GRID_HEIGHT:
		grid[hole_position.x][hole_position.y] = Constants.CellType.HOLE
		
		# Add a few more hole cells to make it more visible (same as in create_grid)
		for x in range(hole_position.x - 1, hole_position.x + 2):
			for y in range(hole_position.y - 1, hole_position.y + 2):
				if x >= 0 and x < Constants.GRID_WIDTH and y >= 0 and y < Constants.GRID_HEIGHT and x < grid.size() and y < grid[x].size():
					if Vector2(x, y).distance_to(hole_position) < 1.5:
						grid[x][y] = Constants.CellType.HOLE
	
	print("Loaded map from JSON: ", file_path)
	print("Hole position: ", hole_position)
	
	return {"grid": grid, "hole_position": hole_position, "cell_properties": cell_properties}

# Optional: Add more level generation methods
static func create_hills_level(hole_position):
	var grid = []
	
	# Create empty grid
	for x in range(Constants.GRID_WIDTH):
		var column = []
		for y in range(Constants.GRID_HEIGHT):
			column.append(Constants.CellType.EMPTY)
		grid.append(column)
	
	# Generate hilly terrain using perlin noise
	var noise = FastNoiseLite.new()
	noise.seed = randi()
	
	for x in range(Constants.GRID_WIDTH):
		# Use noise to create hills
		var height_offset = int(noise.get_noise_1d(x * 0.1) * 150)
		var ground_height = Constants.GRID_HEIGHT - 35 + height_offset
		
		for y in range(ground_height, Constants.GRID_HEIGHT):
			if x < grid.size() and y < grid[x].size():
				grid[x][y] = Constants.CellType.SAND
	
	# Make sure hole is not buried in sand
	for x in range(hole_position.x - 2, hole_position.x + 2):
		for y in range(hole_position.y - 2, hole_position.y + 2):
			if x >= 0 and x < Constants.GRID_WIDTH and y >= 0 and y < Constants.GRID_HEIGHT and x < grid.size() and y < grid[x].size():
				if Vector2(x, y).distance_to(hole_position) < 6:
					grid[x][y] = Constants.CellType.EMPTY
	
	# Set the hole itself
	if hole_position.x < grid.size() and hole_position.y < grid[hole_position.x].size():
		grid[hole_position.x][hole_position.y] = Constants.CellType.HOLE
		
		# Add a few more hole cells to make it more visible
		for x in range(hole_position.x - 1, hole_position.x + 2):
			for y in range(hole_position.y - 1, hole_position.y + 2):
				if x >= 0 and x < Constants.GRID_WIDTH and y >= 0 and y < Constants.GRID_HEIGHT and x < grid.size() and y < grid[x].size():
					if Vector2(x, y).distance_to(hole_position) < 1.5:
						grid[x][y] = Constants.CellType.HOLE
	
	return grid
	
# Create a level with varying terrain properties
static func create_varied_properties_level(hole_position):
	var grid = []
	var cell_properties = {}
	
	# Create empty grid
	for x in range(Constants.GRID_WIDTH):
		var column = []
		for y in range(Constants.GRID_HEIGHT):
			column.append(Constants.CellType.EMPTY)
		grid.append(column)
		
	# Generate terrain with varying properties using multiple noise functions
	var noise1 = FastNoiseLite.new()  # For terrain height
	noise1.seed = randi()
	
	var noise2 = FastNoiseLite.new()  # For material type
	noise2.seed = randi() + 12345
	
	var noise3 = FastNoiseLite.new()  # For mass variation
	noise3.seed = randi() + 54321
	
	var noise4 = FastNoiseLite.new()  # For dampening variation
	noise4.seed = randi() + 98765
	
	# Create different ground types based on noise
	for x in range(Constants.GRID_WIDTH):
		# Determine base ground height
		var height_offset = int(noise1.get_noise_1d(x * 0.05) * 30)
		var ground_height = Constants.GRID_HEIGHT - 40 + height_offset
		
		# Fill in ground
		for y in range(ground_height, Constants.GRID_HEIGHT):
			if x < grid.size() and y < grid[x].size():
				# Use second noise function to determine material type
				var material_value = noise2.get_noise_2d(x * 0.1, y * 0.1)
				
				# Determine cell type
				var cell_type
				if material_value < -0.3:
					cell_type = Constants.CellType.STONE
				elif material_value < 0.2:
					cell_type = Constants.CellType.DIRT
				else:
					cell_type = Constants.CellType.SAND
				
				grid[x][y] = cell_type
				
				# Create varied properties
				var cell_key = str(x) + "," + str(y)
				
				# Get property variations from noise
				var mass_var = noise3.get_noise_2d(x * 0.2, y * 0.2) * Constants.MASS_VARIATION_RANGE
				var damp_var = noise4.get_noise_2d(x * 0.15, y * 0.15) * Constants.DAMPENING_VARIATION_RANGE
				
				# Create a gradual shift in properties for interesting gameplay
				var horizontal_blend = float(x) / float(Constants.GRID_WIDTH)  # 0 to 1 across width
				var vertical_blend = float(y - ground_height) / float(Constants.GRID_HEIGHT - ground_height)  # 0 to 1 down from top of materials
				
				# Set different property ranges in different areas of the level
				# Left side: heavier, more dense materials
				# Right side: lighter, more fluid materials
				var mass_modifier = lerp(0.3, -0.3, horizontal_blend) + mass_var
				var dampening_modifier = lerp(0.1, -0.1, horizontal_blend) + damp_var
				
				# Create color variations that visually indicate physical properties
				# Redder = heavier, bluer = lighter
				var color_r = mass_modifier * 0.3
				var color_g = dampening_modifier * 0.2
				
				# Store properties for this cell
				cell_properties[cell_key] = {
					"mass": Constants.CELL_DEFAULTS[cell_type].mass + mass_modifier,
					"dampening": Constants.CELL_DEFAULTS[cell_type].dampening + dampening_modifier,
					"color_r": color_r,
					"color_g": color_g
				}
	
	# Add water features
	var water_noise = FastNoiseLite.new()
	water_noise.seed = randi() + 54321
	
	for x in range(Constants.GRID_WIDTH):
		for y in range(Constants.GRID_HEIGHT - 60, Constants.GRID_HEIGHT - 20):
			if x < grid.size() and y < grid[x].size():
				var water_value = water_noise.get_noise_2d(x * 0.1, y * 0.1)
				if water_value > 0.4 and grid[x][y] != Constants.CellType.EMPTY:
					# Replace some terrain with water
					grid[x][y] = Constants.CellType.WATER
					
					# Create varied water properties
					var cell_key = str(x) + "," + str(y)
					var water_depth = (y - (Constants.GRID_HEIGHT - 60)) / 40.0  # 0 to 1 based on depth
					
					# Deeper water is denser and more dampening
					cell_properties[cell_key] = {
						"mass": Constants.CELL_DEFAULTS[Constants.CellType.WATER].mass + water_depth * 0.3,
						"dampening": Constants.CELL_DEFAULTS[Constants.CellType.WATER].dampening - water_depth * 0.1,
						"color_r": -water_depth * 0.1,  # Deeper water is bluer
						"color_g": -water_depth * 0.05
					}
	
	# Make sure hole is not buried
	for x in range(hole_position.x - 2, hole_position.x + 2):
		for y in range(hole_position.y - 2, hole_position.y + 2):
			if x >= 0 and x < Constants.GRID_WIDTH and y >= 0 and y < Constants.GRID_HEIGHT and x < grid.size() and y < grid[x].size():
				if Vector2(x, y).distance_to(hole_position) < 6:
					grid[x][y] = Constants.CellType.EMPTY
	
	# Set the hole itself
	if hole_position.x < grid.size() and hole_position.y < grid[hole_position.x].size():
		grid[hole_position.x][hole_position.y] = Constants.CellType.HOLE
		
		# Add a few more hole cells to make it more visible
		for x in range(hole_position.x - 1, hole_position.x + 2):
			for y in range(hole_position.y - 1, hole_position.y + 2):
				if x >= 0 and x < Constants.GRID_WIDTH and y >= 0 and y < Constants.GRID_HEIGHT and x < grid.size() and y < grid[x].size():
					if Vector2(x, y).distance_to(hole_position) < 1.5:
						grid[x][y] = Constants.CellType.HOLE
	
	return {"grid": grid, "cell_properties": cell_properties}
