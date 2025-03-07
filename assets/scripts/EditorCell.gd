extends Node

# Static class for creating and managing cell objects

# Helper function to create a cell with properties
static func create_cell(type):
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

# Helper function to convert string to cell type
static func string_to_cell_type(type_str):
	match type_str:
		"sand":
			return Constants.CellType.SAND
		"dirt":
			return Constants.CellType.DIRT
		"stone":
			return Constants.CellType.STONE
		"water":
			return Constants.CellType.WATER
		"hole":
			return Constants.CellType.HOLE
		"ball_start":
			return Constants.CellType.BALL_START
		_:
			return Constants.CellType.EMPTY

# Helper function to convert cell type to string
static func cell_type_to_string(type):
	match type:
		Constants.CellType.SAND:
			return "sand"
		Constants.CellType.DIRT:
			return "dirt"
		Constants.CellType.STONE:
			return "stone"
		Constants.CellType.WATER:
			return "water"
		Constants.CellType.HOLE:
			return "hole"
		Constants.CellType.BALL_START:
			return "ball_start"
		_:
			return "empty"

# Get a descriptive name for a cell type
static func get_cell_type_name(type):
	match type:
		Constants.CellType.SAND:
			return "Sand"
		Constants.CellType.DIRT:
			return "Dirt"
		Constants.CellType.STONE:
			return "Stone"
		Constants.CellType.WATER:
			return "Water"
		Constants.CellType.HOLE:
			return "Hole"
		Constants.CellType.BALL_START:
			return "Ball Start"
		Constants.CellType.EMPTY:
			return "Empty"
		_:
			return "Unknown"

# Apply property modifiers to a cell (for custom brushes)
static func apply_modifiers_to_cell(cell, mass_mod, dampening_mod, color_mod):
	# Only apply to non-empty, non-hole cells
	if cell.type != Constants.CellType.EMPTY and cell.type != Constants.CellType.HOLE:
		# Adjust mass
		cell.mass += mass_mod
		
		# Adjust dampening (make sure it doesn't go below 0)
		cell.dampening += dampening_mod
		cell.dampening = max(0.1, cell.dampening)
		
		# Adjust color variation
		cell.color_variation.x += color_mod.x
		cell.color_variation.y += color_mod.y
	
	return cell
