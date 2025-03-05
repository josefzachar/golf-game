extends Node

# Level management variables
var levels = []
var current_level_index = 0
var level_directories = ["res://assets/levels/", "user://levels/"]

signal level_selected(level_info)

func _ready():
	# Scan for available levels
	scan_levels()

func scan_levels():
	levels.clear()
	
	# Add the default procedural level
	levels.append({
		"name": "Procedural Level",
		"path": "",
		"description": "Randomly generated level",
		"type": "procedural"
	})
	
	# Scan each directory for level files
	for dir_path in level_directories:
		var dir = DirAccess.open(dir_path)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			
			while file_name != "":
				if not dir.current_is_dir() and file_name.ends_with(".json"):
					var level_path = dir_path + file_name
					var level_info = load_level_metadata(level_path)
					
					if level_info:
						level_info["path"] = level_path
						level_info["type"] = "json"
						levels.append(level_info)
				
				file_name = dir.get_next()
	
	print("Found ", levels.size(), " levels")

func load_level_metadata(level_path):
	var file = FileAccess.open(level_path, FileAccess.READ)
	if not file:
		return null
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		print("JSON Parse Error for ", level_path, ": ", json.get_error_message())
		return null
	
	var map_data = json.get_data()
	
	# Check for required fields
	if not map_data.has("name"):
		map_data["name"] = level_path.get_file().get_basename()
	
	if not map_data.has("description"):
		map_data["description"] = "No description available"
	
	if not map_data.has("par"):
		map_data["par"] = 3
	
	return {
		"name": map_data.name,
		"description": map_data.description,
		"par": map_data.par,
		"difficulty": map_data.get("difficulty", "medium")
	}

func get_level_count():
	return levels.size()

func get_level_info(index):
	if index >= 0 and index < levels.size():
		return levels[index]
	return null

func get_current_level():
	return get_level_info(current_level_index)

func select_level(index):
	if index >= 0 and index < levels.size():
		current_level_index = index
		var level_info = levels[current_level_index]
		emit_signal("level_selected", level_info)
		return level_info
	return null

func select_next_level():
	var next_index = (current_level_index + 1) % levels.size()
	return select_level(next_index)

func select_previous_level():
	var prev_index = (current_level_index - 1)
	if prev_index < 0:
		prev_index = levels.size() - 1
	return select_level(prev_index)

func add_custom_level(level_path):
	# Check if the level exists and is valid
	var level_info = load_level_metadata(level_path)
	if level_info:
		level_info["path"] = level_path
		level_info["type"] = "json"
		levels.append(level_info)
		
		# Select the new level
		select_level(levels.size() - 1)
		return true
	
	return false
