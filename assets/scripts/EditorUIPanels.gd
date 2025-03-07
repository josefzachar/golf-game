extends Node

# UI elements for panels
var property_panel: Panel
var visualization_panel: Panel
var property_labels = {}

# References
var editor
var ui_controller
var vbox  # The main VBox container

# Build the material type buttons section
func build_material_buttons():
	if not vbox:
		print("EditorUIPanels: ERROR - vbox is null")
		return
		
	print("EditorUIPanels: Building material buttons")
	
	# Create HBoxContainer for type buttons
	var hbox = HBoxContainer.new()
	vbox.add_child(hbox)
	
	# Add type buttons
	var sand_button = Button.new()
	sand_button.text = "Sand"
	sand_button.pressed.connect(func(): _safe_set_type(Constants.CellType.SAND))
	hbox.add_child(sand_button)
	
	var dirt_button = Button.new()
	dirt_button.text = "Dirt"
	dirt_button.pressed.connect(func(): _safe_set_type(Constants.CellType.DIRT))
	hbox.add_child(dirt_button)
	
	var stone_button = Button.new()
	stone_button.text = "Stone"
	stone_button.pressed.connect(func(): _safe_set_type(Constants.CellType.STONE))
	hbox.add_child(stone_button)
	
	var water_button = Button.new()
	water_button.text = "Water"
	water_button.pressed.connect(func(): _safe_set_type(Constants.CellType.WATER))
	hbox.add_child(water_button)
	
	var empty_button = Button.new()
	empty_button.text = "Empty"
	empty_button.pressed.connect(func(): _safe_set_type(Constants.CellType.EMPTY))
	hbox.add_child(empty_button)
	
	var hole_button = Button.new()
	hole_button.text = "Hole"
	hole_button.pressed.connect(func(): _safe_set_type(Constants.CellType.HOLE))
	hbox.add_child(hole_button)
	
	# Add special functions
	var set_start_button = Button.new()
	set_start_button.text = "Set Ball Start"
	set_start_button.pressed.connect(func(): _safe_set_type(Constants.CellType.BALL_START))
	vbox.add_child(set_start_button)
	
	# Add separator
	var separator = HSeparator.new()
	vbox.add_child(separator)

# Safe method to set cell type
func _safe_set_type(type):
	if ui_controller and ui_controller.brush_controller:
		ui_controller.brush_controller.set_current_type(type)
	else:
		print("EditorUIPanels: ERROR - Cannot set cell type - brush_controller is null")

# Build the brush controls section
func build_brush_controls():
	if not vbox:
		print("EditorUIPanels: ERROR - vbox is null")
		return
		
	print("EditorUIPanels: Building brush controls")
	
	# Add brush controls header
	var brush_label = Label.new()
	brush_label.text = "Brush Settings"
	vbox.add_child(brush_label)
	
	# Add brush size control
	var brush_size_hbox = HBoxContainer.new()
	vbox.add_child(brush_size_hbox)
	
	var brush_size_label = Label.new()
	brush_size_label.text = "Size:"
	brush_size_hbox.add_child(brush_size_label)
	
	var brush_size_slider = HSlider.new()
	brush_size_slider.min_value = 1
	brush_size_slider.max_value = 10
	brush_size_slider.step = 1
	
	# Set initial value safely
	var initial_brush_size = 1  # Default
	if ui_controller and ui_controller.brush_controller:
		initial_brush_size = ui_controller.brush_controller.brush_size
	brush_size_slider.value = initial_brush_size
	
	brush_size_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brush_size_slider.value_changed.connect(func(new_value): _safe_set_brush_size(int(new_value)))
	brush_size_hbox.add_child(brush_size_slider)
	
	var brush_size_value = Label.new()
	brush_size_value.text = str(initial_brush_size)
	brush_size_value.custom_minimum_size.x = 25
	brush_size_slider.value_changed.connect(func(new_value): brush_size_value.text = str(int(new_value)))
	brush_size_hbox.add_child(brush_size_value)
	
	# Add brush shape control
	var brush_shape_hbox = HBoxContainer.new()
	vbox.add_child(brush_shape_hbox)
	
	var brush_shape_label = Label.new()
	brush_shape_label.text = "Shape:"
	brush_shape_hbox.add_child(brush_shape_label)
	
	var square_button = Button.new()
	square_button.text = "Square"
	
	# We need to safely access BrushShape enum value
	var SQUARE_SHAPE = 0  # Default BrushShape.SQUARE value
	if ui_controller and ui_controller.brush_controller and ui_controller.brush_controller.has_method("get_script"):
		var script = ui_controller.brush_controller.get_script()
		if script and script.has_source_code():
			SQUARE_SHAPE = ui_controller.brush_controller.BrushShape.SQUARE
			
	square_button.pressed.connect(func(): _safe_set_brush_shape(SQUARE_SHAPE))
	brush_shape_hbox.add_child(square_button)
	
	var circle_button = Button.new()
	circle_button.text = "Circle"
	
	# We need to safely access BrushShape enum value 
	var CIRCLE_SHAPE = 1  # Default BrushShape.CIRCLE value
	if ui_controller and ui_controller.brush_controller and ui_controller.brush_controller.has_method("get_script"):
		var script = ui_controller.brush_controller.get_script()
		if script and script.has_source_code():
			CIRCLE_SHAPE = ui_controller.brush_controller.BrushShape.CIRCLE
			
	circle_button.pressed.connect(func(): _safe_set_brush_shape(CIRCLE_SHAPE))
	brush_shape_hbox.add_child(circle_button)
	
	# Add separator
	var separator = HSeparator.new()
	vbox.add_child(separator)

