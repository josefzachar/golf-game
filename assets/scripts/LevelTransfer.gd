extends Node

# Simple singleton to pass level data between scenes
# Add this script as an AutoLoad in Project Settings

var current_level_info = null
var is_from_editor = false

func set_level_for_transfer(level_info):
	print("LevelTransfer: Setting level data: ", level_info)
	current_level_info = level_info
	is_from_editor = true
	
func get_level_info():
	var info = current_level_info
	return info
	
func clear_level_info():
	current_level_info = null
	is_from_editor = false
	
func is_level_from_editor():
	return is_from_editor
