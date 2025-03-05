extends Node

# Static function to initialize a new grid
static func create_grid(hole_position):
	var grid = []
	
	# Create empty grid
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

# Load a map from JSON file
static func load_from_json(file_path):
	var grid = []
	var hole_position = Vector2.ZERO
	
	# Initialize empty grid
	for x in range(Constants.GRID_WIDTH):
		var column = []
		for y in range(Constants.GRID_HEIGHT):
			column.append(Constants.CellType.EMPTY)
		grid.append(column)
	
	# Load and parse JSON file
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("Error: Could not open file ", file_path)
		return {"grid": create_grid(Vector2(150, 112)), "hole_position": Vector2(150, 112)}
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		print("JSON Parse Error: ", json.get_error_message(), " at line ", json.get_error_line())
		return {"grid": create_grid(Vector2(150, 112)), "hole_position": Vector2(150, 112)}
	
	var map_data = json.get_data()
	
	# Check if the expected data exists
	if not map_data.has("terrain") or not map_data.has("hole_position"):
		print("Error: JSON file missing required fields (terrain and/or hole_position)")
		return {"grid": create_grid(Vector2(150, 112)), "hole_position": Vector2(150, 112)}
	
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
				"water":
					grid[x][y] = Constants.CellType.WATER
				"hole":
					grid[x][y] = Constants.CellType.HOLE
				_:
					grid[x][y] = Constants.CellType.EMPTY
	
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
	
	return {"grid": grid, "hole_position": hole_position}

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
	
	# Print debug info about the hole
	print("Hole position: ", hole_position)
	if hole_position.x < grid.size() and hole_position.y < grid[hole_position.x].size():
		print("Cell type at hole position: ", grid[hole_position.x][hole_position.y])
	
	return grid