# Safe method to set brush size
func _safe_set_brush_size(size):
	if ui_controller and ui_controller.brush_controller:
		ui_controller.brush_controller.set_brush_size(size)
	else:
		print("EditorUIPanels: ERROR - Cannot set brush size - brush_controller is null")

# Safe method to set brush shape
func _safe_set_brush_shape(shape):
	if ui_controller and ui_controller.brush_controller:
		ui_controller.brush_controller.set_brush_shape(shape)
	else:
		print("EditorUIPanels: ERROR - Cannot set brush shape - brush_controller is null")

# Build the property controls section
func build_property_controls():
	if not vbox:
		print("EditorUIPanels: ERROR - vbox is null")
		return
		
	print("EditorUIPanels: Building property controls")
	
	# Add advanced properties toggle
	var adv_props_hbox = HBoxContainer.new()
	vbox.add_child(adv_props_hbox)
	
	var adv_props_label = Label.new()
	adv_props_label.text = "Advanced Properties:"
	adv_props_hbox.add_child(adv_props_label)
	
	var adv_props_toggle = CheckButton.new()
	adv_props_toggle.pressed.connect(func(): _safe_toggle_advanced_properties())
	adv_props_hbox.add_child(adv_props_toggle)
	
	# Create panel for advanced properties (initially hidden)
	property_panel = Panel.new()
	property_panel.custom_minimum_size = Vector2(230, 150)
	property_panel.visible = false
	vbox.add_child(property_panel)
	
	# Add sliders for mass, dampening, and color variation
	var prop_vbox = VBoxContainer.new()
	prop_vbox.position = Vector2(10, 10)
	prop_vbox.size = Vector2(210, 130)
	property_panel.add_child(prop_vbox)
	
	# Mass modifier
	var mass_label = Label.new()
	mass_label.text = "Mass Modifier:"
	prop_vbox.add_child(mass_label)
	
	var mass_slider = HSlider.new()
	mass_slider.min_value = -0.5
	mass_slider.max_value = 0.5
	mass_slider.step = 0.05
	
	# Safe initial value
	var initial_mass_mod = 0.0  # Default
	if ui_controller and ui_controller.property_controller:
		initial_mass_mod = ui_controller.property_controller.current_mass_modifier
	mass_slider.value = initial_mass_mod
	
	mass_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mass_slider.value_changed.connect(func(new_value): _safe_set_mass_modifier(new_value))
	prop_vbox.add_child(mass_slider)
	
	# Dampening modifier
	var dampening_label = Label.new()
	dampening_label.text = "Dampening Modifier:"
	prop_vbox.add_child(dampening_label)
	
	var dampening_slider = HSlider.new()
	dampening_slider.min_value = -0.15
	dampening_slider.max_value = 0.15
	dampening_slider.step = 0.01
	
	# Safe initial value
	var initial_damp_mod = 0.0  # Default
	if ui_controller and ui_controller.property_controller:
		initial_damp_mod = ui_controller.property_controller.current_dampening_modifier
	dampening_slider.value = initial_damp_mod
	
	dampening_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dampening_slider.value_changed.connect(func(new_value): _safe_set_dampening_modifier(new_value))
	prop_vbox.add_child(dampening_slider)
	
	# Color variation
	var color_label = Label.new()
	color_label.text = "Color Variation:"
	prop_vbox.add_child(color_label)
	
	var color_r_slider = HSlider.new()
	color_r_slider.min_value = -0.15
	color_r_slider.max_value = 0.15
	color_r_slider.step = 0.01
	
	# Safe initial value
	var initial_color_r = 0.0  # Default
	if ui_controller and ui_controller.property_controller:
		initial_color_r = ui_controller.property_controller.current_color_modifier.x
	color_r_slider.value = initial_color_r
	
	color_r_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_r_slider.value_changed.connect(func(new_value): _safe_set_color_r_modifier(new_value))
	prop_vbox.add_child(color_r_slider)
	
	var color_g_slider = HSlider.new()
	color_g_slider.min_value = -0.15
	color_g_slider.max_value = 0.15
	color_g_slider.step = 0.01
	
	# Safe initial value
	var initial_color_g = 0.0  # Default
	if ui_controller and ui_controller.property_controller:
		initial_color_g = ui_controller.property_controller.current_color_modifier.y
	color_g_slider.value = initial_color_g
	
	color_g_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_g_slider.value_changed.connect(func(new_value): _safe_set_color_g_modifier(new_value))
	prop_vbox.add_child(color_g_slider)
	
	# Add randomize properties button
	var randomize_button = Button.new()
	randomize_button.text = "Randomize Properties"
	randomize_button.pressed.connect(func(): _safe_randomize_properties())
	prop_vbox.add_child(randomize_button)
	
	# Add separator
	var separator = HSeparator.new()
	vbox.add_child(separator)

