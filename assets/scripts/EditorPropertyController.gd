extends Node

# Advanced cell properties
var custom_property_mode = false  # Toggle for advanced property editing
var current_mass_modifier = 0.0  # -0.5 to 0.5
var current_dampening_modifier = 0.0  # -0.15 to 0.15
var current_color_modifier = Vector2.ZERO  # Color variation for r,g

# References
var editor
var ui_controller

# Functions for advanced property handling
func toggle_advanced_properties():
	custom_property_mode = !custom_property_mode
	ui_controller.property_panel.visible = custom_property_mode
	
	if custom_property_mode:
		ui_controller.update_status("Custom Properties Enabled")
	else:
		# Update label to current cell type
		ui_controller.update_type_label(ui_controller.brush_controller.current_cell_type)

func set_mass_modifier(value):
	current_mass_modifier = value
	ui_controller.update_status("Mass Modifier: " + str(snapped(value, 0.01)))

func set_dampening_modifier(value):
	current_dampening_modifier = value
	ui_controller.update_status("Dampening Modifier: " + str(snapped(value, 0.01)))

func set_color_modifier(r_value, g_value):
	current_color_modifier = Vector2(r_value, g_value)
	ui_controller.update_status("Color Modifier: R:" + str(snapped(r_value, 0.01)) + ", G:" + str(snapped(g_value, 0.01)))

func randomize_property_modifiers():
	current_mass_modifier = randf_range(-0.5, 0.5)
	current_dampening_modifier = randf_range(-0.15, 0.15)
	current_color_modifier.x = randf_range(-0.15, 0.15)
	current_color_modifier.y = randf_range(-0.15, 0.15)
	ui_controller.update_status("Properties randomized")
