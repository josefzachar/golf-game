extends Node

# Class to handle saving level data to files

static func save_level_to_path(editor, path):
	print("LevelSaver: Saving level to path: " + path)
	
	# Create the level data dictionary
	var level_data = {
		"name": editor.level_name,
		"description": editor.level_description,
		"difficulty": editor.level_difficulty,
		"par": editor.level_par,
		"hole_position": {
			"x": editor.hole_position.x,
			"y": editor.hole_position.y
		},
		"starting_position": {
			"x": editor.ball_start_position.x,
			"y": editor.ball_start_position.y
		},
		"terrain": []
	}
	
	# Add all non-empty cells to the terrain data
	for x in range(Constants.GRID_WIDTH):
		for y in range(Constants.GRID_HEIGHT):
			# Only save non-empty cells to reduce file size
			if editor.grid[x][y].type != Constants.CellType.EMPTY:
				var cell_data = {
					"x": x,
					"y": y,
					"type": EditorCell.cell_type_to_string(editor.grid[x][y].type),
					"properties": {
						"mass": editor.grid[x][y].mass,
						"dampening": editor.grid[x][y].dampening,
						"color_r": editor.grid[x][y].color_variation.x,
						"color_g": editor.grid[x][y].color_variation.y
					}
				}
				level_data.terrain.append(cell_data)
	
	# Convert to JSON
	var json_text = JSON.stringify(level_data, "  ")
	
	# Create directory if it doesn't exist
	var dir = path.get_base_dir()
	var dir_access = DirAccess.open("user://")
	if dir != "user://" and not dir_access.dir_exists(dir.trim_prefix("user://")):
		dir_access.make_dir_recursive(dir.trim_prefix("user://"))
	
	# Write to file
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(json_text)
		file.close()
		print("LevelSaver: Level saved successfully")
		return true
	else:
		print("LevelSaver: Failed to save level - Could not open file for writing")
		return false