# Safe method to toggle advanced properties
func _safe_toggle_advanced_properties():
	if ui_controller and ui_controller.property_controller:
		ui_controller.property_controller.toggle_advanced_properties()
	else:
		print("EditorUIPanels: ERROR - Cannot toggle advanced properties - property_controller is null")

# Safe method to set mass modifier
func _safe_set_mass_modifier(value):
	if ui_controller and ui_controller.property_controller:
		ui_controller.property_controller.set_mass_modifier(value)
	else:
		print("EditorUIPanels: ERROR - Cannot set mass modifier - property_controller is null")

# Safe method to set dampening modifier
func _safe_set_dampening_modifier(value):
	if ui_controller and ui_controller.property_controller:
		ui_controller.property_controller.set_dampening_modifier(value)
	else:
		print("EditorUIPanels: ERROR - Cannot set dampening modifier - property_controller is null")

# Safe method to set color r modifier
func _safe_set_color_r_modifier(value):
	if ui_controller and ui_controller.property_controller:
		ui_controller.property_controller.set_color_modifier(value, ui_controller.property_controller.current_color_modifier.y)
	else:
		print("EditorUIPanels: ERROR - Cannot set color r modifier - property_controller is null")

# Safe method to set color g modifier
func _safe_set_color_g_modifier(value):
	if ui_controller and ui_controller.property_controller:
		ui_controller.property_controller.set_color_modifier(ui_controller.property_controller.current_color_modifier.x, value)
	else:
		print("EditorUIPanels: ERROR - Cannot set color g modifier - property_controller is null")

# Safe method to randomize properties
func _safe_randomize_properties():
	if ui_controller and ui_controller.property_controller:
		ui_controller.property_controller.randomize_property_modifiers()
	else:
		print("EditorUIPanels: ERROR - Cannot randomize properties - property_controller is null")

