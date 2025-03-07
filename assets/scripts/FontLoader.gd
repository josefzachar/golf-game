class_name FontLoader
extends RefCounted

# Helper class to load and cache fonts

static func get_default_font():
	# In Godot 4, you can access the default theme font
	return ThemeDB.fallback_font