# Build the visualization controls section
func build_visualization_controls():
	if not vbox:
		print("EditorUIPanels: ERROR - vbox is null")
		return
		
	print("EditorUIPanels: Building visualization controls")
	
	# Add visualization toggle
	var visualization_hbox = HBoxContainer.new()
	vbox.add_child(visualization_hbox)
	
	var visualization_label = Label.new()
	visualization_label.text = "Visualize Properties:"
	visualization_hbox.add_child(visualization_label)
	
	var visualization_toggle = CheckButton.new()
	visualization_toggle.pressed.connect(func(): _safe_toggle_property_visualization())
	visualization_hbox.add_child(visualization_toggle)
	
	# Create panel for visualization options (initially hidden)
	visualization_panel = Panel.new()
	visualization_panel.custom_minimum_size = Vector2(230, 80)
	visualization_panel.visible = false
	vbox.add_child(visualization_panel)
	
	var viz_vbox = VBoxContainer.new()
	viz_vbox.position = Vector2(10, 10)
	viz_vbox.size = Vector2(210, 60)
	visualization_panel.add_child(viz_vbox)
	
	# Property to visualize
	var prop_to_vis_label = Label.new()
	prop_to_vis_label.text = "Property to visualize:"
	viz_vbox.add_child(prop_to_vis_label)
	
	var prop_options = HBoxContainer.new()
	viz_vbox.add_child(prop_options)
	
	var mass_button = Button.new()
	mass_button.text = "Mass"
	mass_button.pressed.connect(func(): _safe_set_visualization_property("mass"))
	prop_options.add_child(mass_button)
	
	var dampening_button = Button.new()
	dampening_button.text = "Dampening"
	dampening_button.pressed.connect(func(): _safe_set_visualization_property("dampening"))
	prop_options.add_child(dampening_button)
	
	# Add property labels to show when hovering over cells
	var property_info_label = Label.new()
	property_info_label.text = "Hover over cells to view properties"
	viz_vbox.add_child(property_info_label)
	
	# Create property display labels
	property_labels["position"] = Label.new()
	property_labels["position"].text = "Position: "
	property_labels["position"].visible = false
	vbox.add_child(property_labels["position"])
	
	property_labels["type"] = Label.new()
	property_labels["type"].text = "Type: "
	property_labels["type"].visible = false
	vbox.add_child(property_labels["type"])
	
	property_labels["mass"] = Label.new()
	property_labels["mass"].text = "Mass: "
	property_labels["mass"].visible = false
	vbox.add_child(property_labels["mass"])
	
	property_labels["dampening"] = Label.new()
	property_labels["dampening"].text = "Dampening: "
	property_labels["dampening"].visible = false
	vbox.add_child(property_labels["dampening"])
	
	# Add separator
	var separator = HSeparator.new()
	vbox.add_child(separator)

# Safe method to toggle property visualization
func _safe_toggle_property_visualization():
	if ui_controller and ui_controller.visualization_controller:
		ui_controller.visualization_controller.toggle_property_visualization()
	else:
		print("EditorUIPanels: ERROR - Cannot toggle property visualization - visualization_controller is null")

# Safe method to set visualization property
func _safe_set_visualization_property(property):
	if ui_controller and ui_controller.visualization_controller:
		ui_controller.visualization_controller.set_visualization_property(property)
	else:
		print("EditorUIPanels: ERROR - Cannot set visualization property - visualization_controller is null")

# Build the metadata inputs section
func build_metadata_inputs():
	if not vbox or not editor:
		print("EditorUIPanels: ERROR - vbox or editor is null")
		return
		
	print("EditorUIPanels: Building metadata inputs")
	
	# Add metadata inputs
	var metadata_grid = GridContainer.new()
	metadata_grid.columns = 2
	vbox.add_child(metadata_grid)
	
	# Level name
	var name_label = Label.new()
	name_label.text = "Level Name:"
	metadata_grid.add_child(name_label)
	
	var name_input = LineEdit.new()
	name_input.text = editor.level_name
	name_input.text_changed.connect(func(new_text): _safe_set_level_name(new_text))
	metadata_grid.add_child(name_input)
	
	# Par
	var par_label = Label.new()
	par_label.text = "Par:"
	metadata_grid.add_child(par_label)
	
	var par_input = SpinBox.new()
	par_input.min_value = 1
	par_input.max_value = 10
	par_input.value = editor.level_par
	par_input.value_changed.connect(func(new_value): _safe_set_level_par(int(new_value)))
	metadata_grid.add_child(par_input)
	
	# Description
	var desc_label = Label.new()
	desc_label.text = "Description:"
	metadata_grid.add_child(desc_label)
	
	var desc_input = LineEdit.new()
	desc_input.text = editor.level_description
	desc_input.text_changed.connect(func(new_text): _safe_set_level_description(new_text))
	metadata_grid.add_child(desc_input)
	
	# Add separator
	var separator = HSeparator.new()
	vbox.add_child(separator)

# Safe method to set level name
func _safe_set_level_name(name):
	if editor:
		editor.level_name = name
	else:
		print("EditorUIPanels: ERROR - Cannot set level name - editor is null")

# Safe method to set level par
func _safe_set_level_par(par):
	if editor:
		editor.level_par = par
	else:
		print("EditorUIPanels: ERROR - Cannot set level par - editor is null")

# Safe method to set level description
func _safe_set_level_description(description):
	if editor:
		editor.level_description = description
	else:
		print("EditorUIPanels: ERROR - Cannot set level description - editor is null")

# Build the file operations section
func build_file_operations():
	if not vbox or not editor:
		print("EditorUIPanels: ERROR - vbox or editor is null")
		return
		
	print("EditorUIPanels: Building file operations")
	
	# Add file operations header
	var file_label = Label.new()
	file_label.text = "File Operations"
	vbox.add_child(file_label)
	
	# Add file operation buttons
	var file_buttons_hbox = HBoxContainer.new()
	vbox.add_child(file_buttons_hbox)
	
	var new_button = Button.new()
	new_button.text = "New"
	new_button.pressed.connect(func(): _safe_new_level())
	file_buttons_hbox.add_child(new_button)
	
	var load_button = Button.new()
	load_button.text = "Load"
	load_button.pressed.connect(func(): _safe_load_level())
	file_buttons_hbox.add_child(load_button)
	
	var save_button = Button.new()
	save_button.text = "Save"
	save_button.pressed.connect(func(): _safe_save_level())
	file_buttons_hbox.add_child(save_button)
	
	# Add separator
	var separator = HSeparator.new()
	vbox.add_child(separator)

# Safe method to create new level
func _safe_new_level():
	if editor:
		editor.new_level()
	else:
		print("EditorUIPanels: ERROR - Cannot create new level - editor is null")

# Safe method to load level
func _safe_load_level():
	if editor:
		editor.load_level()
	else:
		print("EditorUIPanels: ERROR - Cannot load level - editor is null")

# Safe method to save level
func _safe_save_level():
	if editor:
		editor.save_level()
	else:
		print("EditorUIPanels: ERROR - Cannot save level - editor is null")

# Build the navigation buttons section
func build_navigation_buttons():
	if not vbox or not editor:
		print("EditorUIPanels: ERROR - vbox or editor is null")
		return
		
	print("EditorUIPanels: Building navigation buttons")
	
	# Add navigation buttons
	var test_button = Button.new()
	test_button.text = "Test Play Level"
	test_button.pressed.connect(func(): _safe_test_level())
	vbox.add_child(test_button)
	
	var menu_button = Button.new()
	menu_button.text = "Return to Main Menu"
	menu_button.pressed.connect(func(): _safe_return_to_menu())
	vbox.add_child(menu_button)

# Safe method to test level
func _safe_test_level():
	if editor:
		editor.test_level()
	else:
		print("EditorUIPanels: ERROR - Cannot test level - editor is null")

# Safe method to return to menu
func _safe_return_to_menu():
	if editor:
		editor.return_to_main_menu()
	else:
		print("EditorUIPanels: ERROR - Cannot return to menu - editor is null")
